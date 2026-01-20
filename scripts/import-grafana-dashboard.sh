#!/bin/bash
# Script to import Grafana dashboard via API

set -e

GRAFANA_INSTANCE_ID="${1:-}"
GRAFANA_ADMIN_PASSWORD="${2:-admin}"

if [ -z "$GRAFANA_INSTANCE_ID" ]; then
  echo "Usage: $0 <grafana-instance-id> [admin-password]"
  echo ""
  echo "Getting Grafana instance ID from Terraform..."
  cd "$(dirname "$0")/../terraform"
  GRAFANA_INSTANCE_ID=$(terraform output -raw grafana_instance_id 2>/dev/null || echo "")
  
  if [ -z "$GRAFANA_INSTANCE_ID" ]; then
    echo "Error: Could not get Grafana instance ID. Please provide it as first argument."
    exit 1
  fi
fi

echo "Grafana Instance ID: $GRAFANA_INSTANCE_ID"
echo "Importing dashboard..."

# Create dashboard JSON with proper format for Grafana API
DASHBOARD_JSON=$(cat <<'DASHBOARDEOF'
{
  "dashboard": {
    "title": "Custom Metrics Dashboard",
    "tags": ["custom-metrics", "business-metrics"],
    "timezone": "browser",
    "schemaVersion": 38,
    "version": 1,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "title": "Orders Created (Counter)",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "rate(sample_app_orders_total[5m])",
            "legendFormat": "Orders/sec",
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          }
        ],
        "yaxes": [
          {"format": "short", "label": "Orders/sec"},
          {"format": "short"}
        ]
      },
      {
        "id": 2,
        "title": "Active Users (Gauge)",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "sample_app_active_users",
            "legendFormat": "Active Users",
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          }
        ],
        "yaxes": [
          {"format": "short", "label": "Users"},
          {"format": "short"}
        ]
      },
      {
        "id": 3,
        "title": "Order Processing Time (Histogram - 95th percentile)",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(sample_app_processing_time_seconds_bucket[5m]))",
            "legendFormat": "95th percentile",
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          },
          {
            "expr": "histogram_quantile(0.50, rate(sample_app_processing_time_seconds_bucket[5m]))",
            "legendFormat": "50th percentile",
            "refId": "B",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          }
        ],
        "yaxes": [
          {"format": "s", "label": "Time (seconds)"},
          {"format": "short"}
        ]
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "rate(sample_app_errors_total[5m])",
            "legendFormat": "{{error_type}}",
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          }
        ],
        "yaxes": [
          {"format": "short", "label": "Errors/sec"},
          {"format": "short"}
        ]
      },
      {
        "id": 5,
        "title": "Request Rate by Endpoint",
        "type": "graph",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16},
        "targets": [
          {
            "expr": "rate(sample_app_requests_total[5m])",
            "legendFormat": "{{method}} {{endpoint}}",
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"}
          }
        ],
        "yaxes": [
          {"format": "short", "label": "Requests/sec"},
          {"format": "short"}
        ]
      }
    ]
  },
  "overwrite": true
}
DASHBOARDEOF
)

# Use SSM Run Command to import dashboard
echo "Sending dashboard import command to Grafana instance..."

aws ssm send-command \
  --instance-ids "$GRAFANA_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'DASHBOARD_JSON=$(cat <<\"JSONEOF\"
$DASHBOARD_JSON
JSONEOF
)',
    'curl -X POST -H \"Content-Type: application/json\" -d \"\$DASHBOARD_JSON\" http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/dashboards/db'
  ]" \
  --output json > /tmp/command-output.json

COMMAND_ID=$(jq -r '.Command.CommandId' /tmp/command-output.json)
echo "Command ID: $COMMAND_ID"
echo "Waiting for command to complete..."

# Wait for command
sleep 5

# Get command output
aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$GRAFANA_INSTANCE_ID" \
  --output json | jq -r '.StandardOutputContent, .StandardErrorContent'

echo ""
echo "Dashboard import completed!"
echo "Access Grafana at http://localhost:3000 (after port forwarding)"
echo "Login: admin/$GRAFANA_ADMIN_PASSWORD"
