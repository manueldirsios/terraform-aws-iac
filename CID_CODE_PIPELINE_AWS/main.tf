provider "aws" {
  region = "us-west-1"
}

# Obtener el repositorio CodeCommit existente
data "aws_codecommit_repository" "repo" {
  repository_name = var.codecommit_repo_name
}

# Obtener el clúster ECS existente
data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

# Obtener el servicio ECS existente
data "aws_ecs_service" "ecs_service" {
  cluster = data.aws_ecs_cluster.ecs_cluster.arn
  service = var.ecs_service_name
}

# Crear un bucket S3 para almacenar artefactos de CodePipeline
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "pipeline-artifacts-${random_id.bucket_id.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

# Crear un rol para CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar permisos necesarios al rol de CodePipeline
resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Crear una canalización de CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "ecs-deployment-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = data.aws_codecommit_repository.repo.repository_name
        BranchName     = var.branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "DeployAction"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      version          = "1"
      input_artifacts  = ["build_output"]

      configuration = {
        ClusterName        = data.aws_ecs_cluster.ecs_cluster.name
        ServiceName        = data.aws_ecs_service.ecs_service.service_name
        FileName           = "imagedefinitions.json"
      }
    }
  }
}
