# SecureFlow Terraform - Vulnerablilities Fixed Version.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "project" {
  type    = string
  default = "secureflow"
}

variable "environment" {
  type    = string
  default = "dev"
}

# IV-01 fix: db_password no longer hardcoded
# Pass via: export TF_VAR_db_password="your-password"
variable "db_password" {
  type      = string
  sensitive = true
}

module "vpc" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
}

module "iam" {
  source  = "./modules/iam"
  project = var.project
}

module "s3" {
  source  = "./modules/s3"
  project = var.project
}

module "eks" {
  source             = "./modules/eks"
  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "rds" {
  source             = "./modules/rds"
  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_password        = var.db_password
}


# # SecureFlow Terraform — INTENTIONALLY VULNERABLE baseline.
# # Planted vulnerabilities are tagged with their Vulnerability Index ID.
# # DO NOT `terraform apply` this against a real AWS account — Checkov should
# # block it in the pipeline. The purpose of this tree is to give idea to interns or developers of what vulnerable infrastructure code looks like, so they can learn to avoid it. 
# # If you want to test the code, use a local testing tool like LocalStack or Terraform's `-target` flag to apply only specific modules.
# # something Checkov can flag.

# terraform {
#   required_version = ">= 1.5.0"
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# provider "aws" {
#   region = var.region
# }

# variable "region" {
#   type    = string
#   default = "eu-west-2"
# }

# variable "project" {
#   type    = string
#   default = "secureflow"
# }

# variable "environment" {
#   type    = string
#   default = "dev"
# }

# module "vpc" {
#   source      = "./modules/vpc"
#   project     = var.project
#   environment = var.environment
# }

# module "iam" {
#   source  = "./modules/iam"
#   project = var.project
# }

# module "s3" {
#   source  = "./modules/s3"
#   project = var.project
# }

# module "eks" {
#   source            = "./modules/eks"
#   project           = var.project
#   environment       = var.environment
#   vpc_id            = module.vpc.vpc_id
#   public_subnet_ids = module.vpc.public_subnet_ids
# }

# module "rds" {
#   source            = "./modules/rds"
#   project           = var.project
#   environment       = var.environment
#   vpc_id            = module.vpc.vpc_id
#   public_subnet_ids = module.vpc.public_subnet_ids
#   db_password       = "postgres" # IV-01 — hardcoded DB password reused from docker-compose.
# }
