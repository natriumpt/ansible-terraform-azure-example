terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

resource "azurerm_availability_set" "vm" {
  name                         = "${var.prefix}-avset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = var.instances
  platform_update_domain_count = var.instances
  managed                      = true
}

resource "azurerm_network_interface" "vm" {
  count               = var.instances
  name                = "${var.prefix}-ni-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "${var.prefix}-ip-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_network_security_group" "vm" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
      name                       = "SSH"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
  }

  security_rule {
      name                       = "HTTP"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  count                     = var.instances
  network_interface_id      = azurerm_network_interface.vm[count.index].id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count                 = var.instances
  name                  = "${var.prefix}VM0${count.index}"
  location              = azurerm_resource_group.rg.location
  availability_set_id   = azurerm_availability_set.vm.id
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.vm.*.id, count.index)]
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching               = "ReadWrite"
    storage_account_type  = "Standard_LRS"
  }
}

resource "azurerm_public_ip" "azlb" {
  name                         = "${var.prefix}-publicIP"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method            = "Static"
}


resource "azurerm_lb" "azlb" {
  name                = "${var.prefix}-loadBalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
 
  frontend_ip_configuration {
    name                 = azurerm_public_ip.azlb.name
    public_ip_address_id = azurerm_public_ip.azlb.id
  }
}

resource "azurerm_lb_backend_address_pool" "azlb" {
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = "BackEndAddressPool"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_probe" "azlb" {
  interval_in_seconds = 5
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = "http"
  number_of_probes    = 2
  port                = 80
  protocol            = "Tcp"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_rule" "azlb" {
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.azlb.id
  disable_outbound_snat          = false
  enable_floating_ip             = false
  frontend_ip_configuration_name = azurerm_public_ip.azlb.name
  frontend_port                  = 80
  idle_timeout_in_minutes        = 5
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = "http"
  protocol                       = "tcp"
  resource_group_name            = azurerm_resource_group.rg.name
  probe_id                       = azurerm_lb_probe.azlb.id
}

resource "azurerm_lb_nat_rule" "azlb" {
  count                          = var.instances
  name                           = "${var.prefix}-SSHNatRule${count.index}"
  frontend_port                  = 50000 + count.index
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_public_ip.azlb.name
  loadbalancer_id                = azurerm_lb.azlb.id
  protocol                       = "tcp"
  resource_group_name            = azurerm_resource_group.rg.name
}


resource "azurerm_network_interface_backend_address_pool_association" "azlb" {
  count                   = var.instances
  backend_address_pool_id = azurerm_lb_backend_address_pool.azlb.id
  ip_configuration_name   = azurerm_network_interface.vm[count.index].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.vm[count.index].id
}

resource "azurerm_network_interface_nat_rule_association" "azlb" {
  count                 = var.instances
  network_interface_id  = azurerm_network_interface.vm[count.index].id
  ip_configuration_name = azurerm_network_interface.vm[count.index].ip_configuration[0].name
  nat_rule_id           = azurerm_lb_nat_rule.azlb[count.index].id
}

data "azurerm_public_ip" "azlb" {
  name                = azurerm_public_ip.azlb.name
  resource_group_name = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.azlb.ip_address
}
