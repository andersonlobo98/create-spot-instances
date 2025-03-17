resource "aws_launch_template" "spot_template" {
  name_prefix   = "spot-template-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.instance_security_group_id]
  }
  
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = var.spot_price
      instance_interruption_behavior = "terminate"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "spot-instance-${var.environment}"
      Environment = var.environment
    }
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "spot-volume-${var.environment}"
      Environment = var.environment
    }
  }
  
  iam_instance_profile {
    name = var.create_iam_role ? aws_iam_instance_profile.instance_profile[0].name : var.instance_iam_role_name
  } 
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Instalar dependências
    apt-get update -y
    apt-get install -y awscli jq

    # Script para identificar e montar volumes persistentes
    cat > /usr/local/bin/attach-volumes.sh << 'SCRIPT'
    #!/bin/bash
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')
    
   # Encontrar volumes marcados com a tag Persistence
    INSTANCE_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)
    INSTANCE_INDEX=$(echo $INSTANCE_NAME | grep -oE '[0-9]+$' || echo "0")

    # Tentar encontrar um volume específico para este índice de instância primeiro
    VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Persistence,Values=true" "Name=tag:Environment,Values=${var.environment}" "Name=tag:InstanceIndex,Values=$INSTANCE_INDEX" "Name=availability-zone,Values=$AVAILABILITY_ZONE" "Name=status,Values=available" --query "Volumes[0].VolumeId" --output text)

    # Se não houver um volume específico, obter qualquer volume disponível
    if [ "$VOLUME_ID" == "None" ] || [ -z "$VOLUME_ID" ]; then
      VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Persistence,Values=true" "Name=tag:Environment,Values=${var.environment}" "Name=availability-zone,Values=$AVAILABILITY_ZONE" "Name=status,Values=available" --query "Volumes[0].VolumeId" --output text)
    fi
    
    # Pegar o primeiro volume disponível
    VOLUME_ID=$(echo $VOLUMES | cut -d' ' -f1)
    
    # Anexar o volume
    aws ec2 attach-volume --region $REGION --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/xvdf
    
    # Esperar o volume ficar disponível
    echo "Aguardando o volume $VOLUME_ID ficar disponível..."
    while ! lsblk | grep -q xvdf; do
      sleep 5
    done
    
    # Verificar se o volume já está formatado
    if ! file -s /dev/xvdf | grep -q filesystem; then
      mkfs -t ext4 /dev/xvdf
    fi
    
    # Criar diretório de montagem
    mkdir -p /data
    
    # Montar o volume
    mount /dev/xvdf /data
    
    # Configurar montagem automática
    if ! grep -q "/dev/xvdf" /etc/fstab; then
      echo "/dev/xvdf /data ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    SCRIPT
    
    # Script para tratar interrupções spot
    cat > /usr/local/bin/handle-spot-interruption.sh << 'SCRIPT'
    #!/bin/bash
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
    
    # Verificar se há volume anexado
    VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" "Name=attachment.device,Values=/dev/xvdf" --query "Volumes[0].VolumeId" --output text)
    
    if [ "$VOLUME_ID" != "None" ]; then
      echo "Criando snapshot do volume $VOLUME_ID antes da interrupção..."
      SNAPSHOT_ID=$(aws ec2 create-snapshot --region $REGION --volume-id $VOLUME_ID --description "Spot interruption snapshot for $INSTANCE_ID" --query SnapshotId --output text)
      
      aws ec2 create-tags --region $REGION --resources $SNAPSHOT_ID --tags Key=Name,Value="spot-interruption-snapshot-${var.environment}" Key=Environment,Value=${var.environment}
      
      # Aguardar snapshot completar
      aws ec2 wait snapshot-completed --region $REGION --snapshot-ids $SNAPSHOT_ID
      
      # Desmontar o volume
      umount /data
      
      # Desanexar o volume
      aws ec2 detach-volume --region $REGION --volume-id $VOLUME_ID
    fi
    SCRIPT
    
    chmod +x /usr/local/bin/attach-volumes.sh
    chmod +x /usr/local/bin/handle-spot-interruption.sh
    
    # Monitorar interrupções de instâncias spot
    cat > /etc/systemd/system/spot-interruption-monitor.service << 'EOF'
    [Unit]
    Description=Monitor Spot Instance Interruption
    After=network.target
    
    [Service]
    Type=simple
    ExecStart=/bin/bash -c "while true; do if curl -s http://169.254.169.254/latest/meta-data/spot/instance-action; then /usr/local/bin/handle-spot-interruption.sh; break; fi; sleep 5; done"
    
    [Install]
    WantedBy=multi-user.target
    EOF
    
    systemctl enable spot-interruption-monitor
    systemctl start spot-interruption-monitor
    
    # Executar script de anexação de volume
    /usr/local/bin/attach-volumes.sh
  EOF
  )
}