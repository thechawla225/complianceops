$region    = "us-west-2"
$accountId = (aws sts get-caller-identity --query Account --output text)
$registry  = "$accountId.dkr.ecr.$region.amazonaws.com"

# --- ECR login: bypass docker login (BOM-corruption issue), write ~/.docker/config.json directly ---
$password    = aws ecr get-login-password --region $region
$authBytes   = [System.Text.Encoding]::UTF8.GetBytes("AWS:$password")
$authBase64  = [Convert]::ToBase64String($authBytes)

$dockerConfigDir = Join-Path $HOME ".docker"
if (-not (Test-Path $dockerConfigDir)) {
    New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
}
$dockerConfigPath = Join-Path $dockerConfigDir "config.json"

$configJson = @{ auths = @{ $registry = @{ auth = $authBase64 } } } | ConvertTo-Json -Depth 5

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($dockerConfigPath, $configJson, $utf8NoBom)

Write-Host "Logged in to $registry" -ForegroundColor Green

# --- Build + push ---
$services = @("gateway", "transaction", "screening", "notifier")   # trim this list if you only need some

# Point gitops/<svc>/values-dev.yaml at the image that's in ECR, so deploys always use the latest upload.
# Only replaces the quoted value of the first "  tag:" line (the image tag); written without a BOM.
function Set-DevImageTag($svc, $tag) {
    $file = Join-Path $PSScriptRoot "..\gitops\$svc\values-dev.yaml"
    $text = [System.IO.File]::ReadAllText($file)
    $new  = ([regex]'(?m)^(  tag:\s*)"[^"]*"').Replace($text, ('${1}"' + $tag + '"'), 1)
    [System.IO.File]::WriteAllText($file, $new, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "values-dev.yaml -> tag $tag" -ForegroundColor Green
}

foreach ($svc in $services) {
    $repo   = "complianceops-$svc"
    # Service source lives in repos next to this one: ..\..\complianceops-<svc>service
    $srcDir = Join-Path $PSScriptRoot "..\..\complianceops-${svc}service"

    Write-Host "`n=== $svc ===" -ForegroundColor Cyan

    # Tag = short commit SHA of the service repo, so the tag always maps to exact source.
    # Uncommitted changes would make the tag lie, so refuse to build those.
    if (git -C $srcDir status --porcelain) { Write-Host "$svc has uncommitted changes - commit first, skipping" -ForegroundColor Red; continue }
    $tag      = git -C $srcDir rev-parse --short HEAD
    $imageUri = "${registry}/${repo}:${tag}"

    # Repos are IMMUTABLE: same SHA = same code, so an existing tag means nothing to do
    aws ecr describe-images --region $region --repository-name $repo --image-ids imageTag=$tag 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "$svc already pushed as $imageUri" -ForegroundColor Yellow; Set-DevImageTag $svc $tag; continue }

    docker build -t $imageUri $srcDir
    if ($LASTEXITCODE -ne 0) { Write-Host "Build failed for $svc" -ForegroundColor Red; continue }

    docker push $imageUri
    if ($LASTEXITCODE -ne 0) { Write-Host "Push failed for $svc" -ForegroundColor Red; continue }

    Write-Host "$svc pushed as $imageUri" -ForegroundColor Green
    Set-DevImageTag $svc $tag
}

Write-Host "`nCommit the updated gitops/*/values-dev.yaml in complianceops so the deployed tags are recorded in git." -ForegroundColor Cyan
