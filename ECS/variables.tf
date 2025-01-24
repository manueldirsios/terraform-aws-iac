# Declarar las variables necesarias

variable "cluster_name" {
  description = "Nombre del ECS Cluster"
  type        = string
}

variable "ecs_task_execution_role" {
  description = "ARN del rol de ejecución de ECS"
  type        = string
}

variable "subnets" {
  description = "Lista de subredes para el servicio ECS"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID de la VPC donde se creará el Security Group"
  type        = string
}
