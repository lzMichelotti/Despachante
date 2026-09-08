terraform {
  required_version = "~> 1.11" # use_lockfile needs 1.11+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
  }
}

# No backend here: this is the code that creates the state bucket.
provider "aws" {
  region = "sa-east-1"

  # Component is not here, it changes per resource.
  default_tags {
    tags = {
      Project     = "despachante"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}
