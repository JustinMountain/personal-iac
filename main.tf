terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.7.0"
    }
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }

  backend "azurerm" {
    key              = "terraform.tfstate"
    use_oidc         = true
    use_azuread_auth = true
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}

provider "ansible" {}

provider "local" {}

resource "azurerm_resource_group" "personal-iac-rg-1" {
  name     = var.resource_group_name
  location = var.region

  tags = {
    environment = "prod"
  }
}

resource "azurerm_virtual_network" "personal-iac-vn-1" {
  name                = var.virtual_network_name
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name
  location            = azurerm_resource_group.personal-iac-rg-1.location
  address_space       = ["${var.address_space}"]

  tags = {
    environment = "prod"
  }
}

resource "azurerm_subnet" "personal-iac-subnet-1" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.personal-iac-rg-1.name
  virtual_network_name = azurerm_virtual_network.personal-iac-vn-1.name
  address_prefixes     = ["${var.subnet_address}"]
}

resource "azurerm_network_security_group" "personal-iac-sg-1" {
  name                = var.security_group_name
  location            = azurerm_resource_group.personal-iac-rg-1.location
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name

  tags = {
    environment = "prod"
  }
}

resource "azurerm_network_security_rule" "personal-iac-sec-rule-1" {
  name                        = var.security_rule_1_name
  priority                    = 100
  direction                   = "Inbound" # Azure uses deny by default
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.security_rule_1_source_ip # Restrict to IP
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.personal-iac-rg-1.name
  network_security_group_name = azurerm_network_security_group.personal-iac-sg-1.name
}

resource "azurerm_subnet_network_security_group_association" "personal-iac-sga-1" {
  subnet_id                 = azurerm_subnet.personal-iac-subnet-1.id
  network_security_group_id = azurerm_network_security_group.personal-iac-sg-1.id
}

resource "azurerm_public_ip" "personal-iac-ip-1" {
  name                = var.public_ip_name
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name
  location            = azurerm_resource_group.personal-iac-rg-1.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "prod"
  }
}

resource "azurerm_network_interface" "personal-iac-nic-1" {
  name                = var.network_interface_name
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name
  location            = azurerm_resource_group.personal-iac-rg-1.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.personal-iac-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.personal-iac-ip-1.id
  }

  tags = {
    environment = "prod"
  }
}

resource "azurerm_linux_virtual_machine" "personal-iac-vm-1" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name
  location            = azurerm_resource_group.personal-iac-rg-1.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  network_interface_ids = [
    azurerm_network_interface.personal-iac-nic-1.id
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  tags = {
    environment = "prod"
  }
}

# Ansible Section

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [azurerm_linux_virtual_machine.personal-iac-vm-1]
  create_duration = "30s"
}

data "azurerm_storage_account" "existing" {
  name                = var.storage_account_name
  resource_group_name = var.storage_resource_group_name
}

data "azurerm_storage_container" "existing" {
  name                 = var.container_name
  storage_account_name = data.azurerm_storage_account.existing.name
}

resource "local_file" "ansible_inventory" {
  content = yamlencode({
    webservers = {
      hosts = {
        "${azurerm_linux_virtual_machine.personal-iac-vm-1.name}" = {
          ansible_host = azurerm_linux_virtual_machine.personal-iac-vm-1.public_ip_address
          ansible_user = var.vm_admin_username
        }
      }
    }
  })
  filename = "${path.module}/inventory.yml"

  provisioner "local-exec" {
    command = "cat ${self.filename}"
  }
}

resource "azurerm_storage_blob" "ansible_inventory" {
  name                   = "inventory.yml"
  storage_account_name   = data.azurerm_storage_account.existing.name
  storage_container_name = data.azurerm_storage_container.existing.name
  type                   = "Block"
  source                 = local_file.ansible_inventory.filename

  depends_on = [time_sleep.wait_30_seconds]
}

resource "ansible_host" "azure_instance" {
  name   = azurerm_linux_virtual_machine.personal-iac-vm-1.public_ip_address
  groups = ["webservers"]
  variables = {
    ansible_user                 = "${var.vm_admin_username}"
    ansible_ssh_private_key_file = "${var.ssh_private_key_content}"
  }

  depends_on = [time_sleep.wait_30_seconds]
}

# resource "terraform_data" "ansible_inventory" {
#   provisioner "local-exec" {
#     command = "ansible-inventory -i ./ansible/inventory.yml --graph"
#   }

#   depends_on = [ansible_host.azure_instance]
# }

data "local_file" "ansible_playbook" {
  filename = "./ansible/webservers.yml"
}

data "local_file" "traefik_compose" {
  filename = "./docker/traefik/compose.yml"
}

data "local_file" "blog_compose" {
  filename = "./docker/blog/compose.yml"
}

data "local_file" "watchtower_compose" {
  filename = "./docker/watchtower/compose.yml"
}

resource "null_resource" "ansible_playbook" {
  triggers = {
    playbook_hash   = data.local_file.ansible_playbook.content_md5
    traefik_hash    = data.local_file.traefik_compose.content_md5
    blog_hash       = data.local_file.blog_compose.content_md5
    watchtower_hash = data.local_file.watchtower_compose.content_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      az storage blob download --account-name ${var.storage_account_name} \
                                --container-name ${var.container_name} \
                                --name inventory.yml \
                                --file ./ansible/inventory.yml \
                                --auth-mode login
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ./ansible/inventory.yml ./ansible/webservers.yml
    EOT
  }

  depends_on = [azurerm_storage_blob.ansible_inventory]
}

# Creates a data object in the state file for reference
data "azurerm_public_ip" "personal-iac-ip-1-data" {
  name                = azurerm_public_ip.personal-iac-ip-1.name
  resource_group_name = azurerm_resource_group.personal-iac-rg-1.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.personal-iac-vm-1.name}: ${data.azurerm_public_ip.personal-iac-ip-1-data.ip_address}"
}
