aws_region          = "us-east-1"
instance_type       = "t3.large"
spot_price          = "0.055"  # Verificar o preço spot atual para t3.large
volume_size         = 40
ami_id              = "ami-0e785a1175643a738"  # Amazon Linux 2023 - verificar ID correto para sua região

# IDs dos recursos existentes
vpc_id                    = "vpc-0c9fe3021f4bd75a1"
subnet_id                 = "subnet-085db4417d01eeca6"
nat_instance_id           = "i-0a41851aaff427d75"
instance_security_group_id = "sg-00e4a59e201e375cf"

# Configuração do autoscaling
min_size           = 4
max_size           = 4
desired_capacity   = 4

# IAM Role
create_iam_role    = true