resource "aws_ebs_volume" "persistent_storage" {
  count             = var.desired_capacity
  availability_zone = data.aws_subnet.existing.availability_zone
  size              = var.volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name          = "spot-persistent-volume-${var.environment}-${count.index}"
    Environment   = var.environment
    Persistence   = "true"
    InstanceIndex = "${count.index}"  # Adicionar um índice para mapeamento
    CostCenter    = "Labs"
    Project       = "SpotLab"
  }

# Um snapshot inicial vazio para backup
resource "aws_ebs_snapshot" "initial_snapshot" {
  count       = var.desired_capacity
  volume_id   = aws_ebs_volume.persistent_storage[count.index].id
  description = "Initial snapshot for spot instance persistence volume ${count.index}"
  
  tags = {
    Name        = "spot-persistent-snapshot-${var.environment}-${count.index}"
    Environment = var.environment
  }
}