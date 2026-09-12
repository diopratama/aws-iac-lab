# Ambil IP publik Anda untuk whitelist Security Group (Zero Trust principle)
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

# Key Pair
resource "aws_key_pair" "es_key" {
  key_name   = "es-lab-key"
  public_key = file(var.public_key_path)
}

# Security Group: Hanya membuka port 22 (SSH) dan 9200 (ES HTTPS) ke IP laptop Anda
resource "aws_security_group" "es_sg" {
  name        = "elasticsearch-sg"
  description = "Restrict access to ES and SSH from my local IP only"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

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

# EC2 Instance
resource "aws_instance" "elasticsearch" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # Free Tier eligible di ap-southeast-3

  key_name               = aws_key_pair.es_key.key_name
  vpc_security_group_ids = [aws_security_group.es_sg.id]

  user_data = templatefile("${path.module}/user_data.sh", {
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