# Alarme quando instâncias estão abaixo do mínimo
resource "aws_cloudwatch_metric_alarm" "spot_instance_termination" {
  alarm_name          = "spot-instance-termination-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = "60"
  statistic           = "Average"
  threshold           = var.min_size
  alarm_description   = "Monitor for spot instance termination"
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.spot_asg.name
  }
  
  alarm_actions = [aws_autoscaling_policy.scale_up_policy.arn]
  
  tags = {
    Environment = var.environment
  }
}

# Monitorar avisos de interrupção spot
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "spot-interruption-${var.environment}"
  description = "Detecta avisos de interrupção de instâncias spot"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

# Não referencia mais uma função Lambda inexistente
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "SendToSNSTopic"
  # Você pode criar um tópico SNS para notificações
  arn       = aws_sns_topic.spot_notifications.arn
}

# Tópico SNS para notificações
resource "aws_sns_topic" "spot_notifications" {
  name = "spot-interruption-notifications-${var.environment}"
  
  tags = {
    Environment = var.environment
  }
}

# Dashboard para monitoramento
resource "aws_cloudwatch_dashboard" "spot_dashboard" {
  dashboard_name = "spot-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.spot_asg.name]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "Instâncias em serviço",
          period  = 300
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.spot_asg.name]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "CPU Utilization",
          period  = 300
        }
      },
      {
        type   = "metric", 
        x      = 12,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", aws_autoscaling_group.spot_asg.name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", aws_autoscaling_group.spot_asg.name]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "Network Traffic",
          period  = 300
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EBS", "VolumeReadOps", "VolumeId", "*", {"label": "Read Ops"}],
            ["AWS/EBS", "VolumeWriteOps", "VolumeId", "*", {"label": "Write Ops"}]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "EBS Operations",
          period  = 300
        }
      }
    ]
  })
}