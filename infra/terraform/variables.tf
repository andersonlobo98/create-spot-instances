variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil AWS CLI"
  type        = string
  default     = "terraform-user"
}

variable "subnet_ids" {
  description = "Lista de subnets para as instâncias Spot"
  type        = list(string)
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "ID da AMI"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "desired_capacity" {
  description = "Número desejado de instâncias"
  type        = number
  default     = 4
}

variable "max_size" {
  description = "Máximo de instâncias"
  type        = number
  default     = 4
}

variable "min_size" {
  description = "Mínimo de instâncias"
  type        = number
  default     = 4
}

# variables.tf (adicionar)
variable "environment" {
  description = "Ambiente (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Nome do projeto"
  type        = string
  default     = "spot-project"
}

# variables.tf
variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition     = contains(["t3.medium", "t3a.medium", "t2.medium"], var.instance_type)
    error_message = "O tipo de instância deve ser um dos seguintes: t3.medium, t3a.medium, t2.medium."
  }
}