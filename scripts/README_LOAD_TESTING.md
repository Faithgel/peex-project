# Load Testing Scripts

Scripts to generate test load and metrics for monitoring and alerting validation.

## Quick Start

**Prerequisites:**
1. Port forward the application:
   ```bash
   ./scripts/port-forward-app.sh
   ```

2. Run a load test:
   ```bash
   ./scripts/generate-load-test.sh localhost:8080
   ```

## Available Scripts

### 1. `generate-load-test.sh` - Concurrent Load Test

Generates high-volume concurrent load for a specified duration.

**Usage:**
```bash
./scripts/generate-load-test.sh [endpoint] [duration] [concurrent]
```

**Parameters:**
- `endpoint`: Application endpoint (default: `localhost:8080`)
- `duration`: Test duration in seconds (default: `300` = 5 minutes)
- `concurrent`: Number of concurrent workers (default: `5`)

**Examples:**
```bash
# Quick 1-minute test with 3 workers
./scripts/generate-load-test.sh localhost:8080 60 3

# 10-minute test with 10 concurrent workers
./scripts/generate-load-test.sh localhost:8080 600 10

# 30-minute sustained test
./scripts/generate-load-test.sh localhost:8080 1800 5
```

**What it does:**
- 60% orders
- 25% user updates
- 10% health checks
- 3% metrics scrapes
- 2% errors

### 2. `generate-sustained-load.sh` - Long-Running Load

Generates continuous load over an extended period.

**Usage:**
```bash
./scripts/generate-sustained-load.sh [endpoint] [duration]
```

**Parameters:**
- `endpoint`: Application endpoint (default: `localhost:8080`)
- `duration`: Duration in seconds (default: `1800` = 30 minutes)

**Examples:**
```bash
# 30-minute sustained load
./scripts/generate-sustained-load.sh localhost:8080 1800

# 1-hour load test
./scripts/generate-sustained-load.sh localhost:8080 3600

# 2-hour load test
./scripts/generate-sustained-load.sh localhost:8080 7200
```

### 3. `test-alerts.sh` - Quick Test

Quick test with configurable request count.

**Usage:**
```bash
./scripts/test-alerts.sh [endpoint] [count]
```

**Examples:**
```bash
# Default: 50 requests
./scripts/test-alerts.sh localhost:8080

# 100 requests
./scripts/test-alerts.sh localhost:8080 100

# 500 requests
./scripts/test-alerts.sh localhost:8080 500
```

## Recommended Test Scenarios

### Scenario 1: Quick Validation (5 minutes)
```bash
./scripts/generate-load-test.sh localhost:8080 300 5
```
- Good for: Quick dashboard validation, basic alert testing

### Scenario 2: Medium Load (30 minutes)
```bash
./scripts/generate-load-test.sh localhost:8080 1800 10
```
- Good for: Alert threshold testing, metric collection validation

### Scenario 3: Sustained Load (1 hour+)
```bash
./scripts/generate-sustained-load.sh localhost:8080 3600
```
- Good for: Long-term monitoring, anomaly detection testing

### Scenario 4: High Load Stress Test
```bash
./scripts/generate-load-test.sh localhost:8080 600 20
```
- Good for: Stress testing, performance monitoring

## Monitoring During Tests

While tests are running, monitor:

1. **Grafana Dashboards:**
   - Orders Created
   - Active Users
   - Request Rate
   - Error Rate
   - Processing Time

2. **Prometheus:**
   - http://localhost:9090/targets (after port forwarding)
   - http://localhost:9090/graph (query metrics)

3. **CloudWatch:**
   - AWS Console → CloudWatch → Metrics
   - Namespace: `PeexProject/CustomMetrics`

4. **Alerts:**
   - Prometheus: http://localhost:9090/alerts
   - CloudWatch: AWS Console → CloudWatch → Alarms

## Tips

- Run tests in background: `nohup ./scripts/generate-load-test.sh localhost:8080 1800 5 &`
- Monitor in real-time: Keep Grafana dashboard open while test runs
- Test alert thresholds: Generate enough errors to trigger alerts
- Check resource usage: Monitor CPU/memory during high load

## Troubleshooting

**"Cannot connect to application":**
- Make sure port forwarding is active: `./scripts/port-forward-app.sh`
- Check application is running: `curl http://localhost:8080/health`

**No metrics appearing:**
- Wait 10-15 seconds for Prometheus to scrape
- Check Prometheus targets: http://localhost:9090/targets
- Verify application is generating metrics: `curl http://localhost:8080/metrics`

**High error rate:**
- Reduce concurrent workers
- Increase delay between requests
- Check application logs
