output "cluster_name" {
  description = "Name of the minikube cluster"
  value       = minikube_cluster.datadog_sandbox.cluster_name
}

# Note: minikube_cluster resource does not expose status attribute
# Use kubectl or minikube commands to check cluster status

output "cluster_host" {
  description = "Kubernetes cluster host"
  value       = minikube_cluster.datadog_sandbox.host
  sensitive   = true
}

output "cluster_nodes" {
  description = "Number of nodes in the cluster"
  value       = minikube_cluster.datadog_sandbox.nodes
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = minikube_cluster.datadog_sandbox.kubernetes_version
}

# Note: minikube_cluster resource does not expose ip attribute
# Use 'minikube ip' command to get cluster IP

output "datadog_namespace" {
  description = "Datadog namespace name"
  value       = kubernetes_namespace.datadog.metadata[0].name
}

output "monitoring_namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = "${path.cwd}/kubeconfig-${var.cluster_name}"
}

output "dashboard_url" {
  description = "Kubernetes dashboard URL (run 'minikube dashboard' to access)"
  value       = "Use 'minikube dashboard --url' to get the dashboard URL"
}

output "cluster_info" {
  description = "Cluster information summary"
  value = {
    name               = minikube_cluster.datadog_sandbox.cluster_name
    nodes              = minikube_cluster.datadog_sandbox.nodes
    kubernetes_version = minikube_cluster.datadog_sandbox.kubernetes_version
    host               = minikube_cluster.datadog_sandbox.host
    # Note: status and ip are not available from the resource
    # Use 'minikube status' and 'minikube ip' commands for these values
  }
} 