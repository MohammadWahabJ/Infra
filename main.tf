# Provider for AWS
provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

# Subnet for Load Balancer in ap-south-1a
resource "aws_subnet" "public_subnet_alb" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"  # Subnet in ap-south-1a for ALB

  tags = {
    Name = "PublicSubnetALB"
  }
}

# Subnet for ECS tasks in ap-south-1b
resource "aws_subnet" "public_subnet_ecs" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"  # Subnet in ap-south-1b for ECS tasks

  tags = {
    Name = "PublicSubnetECS"
  }
}

# Internet Gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyIGW"
  }
}

# Route Table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Route Table with Subnet for ALB
resource "aws_route_table_association" "rta_public_alb" {
  subnet_id      = aws_subnet.public_subnet_alb.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate Route Table with Subnet for ECS
resource "aws_route_table_association" "rta_public_ecs" {
  subnet_id      = aws_subnet.public_subnet_ecs.id
  route_table_id = aws_route_table.public_route_table.id
}


# Application Load Balancer (ALB) in ap-south-1a
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false  # Public-facing ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_alb.id,aws_subnet.public_subnet_ecs.id]  # ALB in ap-south-1a

  tags = {
    Name = "MyALB"
  }
}

# Security Group for ALB 
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALBSecurityGroup"
  }
}






# ECS Cluster
resource "aws_ecs_cluster" "my_ecs_cluster" {
  name = "my-ecs-cluster"

  tags = {
    Name = "MyECSCluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "my-container"
      image     = "${aws_ecr_repository.my_ecr_repository.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true

      portMappings = [{
        containerPort = 80
        hostPort      = 80
      }]

      environment = [
    {
       "name":"DB_NAME",
       "value":"postgres"
    },
    {
       "name":"DB_USER",
       "value":"dbtestuser"
    },
    {
       "name":"DB_PASS",
       "value":"password123"
    },
    {
       "name":"DB_HOST",
       "value":"terraform-20241006180357721100000001.cpekewewqm5e.ap-south-1.rds.amazonaws.com"
    },
    {
       "name":"DB_PORT",
       "value":"5432"
    },
    {
       "name":"APP_SECRET",
       "value":"sntmf1hhfxaMfckv4u16B89emqt9PTfg"
    }
    
    ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/ef-dev-ecs-task"
          mode                  = "non-blocking"
          awslogs-create-group  = "true"
          max-buffer-size       = "25m"
          awslogs-region        = "ap-south-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.40.2"
      cpu       = 0
      essential = true
      command   = ["--config=/etc/ecs/ecs-cloudwatch-xray.yaml"]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/ecs-aws-otel-sidecar-collector"
          mode                  = "non-blocking"
          awslogs-create-group  = "true"
          max-buffer-size       = "25m"
          awslogs-region        = "ap-south-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
#   container_definitions = <<DEFINITION
# [
#   {
#     "name": "my-container",
#     "image": "nginx",   
#     "essential": true,
#     "environment":[
#     {
#        "name":"DB_NAME",
#        "value":"postgress"
#     },
#     {
#        "name":"DB_USER",
#        "value":"dbtestuser"
#     },
#     {
#        "name":"DB_PASS",
#        "value":"password123"
#     },
#     {
#        "name":"DB_HOST",
#        "value":"terraform-20241006180357721100000001.cpekewewqm5e.ap-south-1.rds.amazonaws.com"
#     },
#     {
#        "name":"DB_PORT",
#        "value":"5432"
#     },
#     {
#        "name":"APP_SECRET",
#        "value":"sntmf1hhfxaMfckv4u16B89emqt9PTfg"
#     }
    
#     ],
#     "portMappings": [
#       {
#         "containerPort": 80,
#         "hostPort": 80
#       }
#     ]
#   }
# ]
# DEFINITION
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}








# ECS Service in ap-south-1b
resource "aws_ecs_service" "my_ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_ecs.id]  # ECS tasks in ap-south-1b
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.my_tg.arn
    container_name   = "my-container"
    container_port   = 80
  }

  desired_count = 1
}

# Security Group for ECS Service (Allow HTTP traffic)
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ECSSecurityGroup"
  }
}

# Target Group for ECS tasks in ap-south-1b
resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  target_type = "ip"  

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  tags = {
    Name = "MyTG"
  }
}


# ALB Listener in ap-south-1a (Listening for HTTP traffic)
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_alb.arn  # ALB is in ap-south-1a
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn  # Forward traffic to ECS tasks in ap-south-1b
  }
}





# DB creation section comes here............................................

# Security Group for RDS (Allow MySQL traffic only from ECS Security Group)
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]  # Allow traffic only from the ECS security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  tags = {
    Name = "RDSSecurityGroup"
  }
}


# RDS Subnet Group (Associates the public subnet for the RDS)
resource "aws_db_subnet_group" "my_rds_subnet_group" {
  name       = "my-rds-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_ecs.id,aws_subnet.public_subnet_alb.id]  # Place the RDS in the same public subnet as the ECS tasks

  tags = {
    Name = "MyRDSSubnetGroup"
  }
}


# RDS Instance (PostgreSQL) in a single AZ (ap-south-1b)
resource "aws_db_instance" "my_rds_instance" {
  allocated_storage    = 20
  engine               = "postgres"     # PostgreSQL engine
  instance_class       = "db.t3.micro"  # Instance class for cost-efficiency
  username             = "dbtestuser"        # Master username for the database
  password             = "password123"  # Master password for the database (ensure it's secure)
  db_subnet_group_name = aws_db_subnet_group.my_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]  # Reuse the RDS security group
  publicly_accessible  = true           # Set to true if you want the RDS to be publicly accessible
  skip_final_snapshot  = true           # Skip snapshot when deleting (optional)
  availability_zone    = "ap-south-1b"  # Restrict RDS to one AZ (ap-south-1b)


  tags = {
    Name = "MyPostgresRDSInstance"
  }
}



# ECR
# Create an ECR repository
resource "aws_ecr_repository" "my_ecr_repository" {
  name = "my-app-repo"  # Name of the ECR repository

  # Optional: Configure image scanning and retention policy
  image_scanning_configuration {
    scan_on_push = true  # Enable image scanning on push
  }

  image_tag_mutability = "MUTABLE"  # Allows overwriting image tags


}

