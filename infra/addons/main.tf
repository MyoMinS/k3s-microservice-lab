terraform {
  backend "s3" {

    bucket = "terraform-state-file-store-mms"
    key = "envs/addons/terraform.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    #use_lockfile = true
  }
  required_version = ">= 1.6.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}

provider "helm" {
  kubernetes  {
    config_path = var.kubeconfig_path
  }
}

# Gateway API CRDs are not shipped with k3s or Traefik. The host running
# Terraform must have kubectl and internet access. CRDs intentionally remain
# after terraform destroy to avoid deleting existing Gateway/HTTPRoute objects.
#resource "terraform_data" "gateway_api" {
#  triggers_replace = "v1.6.3"
#  provisioner "local-exec" {
#    command = "kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.3/standard-install.yaml && kubectl wait --for=condition=Established --timeout=120s crd/gateways.gateway.networking.k8s.io crd/gatewayclasses.gateway.networking.k8s.io crd/httproutes.gateway.networking.k8s.io"
#    environment = {
#      KUBECONFIG = var.kubeconfig_path
#    }
#  }
#}

resource "terraform_data" "helm_repo_update" {
  provisioner "local-exec" {
    command = "helm repo update"
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.15.1"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600
  values           = [file("${path.module}/cert-manager-values.yaml")]
  depends_on       = [terraform_data.helm_repo_update]
}

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "42.4.2"
  namespace        = "traefik"
  create_namespace = true
  wait             = true
  timeout          = 600
  values           = [file("${path.module}/traefik-values.yaml")]
#  depends_on       = [terraform_data.gateway_api]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.18.2"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600
  values           = [file("${path.module}/argocd-values.yaml")]
}


resource "helm_release" "external-secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.15.0"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 600
  values           = [file("${path.module}/external-secrets-values.yaml")]
}