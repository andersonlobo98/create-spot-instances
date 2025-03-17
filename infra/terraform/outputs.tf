output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.spot_asg.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.spot_template.id
}
