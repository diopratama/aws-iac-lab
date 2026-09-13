output "primary_instance_id" {
  value       = module.elasticsearch.primary_instance_id
  description = "Primary EC2 Instance ID for SSM connection target"
}

output "instance_ids" {
  value       = module.elasticsearch.instance_ids
  description = "All EC2 Instance IDs in the cluster"
}

output "instance_private_ips" {
  value       = module.elasticsearch.instance_private_ips
  description = "Private IP addresses of all 3 cluster nodes"
}

output "ilb_dns_name" {
  value       = module.elasticsearch.ilb_dns_name
  description = "Internal Application Load Balancer DNS name"
}

output "ssm_connect_command" {
  value       = module.elasticsearch.ssm_connect_command
  description = "CLI command to open interactive shell session via AWS SSM"
}

output "ssm_ilb_port_forward_command" {
  value       = module.elasticsearch.ssm_ilb_port_forward_command
  description = "CLI command to tunnel ILB port 9200 securely to localhost via AWS SSM Remote Host"
}

output "curl_test_command" {
  value       = module.elasticsearch.curl_test_command
  sensitive   = true
  description = "cURL validation command (run after establishing SSM port forwarding)"
}
