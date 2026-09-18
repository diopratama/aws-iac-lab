output "asg_name" {
  value       = module.elasticsearch.asg_name
  description = "Auto Scaling Group name"
}

output "asg_id" {
  value       = module.elasticsearch.asg_id
  description = "Auto Scaling Group ID"
}

output "launch_template_id" {
  value       = module.elasticsearch.launch_template_id
  description = "Launch Template ID for cluster nodes"
}

output "ilb_dns_name" {
  value       = module.elasticsearch.ilb_dns_name
  description = "Internal Application Load Balancer DNS name"
}

output "ssm_connect_command" {
  value       = module.elasticsearch.ssm_connect_command
  description = "CLI command to open interactive shell session via AWS SSM to an active cluster node"
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
