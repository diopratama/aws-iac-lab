output "instance_id" {
  value       = aws_instance.elasticsearch.id
  description = "EC2 Instance ID for SSM Session Manager connection"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.elasticsearch.id}"
  description = "Command to connect directly to instance terminal via AWS SSM"
}

output "ssm_port_forward_command" {
  value       = "aws ssm start-session --target ${aws_instance.elasticsearch.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"9200\"],\"localPortNumber\":[\"9200\"]}'"
  description = "Command to securely tunnel port 9200 to your local machine via SSM"
}

output "elasticsearch_url" {
  value       = "https://${aws_instance.elasticsearch.public_ip}:9200"
  description = "Elasticsearch HTTPS endpoint"
}

output "curl_test_command" {
  value       = "curl -k -u elastic:${var.es_password} https://${aws_instance.elasticsearch.public_ip}:9200"
  description = "Validation command via local terminal"
}