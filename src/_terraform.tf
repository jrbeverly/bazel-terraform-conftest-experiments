# Temp thing
terraform {
  backend "local" {
    path = "/workspace/conftest-terraform-workflow/src/terraform.tfstate"
  }
}