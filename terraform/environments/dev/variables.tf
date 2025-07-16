variable "cluster_name" {
  description = "Name of the minikube cluster"
  type        = string
  default     = "dd-sandbox-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "v1.28.3"
}

variable "minikube_driver" {
  description = "Minikube driver to use (docker, hyperkit, virtualbox, etc.)"
  type        = string
  default     = "docker"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3
}

variable "node_memory" {
  description = "Memory allocation per node in MB"
  type        = string
  default     = "4096"
}

variable "node_cpus" {
  description = "CPU allocation per node"
  type        = string
  default     = "2"
}

variable "node_disk_size" {
  description = "Disk size per node"
  type        = string
  default     = "20g"
}

variable "datadog_namespace" {
  description = "Kubernetes namespace for Datadog agent"
  type        = string
  default     = "datadog"
}

# Note: Datadog API keys are managed in configs/config.yaml
# and passed to Helm during deployment, not via Terraform

# Note: All Datadog configuration is now managed in configs/config.yaml
# Terraform only handles infrastructure (cluster, nodes, namespaces) 