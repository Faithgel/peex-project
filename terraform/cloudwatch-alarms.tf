# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-topic"

  tags = {
    Name = "${var.project_name}-alerts-topic"
  }
}

# SNS Subscription (email - update with your email)
# Uncomment and configure with your email
# resource "aws_sns_topic_subscription" "email" {
#   topic_arn = aws_sns_topic.alerts.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }

# Static Threshold Alert: High CPU Usage
resource "aws_cloudwatch_metric_alarm" "high_cpu_prometheus" {
  alarm_name          = "${var.project_name}-prometheus-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "PeexProject/Prometheus"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Prometheus CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.prometheus.id
  }

  tags = {
    Name = "${var.project_name}-prometheus-high-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_grafana" {
  alarm_name          = "${var.project_name}-grafana-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "PeexProject/Grafana"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Grafana CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.grafana.id
  }

  tags = {
    Name = "${var.project_name}-grafana-high-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_application" {
  alarm_name          = "${var.project_name}-application-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "PeexProject/Application"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors application CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.application.id
  }

  tags = {
    Name = "${var.project_name}-application-high-cpu-alarm"
  }
}

# Static Threshold Alert: High Memory Usage
resource "aws_cloudwatch_metric_alarm" "high_memory_prometheus" {
  alarm_name          = "${var.project_name}-prometheus-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "PeexProject/Prometheus"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This metric monitors Prometheus memory usage"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.prometheus.id
  }

  tags = {
    Name = "${var.project_name}-prometheus-high-memory-alarm"
  }
}

# Custom Metric Alert: High Order Rate
resource "aws_cloudwatch_metric_alarm" "high_order_rate" {
  alarm_name          = "${var.project_name}-high-order-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "OrdersCreated"
  namespace           = "PeexProject/CustomMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This metric monitors order creation rate (business metric)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-high-order-rate-alarm"
  }
}

# Custom Metric Alert: High Error Rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorRate"
  namespace           = "PeexProject/CustomMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors application error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-high-error-rate-alarm"
  }
}

# Anomaly Detection Alert: Active Users
resource "aws_cloudwatch_metric_alarm" "anomaly_active_users" {
  alarm_name          = "${var.project_name}-anomaly-active-users"
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "e1"
  alarm_description   = "This metric monitors active users for anomalies"

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "ActiveUsers (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "ActiveUsers"
      namespace   = "PeexProject/CustomMetrics"
      period      = 300
      stat        = "Average"
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-anomaly-active-users-alarm"
  }
}

# Composite Alarm: High CPU + High Error Rate
resource "aws_cloudwatch_composite_alarm" "high_cpu_and_errors" {
  alarm_name        = "${var.project_name}-composite-cpu-errors"
  alarm_description = "Composite alarm: High CPU and high error rate"
  alarm_rule        = "ALARM(${aws_cloudwatch_metric_alarm.high_cpu_application.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.high_error_rate.alarm_name})"
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-composite-cpu-errors-alarm"
  }
}

# Maintenance Window (suppress alerts during maintenance)
resource "aws_ssm_maintenance_window" "maintenance" {
  name     = "${var.project_name}-maintenance-window"
  schedule = "cron(0 2 ? * SUN *)" # Every Sunday at 2 AM
  duration = 4
  cutoff   = 1
}
