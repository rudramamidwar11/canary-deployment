data "archive_file" "rollback" {
  type        = "zip"
  source_file = "${path.module}/../lambda/rollback.py"
  output_path = "${path.module}/../lambda/rollback.zip"
}

resource "aws_lambda_function" "rollback" {
  filename         = data.archive_file.rollback.output_path
  function_name    = "${var.project_name}-rollback"
  role             = aws_iam_role.lambda_role.arn
  handler          = "rollback.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.rollback.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      EC2_INSTANCE_ID = aws_instance.app.id
      PROJECT_NAME    = var.project_name
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rollback.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.error_rate.arn
}