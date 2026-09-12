# Fetch latest official Ubuntu 22.04 LTS AMI in AWS Jakarta region (ap-southeast-3)
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
# Enables secure shell access without opening SSH port 22 or managing SSH keys
resource "aws_iam_role" "ssm_role" {
  name = "elasticsearch-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "elasticsearch-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# 2. Security Group: Zero open ingress ports (Access managed via AWS SSM Session Manager)
resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg-secure"
  description = "Zero-ingress SG leveraging AWS SSM for shell access and port forwarding"

  # Outbound access allowed for OS packages, Docker downloads, and SSM communication
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. EC2 Instance hosting Elasticsearch container
resource "aws_instance" "elasticsearch" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro" # AWS Free Tier eligible (1 vCPU, 1 GB RAM)
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  vpc_security_group_ids = [aws_security_group.es_sg.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    es_password = var.es_password
  })

  root_block_device {
    volume_size = 20 # 20 GB EBS volume (Free Tier allows up to 30 GB)
    volume_type = "gp3"
  }

  tags = {
    Name        = "Elasticsearch-Lab-Node"
    Environment = "Interview-Lab"
  }
}
