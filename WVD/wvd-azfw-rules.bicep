//parameters azure firewall
param location string = resourceGroup().location
param azureFirewallName string = 'az-fw-test'
param avdipgroupid string = ''


// variables
var environmentName = 'production'
var functionName = 'networking'
var costCenterName = 'it'

// resource - azure firewall


resource azureFirewall 'Microsoft.Network/azureFirewalls@2020-07-01' = {
  name: azureFirewallName
  location: location
  tags: {
    environment: environmentName
    function: functionName
    costCenter: costCenterName
  }
    properties: {
    applicationRuleCollections: [
      {
        name: 'AVD_Outbound_Allow'
        properties: {
          priority: 110
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'SXS Stack '
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }
               ]
              targetFqdns: [
                '*xt.blob.core.windows.net'
              ]
              sourceIpGroups: [
                avdipgroupid
              ]
            }

            {
              name: 'XT Agent Traffic'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }
               ]
              targetFqdns: [
                '*xt.table.core.windows.net'
              ]
              sourceIpGroups: [
                avdipgroupid
              ]
            }

            {
              name: 'EH Agent Traffic'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }
               ]
              targetFqdns: [
                '*eh.servicebus.windows.net'
              ]
              sourceIpGroups: [
                avdipgroupid
              ]

            }

            {
              name: 'OS Connection Test'
              protocols: [
                {
                  port: 80
                  protocolType: 'Http'
                }
               ]
              targetFqdns: [
                'www.msftconnecttest.com'
              ]
              sourceIpGroups: [
                avdipgroupid
              ]
            }

            {
              name: 'All AVD Services'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }
               ]
              fqdnTags: [
                'WindowsVirtualDesktop'
              ]
              sourceIpGroups: [
                avdipgroupid
              ]
            }



            
          ]
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'AVD_Allow_Outbound'
        properties:{
          priority:120
          action:{
            type:'Allow'
          }
          rules:[
            {
              name:'Allow KMS'
              protocols: [
                'TCP'
                ]
                destinationAddresses: [
                  '23.102.135.246'
                ]
  
                destinationPorts: [
                  '1688'
                ]
  
                sourceIpGroups: [
                  avdipgroupid
                ]
                }
                
                {
                  name:'Allow DNS'
                  protocols: [
                    'UDP'
                    ]
                    destinationAddresses: [
                      '1.1.1.1'
                      '8.8.8.8'

                    ]
      
                    destinationPorts: [
                      '53'
                    ]
      
                    sourceIpGroups: [
                      avdipgroupid
                    ]
                    }

                    {
                      name:'Allow NTP'
                      protocols: [
                        'UDP'
                        ]
                        destinationAddresses: [
                          '51.105.208.173'
                        ]
          
                        destinationPorts: [
                          '123'
                        ]
          
                        sourceIpGroups: [
                          avdipgroupid
                        ]
                        }

                        {
                          name:'Allow AVD Services'
                          protocols: [
                            'Any'
                            ]
                            destinationAddresses: [
                              'AzureMonitor'
                              'AzureActiveDirectory'
                              'AzureFrontDoor.Backend'
                              'AzureBackup'
                              'AzureKeyVault'
                              'AzurePortal'
                              'AzureResourceManager'
                              'AzureSiteRecovery'
                              'Storage'
                              'GuestAndHybridManagement'
                            ]
              
                            destinationPorts: [
                              '*'
                            ]
              
                            sourceIpGroups: [
                              avdipgroupid
                            ]
                            }

          ]
        }  


        
        }
        
      
    ]
  }
}
