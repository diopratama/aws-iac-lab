output "instance_id" {
  value       = module.elasticsearch.instance_id
  description = "EC2 Instance ID for AWS Systems Manager connection"
}

output "ssm_connect_command" {
  value       = module.elasticsearch.ssm_connect_command
  description = "CLI command to open interactive shell session via AWS SSM"
}

output "ssm_port_forward_command" {
  value       = module.elasticsearch.ssm_port_forward_command
  description = "CLI command to tunnel Elasticsearch port 9200 securely to localhost"
}

output "curl_test_command" {
  value       = module.elasticsearch.curl_test_command
  sensitive   = true
  description = "cURL validation command (run after establishing SSM port forwarding)"
}
