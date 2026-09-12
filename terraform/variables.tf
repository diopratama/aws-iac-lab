variable "es_password" {
  type        = string
  default     = "SuperSecureLabPass123!"
  sensitive   = true
  description = "Master password for the elastic superuser account"
}