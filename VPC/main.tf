# Proveedor de AWS
provider "aws" {
  region = "us-west-1" # Cambia según tu región preferida
}

# Crear una VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.99.70.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-TFM"
  }
}

# Crear una Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "IG-TFM"
  }
}

# Crear una Tabla de Rutas para Subredes Públicas
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "RT-PUBLIC-TFM"
  }
}

# Crear una Subred Pública
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.99.70.16/28"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-1b"

  tags = {
    Name = "SUBNET-PUB-TFM"
  }
}

# Asociar la Tabla de Rutas con la Subred Pública
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Crear una Subred Privada
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.99.70.32/28"
  availability_zone = "us-west-1c"

  tags = {
    Name = "SUBNET-PRIV-TFM"
  }
}