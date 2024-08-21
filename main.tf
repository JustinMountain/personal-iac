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
  name     = "can-example-resources"
  location = "Canada East"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "example-vn" {
  name                = "can-example-network"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = "dev"
  }

  # Set an explicit dependency
  # depends_on = [azurerm_resource_group.example-rg]
}

resource "azurerm_subnet" "example-subnet" {
  name                 = "can-example-subnet"
  resource_group_name  = azurerm_resource_group.example-rg.name
  virtual_network_name = azurerm_virtual_network.example-vn.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "example-sg" {
  name                = "can-example-security-group"
  location            = azurerm_resource_group.example-rg.location
  resource_group_name = azurerm_resource_group.example-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "example-dev-rule" {
  name                        = "can-example-dev-security-rule"
  priority                    = 100
  direction                   = "Inbound" # Azure uses deny by default
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"       # Restrict to IP
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example-rg.name
  network_security_group_name = azurerm_network_security_group.example-sg.name
}

resource "azurerm_subnet_network_security_group_association" "example-sga" {
  subnet_id                 = azurerm_subnet.example-subnet.id
  network_security_group_id = azurerm_network_security_group.example-sg.id
}

resource "azurerm_public_ip" "example-ip" {
  name                = "can-example-ip-1"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "example-nic" {
  name                = "can-example-nic-1"
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
  name                = "can-example-vm-1"
  resource_group_name = azurerm_resource_group.example-rg.name
  location            = azurerm_resource_group.example-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example-nic.id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/exampleazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
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
    ansible_user                 = "adminuser"
    ansible_ssh_private_key_file = "~/.ssh/exampleazurekey"
  }

  depends_on = [time_sleep.wait_30_seconds]
}

resource "terraform_data" "ansible_inventory" {
  provisioner "local-exec" {
    command = "ansible-inventory -i ./ansible/inventory.yml --graph"
  }

  depends_on = [ansible_host.azure_instance]
}

resource "terraform_data" "ansible_playbook" {
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ./ansible/inventory.yml ./ansible/webservers.yml"
  }

  depends_on = [terraform_data.ansible_inventory]
}

