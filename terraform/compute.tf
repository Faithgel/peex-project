# Generate SSH key pair
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally (for Session Manager port forwarding if needed)
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.module}/../keys/id_rsa"
  file_permission = "0600"
}

# Save public key locally
resource "local_file" "public_key" {
  content  = tls_private_key.main.public_key_openssh
  filename = "${path.module}/../keys/id_rsa.pub"
}

# AWS Key Pair (optional, for emergency access via EC2 Instance Connect)
resource "aws_key_pair" "main" {
  count      = var.enable_ssh_access ? 1 : 0
  key_name   = "${var.project_name}-keypair"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# Prometheus EC2 Instance
resource "aws_instance" "prometheus" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.prometheus_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.prometheus.id, aws_security_group.session_manager.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_session_manager.name

  user_data = base64encode(templatefile("${path.module}/scripts/prometheus-setup.sh", {
    prometheus_version = "2.45.0"
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-prometheus"
    Role    = "monitoring"
    Service = "prometheus"
  }
}

# Grafana EC2 Instance
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.grafana_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.grafana.id, aws_security_group.session_manager.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_session_manager.name

  user_data = base64encode(templatefile("${path.module}/scripts/grafana-setup.sh", {
    grafana_version = "10.0.0"
    prometheus_url  = "http://${aws_instance.prometheus.private_ip}:9090"
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-grafana"
    Role    = "monitoring"
    Service = "grafana"
  }
}

# Sample Application EC2 Instance (for custom metrics)
resource "aws_instance" "application" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private[1].id
  vpc_security_group_ids = [aws_security_group.application.id, aws_security_group.session_manager.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_session_manager.name

  user_data = base64encode(templatefile("${path.module}/scripts/app-setup.sh", {
    prometheus_url = "http://${aws_instance.prometheus.private_ip}:9090"
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-application"
    Role    = "application"
    Service = "sample-app"
  }
}

# Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
