variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"  # t3.large conforme solicitado
}

variable "spot_price" {
  description = "Maximum spot price in USD"
  type        = string
  default     = "0.055"  # Ajuste conforme preços atuais da região
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 40  # 40GB conforme solicitado
}

variable "ami_id" {
  description = "AMI ID for the instances"
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 4  
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4  
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 4  
}

# Recursos de rede existentes
variable "vpc_id" {
  description = "ID da VPC existente"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet privada existente"
  type        = string
}

variable "nat_instance_id" {
  description = "ID da NAT instance existente"
  type        = string
}

variable "nat_security_group_id" {
  description = "ID do security group da NAT instance"
  type        = string
  default     = ""  # Deixe vazio para usar o mesmo que a NAT instance
}

variable "instance_security_group_id" {
  description = "ID do security group existente para as instâncias"
  type        = string
}

# Adicionando variáveis para o IAM role
variable "create_iam_role" {
  description = "Whether to create a new IAM role for instances"
  type        = bool
  default     = true
}

variable "instance_iam_role_name" {
  description = "Name of existing IAM role to use (if create_iam_role = false)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Lista de IDs de subnets privadas para o ASG"
  type        = list(string)
  # Você pode usar a subnet id que você já tem como padrão
  default     = []
}