# Security Group for Prometheus
resource "aws_security_group" "prometheus" {
  name        = "${var.project_name}-prometheus-sg"
  description = "Security group for Prometheus server"
  vpc_id      = aws_vpc.main.id

  # Allow inbound from Grafana
  ingress {
    description     = "Prometheus API from Grafana"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana.id]
  }

  # Allow inbound from VPC (for Prometheus web UI access via port forwarding)
  ingress {
    description = "Prometheus API from VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outbound to scrape application metrics
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-prometheus-sg"
  }
}

# Security Group for Grafana
resource "aws_security_group" "grafana" {
  name        = "${var.project_name}-grafana-sg"
  description = "Security group for Grafana server"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP access from VPC only (use ALB or Session Manager port forwarding for external access)
  ingress {
    description = "Grafana HTTP from VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow HTTPS
  ingress {
    description = "Grafana HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-grafana-sg"
  }
}

# Application Security Group (for sample app with custom metrics)
resource "aws_security_group" "application" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for sample application"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from VPC
  ingress {
    description = "HTTP from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Metrics endpoint
  ingress {
    description     = "Metrics endpoint from Prometheus"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.prometheus.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# Security Group for Session Manager (no SSH ports exposed)
resource "aws_security_group" "session_manager" {
  name        = "${var.project_name}-session-manager-sg"
  description = "Security group for Session Manager access (no SSH ports)"
  vpc_id      = aws_vpc.main.id

  # No inbound rules - Session Manager uses Systems Manager API, not direct network access
  # Only outbound HTTPS to Systems Manager endpoints
  egress {
    description = "HTTPS to AWS Systems Manager endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound for package updates and metric publishing
  egress {
    description = "HTTP/HTTPS for package updates"
    from_port   = 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-session-manager-sg"
  }
}
