targetScope = 'tenant'



resource contosomgmt 'Microsoft.Management/managementGroups@2021-04-01' = {

  name: 'contoso'

}



resource contosoChildmgmt 'Microsoft.Management/managementGroups@2021-04-01' = {

  name: 'contoso-child'

  properties: {

    displayName: 'child'

    details: {

      parent: {
        id:contosomgmt.id
      }

    }

  }

}
 //az deployment tenant create --name mgcreation --location eastus --template-file mgmt.bicep

 