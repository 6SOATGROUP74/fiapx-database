# Provedor da AWS
provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}

resource "aws_db_instance" "data_base" {


  depends_on = [
    aws_secretsmanager_secret.ssm_rds,aws_security_group_rule.allow_mysql_ingress
  ]

  allocated_storage      = 20
  db_name                = "db_security"
  identifier             = "fiapx-security-database"
  engine                 = "mysql"
  engine_version         = "8.0.37"
  instance_class         = "db.t3.micro"
  username               = jsondecode(aws_secretsmanager_secret_version.ssm_rds_version.secret_string)["username"]
  password               = jsondecode(aws_secretsmanager_secret_version.ssm_rds_version.secret_string)["password"]
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}


resource "aws_secretsmanager_secret" "ssm_rds" {
  description = "RDS MySQL"
}

resource "aws_secretsmanager_secret_version" "ssm_rds_version" {

  secret_id = aws_secretsmanager_secret.ssm_rds.id
  secret_string = jsonencode({
    username = "tech_user"
    password = "tech_password"
  })
}

resource "aws_security_group_rule" "allow_mysql_ingress" {

  depends_on = [
    aws_security_group.rds_sg
  ]

  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "rds_sg" {
  name        = "shogun-rds-security-group"
  description = "Security group for RDS MySQL"
  vpc_id      = data.aws_vpc.this.id
}

resource "aws_dynamodb_table" "example" {
  name           = "tb_fiapx_core"
  billing_mode   = "PROVISIONED"
  hash_key       = "id"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }

  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES" 

  tags = {
    Environment = "prod"
  }
}

resource "aws_lambda_function" "example" {
  function_name = "lambda-streams-email"
  role          = "arn:aws:iam::014732159800:role/LabRole"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "source/lambda_function.zip"


  environment {
    variables = {
      DYNAMO_TABLE_NAME = aws_dynamodb_table.example.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "dynamodb_to_lambda" {
  event_source_arn  = aws_dynamodb_table.example.stream_arn
  function_name     = aws_lambda_function.example.arn
  starting_position = "TRIM_HORIZON"
}

data "aws_vpc" "this" {
  default = true
}