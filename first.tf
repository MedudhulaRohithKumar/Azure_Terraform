terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.91.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rkkumar" {
  name     = "rg2"
  location = "Central India"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_group" "rkkumar" {
  name                = "rg2-security-group"
  location            = azurerm_resource_group.rkkumar.location
  resource_group_name = azurerm_resource_group.rkkumar.name
}

resource "azurerm_virtual_network" "rkkumar" {
  name                = "rg2-virtual-network"
  resource_group_name = azurerm_resource_group.rkkumar.name
  location            = azurerm_resource_group.rkkumar.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "rkkumar-sn" {
  name                 = "rg2-subnet1"
  resource_group_name  = azurerm_resource_group.rkkumar.name
  virtual_network_name = azurerm_virtual_network.rkkumar.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "rkkumar-nsg" {
  name                = "rg2-nsg"
  location            = azurerm_resource_group.rkkumar.location
  resource_group_name = azurerm_resource_group.rkkumar.name
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "rkkumar-rule" {
  name                        = "rkkumar-nsg-rule1"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rkkumar.name
  network_security_group_name = azurerm_network_security_group.rkkumar-nsg.name
}

resource "azurerm_subnet_network_security_group_association" "rkkumar-sga" {
  subnet_id                 = azurerm_subnet.rkkumar-sn.id
  network_security_group_id = azurerm_network_security_group.rkkumar-nsg.id
}

resource "azurerm_public_ip" "rkkumar-ip" {
  name                = "rg2-ip"
  resource_group_name = azurerm_resource_group.rkkumar.name
  location            = azurerm_resource_group.rkkumar.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "rkkumar-nic" {
  name = "rg2-nic"
  location = azurerm_resource_group.rkkumar.location
  resource_group_name = azurerm_resource_group.rkkumar.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.rkkumar-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.rkkumar-ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "rkkumar-vm" {
  name                = "rg2-vm"
  resource_group_name = azurerm_resource_group.rkkumar.name
  location            = azurerm_resource_group.rkkumar.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.rkkumar-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  custom_data = filebase64("customdata.tpl")

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("windoes-ssh-config.tpl",{
      hostname = self.public_ip_address,
      user = "adminuser",
      identityfile = "~/.ssh/"
    })
    interpreter = ["Powershell", "-Command"]
  }

  tags ={
    environment = "dev"
  }
}