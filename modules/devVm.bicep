@description('Azure region that will be targeted for resources.')
param location string

@description('Subnet id')
param subnetId string

@description('Network security group id')
param nsg string

@description('The identity used by the VM')
param managedIdentity string

@description('The size of the virtual machine')
param vmSize string

@description('Username for the VM')
param adminUsername string

@description('Type of authentication to use for the VM')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string

@description('SSH key or password for the VM')
@secure()
param adminPasswordOrKey string

@description('AKV name')
param akvName string

@description('Storage name')
param strgName string

@description('Total nodes')
param totalNodes int

@description('Polygon version number')
param polygonVersion string

@description('Token Full Name')
@minLength(3)
@maxLength(24)
param tokenFullName string

@description('Token Symbol')
@minLength(2)
@maxLength(6)
param tokenSymbol string

@description('Block gas limit')
param blockGasLimit int

@description('Epoch size')
param epochSize int

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${uniqueString(resourceGroup().id)}nic50'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.1.1.50'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId 
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: nsg
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: '${uniqueString(resourceGroup().id)}vm50'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${uniqueString(resourceGroup().id)}vm'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${uniqueString(resourceGroup().id)}vmext50'
  location: location
  parent: vm
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/Ankr-network/polygon-azure/${polygonVersion}/scripts/rootchain.sh'
      ]
      // /bin/bash rootchain.sh managedIdentity=$1 vaultName=$2 validatorsAmount=$3 storageAccountName=$4 nativeTokenConfig=$5 blockGasLimit=$6 epochSize=$7 polygonVersion=$8
      commandToExecute: '/bin/bash rootchain.sh ${managedIdentity} ${akvName} ${totalNodes} ${strgName} "${tokenFullName}:${tokenSymbol}:18" ${blockGasLimit} ${epochSize} ${polygonVersion}'
    }
  }
}
