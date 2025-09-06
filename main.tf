provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "msur" {
  name = var.kubernetes_cluster_id
}

# Kubernetes provider: dùng exec -> aws eks get-token (v1beta1)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.msur.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.msur.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", data.aws_eks_cluster.msur.name,
      "--region", var.aws_region
    ]
  }
}

# Helm provider (v3): kubernetes là attribute object, exec = { ... }
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.msur.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.msur.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", data.aws_eks_cluster.msur.name,
        "--region", var.aws_region
      ]
    }
  }
}

resource "kubernetes_namespace" "argo-ns" {
  metadata { name = "argocd" }
}

resource "helm_release" "argocd" {
  name       = "msur"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = kubernetes_namespace.argo-ns.metadata[0].name
  depends_on = [kubernetes_namespace.argo-ns]
}
