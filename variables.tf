# Resource Group
variable "resource_group_name" {
  type    = string
  default = "personal-iac-rg-1"
}
variable "region" {
  type    = string
  default = "Canada East"
}

# Virtual Network
variable "virtual_network_name" {
  type    = string
  default = "personal-iac-vn-1"
}
variable "address_space" {
  type    = string
  default = "10.1.0.0/16"
}

# Subnet
variable "subnet_name" {
  type    = string
  default = "personal-iac-subnet-1"
}
variable "subnet_address" {
  type    = string
  default = "10.1.1.0/24"
}

# Security Group
variable "security_group_name" {
  type    = string
  default = "personal-iac-sg-1"
}

# Network Security Rules
variable "security_rule_1_name" {
  type    = string
  default = "personal-iac-sec-rule-1"
}
variable "security_rule_1_source_ip" {
  type    = string
  default = "*" # Accessible from anywhere
}

# Public IP
variable "public_ip_name" {
  type    = string
  default = "personal-iac-ip-1"
}

# Network Interface
variable "network_interface_name" {
  type    = string
  default = "personal-iac-nic-1"
}

# Virtual Machine
variable "vm_name" {
  type    = string
  default = "personal-iac-vm-1"
}
variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}
variable "vm_admin_username" {
  type    = string
  default = "adminuser"
}
variable "vm_ssh_public_key" {
  type      = string
  sensitive = true
}
variable "vm_image_publisher" {
  type    = string
  default = "Canonical"
}
variable "vm_image_offer" {
  type    = string
  default = "ubuntu-24_04-lts"
}
variable "vm_image_sku" {
  type    = string
  default = "server"
}
variable "vm_image_version" {
  type    = string
  default = "latest"
}

# Ansible
variable "storage_account_name" {
  description = "Name of the existing Azure Storage Account"
  type        = string
}
variable "storage_resource_group_name" {
  description = "Name of the resource group containing the storage account"
  type        = string
}
variable "container_name" {
  description = "Name of the existing container in the Azure Storage Account"
  type        = string
}
variable "ssh_private_key_content" {
  type      = string
  sensitive = true
}

# Porkbun
variable "porkbun_secret_api_key" {
  type      = string
  sensitive = true
}
variable "porkbun_api_key" {
  type      = string
  sensitive = true
}