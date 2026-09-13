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

# 1. IAM Role & Policy for AWS Systems Manager (SSM) Session Manager
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

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "elasticsearch-ssm-instance-profile-${var.environment}"
  role = aws_iam_role.ssm_role.name
}

# 2. Security Group: Zero open ingress ports (Access via AWS SSM Session Manager)
resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg-secure-${var.environment}"
  description = "Zero-ingress SG leveraging AWS SSM for shell access and port forwarding"
  vpc_id      = var.vpc_id

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

# 3. EC2 Instance hosting Elasticsearch container
resource "aws_instance" "elasticsearch" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  vpc_security_group_ids = [aws_security_group.es_sg.id]

  user_data = templatefile("${path.module}/templates/user-data.sh.tpl", {
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
      Name        = "Elasticsearch-Node-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
