output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "prometheus_instance_id" {
  description = "Prometheus EC2 instance ID"
  value       = aws_instance.prometheus.id
}

output "prometheus_private_ip" {
  description = "Prometheus private IP address"
  value       = aws_instance.prometheus.private_ip
}

output "grafana_instance_id" {
  description = "Grafana EC2 instance ID"
  value       = aws_instance.grafana.id
}

output "grafana_private_ip" {
  description = "Grafana private IP address"
  value       = aws_instance.grafana.private_ip
}

output "application_instance_id" {
  description = "Application EC2 instance ID"
  value       = aws_instance.application.id
}

output "application_private_ip" {
  description = "Application private IP address"
  value       = aws_instance.application.private_ip
}

output "session_manager_command" {
  description = "Command to connect via Session Manager"
  value       = "aws ssm start-session --target <instance-id>"
}

output "grafana_port_forward_command" {
  description = "Command to port forward Grafana via Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.grafana.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3000\"],\"localPortNumber\":[\"3000\"]}'"
}

output "prometheus_port_forward_command" {
  description = "Command to port forward Prometheus via Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.prometheus.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"9090\"],\"localPortNumber\":[\"9090\"]}'"
}

output "ssh_private_key_path" {
  description = "Path to generated SSH private key"
  value       = "${path.module}/../keys/id_rsa"
  sensitive   = true
}
