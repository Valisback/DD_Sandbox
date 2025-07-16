terraform {
  required_version = ">= 1.0"
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "~> 0.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure the providers
provider "minikube" {
  kubernetes_version = var.kubernetes_version
}

provider "kubernetes" {
  host                   = minikube_cluster.datadog_sandbox.host
  client_certificate     = minikube_cluster.datadog_sandbox.client_certificate
  client_key            = minikube_cluster.datadog_sandbox.client_key
  cluster_ca_certificate = minikube_cluster.datadog_sandbox.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = minikube_cluster.datadog_sandbox.host
    client_certificate     = minikube_cluster.datadog_sandbox.client_certificate
    client_key            = minikube_cluster.datadog_sandbox.client_key
    cluster_ca_certificate = minikube_cluster.datadog_sandbox.cluster_ca_certificate
  }
}

# Create minikube cluster
resource "minikube_cluster" "datadog_sandbox" {
  cluster_name = var.cluster_name
  driver       = var.minikube_driver
  
  # Configure for 3 nodes
  nodes = var.node_count
  
  # Memory and CPU configuration
  memory    = var.node_memory
  cpus      = var.node_cpus
  disk_size = var.node_disk_size
  
  # Enable required addons
  addons = [
    "default-storageclass",
    "storage-provisioner",
    "metrics-server",
    "dashboard"
  ]
  
  # Configure container runtime
  container_runtime = "containerd"
  
  # Enable CNI
  cni = "auto"
  
  # Wait for the cluster to be ready
  wait = ["all"]
}

# Create Datadog namespace
resource "kubernetes_namespace" "datadog" {
  metadata {
    name = var.datadog_namespace
    labels = {
      name        = var.datadog_namespace
      environment = var.environment
    }
  }
  
  depends_on = [minikube_cluster.datadog_sandbox]
}

# Create monitoring namespace for additional tools
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = var.environment
    }
  }
  
  depends_on = [minikube_cluster.datadog_sandbox]
} 