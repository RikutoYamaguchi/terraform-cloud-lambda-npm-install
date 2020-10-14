provider "aws" {
  region  = "ap-northeast-1"
  version = "~> 3.6"
}

terraform {
  required_version = "0.13.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

