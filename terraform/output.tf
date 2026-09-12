output "instance_id" {
  value       = aws_instance.elasticsearch.id
  description = "EC2 Instance ID for AWS Systems Manager connection"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.elasticsearch.id}"
  description = "CLI command to open interactive shell session via AWS SSM (No SSH key needed)"
}

output "ssm_port_forward_command" {
  value       = "aws ssm start-session --target ${aws_instance.elasticsearch.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"9200\"],\"localPortNumber\":[\"9200\"]}'"
  description = "CLI command to tunnel Elasticsearch port 9200 securely to localhost"
}

output "curl_test_command" {
  value       = "curl -u elastic:${var.es_password} http://localhost:9200"
  sensitive   = true
  description = "cURL validation command (run after establishing SSM port forwarding)"
}