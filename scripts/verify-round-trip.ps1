#requires -Version 5.1
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptDir "..")

try {
    Write-Host "Building and starting the stack..."
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

    Write-Host "Waiting for the gateway to report healthy..."
    $status = "starting"
    for ($i = 0; $i -lt 30; $i++) {
        $containerId = docker compose ps -q gateway
        if ($containerId) {
            $status = docker inspect --format='{{.State.Health.Status}}' $containerId 2>$null
        }
        if ($status -eq "healthy") { break }
        Start-Sleep -Seconds 2
    }
    if ($status -ne "healthy") {
        Write-Host "gateway never became healthy" -ForegroundColor Red
        docker compose logs
        throw "gateway unhealthy"
    }

    Write-Host "Posting a transaction through the Gateway..."
    $body = @{
        endToEndId       = "REF-ROUNDTRIP"
        debtor           = @{ name = "Debtor Exports Ltd" }
        creditor         = @{ name = "Creditor Trading Co" }
        instructedAmount = @{ amount = "1020.00"; currency = "USD" }
    } | ConvertTo-Json

    $resp = Invoke-RestMethod -Method POST http://localhost:8000/transactions `
        -Headers @{ "x-api-key" = "dev-secret-key" } -ContentType "application/json" -Body $body
    $resp | ConvertTo-Json

    if ($resp.status -ne "clear") {
        throw "expected status 'clear' (the hardcoded Screening stub), got '$($resp.status)'"
    }

    Write-Host "Fetching it back by id ($($resp.id))..."
    $getResp = Invoke-RestMethod -Method GET "http://localhost:8000/transactions/$($resp.id)" `
        -Headers @{ "x-api-key" = "dev-secret-key" }
    if ($getResp.id -ne $resp.id) {
        throw "GET returned a different id than the one just created"
    }

    Write-Host "Round trip OK - Gateway, Transaction Service, and Postgres are wired correctly." -ForegroundColor Green
}
finally {
    Write-Host "Tearing down..."
    docker compose down -v
}