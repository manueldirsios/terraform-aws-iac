provider "aws" {
  region = "us-west-1"
}

# Obtener el repositorio CodeCommit existente
data "aws_codecommit_repository" "repo" {
  repository_name = var.codecommit_repo_name
}

# Crear un rol para CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar permisos necesarios al rol de CodeBuild
resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Usa mínimos privilegios en producción
}

# Crear un proyecto de CodeBuild
resource "aws_codebuild_project" "codebuild_project" {
  name         = "CD-MICROSERVICE"
  service_role = aws_iam_role.codebuild_role.arn

  source {
    type     = "CODECOMMIT"
    location = data.aws_codecommit_repository.repo.clone_url_http
    buildspec = "buildspec.yml"
    
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # Variables de entorno opcionales
    environment_variable {
      name  = "ENVIRONMENT"
      value = "production"
    }
  }

  # Bloque de artefactos (requerido)
  artifacts {
    type = "NO_ARTIFACTS" # No se generarán artefactos
  }


}

output "codebuild_project_name" {
  value = aws_codebuild_project.codebuild_project.name
}

output "codecommit_repo_url" {
  value = data.aws_codecommit_repository.repo.clone_url_http
}
