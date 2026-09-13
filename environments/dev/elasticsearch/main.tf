# Call the reusable Elasticsearch module for Dev Environment
module "elasticsearch" {
  source        = "../../../modules/elasticsearch"
  environment   = var.environment
  node_count    = var.node_count
  instance_type = var.instance_type
  volume_size   = var.volume_size
  enable_ilb    = var.enable_ilb
  es_password   = var.es_password
}
