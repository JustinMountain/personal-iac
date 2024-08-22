# Resource Group
variable "resource_group_name" {
  type = string
  # default = "can-example-resources"
}
variable "region" {
  type = string
  # default = "Canada East"
}

# Virtual Network
variable "virtual_network_name" {
  type = string
  # default = "can-example-network"
}
variable "address_space" {
  type = string
  # default = "10.1.0.0/16"
}

# Subnet
variable "subnet_name" {
  type = string
  # default = "can-example-subnet"
}
variable "subnet_address" {
  type = string
  # default = "10.1.1.0/24"
}

# Security Group
variable "security_group_name" {
  type = string
  # default = "can-example-security-group"
}

# Network Security Rules
variable "security_rule_1_name" {
  type = string
  # default = "can-example-dev-security-rule"
}
variable "security_rule_1_source_ip" {
  type = string
  # default = "*"
}

# Public IP
variable "public_ip_name" {
  type = string
  # default = "can-example-ip-1"
}

# Network Interface
variable "network_interface_name" {
  type = string
  # default = "can-example-nic-1"
}

# Virtual Machine
variable "vm_name" {
  type = string
  # default = "can-example-vm-1"
}
variable "vm_size" {
  type = string
  # default = "Standard_B1s"
}
variable "vm_admin_username" {
  type = string
  # default = "adminuser"
}
variable "vm_ssh_key_location" {
  type = string
  # default = "~/.ssh/exampleazurekey.pub"
}
variable "vm_image_publisher" {
  type = string
  # default = "Canonical"
}
variable "vm_image_offer" {
  type = string
  # default = "ubuntu-24_04-lts"
}
variable "vm_image_sku" {
  type = string
  # default = "server"
}
variable "vm_image_version" {
  type = string
  # default = "latest"
}

# Ansible
variable "ssh_private_key_location" {
  type = string
  # default = "~/.ssh/exampleazurekey"
}
