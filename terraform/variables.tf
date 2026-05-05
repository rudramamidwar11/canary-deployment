variable "aws_region"    { default = "us-east-1" }
variable "project_name"  { default = "canary-deploy" }
variable "instance_type" { default = "t2.micro" }
# Amazon Linux 2023 — us-east-1 (update if needed)
variable "ami_id"        { default = "ami-0453ec754f44f9a4a" }
variable "github_org"    { description = "Your GitHub username" }
variable "github_repo"   { description = "Your repo name" }
variable "alert_email"   { description = "Email for alarm notifications" }