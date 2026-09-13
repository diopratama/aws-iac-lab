#!/bin/bash
set -e

# 1. Configure Linux Swapfile (Prevents Out-Of-Memory terminations)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Raise max_map_count required by Elasticsearch 8.x
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

# 2. Install Docker Engine & AWS CLI
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release awscli jq
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# 3. Determine AWS Region and Instance Metadata
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region || echo "ap-southeast-3")
MY_IP=$(hostname -I | awk '{print $1}')
NODE_NAME="es-node-${node_index}"
CLUSTER_NAME="${cluster_name}"

if [ "${node_count}" -le 1 ]; then
  # Single-Node Execution
  docker run -d \
    --name elasticsearch \
    --restart always \
    -p 9200:9200 \
    -e "discovery.type=single-node" \
    -e "ELASTIC_PASSWORD=${es_password}" \
    -e "xpack.security.enabled=true" \
    -e "ES_JAVA_OPTS=-Xms${es_heap_size} -Xmx${es_heap_size}" \
    docker.elastic.co/elasticsearch/elasticsearch:${es_version}
else
  # Multi-Node Cluster Bootstrapping
  echo "Polling EC2 tags for cluster peers in cluster $CLUSTER_NAME..."
  
  INITIAL_MASTERS="es-node-0"
  for i in $(seq 1 $((${node_count} - 1))); do
    INITIAL_MASTERS="$INITIAL_MASTERS,es-node-$i"
  done

  PEER_IPS=""
  for try in $(seq 1 30); do
    IPS=$(aws ec2 describe-instances --region "$AWS_REGION" \
      --filters "Name=tag:Cluster,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running,pending" \
      --query "Reservations[*].Instances[*].PrivateIpAddress" --output text | tr '\t' '\n' | sort -u | paste -sd "," -)
    
    COUNT=$(echo "$IPS" | tr ',' '\n' | grep -c '.' || true)
    if [ "$COUNT" -ge "${node_count}" ]; then
      PEER_IPS="$IPS"
      break
    fi
    sleep 5
  done

  if [ -z "$PEER_IPS" ]; then
    PEER_IPS="$MY_IP"
  fi

  docker run -d \
    --name elasticsearch \
    --restart always \
    -p 9200:9200 \
    -p 9300:9300 \
    -e "cluster.name=$CLUSTER_NAME" \
    -e "node.name=$NODE_NAME" \
    -e "network.host=0.0.0.0" \
    -e "discovery.seed_hosts=$PEER_IPS" \
    -e "cluster.initial_master_nodes=$INITIAL_MASTERS" \
    -e "ELASTIC_PASSWORD=${es_password}" \
    -e "xpack.security.enabled=true" \
    -e "ES_JAVA_OPTS=-Xms${es_heap_size} -Xmx${es_heap_size}" \
    docker.elastic.co/elasticsearch/elasticsearch:${es_version}
fi
