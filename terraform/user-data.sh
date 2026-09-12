#!/bin/bash
set -e

# 1. Configure Linux Swapfile (Critical for 1GB RAM Free Tier instances to prevent OOM)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Raise max_map_count required by Elasticsearch 8.x
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

# 2. Install Docker Engine
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# 3. Launch Elasticsearch 8 container with native TLS and X-Pack Authentication
# ES_JAVA_OPTS is capped at 512MB heap for Free Tier stability
docker run -d \
  --name elasticsearch \
  --restart always \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "ELASTIC_PASSWORD=${es_password}" \
  -e "xpack.security.enabled=true" \
  -e "xpack.security.http.ssl.enabled=true" \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  docker.elastic.co/elasticsearch/elasticsearch:8.13.0