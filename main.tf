terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example-rg" {
  name     = "${var.resource_group_name}"
  location = "${var.region}"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "example-vn" {
  name                = "${var.virtual_network_name}"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  address_space       = ["${var.address_space}"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "example-subnet" {
  name                 = "${var.subnet_name}"
  resource_group_name  = azurerm_resource_group.example-rg.name
  virtual_network_name = azurerm_virtual_network.example-vn.name
  address_prefixes     = ["${var.subnet_address}"]
}

resource "azurerm_network_security_group" "example-sg" {
  name                = "${var.security_group_name}"
  location            = azurerm_resource_group.example-rg.location
  resource_group_name = azurerm_resource_group.example-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "example-dev-rule" {
  name                        = "${var.security_rule_1_name}"
  priority                    = 100
  direction                   = "Inbound"                             # Azure uses deny by default
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "${var.security_rule_1_source_ip}"   # Restrict to IP
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example-rg.name
  network_security_group_name = azurerm_network_security_group.example-sg.name
}

resource "azurerm_subnet_network_security_group_association" "example-sga" {
  subnet_id                 = azurerm_subnet.example-subnet.id
  network_security_group_id = azurerm_network_security_group.example-sg.id
}

resource "azurerm_public_ip" "example-ip" {
  name                = "${var.public_ip_name}"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "example-nic" {
  name                = "${var.network_interface_name}"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example-ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "example-vm" {
  name                = "${var.vm_name}"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  size                = "${var.vm_size}"
  admin_username      = "${var.vm_admin_username}"
  network_interface_ids = [
    azurerm_network_interface.example-nic.id
  ]

  admin_ssh_key {
    username   = "${var.vm_admin_username}"
    public_key = file("${var.vm_ssh_key_location}")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "${var.vm_image_publisher}"
    offer     = "${var.vm_image_offer}"
    sku       = "${var.vm_image_sku}"
    version   = "${var.vm_image_version}"
  }

  tags = {
    environment = "dev"
  }
}

# Ansible Section

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [azurerm_linux_virtual_machine.example-vm]
  create_duration = "30s"
}

resource "ansible_host" "azure_instance" {
  name   = azurerm_linux_virtual_machine.example-vm.public_ip_address
  groups = ["webservers"]
  variables = {
    ansible_user                 = "${var.vm_admin_username}"
    ansible_ssh_private_key_file = "${var.ssh_private_key_location}"
  }

  depends_on = [time_sleep.wait_30_seconds]
}

resource "terraform_data" "ansible_inventory" {
  provisioner "local-exec" {
    command = "ansible-inventory -i ./ansible/inventory.yml --graph"
  }

  depends_on = [ansible_host.azure_instance]
}

data "local_file" "ansible_playbook" {
  filename = "./ansible/webservers.yml"
}

data "local_file" "nginx_compose" {
  filename = "./docker/nginx/compose.yml"
}

data "local_file" "watchtower_compose" {
  filename = "./docker/watchtower/compose.yml"
}

resource "null_resource" "ansible_playbook" {
  triggers = {
    playbook_hash = data.local_file.ansible_playbook.content_md5
    nginx_hash  = data.local_file.nginx_compose.content_md5
    watchtower_hash  = data.local_file.watchtower_compose.content_md5
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ./ansible/inventory.yml ./ansible/webservers.yml"
  }

  depends_on = [terraform_data.ansible_inventory]
}

# Creates a data object in the state file for reference
data "azurerm_public_ip" "example-ip-data" {
  name                = azurerm_public_ip.example-ip.name
  resource_group_name = azurerm_resource_group.example-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.example-vm.name}: ${data.azurerm_public_ip.example-ip-data.ip_address}"
}
