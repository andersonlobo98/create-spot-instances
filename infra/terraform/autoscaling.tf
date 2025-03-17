resource "aws_autoscaling_group" "spot_asg" {
  name                = "spot-asg-${var.environment}"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  # Usar múltiplas subnets para alta disponibilidade
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }
    
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.spot_template.id
        version            = "$Latest"
      }
      
      # Adicionar vários tipos de instância compatíveis
      override {
        instance_type = "t3.large"  # Seu tipo principal
      }
      override {
        instance_type = "t3a.large"  # AMD pode ser mais barato
      }
      override {
        instance_type = "m5.large"  # Alternativa com bom custo-benefício 
      }
      override {
        instance_type = "m5a.large"  # Versão AMD da m5
      }
    }
  }
  
  tag {
    key                 = "Name"
    value               = "spot-instance-${var.environment}"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "CostCenter"
    value               = "Labs"
    propagate_at_launch = true
  }
  
  # Protege durante regeneração
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 75
    }
  }

  # Garantir que o ASG aguarde até que uma instância esteja totalmente em serviço
  wait_for_capacity_timeout = "15m"
}

# Política de escalonamento para recuperar instâncias
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "spot-scale-up-policy-${var.environment}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.spot_asg.name
}

# Lifecycle hook para operações antes da terminação
resource "aws_autoscaling_lifecycle_hook" "termination_hook" {
  name                   = "spot-termination-hook-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.spot_asg.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}