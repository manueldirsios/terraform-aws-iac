# Proveedor de AWS
provider "aws" {
  region = "us-west-1" # Cambia a tu región preferida
}

# Referenciar una Subred existente
data "aws_subnet" "existing_subnet" {
  id = "subnet-072d4a047ae31e99c" # Reemplaza con el ID de tu Subnet
}

# Referenciar un Grupo de Seguridad existente
data "aws_security_group" "existing_sg" {
  id = "sg-03e89f6b0cdaba8c7" # Reemplaza con el ID de tu Security Group
}
# Crear una clave SSH para acceder a la instancia
resource "aws_key_pair" "my_key" {
  key_name   = "my-terraform-key"
  public_key = file("/ssh/id_rsa.pub") # Ruta a tu clave pública SSH
}

# Instancia EC2
resource "aws_instance" "my_ec2" {
  ami           = "ami-038bba9a164eb3dc1" # Amazon Linux 2 AMI
  instance_type = "t2.micro"

  key_name = aws_key_pair.my_key.key_name
  #Asociar subnet existente
  subnet_id              = data.aws_subnet.existing_subnet.id
  #Asociar grupo de seguridad  existente
  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]
  #Asociar ip publica
  associate_public_ip_address = true

  tags = {
    Name = "EC2-TERRAFORM-PERSONALIZE-NETWORK"
  }
}

# Salida: IP pública de la instancia
output "instance_ip" {
  value = aws_instance.my_ec2.public_ip
}
