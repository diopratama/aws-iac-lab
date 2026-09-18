# Fetch latest official Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Lookup VPC and Subnets
data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : null
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# 1. IAM Role & Policy for AWS Systems Manager (SSM) Session Manager & EC2 Describe
resource "aws_iam_role" "ssm_role" {
  name = "elasticsearch-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(
    {
      Name        = "elasticsearch-ssm-role-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_describe" {
  name = "elasticsearch-ec2-describe-${var.environment}"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "elasticsearch-ssm-instance-profile-${var.environment}"
  role = aws_iam_role.ssm_role.name
}

# 2. Security Groups
# ILB SG: Restricts inbound traffic to VPC CIDR only (internal ALB has no public exposure)
resource "aws_security_group" "ilb_sg" {
  count       = var.enable_ilb ? 1 : 0
  name        = "elasticsearch-ilb-sg-${var.environment}"
  description = "Security Group for Internal Application Load Balancer"
  vpc_id      = data.aws_vpc.selected.id

  # Only allow Elasticsearch REST API traffic from within the VPC
  ingress {
    description = "Allow ES REST API from VPC CIDR only"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "elasticsearch-ilb-sg-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ES Node SG: Zero public ingress. Only allows cluster-internal and ILB traffic.
resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg-secure-${var.environment}"
  description = "Security group for Elasticsearch cluster nodes"
  vpc_id      = data.aws_vpc.selected.id

  # Cluster-internal: allows transport (9300) and REST (9200) between nodes
  ingress {
    description = "Intra-cluster communication (transport + REST)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # ILB → Nodes: allows the load balancer to forward REST API traffic
  dynamic "ingress" {
    for_each = var.enable_ilb ? [1] : []
    content {
      description     = "REST API traffic from Internal Load Balancer"
      from_port       = 9200
      to_port         = 9200
      protocol        = "tcp"
      security_groups = [aws_security_group.ilb_sg[0].id]
    }
  }

  # Outbound: required for Docker image pull, SSM agent, and AWS API calls
  egress {
    description = "Allow all outbound (Docker pull, SSM, AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "elasticsearch-sg-secure-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# 3. AWS Launch Template for Elasticsearch Cluster Nodes
resource "aws_launch_template" "es_lt" {
  name_prefix   = "es-node-lt-${var.environment}-"
  description   = "Launch template for Elasticsearch cluster node (${var.environment})"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.es_sg.id]
  }

  # Bootstrap script handles Docker installation, certificates generation, and dynamic peer discovery
  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tpl", {
    node_count   = var.node_count
    cluster_name = "es-cluster-${var.environment}"
    es_password  = var.es_password
    es_heap_size = var.es_heap_size
    es_version   = var.es_version
  }))

  # Root volume: 10GB per node fits within the 30GB AWS Free Tier storage allocation
  block_device_mappings {
    device_name = data.aws_ami.ubuntu.root_device_name
    ebs {
      volume_size           = var.volume_size
      volume_type           = var.volume_type
      encrypted             = var.volume_encrypted # Encrypt at rest via KMS
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name        = "Elasticsearch-Node-${var.environment}"
        Cluster     = "es-cluster-${var.environment}"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name        = "Elasticsearch-Disk-${var.environment}"
        Cluster     = "es-cluster-${var.environment}"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    {
      Name        = "es-launch-template-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# 4. Auto Scaling Group (ASG) with Automated Rolling Update
resource "aws_autoscaling_group" "es_asg" {
  name_prefix         = "es-asg-${var.environment}-"
  desired_capacity    = var.node_count
  min_size            = var.node_count
  max_size            = var.asg_max_size != null ? var.asg_max_size : var.node_count + 1
  vpc_zone_identifier = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.all.ids

  # Direct registration to ALB Target Group (replaces static target attachments)
  target_group_arns = var.enable_ilb ? [aws_lb_target_group.es_tg[0].arn] : []

  # Use ELB health check so ASG monitors the REST API health on port 9200
  health_check_type         = var.enable_ilb ? "ELB" : "EC2"
  health_check_grace_period = var.asg_health_check_grace_period

  launch_template {
    id      = aws_launch_template.es_lt.id
    version = "$Latest"
  }

  # Automated rolling updates: replaces nodes one by one with zero downtime
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 66
      instance_warmup        = var.asg_instance_warmup
    }
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [target_group_arns]
  }

  dynamic "tag" {
    for_each = merge(
      {
        Name        = "Elasticsearch-Cluster-${var.environment}"
        Cluster     = "es-cluster-${var.environment}"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# 5. Internal Application Load Balancer (ILB)
# Fronts the cluster nodes inside the VPC for unified REST API access (port 9200)
resource "aws_lb" "es_ilb" {
  count              = var.enable_ilb ? 1 : 0
  name               = "es-ilb-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ilb_sg[0].id]
  subnets            = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.all.ids

  tags = merge(
    {
      Name        = "es-ilb-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Target group for Elasticsearch HTTP REST API (port 9200)
resource "aws_lb_target_group" "es_tg" {
  count       = var.enable_ilb ? 1 : 0
  name        = "es-tg-${var.environment}"
  port        = 9200
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    enabled  = true
    path     = "/"
    port     = "9200"
    protocol = "HTTP"
    # HTTP 401 indicates ES is running and actively enforcing authentication; 200 for unauthenticated root
    matcher             = "200,401"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    {
      Name        = "es-tg-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_lb_listener" "es_listener" {
  count             = var.enable_ilb ? 1 : 0
  load_balancer_arn = aws_lb.es_ilb[0].arn
  port              = 9200
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.es_tg[0].arn
  }
}
