variable "public_key_path" {
  type        = string
  default     = "~/.ssh/es-lab-key.pub"
  description = "Path ke file public key SSH"
}

variable "es_password" {
  type        = string
  default     = "SuperSecureLabPass123!"
  sensitive   = true
  description = "Password akun elastic"
}