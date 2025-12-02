terraform {
  backend "s3" {
    bucket  = "devops-stage6-terraform-state-five"
    key     = "terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}
