variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil AWS CLI"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets para as instâncias Spot"
  type        = list(string)
}

variable "ami_id" {
  description = "ID da AMI"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, stage, prod)"
  type        = string
}

variable "project" {
  description = "Nome do projeto"
  type        = string
}