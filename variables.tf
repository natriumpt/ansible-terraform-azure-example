variable "location" {
  type        = string
  description = "Physical datacenter location for the resource"
}

variable "admin_username" {
  type        = string
  description = "Administrator user name for virtual machine"
  default = "azureuser"
}

variable "prefix" {
  type    = string
  default = "terraform"
}

variable "instances" {
  type = number
  default = 2
}