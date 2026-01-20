#!/bin/bash
# Script to update Prometheus configuration with actual application IP

set -e

APP_IP="${1:-}"
PROMETHEUS_INSTANCE_ID="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "$APP_IP" ]; then
  cd "$PROJECT_ROOT/terraform"
  APP_IP=$(terraform output -raw application_private_ip 2>/dev/null || echo "")
  
  if [ -z "$APP_IP" ]; then
    echo "Error: Could not get application IP from Terraform output"
    echo "Usage: $0 <application-private-ip> [prometheus-instance-id]"
    exit 1
  fi
fi

if [ -z "$PROMETHEUS_INSTANCE_ID" ]; then
  cd "$PROJECT_ROOT/terraform"
  PROMETHEUS_INSTANCE_ID=$(terraform output -raw prometheus_instance_id 2>/dev/null || echo "")
  
  if [ -z "$PROMETHEUS_INSTANCE_ID" ]; then
    echo "Error: Could not get Prometheus instance ID from Terraform output"
    echo "Please provide it as second argument: $0 <app-ip> <prometheus-instance-id>"
    exit 1
  fi
fi

echo "Updating Prometheus configuration..."
echo "Application IP: $APP_IP"
echo "Prometheus Instance: $PROMETHEUS_INSTANCE_ID"
echo ""

# Create updated Prometheus config
PROMETHEUS_CONFIG=$(cat <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'peex-project'
    environment: 'dev'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'sample-app'
    static_configs:
      - targets: ['${APP_IP}:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
)

echo "Copying configuration to Prometheus instance..."

# Base64 encode the config to avoid JSON escaping issues
CONFIG_B64=$(echo "$PROMETHEUS_CONFIG" | base64)

aws ssm send-command \
  --instance-ids "$PROMETHEUS_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'echo \"${CONFIG_B64}\" | base64 -d > /tmp/prometheus.yml',
    'sudo cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml',
    'sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml',
    'sudo systemctl reload prometheus || sudo systemctl restart prometheus'
  ]" \
  --output json > /tmp/command-output.json

COMMAND_ID=$(jq -r '.Command.CommandId' /tmp/command-output.json)
echo "Command ID: $COMMAND_ID"
echo "Waiting for command to complete..."

# Wait for command to complete
sleep 5

# Get command output
OUTPUT=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$PROMETHEUS_INSTANCE_ID" \
  --output json)

echo "$OUTPUT" | jq -r '.StandardOutputContent'
if [ "$(echo "$OUTPUT" | jq -r '.StandardErrorContent')" != "" ]; then
  echo "Errors:"
  echo "$OUTPUT" | jq -r '.StandardErrorContent'
fi

echo ""
echo "Prometheus configuration updated successfully!"
echo ""
echo "Verify targets at: http://localhost:9090/targets (after port forwarding Prometheus)"
echo "Or check from instance: curl http://localhost:9090/api/v1/targets"
