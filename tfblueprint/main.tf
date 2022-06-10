resource "random_string" "random" {
  length           = 16
  special          = true
  override_special = "/@£$"
}

output "string" {
  value = random_string.random.result
}

module "random_uuid" {
  source = "./modules/remap-random-uuid"
}

output "another_output" {
  value = module.random_uuid.result
}