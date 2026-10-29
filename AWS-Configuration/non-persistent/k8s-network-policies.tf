
resource "kubernetes_network_policy" "default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}


resource "kubernetes_network_policy" "allow_dns" {
  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}


resource "kubernetes_network_policy" "gateway" {
  metadata {
    name      = "gateway-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "gateway" }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {

      ports { port = 8000 }
    }
    egress {
      to {
        pod_selector {
          match_labels = { app = "transaction" }
        }
      }
      ports { port = 8000 }
    }
  }
}


resource "kubernetes_network_policy" "transaction" {
  metadata {
    name      = "transaction-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "transaction" }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "gateway" }
        }
      }
      ports { port = 8000 }
    }
    egress {
      to {
        pod_selector {
          match_labels = { app = "screening" }
        }
      }
      ports { port = 8002 }
    }
    egress {
      to {
        pod_selector {
          match_labels = { app = "postgres" }
        }
      }
      ports { port = 5432 }
    }
    # SQS + STS (IRSA) are public AWS endpoints with changing IPs. Prod: VPC endpoints + VPC CIDR only.
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}


resource "kubernetes_network_policy" "postgres" {
  metadata {
    name      = "postgres-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "postgres" }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "transaction" }
        }
      }
      ports { port = 5432 }
    }
  }
}


resource "kubernetes_network_policy" "screening" {
  metadata {
    name      = "screening-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "screening" }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "transaction" }
        }
      }
      ports { port = 8002 }
    }
    egress {
      to {
        pod_selector {
          match_labels = { app = "redis" }
        }
      }
      ports { port = 6379 }
    }
  }
}


resource "kubernetes_network_policy" "redis" {
  metadata {
    name      = "redis-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "redis" }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "screening" }
        }
      }
      ports { port = 6379 }
    }
  }
}


resource "kubernetes_network_policy" "notifier" {
  metadata {
    name      = "notifier-policy"
    namespace = kubernetes_namespace.sanctions_platform.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "notifier" }
    }
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}
