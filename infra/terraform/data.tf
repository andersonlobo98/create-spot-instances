data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Obter detalhes da subnet existente
data "aws_subnet" "existing" {
  id = var.subnet_id
}

# Obter detalhes da NAT instance
data "aws_instance" "nat" {
  instance_id = var.nat_instance_id
}

# Se o security group da NAT não for especificado, obter os security groups da instância
locals {
  nat_security_group_id = var.nat_security_group_id != "" ? var.nat_security_group_id : tolist(data.aws_instance.nat.vpc_security_group_ids)[0]
}