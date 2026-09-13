output "instance_ids" {
  value       = aws_instance.elasticsearch[*].id
  description = "List of EC2 Instance IDs in the cluster"
}

output "primary_instance_id" {
  value       = aws_instance.elasticsearch[0].id
  description = "Primary EC2 Instance ID for AWS SSM Session Manager target"
}

output "instance_private_ips" {
  value       = aws_instance.elasticsearch[*].private_ip
  description = "List of private IP addresses of cluster nodes"
}

output "ilb_dns_name" {
  value       = length(aws_lb.es_ilb) > 0 ? aws_lb.es_ilb[0].dns_name : null
  description = "DNS endpoint of the Internal Application Load Balancer"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.elasticsearch[0].id}"
  description = "CLI command to open interactive shell session via AWS SSM to Node 0"
}

output "ssm_ilb_port_forward_command" {
  value       = length(aws_lb.es_ilb) > 0 ? "aws ssm start-session --target ${aws_instance.elasticsearch[0].id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"${aws_lb.es_ilb[0].dns_name}\"],\"portNumber\":[\"9200\"],\"localPortNumber\":[\"9200\"]}'" : null
  description = "CLI command to tunnel ILB port 9200 securely to localhost via AWS SSM Remote Host"
}

output "curl_test_command" {
  value       = "curl -u elastic:${var.es_password} http://localhost:9200/_cluster/health?pretty"
  sensitive   = true
  description = "cURL validation command (run after establishing SSM port forwarding to test cluster health)"
}
