#!/bin/bash
set -e

PROMETHEUS_URL="${prometheus_url}"

# Update system
yum update -y

# Install required packages
yum install -y python3 python3-pip git

# Install Python dependencies
pip3 install flask prometheus-client boto3

# Create application directory
mkdir -p /opt/sample-app
cd /opt/sample-app

# Create sample application with custom metrics
cat > app.py <<'APPEOF'
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time
import random
import boto3
from datetime import datetime

app = Flask(__name__)

# Custom metrics
request_count = Counter('sample_app_requests_total', 'Total number of requests', ['method', 'endpoint'])
request_duration = Histogram('sample_app_request_duration_seconds', 'Request duration in seconds', ['endpoint'])
active_users = Gauge('sample_app_active_users', 'Number of active users')
order_count = Counter('sample_app_orders_total', 'Total number of orders')
processing_time = Histogram('sample_app_processing_time_seconds', 'Order processing time in seconds')
error_count = Counter('sample_app_errors_total', 'Total number of errors', ['error_type'])

# CloudWatch client
cloudwatch = boto3.client('cloudwatch', region_name='us-east-1')

# Simulated active users
current_users = 0

@app.route('/')
def index():
    return jsonify({
        'message': 'Sample Application with Custom Metrics',
        'endpoints': {
            '/metrics': 'Prometheus metrics endpoint',
            '/order': 'Create an order (POST)',
            '/users': 'Get active users',
            '/health': 'Health check'
        }
    })

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/order', methods=['POST'])
def create_order():
    start_time = time.time()
    global current_users
    
    try:
        # Simulate order processing
        processing_delay = random.uniform(0.1, 0.5)
        time.sleep(processing_delay)
        
        # Increment metrics
        order_count.inc()
        processing_time.observe(processing_delay)
        request_count.labels(method='POST', endpoint='/order').inc()
        
        # Publish custom metric to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='PeexProject/CustomMetrics',
            MetricData=[
                {
                    'MetricName': 'OrdersCreated',
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'OrderProcessingTime',
                    'Value': processing_delay,
                    'Unit': 'Seconds',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        duration = time.time() - start_time
        request_duration.labels(endpoint='/order').observe(duration)
        
        return jsonify({
            'status': 'success',
            'message': 'Order created',
            'processing_time': processing_delay
        }), 201
        
    except Exception as e:
        error_count.labels(error_type='order_creation_error').inc()
        request_duration.labels(endpoint='/order').observe(time.time() - start_time)
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/users', methods=['GET', 'POST'])
def users():
    global current_users
    
    if request.method == 'POST':
        # Simulate user login
        current_users = min(current_users + random.randint(1, 5), 100)
        active_users.set(current_users)
        
        # Publish to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='PeexProject/CustomMetrics',
            MetricData=[
                {
                    'MetricName': 'ActiveUsers',
                    'Value': current_users,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        request_count.labels(method='POST', endpoint='/users').inc()
        return jsonify({'active_users': current_users}), 200
    else:
        request_count.labels(method='GET', endpoint='/users').inc()
        return jsonify({'active_users': current_users}), 200

@app.route('/health')
def health():
    request_count.labels(method='GET', endpoint='/health').inc()
    return jsonify({'status': 'healthy'}), 200

@app.route('/error')
def generate_error():
    """Endpoint to generate errors for testing alerts"""
    error_count.labels(error_type='test_error').inc()
    
    cloudwatch.put_metric_data(
        Namespace='PeexProject/CustomMetrics',
        MetricData=[
            {
                'MetricName': 'ErrorRate',
                'Value': 1,
                'Unit': 'Count',
                'Timestamp': datetime.utcnow()
            }
        ]
    )
    
    return jsonify({'status': 'error generated'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
APPEOF

# Create systemd service
cat > /etc/systemd/system/sample-app.service <<EOF
[Unit]
Description=Sample Application with Custom Metrics
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/sample-app
ExecStart=/usr/bin/python3 /opt/sample-app/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start application
systemctl daemon-reload
systemctl enable sample-app
systemctl start sample-app

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWEOF'
{
  "metrics": {
    "namespace": "PeexProject/Application",
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
