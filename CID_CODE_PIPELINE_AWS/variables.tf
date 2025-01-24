variable "codecommit_repo_name" {
  description = "Nombre del repositorio CodeCommit existente"
  type        = string
}

variable "branch_name" {
  description = "Nombre de la rama en CodeCommit"
  type        = string
  default     = "master"
}

variable "ecs_cluster_name" {
  description = "Nombre del clúster ECS existente"
  type        = string
}

variable "ecs_service_name" {
  description = "Nombre del servicio ECS existente"
  type        = string
}

variable "codebuild_project_name" {
  description = "Nombre del proyecto CodeBuild existente"
  type        = string
}
