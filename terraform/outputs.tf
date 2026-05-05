output "ec2_public_ip"           { value = aws_eip.app.public_ip }
output "ec2_instance_id"         { value = aws_instance.app.id }
output "ecr_repository_url"      { value = aws_ecr_repository.app.repository_url }
output "github_actions_role_arn" { value = aws_iam_role.github_actions_role.arn }
output "app_url"                 { value = "http://${aws_eip.app.public_ip}" }
output "prometheus_url"          { value = "http://${aws_eip.app.public_ip}:9090" }
output "grafana_url"             { value = "http://${aws_eip.app.public_ip}:3000" }