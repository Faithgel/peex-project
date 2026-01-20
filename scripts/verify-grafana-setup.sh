#!/bin/bash
# Script to verify Grafana setup and Prometheus connection

set -e

GRAFANA_INSTANCE_ID="${1:-}"

if [ -z "$GRAFANA_INSTANCE_ID" ]; then
  cd "$(dirname "$0")/../terraform"
  GRAFANA_INSTANCE_ID=$(terraform output -raw grafana_instance_id 2>/dev/null || echo "")
fi

if [ -z "$GRAFANA_INSTANCE_ID" ]; then
  echo "Error: Could not get Grafana instance ID"
  exit 1
fi

echo "Verifying Grafana setup on instance: $GRAFANA_INSTANCE_ID"
echo ""

# Check Grafana service status
echo "1. Checking Grafana service status..."
aws ssm send-command \
  --instance-ids "$GRAFANA_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl status grafana-server --no-pager | head -10"]' \
  --output json > /tmp/grafana-status.json

COMMAND_ID=$(jq -r '.Command.CommandId' /tmp/grafana-status.json)
sleep 3
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$GRAFANA_INSTANCE_ID" --output json | jq -r '.StandardOutputContent'

# Check Prometheus data source
echo ""
echo "2. Checking Prometheus data source configuration..."
aws ssm send-command \
  --instance-ids "$GRAFANA_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s http://admin:admin@localhost:3000/api/datasources | jq ."]' \
  --output json > /tmp/datasources.json

COMMAND_ID=$(jq -r '.Command.CommandId' /tmp/datasources.json)
sleep 3
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$GRAFANA_INSTANCE_ID" --output json | jq -r '.StandardOutputContent'

# Check dashboards
echo ""
echo "3. Checking existing dashboards..."
aws ssm send-command \
  --instance-ids "$GRAFANA_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s http://admin:admin@localhost:3000/api/search?type=dash-db | jq ."]' \
  --output json > /tmp/dashboards.json

COMMAND_ID=$(jq -r '.Command.CommandId' /tmp/dashboards.json)
sleep 3
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$GRAFANA_INSTANCE_ID" --output json | jq -r '.StandardOutputContent'

echo ""
echo "Verification complete!"
