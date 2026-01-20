# Peex Project - DevOps Infrastructure Automation

A comprehensive DevOps project demonstrating Infrastructure as Code (Terraform), secure access management, custom metrics collection, and alerting configuration on AWS.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Features](#features)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Testing & Validation](#testing--validation)
- [Access & Usage](#access--usage)
- [Troubleshooting](#troubleshooting)
- [Key Commands](#key-commands)
- [Next Steps](#next-steps)

## Overview

This project implements a complete monitoring and observability stack with:

- **Infrastructure as Code**: Terraform-managed AWS infrastructure
- **Secure Access**: AWS Systems Manager Session Manager (no SSH ports exposed)
- **Monitoring Stack**: Prometheus + Grafana
- **Custom Metrics**: 5 application-specific business metrics
- **Alerting**: Multi-level alerting (Prometheus + CloudWatch) with static, anomaly, and composite alerts

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                             │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  Prometheus  │  │   Grafana    │  │  Application │    │
│  │  (Private)   │  │  (Private)   │  │  (Private)   │    │
│  │   Port 9090  │  │   Port 3000  │  │   Port 8080  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│         │                 │                  │             │
│         └─────────────────┴──────────────────┘             │
│                    Security Groups                          │
│                    Session Manager                          │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured (`aws sts get-caller-identity`)
- Access to create VPC, EC2, IAM resources

### 5-Minute Deployment

```bash
# 1. Configure
cd terraform
cp terraform.tfvars.example terraform.tfvars

# 2. Deploy
terraform init
terraform plan
terraform apply  # Takes ~5-10 minutes

# 3. Access Grafana (port forward)
terraform output grafana_instance_id
aws ssm start-session --target <grafana-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'

# 4. Open http://localhost:3000 (admin/admin)
```

## Project Structure

```
peex-project/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # VPC, networking, routing
│   ├── variables.tf       # Configurable variables
│   ├── security.tf        # Security groups
│   ├── iam.tf            # IAM roles and policies
│   ├── compute.tf         # EC2 instances
│   ├── cloudwatch-alarms.tf # CloudWatch alarms
│   ├── outputs.tf        # Output values
│   └── scripts/          # User data scripts
│       ├── prometheus-setup.sh
│       ├── grafana-setup.sh
│       └── app-setup.sh
├── prometheus/            # Prometheus configuration
│   ├── prometheus.yml    # Main config
│   └── alerts.yml        # Alert rules
├── grafana/              # Grafana dashboards
│   └── dashboards/custom-metrics-dashboard.json
├── application/          # Sample app with custom metrics
│   ├── app.py
│   └── requirements.txt
├── scripts/              # Utility scripts
│   ├── generate-ssh-keys.sh
│   ├── validate-terraform.sh
│   ├── test-alerts.sh
│   └── update-prometheus-config.sh
├── keys/                 # SSH keys (gitignored)
├── Makefile             # Convenience commands
└── README.md            # This file
```

## Features

### 1. Infrastructure as Code (Terraform)

**Components:**
- VPC with public/private subnets across 2 availability zones
- NAT Gateway for private subnet internet access
- Security groups with least-privilege rules
- 3 EC2 instances: Prometheus, Grafana, Sample Application
- IAM roles with Session Manager support
- Encrypted EBS volumes
- CloudWatch alarms and SNS topics

**Validation:**
```bash
terraform fmt -check -recursive
terraform validate
terraform plan  # Dry-run
```

### 2. Secure Access (AWS Systems Manager Session Manager)

**Security Features:**
- No SSH ports exposed to internet
- IAM-based access control
- Session Manager for secure shell access
- Port forwarding for web interfaces
- Application Security Groups for workload isolation

**Security Groups:**
- `prometheus-sg` - Allows inbound from Grafana and application
- `grafana-sg` - Allows inbound from VPC only
- `application-sg` - Allows inbound from Prometheus and VPC
- `session-manager-sg` - Only outbound HTTPS to SSM endpoints

**Access Methods:**
```bash
# Direct session
aws ssm start-session --target <instance-id>

# Port forwarding
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
```

### 3. Custom Metrics (5 Metrics)

1. **`sample_app_orders_total`** (Counter) - Total orders created
2. **`sample_app_active_users`** (Gauge) - Current active users
3. **`sample_app_processing_time_seconds`** (Histogram) - Order processing time
4. **`sample_app_requests_total`** (Counter) - HTTP request count
5. **`sample_app_errors_total`** (Counter) - Error count by type

**Collection:**
- Prometheus: Scrapes `/metrics` endpoint every 10 seconds
- CloudWatch: Published via boto3 to `PeexProject/CustomMetrics` namespace

### 4. Alerting Configuration

**Prometheus Alerts** (`prometheus/alerts.yml`):
- **Static Threshold**: High CPU (>80%), High Memory (>85%), Disk Space Low (<15%)
- **Application**: High Error Rate (>0.1/sec), High Request Duration (95th pct >2s)
- **Custom Metrics**: High Order Processing Time (95th pct >1s), Low Active Users (<5)
- **Composite**: High CPU AND High Error Rate

**CloudWatch Alarms** (`terraform/cloudwatch-alarms.tf`):
- **Static Threshold**: CPU > 80%, Memory > 85%
- **Anomaly Detection**: Active Users (2 standard deviations)
- **Custom Metrics**: High Order Rate (>100/5min), High Error Rate (>5/min)
- **Composite**: High CPU AND High Error Rate

**Notification:**
- SNS Topic: `peex-project-alerts-topic`
- Configurable subscriptions (email, Slack, PagerDuty)

### 5. Monitoring Stack

- **Prometheus 2.45.0**: Port 9090, 15s scrape interval
- **Grafana 10.0.0**: Port 3000, auto-configured Prometheus data source
- **CloudWatch Agent**: Installed on all instances for system metrics

## Deployment

### Step-by-Step Deployment

1. **Initial Setup**
   ```bash
   git clone <repository-url>
   cd peex-project
   ```

2. **Configure Terraform**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed
   ```

3. **Validate Configuration**
   ```bash
   terraform init
   terraform fmt
   terraform validate
   terraform plan
   ```

4. **Deploy Infrastructure**
   ```bash
   terraform apply
   # Review plan and type 'yes' to confirm
   ```

5. **Verify Deployment**
   ```bash
   terraform output
   # Test Session Manager access
   aws ssm start-session --target <prometheus-instance-id>
   ```

6. **Configure Access**
   ```bash
   # Port forward Grafana
   aws ssm start-session --target <grafana-instance-id> \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
   # Access http://localhost:3000 (admin/admin)
   ```

7. **Update Prometheus Config** (with application IP)
   ```bash
   APP_IP=$(terraform output -raw application_private_ip)
   cd ..
   ./scripts/update-prometheus-config.sh ${APP_IP}
   ```

8. **Test Custom Metrics**
   ```bash
   ./scripts/test-alerts.sh ${APP_IP}:8080
   ```

## Configuration

### Terraform Variables

Key variables in `terraform/variables.tf`:
- `aws_region`: AWS region (default: us-east-1)
- `environment`: Environment name (dev/staging/prod)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `prometheus_instance_type`: Instance type (default: t3.medium)
- `grafana_instance_type`: Instance type (default: t3.small)
- `app_instance_type`: Instance type (default: t3.micro)
- `enable_ssh_access`: SSH access flag (default: false)

### Environment-Specific Configuration

Use `terraform.tfvars` for environment-specific values:
```hcl
environment = "dev"
aws_region = "us-east-1"
prometheus_instance_type = "t3.medium"
```

### Post-Deployment Configuration

1. **Configure SNS Notifications**
   - Edit `terraform/cloudwatch-alarms.tf`
   - Uncomment and configure email subscription:
   ```hcl
   resource "aws_sns_topic_subscription" "email" {
     topic_arn = aws_sns_topic.alerts.arn
     protocol  = "email"
     endpoint  = "your-email@example.com"
   }
   ```
   - Apply: `terraform apply`

2. **Import Grafana Dashboard**
   - Login to Grafana (http://localhost:3000)
   - Go to Dashboards → Import
   - Upload `grafana/dashboards/custom-metrics-dashboard.json`

## Testing & Validation

### Terraform Validation

```bash
cd terraform
terraform fmt -check -recursive
terraform validate
terraform plan
```

### Access Testing

```bash
# Test Session Manager
aws ssm start-session --target <instance-id>

# Verify security groups
aws ec2 describe-security-groups --group-names peex-project-*-sg
```

### Metrics Testing

```bash
# Generate test metrics
APP_IP=$(cd terraform && terraform output -raw application_private_ip)
cd ..
./scripts/test-alerts.sh ${APP_IP}:8080

# Verify metrics endpoint
curl http://${APP_IP}:8080/metrics
```

### Alert Testing

```bash
# Generate errors to trigger alerts
curl http://<app-ip>:8080/error

# Check Prometheus alerts
# Access Prometheus UI → Alerts tab (after port forwarding)

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-name-prefix peex-project
```

## Access & Usage

### Session Manager Access

```bash
# Connect to instance
aws ssm start-session --target <instance-id>

# Port forward Grafana
aws ssm start-session --target <grafana-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'

# Port forward Prometheus
aws ssm start-session --target <prometheus-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9090"],"localPortNumber":["9090"]}'
```

### Web Interfaces

- **Grafana**: http://localhost:3000 (after port forwarding)
  - Default: admin/admin (change on first login)
- **Prometheus**: http://localhost:9090 (after port forwarding)
  - Check targets: http://localhost:9090/targets
  - View alerts: http://localhost:9090/alerts

### Monitoring

- **Prometheus Targets**: http://localhost:9090/targets
- **Prometheus Alerts**: http://localhost:9090/alerts
- **Grafana Dashboards**: Import custom metrics dashboard
- **CloudWatch**: AWS Console → CloudWatch → Alarms

## Troubleshooting

### Session Manager Not Working

1. Verify IAM role is attached:
   ```bash
   terraform output
   aws ec2 describe-instances --instance-ids <id> --query 'Instances[0].IamInstanceProfile'
   ```

2. Check SSM Agent status:
   ```bash
   aws ssm describe-instance-information --filters "Key=InstanceIds,Values=<id>"
   ```

### Metrics Not Appearing

1. Check Prometheus targets:
   - Access Prometheus UI → Status → Targets
   - Verify application is UP

2. Check application metrics endpoint:
   ```bash
   curl http://<app-ip>:8080/metrics
   ```

3. Verify security groups allow traffic

4. Wait 2-3 minutes after deployment for metrics to appear

### Alerts Not Triggering

1. Check Prometheus alert rules:
   ```bash
   promtool check rules prometheus/alerts.yml
   ```

2. Verify alert conditions in Prometheus UI

3. Check CloudWatch alarm state:
   ```bash
   aws cloudwatch describe-alarms --alarm-names peex-project-*
   ```

4. Generate test errors:
   ```bash
   curl http://<app-ip>:8080/error
   ```

### Application Not Responding

```bash
# Check application status
aws ssm start-session --target <app-instance-id>
sudo systemctl status sample-app
sudo journalctl -u sample-app -f
```

## Key Commands

### Terraform

```bash
terraform init          # Initialize
terraform plan          # Dry-run
terraform apply         # Apply changes
terraform destroy       # Destroy infrastructure
terraform output        # Show outputs
terraform fmt           # Format code
terraform validate      # Validate syntax
```

### Session Manager

```bash
# Connect to instance
aws ssm start-session --target <instance-id>

# Port forward
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
```

### CloudWatch

```bash
# List alarms
aws cloudwatch describe-alarms --alarm-name-prefix peex-project

# List custom metrics
aws cloudwatch list-metrics --namespace PeexProject/CustomMetrics

# Get alarm state
aws cloudwatch describe-alarms --alarm-names peex-project-prometheus-high-cpu
```

### Makefile Commands

```bash
make init              # Initialize Terraform
make plan              # Terraform plan
make apply             # Apply infrastructure
make validate          # Validate configuration
make session-grafana   # Connect to Grafana
make port-forward-grafana  # Port forward Grafana
make test-alerts       # Test alerting (requires APP_IP env var)
```

## Next Steps

1. **Configure SNS Subscriptions**
   - Uncomment email subscription in `terraform/cloudwatch-alarms.tf`
   - Add Slack/PagerDuty integration

2. **Import Grafana Dashboard**
   - Login to Grafana
   - Import `grafana/dashboards/custom-metrics-dashboard.json`

3. **Update Prometheus Config**
   - Run `./scripts/update-prometheus-config.sh <app-ip>`
   - Or manually update with application IP

4. **Set Up CI/CD**
   - GitHub Actions for Terraform validation
   - Automated testing on pull requests

5. **Enhance Monitoring**
   - Add log aggregation (CloudWatch Logs)
   - Set up additional dashboards
   - Configure alert routing

## Rollback Procedure

```bash
# View previous state
terraform state list

# Rollback to previous version
git checkout <previous-commit>
terraform plan
terraform apply
```

**Note:** Always backup state before major changes:
```bash
cp terraform.tfstate terraform.tfstate.backup
```

## Security Considerations

- **Least Privilege**: IAM roles have minimal required permissions
- **Network Security**: Private subnets, security groups with minimal access
- **No Public SSH**: Session Manager only
- **Encryption**: Encrypted EBS volumes
- **Secrets**: SSH keys stored locally (gitignored), no hardcoded credentials

## Cost Optimization

- Instance types: t3.micro (app), t3.small (Grafana), t3.medium (Prometheus)
- NAT Gateway: ~$32/month + data transfer
- EBS volumes: gp3 (cost-effective)
- CloudWatch: First 10 custom metrics free, then $0.30/metric/month
- Estimated monthly cost (dev): ~$50-100 depending on usage

## Support & Resources

- **Terraform Docs**: https://www.terraform.io/docs
- **AWS Session Manager**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/

## License

This project is for educational/demonstration purposes.
