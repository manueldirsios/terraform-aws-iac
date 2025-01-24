provider "aws" {
  region = "us-west-1" # Cambia a tu región preferida
}

# Crear un Security Group para RDS
resource "aws_security_group" "rds_sg" {
  name        = "SG-RDS-MICROSERVICE"
  description = "Security Group para la base de datos RDS"
  vpc_id      = "vpc-09a1df448b7c1a839" # ID de tu VPC

  ingress {
    description = "Permitir acceso MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Abierto a todas las IPs (ajústalo según tus necesidades)
  }

  egress {
    description = "Permitir trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear la base de datos RDS MySQL
resource "aws_db_instance" "rds_instance" {
  identifier              = "rds-microservice-instance" # Identificador de la instancia
  db_name                 = "rds_microservice_db" # Nombre de la base de datos inicial
  allocated_storage       = 20                   # Almacenamiento mínimo (GB)
  engine                  = "mysql"              # Motor de base de datos
  engine_version          = "8.0"                # Versión de MySQL
  instance_class          = "db.t3.micro"        # Instancia económica
  username                = "admin"              # Usuario administrador
  password                = "SecurePass123!"     # Contraseña (reemplázala por una segura)
  publicly_accessible     = true                 # No accesible públicamente
  skip_final_snapshot     = true                 # Evita snapshot al destruir
  vpc_security_group_ids  = [aws_security_group.rds_sg.id] # Asociar SG
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "RDS-Microservice-DB"
    Environment = "Dev"
  }
}

# Crear un Subnet Group para RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "rds-subnet-group"
  description = "Grupo de subnets para RDS"
  subnet_ids  = ["subnet-0e2ccef71ac17fea2", "subnet-0bb2e1d426f7f0dc7"] # Subnets existentes

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Output para el endpoint de la base de datos
output "rds_endpoint" {
  value = aws_db_instance.rds_instance.endpoint
}
