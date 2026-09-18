output "asg_id" {
  value       = aws_autoscaling_group.es_asg.id
  description = "Auto Scaling Group ID"
}

output "asg_name" {
  value       = aws_autoscaling_group.es_asg.name
  description = "Auto Scaling Group Name"
}

output "asg_arn" {
  value       = aws_autoscaling_group.es_asg.arn
  description = "Auto Scaling Group ARN"
}

output "launch_template_id" {
  value       = aws_launch_template.es_lt.id
  description = "Launch Template ID for cluster nodes"
}

output "launch_template_latest_version" {
  value       = aws_launch_template.es_lt.latest_version
  description = "Latest version of the Launch Template"
}

output "ilb_dns_name" {
  value       = length(aws_lb.es_ilb) > 0 ? aws_lb.es_ilb[0].dns_name : null
  description = "DNS endpoint of the Internal Application Load Balancer"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target $(aws ec2 describe-instances --filters \"Name=tag:Cluster,Values=es-cluster-${var.environment}\" \"Name=instance-state-name,Values=running\" --query \"Reservations[0].Instances[0].InstanceId\" --output text)"
  description = "CLI command to open interactive shell session via AWS SSM to an active cluster node"
}

output "ssm_ilb_port_forward_command" {
  value       = length(aws_lb.es_ilb) > 0 ? "aws ssm start-session --target $(aws ec2 describe-instances --filters \"Name=tag:Cluster,Values=es-cluster-${var.environment}\" \"Name=instance-state-name,Values=running\" --query \"Reservations[0].Instances[0].InstanceId\" --output text) --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"${aws_lb.es_ilb[0].dns_name}\"],\"portNumber\":[\"9200\"],\"localPortNumber\":[\"9200\"]}'" : null
  description = "CLI command to tunnel ILB port 9200 securely to localhost via AWS SSM Remote Host (queries first active instance dynamically)"
}

output "curl_test_command" {
  value       = "curl -u elastic:${var.es_password} http://localhost:9200/_cluster/health?pretty"
  sensitive   = true
  description = "cURL validation command (run after establishing SSM port forwarding to test cluster health)"
}
