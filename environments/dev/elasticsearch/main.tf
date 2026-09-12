# Call the reusable Elasticsearch module for Dev Environment
module "elasticsearch" {
  source        = "../../../modules/elasticsearch"
  environment   = var.environment
  instance_type = var.instance_type
  es_password   = var.es_password
}
