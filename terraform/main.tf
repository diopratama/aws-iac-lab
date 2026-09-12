# Ambil IP publik Anda untuk whitelist Security Group
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# Ambil Ubuntu 22.04 AMI resmi di ap-southeast-3
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

# 1. IAM Role for Systems Manager (SSM) - Zero SSH Ingress Architecture
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

# 2. Security Group (Port 22 SSH removed; Port 9200 restricted to local IP)
resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg-secure"
  description = "Zero-ingress SSH SG leveraging AWS SSM Session Manager"

  ingress {
    description = "Elasticsearch HTTPS"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. EC2 Instance attached to IAM Instance Profile (No SSH Key Pair required)
resource "aws_instance" "elasticsearch" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  vpc_security_group_ids = [aws_security_group.es_sg.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    es_password = var.es_password
  })

  root_block_device {
    volume_size = 20 # Free tier mengizinkan hingga 30 GB EBS
    volume_type = "gp3"
  }

  tags = {
    Name        = "Elasticsearch-Lab-Node"
    Environment = "Interview-Lab"
  }
}
