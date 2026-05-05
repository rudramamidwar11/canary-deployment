resource "aws_sns_topic" "alerts" { name = "${var.project_name}-alerts" }

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CanaryErrorRate"
  namespace           = "${var.project_name}/app-metrics"
  period              = 60
  statistic           = "Average"
  threshold           = 5.0
  alarm_description   = "Canary error rate > 5% — auto rollback"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-rollback"
  retention_in_days = 7
}