terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

data "http" "local_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  pip_obj = jsondecode(data.http.local_public_ip.response_body)
}

resource "azurerm_resource_group" "lab-rg" {
  name     = "AzureTFLab${var.labnum}"
  location = var.location
  tags = {
    environment = "lab"
  }
}

resource "azurerm_virtual_network" "lab-vnet" {
  name                = "vnet-lab${var.labnum}"
  address_space       = ["10.${var.vnetoctet}.0.0/16"]
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name
  tags = {
    environment = "lab"
  }

}

resource "azurerm_subnet" "lab-snet" {
  name                 = "snet-lab${var.labnum}"
  resource_group_name  = azurerm_resource_group.lab-rg.name
  virtual_network_name = azurerm_virtual_network.lab-vnet.name
  address_prefixes     = ["10.${var.vnetoctet}.1.0/24"]
}

resource "azurerm_network_security_group" "lab-nsg" {
  name                = "nsg-lab${var.labnum}"
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name

  security_rule {
    name                       = "Allow Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.pip_obj.ip
    destination_address_prefix = "*"
  }

  tags = {
    environment = "lab"
  }
}

resource "azurerm_subnet_network_security_group_association" "lab-nsgassociation" {
  subnet_id                 = azurerm_subnet.lab-snet.id
  network_security_group_id = azurerm_network_security_group.lab-nsg.id
}

resource "azurerm_public_ip" "lab-pip" {
  count               = var.vmnum
  name                = "pip-lab${var.labnum}-${count.index}"
  resource_group_name = azurerm_resource_group.lab-rg.name
  location            = azurerm_resource_group.lab-rg.location
  allocation_method   = "Static"

  tags = {
    environment = "lab"
  }
}

resource "azurerm_network_interface" "lab-nic" {
  count               = var.vmnum
  name                = "nic-lab${var.labnum}-${count.index}"
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab-snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab-pip[count.index].id

  }
  tags = {
    environment = "lab"
  }
}

resource "azurerm_virtual_machine" "lab-vm" {
  count = var.vmnum

  name                  = "vm-lab${var.labnum}-${count.index}"
  location              = azurerm_resource_group.lab-rg.location
  resource_group_name   = azurerm_resource_group.lab-rg.name
  network_interface_ids = [azurerm_network_interface.lab-nic[count.index].id]
  vm_size               = var.vmsize

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "osdisk-lab${var.labnum}-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "vm-lab${var.labnum}-${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  os_profile_windows_config {}
  tags = {
    environment = "lab"
  }
}

output "vm_pips" {
  description = "VM Public IPs"
  value       = ["${azurerm_public_ip.lab-pip.*.ip_address}"]
}