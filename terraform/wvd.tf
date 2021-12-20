provider "azurerm" {
  features {}
}

variable "resource_group_name" {default = "WVDTEST-RG"}
variable "location" {default = "East US 2"}
variable "wvdworkspacename" {default = "WVD-Workspace-TF"}
variable "pooltype" {default = "Pooled"}

#Deploy Resource Group
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

#Deploy Pooled Host Pool
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  location            = var.location
  resource_group_name = var.resource_group_name
  name                     = "WVD-TF-Demo"
  friendly_name            = "Terraform Demo"
  validate_environment     = true
  start_vm_on_connect      = true
  custom_rdp_properties    = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;use multimon:i:1"
  description              = "Terraform Demo"
  type                     = var.pooltype
  maximum_sessions_allowed = 20
  load_balancer_type       = "DepthFirst" #Options: BreadthFirst / DepthFirst 

  registration_info {
    expiration_date = "2021-10-14T16:00:00Z"               # Must be set to a time between 1 hour in the future & 27 days in the future
  }
}

/*# Deploy Personal Host Pool'
resource "azurerm_virtual_desktop_host_pool" "wvd_pool2" {
  name                             = "HostPool2NameGoesHere"
  resource_group_name              = azurerm_resource_group.wvd_rg.name
  location                         = azurerm_resource_group.wvd_rg.location
  type                             = "Personal"
  load_balancer_type               = "Persistent"
  personal_desktop_assignment_type = "Automatic"           # Options: Automatic / Direct
  friendly_name                    = "Second WVD Pool"
  description                      = "Short description of the second Host Pool"
  validate_environment             = false
  maximum_sessions_allowed         = 1
*/

#Deploy Workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = var.wvdworkspacename
  location            = var.location
  resource_group_name = var.resource_group_name

  friendly_name = "WVDTest"
  description   = "A description of my workspace"
}


#Deploy Application Group
resource "azurerm_virtual_desktop_application_group" "desktopapp" {
  name                = "WVD-TF-Demo-Desktop"
  location            = var.location
  resource_group_name = var.resource_group_name

  type          = "Desktop"
  host_pool_id  = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name = "WVD-TF-Demo-Desktop"
  description   = "WVD-TF-Demo-Desktop"
}