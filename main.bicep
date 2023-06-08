@description('Azure region that will be targeted for resources.')
param location string = resourceGroup().location

@description('Username for the VM')
param adminUsername string = 'azureuser'

@description('Type of authentication to use for the VM')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH key or password for the VM')
@secure()
param adminPasswordOrKey string

@description('Dev VM size')
param devVmSize string = 'Standard_D4s_v4'

@description('Validator VM size')
param validatorVmSize string = 'Standard_D4s_v4'

@description('Validator VM availability zones')
param validatorAvailabilityZones string = ''

@description('Validator VM amount')
@minValue(4)
@maxValue(10)
param validatorVmAmount int = 10

// @description('Addresses and the amount of tokens to premine.')
// @metadata({
//   addresses: [
//     {
//       address: '0x3383e0EbB44d2929abD654cFe4DF52C818af3230'
//       tokenAmount: '1000'
//     }
//   ]
// })
// param addressesToPremine object

// @description('Premine amount for validators')
// param premineAmount int = 100

@description('RPC enabled')
param rpcEnabled bool = true

@description('RPC VM size')
param rpcVmSize string = 'Standard_D4s_v4'

@description('RPC VM availability zones')
param rpcAvailabilityZones string = ''

@description('RPC VM amount')
@minValue(2)
@maxValue(10)
param rpcVmAmount int = 6

@description('Indexer enabled')
param indexerEnabled bool = false

@description('Indexer VM size')
param indexerVmSize string = 'Standard_D4s_v4'

@description('Indexer VM availability zones')
param indexerAvailabilityZones string = ''

@description('Explorer enabled')
param explorerEnabled bool = true

@description('Explorer VM size')
param explorerVmSize string = 'Standard_D4s_v4'

@description('Explorer VM availability zones')
param explorerAvailabilityZones string = ''

@description('Token Full Name')
@minLength(3)
@maxLength(24)
param tokenFullName string = 'SuperTestCoin'

@description('Token Symbol')
@minLength(2)
@maxLength(6)
param tokenSymbol string = 'STC'

@description('The maximum amount of gas used by all transactions in a block')
param blockGasLimit int = 10000000

@description('Epoch size')
param epochSize int = 10

// this is used to ensure uniqueness to naming (making it non-deterministic)
param rutcValue string = utcNow()

var polygonVersion = '1.0.0-rc1'

// var blockscoutVersion = '4.1.5'

var loadBalancerName = '${uniqueString(resourceGroup().id)}lb'

// the built-in role that allow contributor permissions (create)
// NOTE: there is no built-in creator/contributor role 
var roleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${uniqueString(resourceGroup().id)}mi'
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  #disable-next-line use-stable-resource-identifiers simplify-interpolation
  name: '${guid(uniqueString(resourceGroup().id), rutcValue)}'
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    description: 'akvrole'
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource akv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'a${uniqueString(resourceGroup().id)}akv'
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        tenantId: managedIdentity.properties.tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${uniqueString(resourceGroup().id)}strg'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    defaultServiceVersion: '2020-10-02'
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: 'configs'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}


resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'main'
        properties: {
          addressPrefix: '10.1.1.0/24'
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'rpc'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '10001'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          priority: 101
        }
      },{
        name: 'explorer'
        properties: {
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '4010'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          priority: 111
        }
      }
    ]
  }
}

resource pipIdx 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}pipidx'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource pipExp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}pipexp'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource pipRpc 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}piprpc'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource lb 'Microsoft.Network/loadBalancers@2022-07-01' = {
  name: loadBalancerName
  location: location
  dependsOn: [
    vnet
  ]
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'lbrpcfe'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipRpc.id
          }
        }
      },{
        name: 'lbidxfe'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipIdx.id
          }
        }
      },{
        name: 'lbexpfe'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipExp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'lbrpcbe'
      },{
        name: 'lbidxbe'
      },{
        name: 'lbexpbe'
      }
    ]
    loadBalancingRules: [
      {
        name: 'lbrpcrule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName , 'lbrpcfe')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'lbrpcbe')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 10001
          backendPort: 10001
          idleTimeoutInMinutes: 15
        }
      },{
        name: 'lbidxrule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName , 'lbidxfe')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'lbidxbe')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 10001
          backendPort: 10001
          idleTimeoutInMinutes: 15
        }
      },{
        name: 'lbexprule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName , 'lbexpfe')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'lbexpbe')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbexpprobe')
          }
          protocol: 'Tcp'
          frontendPort: 4010
          backendPort: 4010
          idleTimeoutInMinutes: 15
        }
      }
    ]
    probes: [
      {
        name: 'lbprobe'
        properties: {
          protocol: 'Tcp'
          port: 10001
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      },{
        name: 'lbexpprobe'
        properties: {
          protocol: 'Tcp'
          port: 4010
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

module devVmModule 'modules/devVm.bicep' = {
  name: 'devDeploy'
  params: {
    location: location
    vmSize: devVmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    akvName: akv.name
    strgName: storageAccount.name
    managedIdentity: managedIdentity.id
    nsg: nsg.id
    subnetId: vnet.properties.subnets[0].id
    totalNodes: validatorVmAmount
    polygonVersion: polygonVersion
    tokenFullName: tokenFullName
    tokenSymbol: tokenSymbol
    blockGasLimit: blockGasLimit
    epochSize: epochSize
  }
}

module validatorVmModule 'modules/validatorVm.bicep' = {
  name: 'validatorDeploy'
  dependsOn: [
    devVmModule
  ]
  params: {
    location: location
    vmSize: validatorVmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    akvName: akv.name
    strgName: storageAccount.name
    managedIdentity: managedIdentity.id
    nsg: nsg.id
    subnetId: vnet.properties.subnets[0].id
    totalNodes: validatorVmAmount
    availabilityZones: validatorAvailabilityZones
    polygonVersion: polygonVersion
  }
}

module rpcVmModule 'modules/rpcVm.bicep' = if (rpcEnabled) {
  name: 'rpcDeploy'
  dependsOn: [
    validatorVmModule
  ]
  params: {
    location: location
    vmSize: rpcVmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    akvName: akv.name
    strgName: storageAccount.name
    managedIdentity: managedIdentity.id
    nsg: nsg.id
    subnetId: vnet.properties.subnets[0].id
    totalNodes: rpcVmAmount
    availabilityZones: rpcAvailabilityZones
    loadBalancerName: loadBalancerName
    loadBalancerBackendName: 'lbrpcbe'
    polygonVersion: polygonVersion
  }
}

module idxVmModule 'modules/idxVm.bicep' = if (indexerEnabled) {
  name: 'idxDeploy'
  dependsOn: [
    validatorVmModule
  ]
  params: {
    location: location
    vmSize: indexerVmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    akvName: akv.name
    strgName: storageAccount.name
    managedIdentity: managedIdentity.id
    nsg: nsg.id
    subnetId: vnet.properties.subnets[0].id
    totalNodes: 2
    availabilityZones: indexerAvailabilityZones
    loadBalancerName: loadBalancerName
    loadBalancerBackendName: 'lbidxbe'
    polygonVersion: polygonVersion
  }
}

module explorerVmModule 'modules/explorerVm.bicep' = if (explorerEnabled) {
  name: 'explorerDeploy'
  dependsOn: [
    rpcVmModule
  ]
  params: {
    location: location
    vmSize: explorerVmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    managedIdentity: managedIdentity.id
    nsg: nsg.id
    subnetId: vnet.properties.subnets[0].id
    totalNodes: 1
    availabilityZones: explorerAvailabilityZones
    loadBalancerName: loadBalancerName
    loadBalancerBackendName: 'lbexpbe'
  }
}
// output rpcAddress string = pipRpc.properties.ipAddress
// output idxAddress string = pipIdx.properties.ipAddress
