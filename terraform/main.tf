provider "azurerm" {
  features {}
  }

resource "azurerm_resource_group" "demorg" {
name = "bradyteraform-rg"
location = "EastUS2"



tags = {
        Environment = "Dev"
        Team = "DevOps"
    }

}

resource "azurerm_storage_account" "example" {
  name                     = "bradydemosatf"
  resource_group_name      = azurerm_resource_group.demorg.name
  location                 = azurerm_resource_group.demorg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}