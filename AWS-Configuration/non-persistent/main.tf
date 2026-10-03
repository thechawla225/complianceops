provider "aws" {
  region = "us-west-2"
}


data "aws_sqs_queue" "flagged_transactions" {
  name = "complianceops-flagged-transactions"
}

// -----------------------------------------------------VPC Configuration-----------------------------------------------------

module "vpc" {
  // Added Source with commit hash as per checkov suggestion to prevent supply chain attack
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=b3abd6df2ecf052451a361ed55b8f06f8742a795"

  name = "complianceops-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

// -----------------------------------------------------EKS Configuration-----------------------------------------------------
// Adding some logic so that I dont have to comment and uncomment eks_managed_node_groups in the module "eks" block

variable "create_node_group" {
  type    = bool
  default = true
}

module "eks" {
  // Added Source with commit hash as per checkov suggestion to prevent supply chain attack
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=d386adc021dc370efe1bceb7991fbed6e9787c84"

  kubernetes_version = "1.35"

  name = "complianceops-eks"

  // Allow cluster access, but only to the admin
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  // Added logic to prevent repeated uncommenting and commenting
  eks_managed_node_groups = var.create_node_group ? {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  } : null
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

// -----------------------------------------------------EBS CSI (IRSA, tied to this cluster's OIDC provider)-----------------------------------------------------

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "complianceops-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
}

// -----------------------------------------------------Namespace / RBAC / Quotas-----------------------------------------------------

resource "kubernetes_namespace" "sanctions_platform" {
  metadata {
    name = "sanctions-platform"
  }
}

resource "kubernetes_service_account" "sanctions_platform_sa" {
  metadata {
    name      = "sanctions-platform-sa"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
}

resource "kubernetes_role" "sanctions_platform_dev" {
  metadata {
    name      = "sanctions-platform-dev"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  rule {
    api_groups = ["", "apps"]
    resources  = ["pods", "deployments", "services", "configmaps", "pods/log"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "sanctions_platform_dev" {
  metadata {
    name      = "sanctions-platform-dev-binding"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.sanctions_platform_dev.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.sanctions_platform_sa.metadata[0].name
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
}

resource "kubernetes_resource_quota" "sanctions_platform" {
  metadata {
    name      = "sanctions-platform-quota"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"            = "20"
    }
  }
}

resource "kubernetes_limit_range" "sanctions_platform" {
  metadata {
    name      = "sanctions-platform-limits"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "250m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

// -----------------------------------------------------SQS app roles (IRSA, tied to this cluster's OIDC provider)-----------------------------------------------------

resource "kubernetes_service_account" "transaction_sa" {
  metadata {
    name      = "transaction-sa"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.transaction_sqs.arn
    }
  }
}

resource "kubernetes_service_account" "notifier_sa" {
  metadata {
    name      = "notifier-sa"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.notifier_sqs.arn
    }
  }
}

// --- transaction: send only ---
data "aws_iam_policy_document" "transaction_sqs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:sanctions-platform:transaction-sa"]
    }
  }
}

resource "aws_iam_role" "transaction_sqs" {
  name               = "complianceops-transaction-sqs-role"
  assume_role_policy = data.aws_iam_policy_document.transaction_sqs_assume_role.json
}

data "aws_iam_policy_document" "transaction_sqs" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    resources = [data.aws_sqs_queue.flagged_transactions.arn]
  }
}

resource "aws_iam_role_policy" "transaction_sqs" {
  name   = "complianceops-transaction-sqs-policy"
  role   = aws_iam_role.transaction_sqs.id
  policy = data.aws_iam_policy_document.transaction_sqs.json
}

// --- notifier: receive/delete only ---
data "aws_iam_policy_document" "notifier_sqs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:sanctions-platform:notifier-sa"]
    }
  }
}

resource "aws_iam_role" "notifier_sqs" {
  name               = "complianceops-notifier-sqs-role"
  assume_role_policy = data.aws_iam_policy_document.notifier_sqs_assume_role.json
}

data "aws_iam_policy_document" "notifier_sqs" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [data.aws_sqs_queue.flagged_transactions.arn]
  }
}

resource "aws_iam_role_policy" "notifier_sqs" {
  name   = "complianceops-notifier-sqs-policy"
  role   = aws_iam_role.notifier_sqs.id
  policy = data.aws_iam_policy_document.notifier_sqs.json
}