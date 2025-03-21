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
  # Obter token de autenticação para metadados
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  # Obter ID da instância
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
  # Obter zona de disponibilidade
  AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
  # Extrair região da zona de disponibilidade
  REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')

  # Verificar se o volume já está montado
  if mount | grep -q "/data"; then
    echo "Volume já está montado em /data. Pulando montagem."
    exit 0
  fi

  # Encontrar volumes marcados com a tag Persistence
  INSTANCE_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)
  INSTANCE_INDEX=$(echo $INSTANCE_NAME | grep -oE '[0-9]+$' || echo "0")

  # Tentar encontrar um volume específico para este índice de instância primeiro
  VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Persistence,Values=true" "Name=tag:Environment,Values=prod" "Name=tag:InstanceIndex,Values=$INSTANCE_INDEX" "Name=availability-zone,Values=$AVAILABILITY_ZONE" "Name=status,Values=available" --query "Volumes[0].VolumeId" --output text)

  # Se não houver um volume específico, obter qualquer volume disponível
  if [ "$VOLUME_ID" == "None" ] || [ -z "$VOLUME_ID" ]; then
    VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Persistence,Values=true" "Name=tag:Environment,Values=prod" "Name=availability-zone,Values=$AVAILABILITY_ZONE" "Name=status,Values=available" --query "Volumes[0].VolumeId" --output text)
  fi

  # Anexar o volume se encontrado
  if [ "$VOLUME_ID" != "None" ] && [ ! -z "$VOLUME_ID" ]; then
    echo "Anexando volume $VOLUME_ID à instância $INSTANCE_ID..."
    if ! aws ec2 attach-volume --region $REGION --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/xvdf; then
      echo "Falha ao anexar o volume. Saindo."
      exit 1
    fi

    # Esperar o volume ficar disponível
    echo "Aguardando o volume $VOLUME_ID ficar disponível..."
    COUNTER=0
    MAX_WAIT=60  # 5 minutos (60 * 5s)
    while ! lsblk | grep -q xvdf; do
      sleep 5
      COUNTER=$((COUNTER+1))
      if [ $COUNTER -ge $MAX_WAIT ]; then
        echo "Tempo limite esgotado aguardando o volume. Saindo."
        exit 1
      fi
    done

    # Criar diretório de montagem
    mkdir -p /data

    # Verificar se o volume já está formatado
    FORMATTED=$(blkid /dev/xvdf || echo "")
    if [ -z "$FORMATTED" ]; then
      echo "Formatando volume $VOLUME_ID..."
      mkfs -t ext4 /dev/xvdf
      if [ $? -ne 0 ]; then
        echo "Falha ao formatar o volume. Saindo."
        exit 1
      fi
    else
      echo "Volume já está formatado."
    fi

    # Montar o volume
    echo "Montando volume em /data..."
    if ! mount /dev/xvdf /data; then
      echo "Falha ao montar o volume. Saindo."
      exit 1
    fi

    # Configurar montagem automática
    if ! grep -q "/dev/xvdf" /etc/fstab; then
      echo "Configurando montagem automática..."
      echo "/dev/xvdf /data ext4 defaults,nofail 0 2" >> /etc/fstab
    fi

    echo "Volume $VOLUME_ID montado com sucesso em /data."
  else
    echo "Nenhum volume persistente disponível encontrado."
  fi
  SCRIPT

  # Script para tratar interrupções spot
  cat > /usr/local/bin/handle-spot-interruption.sh << 'SCRIPT'
  #!/bin/bash
  # Obter token de autenticação para metadados
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  # Obter ID da instância
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
  # Obter região
  REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

  # Verificar se há volume anexado
  VOLUME_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" "Name=attachment.device,Values=/dev/xvdf" --query "Volumes[0].VolumeId" --output text)

  if [ "$VOLUME_ID" != "None" ] && [ ! -z "$VOLUME_ID" ]; then
    echo "Criando snapshot do volume $VOLUME_ID antes da interrupção..."
    SNAPSHOT_ID=$(aws ec2 create-snapshot --region $REGION --volume-id $VOLUME_ID --description "Spot interruption snapshot for $INSTANCE_ID" --query SnapshotId --output text)

    if [ -z "$SNAPSHOT_ID" ]; then
      echo "Falha ao criar snapshot. Continuando com desanexação do volume."
    else
      echo "Snapshot $SNAPSHOT_ID criado. Adicionando tags..."
      aws ec2 create-tags --region $REGION --resources $SNAPSHOT_ID --tags Key=Name,Value="spot-interruption-snapshot-prod" Key=Environment,Value=prod

      # Aguardar snapshot completar (com timeout)
      echo "Aguardando conclusão do snapshot..."
      COUNTER=0
      MAX_WAIT=36  # 3 minutos (36 * 5s)
      while true; do
        STATUS=$(aws ec2 describe-snapshots --region $REGION --snapshot-ids $SNAPSHOT_ID --query "Snapshots[0].State" --output text)
        if [ "$STATUS" = "completed" ]; then
          echo "Snapshot concluído com sucesso."
          break
        fi

        COUNTER=$((COUNTER+1))
        if [ $COUNTER -ge $MAX_WAIT ]; then
          echo "Tempo limite esgotado aguardando o snapshot. Continuando com desanexação do volume."
          break
        fi

        sleep 5
      done
    fi

    # Desmontar o volume
    echo "Desmontando o volume..."
    if mount | grep -q "/data"; then
      umount /data
      if [ $? -ne 0 ]; then
        echo "Falha ao desmontar o volume. Tentando força a desmontagem..."
        umount -f /data
      fi
    fi

    # Desanexar o volume
    echo "Desanexando o volume $VOLUME_ID..."
    aws ec2 detach-volume --region $REGION --volume-id $VOLUME_ID
    echo "Volume $VOLUME_ID desanexado com sucesso."
  fi

  echo "Tratamento de interrupção spot concluído."
  SCRIPT

  chmod +x /usr/local/bin/attach-volumes.sh
  chmod +x /usr/local/bin/handle-spot-interruption.sh

  # Monitorar interrupções de instâncias spot
  cat > /etc/systemd/system/spot-interruption-monitor.service << 'SERVICEDEF'
  [Unit]
  Description=Monitor Spot Instance Interruption
  After=network.target

  [Service]
  Type=simple
  ExecStart=/bin/bash -c "while true; do if curl -s http://169.254.169.254/latest/meta-data/spot/instance-action; then /usr/local/bin/handle-spot-interruption.sh && echo 'Interrupção spot tratada, encerrando serviço.' && exit 0; fi; sleep 5; done"
  Restart=on-failure
  RestartSec=30
  StandardOutput=journal
  StandardError=journal

  [Install]
  WantedBy=multi-user.target
  SERVICEDEF

  systemctl enable spot-interruption-monitor
  systemctl start spot-interruption-monitor

  # Executar script de anexação de volume
  /usr/local/bin/attach-volumes.sh
EOF
)