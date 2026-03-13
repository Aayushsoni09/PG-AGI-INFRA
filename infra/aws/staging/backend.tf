terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { 
      source = "hashicorp/aws"
     version = "~> 5.0" 
     }
  }
  backend "s3" {
    bucket         = "pgagi-tfstate-monkweb009"
    key            = "aws/staging/terraform.tfstate"   # different key = isolated state
    region         = "ap-south-1"
    encrypt        = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = { ManagedBy = "terraform", Project = "pgagi", Environment = "staging" }
  }
}
