variable "labnum" {
  default     = "1"
  description = "Lab number for naming"
}

variable "vnetoctet" {
  type        = number
  default     = "222"
  description = "vnet/snet second octet - Value must be between 1 and 254"
}

variable "vmnum" {
  type        = number
  description = "Number of VMs to provision"
}

variable "admin_username" {
default = "azadmin"
  description = "Local admin username for VMs"
}

variable "admin_password" {
  description = "Local admin password for VMs"
}