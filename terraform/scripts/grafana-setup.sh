#!/bin/bash
set -e

GRAFANA_VERSION="${grafana_version}"
PROMETHEUS_URL="${prometheus_url}"

# Update system
yum update -y

# Install required packages
yum install -y wget

# Install Grafana
cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

yum install -y grafana

# Start and enable Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Wait for Grafana to start
sleep 10

# Configure Grafana data source (Prometheus)
cat > /tmp/grafana-datasource.json <<EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "$${PROMETHEUS_URL}",
  "access": "proxy",
  "isDefault": true,
  "jsonData": {
    "timeInterval": "15s"
  }
}
EOF

# Wait for Grafana API to be ready
for i in {1..30}; do
  if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Add Prometheus data source using API
GRAFANA_ADMIN_PASSWORD=$(cat /etc/grafana/grafana.ini | grep "^admin_password" | cut -d'=' -f2 | tr -d ' ')
if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
  GRAFANA_ADMIN_PASSWORD="admin"
fi

curl -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/grafana-datasource.json \
  http://admin:$${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/datasources

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWEOF'
{
  "metrics": {
    "namespace": "PeexProject/Grafana",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_user",
          "cpu_usage_system"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      }
    }
  }
}
CWEOF

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
