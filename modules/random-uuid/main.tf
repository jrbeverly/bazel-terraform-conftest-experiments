resource "random_string" "default" {
  length           = 16
  special          = true
  override_special = "/@£$"
}

output "result" {
  value = random_string.default.result
}