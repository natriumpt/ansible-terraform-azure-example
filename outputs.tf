### The Ansible inventory file
resource "local_file" "AnsibleInventory" {
 content = templatefile("inventory.tmpl",
 {
  admin_user = var.admin_username
  public-ip = azurerm_public_ip.azlb.ip_address,
  vm-name = azurerm_linux_virtual_machine.vm.*.name
  ssh-port = azurerm_lb_nat_rule.azlb.*.frontend_port
 }
 )
 filename = "inventory"
}