terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — isolated per environment
  # Each env has its own state file → no blast radius across envs
  backend "s3" {
    bucket         = "pgagi-tfstate-monkweb009"      # change to your bucket name
    key            = "aws/dev/terraform.tfstate"      # unique path per environment
    region         = "ap-south-1"
    encrypt        = true                             # encrypt state at rest
    use_lockfile = true             # state locking table
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "pgagi"
      Environment = "dev"
    }
  }
}
