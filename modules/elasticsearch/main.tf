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
resource "aws_security_group" "ilb_sg" {
  count       = var.enable_ilb ? 1 : 0
  name        = "elasticsearch-ilb-sg-${var.environment}"
  description = "Security Group for Internal Application Load Balancer"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg-secure-${var.environment}"
  description = "Security group for Elasticsearch cluster nodes"
  vpc_id      = data.aws_vpc.selected.id

  # Allow all node-to-node transport & HTTP traffic within the cluster
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow HTTP traffic from the ILB
  dynamic "ingress" {
    for_each = var.enable_ilb ? [1] : []
    content {
      from_port       = 9200
      to_port         = 9200
      protocol        = "tcp"
      security_groups = [aws_security_group.ilb_sg[0].id]
    }
  }

  egress {
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

# 3. EC2 Cluster Nodes
resource "aws_instance" "elasticsearch" {
  count                = var.node_count
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id != null ? var.subnet_id : element(data.aws_subnets.all.ids, count.index)
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  vpc_security_group_ids = [aws_security_group.es_sg.id]

  user_data = templatefile("${path.module}/templates/user-data.sh.tpl", {
    node_count   = var.node_count
    node_index   = count.index
    cluster_name = "es-cluster-${var.environment}"
    es_password  = var.es_password
    es_heap_size = var.es_heap_size
    es_version   = var.es_version
  })

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
    encrypted   = var.volume_encrypted
    kms_key_id  = var.kms_key_arn
  }

  tags = merge(
    {
      Name        = "Elasticsearch-Node-${count.index}-${var.environment}"
      Cluster     = "es-cluster-${var.environment}"
      NodeName    = "es-node-${count.index}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# 4. Internal Application Load Balancer (ILB)
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

resource "aws_lb_target_group" "es_tg" {
  count       = var.enable_ilb ? 1 : 0
  name        = "es-tg-${var.environment}"
  port        = 9200
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "9200"
    protocol            = "HTTP"
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

resource "aws_lb_target_group_attachment" "es_tga" {
  count            = var.enable_ilb ? var.node_count : 0
  target_group_arn = aws_lb_target_group.es_tg[0].arn
  target_id        = aws_instance.elasticsearch[count.index].id
  port             = 9200
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
