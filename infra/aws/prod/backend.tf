// backend.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "pgagi-tfstate-monkweb009"
    key            = "aws/prod/terraform.tfstate"   # isolated prod state
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "pgagi-tfstate-lock"
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = { ManagedBy = "terraform", Project = "pgagi", Environment = "prod" }
  }
}
