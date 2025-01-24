# Configuración del proveedor AWS
provider "aws" {
  region = "us-west-1"
}

# Referenciar un Grupo de Seguridad existente
# 4. Datos del Target Group Existente
data "aws_lb_target_group" "existing_tg" {
  name = "TG-ALB-MICROSERVICE-TFM" # Nombre del Target Group existente
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar la política predefinida de AWS para ejecución de tareas ECS
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Crear un Security Group
resource "aws_security_group" "ecs_task_sg" {
  name        = "SG-TASK-MICROSERVICE"
  description = "Security Group Para Tareas ECS"
  vpc_id      = var.vpc_id  # Asegúrate de proporcionar el ID de tu VPC

  # Reglas de entrada (inbound)
  ingress {
    from_port   = 8080                    # Puerto abierto para el contenedor
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]           # Permitir tráfico desde cualquier IP
  }

  # Reglas de salida (outbound)
  egress {
    from_port   = 0                       # Permitir todo el tráfico de salida
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear un repositorio en ECR
resource "aws_ecr_repository" "my_repository" {
  name = "ecr-repo-microservice"
}

# Crear un clúster ECS
resource "aws_ecs_cluster" "my_cluster" {
  name = var.cluster_name
}

# Crear la definición de tarea ECS
resource "aws_ecs_task_definition" "my_task" {
  family                   = "TASK-MICROSERVICE-TFM"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"     # 1/4 de vCPU
  memory                   = "512"     # 512 MB de memoria
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn  # Referencia al rol creado


  container_definitions = jsonencode([{
    name      = "CONTAINER-TASK"
    image     = "${aws_ecr_repository.my_repository.repository_url}:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

# Crear un servicio ECS
resource "aws_ecs_service" "my_service" {
  name            = "SRV-MICROSERVICE"
  cluster         = aws_ecs_cluster.my_cluster.arn
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.ecs_task_sg.id]

    assign_public_ip = true
  }

 load_balancer {
    target_group_arn = data.aws_lb_target_group.existing_tg.arn
    container_name   = "CONTAINER-TASK" # Nombre del contenedor en la Task Definition
    container_port   = 8080
  }
}


########################################################## Configuración para Auto Scaling #################################################################
# Configuración del objetivo de autoescalado para ECS
resource "aws_appautoscaling_target" "ecs_service" {
    max_capacity       = 5  # Máximo número de tareas que el servicio puede escalar
    min_capacity       = 1  # Mínimo número de tareas que el servicio debe mantener
    resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.my_service.name}"  # Identificador del recurso ECS que será escalado
    scalable_dimension = "ecs:service:DesiredCount"  # Dimensión escalable para el número de tareas deseadas
    service_namespace  = "ecs"  # Espacio de nombres del servicio ECS
}

# Política de autoescalado para aumentar tareas
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "scale-up-policy"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
        adjustment_type         = "ChangeInCapacity"  # Tipo de ajuste para modificar la capacidad deseada
        cooldown                = 60  # Tiempo de espera entre ajustes de escalado
    metric_aggregation_type = "Maximum"

    step_adjustment {
            scaling_adjustment = 1  # Incremento de 1 tarea al escalar hacia arriba
      metric_interval_lower_bound = 0
    }
  }
}

# Política de autoescalado para reducir tareas
resource "aws_appautoscaling_policy" "scale_down" {
  name               = "scale-down-policy"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      scaling_adjustment = -1  # Decremento de 1 tarea al escalar hacia abajo
      metric_interval_upper_bound = 0
    }
  }
}
####################################AUTO ESCALIMG BASADO EN CPU#############################
# Auto Scaling basado en métricas de CPU
# Configuración de la alarma para alto uso de CPU
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
    alarm_name          = "ECS-High-CPU-Usage"  # Nombre descriptivo para la alarma de alto uso de CPU
    comparison_operator = "GreaterThanThreshold"  # Activa la alarma si el uso de CPU supera el umbral definido
    evaluation_periods  = 2  # Número de períodos consecutivos necesarios para activar la alarma
    metric_name         = "CPUUtilization"  # Métrica monitoreada: Utilización de CPU
    namespace           = "AWS/ECS"
    period              = 60
    statistic           = "Average"
    threshold           = 75  # Umbral de uso de memoria en porcentaje que activa la alarma  # Umbral de uso de CPU en porcentaje que activa la alarma

  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

      alarm_actions = [aws_appautoscaling_policy.scale_up.arn]  # Acción a ejecutar: escalar hacia arriba  # Acción a ejecutar: escalar hacia arriba
}

# Configuración de la alarma para bajo uso de CPU
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "ECS-Low-CPU-Usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold       = 25  # Umbral de uso de memoria en porcentaje que activa la alarma de bajo uso  # Umbral de uso de CPU en porcentaje que activa la alarma de bajo uso

  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

      alarm_actions = [aws_appautoscaling_policy.scale_down.arn]  # Acción a ejecutar: escalar hacia abajo  # Acción a ejecutar: escalar hacia abajo
}
####################################AUTO ESCALIMG BASADO EN MEMORIA#############################
# Auto Scaling basado en métricas de memoria
# Configuración de la alarma para alto uso de memoria
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "ECS-High-Memory-Usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
    metric_name         = "MemoryUtilization"  # Métrica monitoreada: Utilización de memoria
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
}

# Configuración de la alarma para bajo uso de memoria
resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "ECS-Low-Memory-Usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 25

  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_down.arn]
}


