output "master_node_public_ip" {
  description = "Public IP of the master node"
  value       = aws_instance.k8s_master.public_ip
}

output "worker_node_public_ip" {
  description = "Public IP of the worker node"
  value       = aws_instance.k8s_worker.public_ip
}
