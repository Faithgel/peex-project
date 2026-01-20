# Grafana Alert Rules

This directory contains Grafana alert rule definitions that can be imported into Grafana's unified alerting system.

## Files

- `alert-rules.json` - Complete set of alert rules for the Peex Project

## Alert Rules Included

### Infrastructure Alerts

1. **High CPU Usage** - CPU > 80% for 5 minutes
2. **High Memory Usage** - Memory > 85% for 5 minutes
3. **Low Disk Space** - Disk < 15% available for 5 minutes

### Application Alerts

4. **High Error Rate** - Error rate > 0.1/sec for 3 minutes
5. **High Request Duration** - 95th percentile > 2s for 5 minutes
6. **No Metrics Received** - Application not sending metrics for 5 minutes

### Business Metrics Alerts

7. **High Order Processing Time** - 95th percentile > 1s for 5 minutes
8. **Low Active Users** - Active users < 5 for 10 minutes

### Composite Alerts

9. **High CPU and Error Rate** - Both conditions met for 3 minutes

## How to Import Alert Rules

### Option 1: Via Grafana UI

1. Go to Grafana → Alerting → Alert rules
2. Click "New alert rule"
3. For each alert:
   - Copy the query from `alert-rules.json`
   - Set the condition and thresholds
   - Configure labels and annotations

### Option 2: Via Grafana API

You can use the Grafana API to create alert rules programmatically:

```bash
# Get API key from Grafana (Configuration → API Keys)
GRAFANA_API_KEY="your-api-key"
GRAFANA_URL="http://localhost:3000"

# Create alert rule
curl -X POST \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d @grafana/alert-rules.json \
  "$GRAFANA_URL/api/ruler/grafana/api/v1/rules/peex-project"
```

### Option 3: Via Provisioning (Recommended for Production)

Create a provisioning file at `/etc/grafana/provisioning/alerting/peex-project.yml`:

```yaml
apiVersion: 1

groups:
  - name: peex-project-alerts
    interval: 30s
    orgId: 1
    folder: 'Peex Project'
    rules:
      - uid: high-cpu-usage
        title: High CPU Usage
        condition: A
        data:
          - refId: A
            relativeTimeRange:
              from: 300
              to: 0
            datasourceUid: prometheus
            model:
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
              refId: A
        noDataState: NoData
        execErrState: Error
        for: 5m
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }}"
        labels:
          severity: warning
          component: infrastructure
```

## Notification Channels

Before alerts can send notifications, configure notification channels:

1. Go to Alerting → Notification channels
2. Add channels for:
   - Email
   - Slack
   - PagerDuty
   - Webhook

## Testing Alerts

### Test Individual Alert

1. Go to Alerting → Alert rules
2. Click on an alert rule
3. Click "Test rule" to see if it would fire

### Generate Test Data

Use the load testing scripts to trigger alerts:

```bash
# Generate high error rate
./scripts/test-alerts.sh localhost:8080 1000

# Generate sustained load (may trigger CPU/memory alerts)
./scripts/generate-load-test.sh localhost:8080 600 10
```

## Alert States

- **Pending** - Condition met but not yet for the `for` duration
- **Firing** - Alert is active and sending notifications
- **Normal** - Condition not met, alert is resolved

## Integration with Prometheus

These Grafana alerts complement the Prometheus alerts defined in `prometheus/alerts.yml`. You can use either:

- **Prometheus alerts** - Managed by Prometheus/Alertmanager
- **Grafana alerts** - Managed by Grafana's unified alerting

For this project, both are configured to provide redundancy.
