output "instance_public_ip" {
  value       = aws_instance.elasticsearch.public_ip
  description = "Public IP instance"
}

output "elasticsearch_url" {
  value       = "https://${aws_instance.elasticsearch.public_ip}:9200"
  description = "Elasticsearch HTTPS endpoint"
}

output "curl_test_command" {
  value       = "curl -k -u elastic:${var.es_password} https://${aws_instance.elasticsearch.public_ip}:9200"
  description = "Perintah validasi via terminal lokal"
}