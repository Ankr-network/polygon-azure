# Init variables from Bicep
managedIdentity=$1
vaultName=$2
nodeId=$3
storageAccountName=$4

nodeId=$(( nodeId + 1 ))

# Install dependencies
mkdir -p /srv/tank/edge-validator-${nodeId}
sudo chown -R azureuser:sudo /srv/tank

sudo apt update
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity --username $managedIdentity

# Install dependecies 
sudo apt install jq -y

# Download Keys and genesis file
az keyvault secret download --vault-name ${vaultName} --file node${nodeId} --name node${nodeId}

accountKey=$(az storage account keys list --account-name ${storageAccountName} | jq -r '.[0].value')
az storage blob download  --account-name ${storageAccountName} --account-key ${accountKey}  --container-name configs --name genesis.json  --file /srv/tank/edge-validator-${nodeId}/genesis.json

# Extract data 
base64 -d node${nodeId} > data.tar.gz
tar xvfz data.tar.gz -C /srv/tank

# Launch validator node
echo "[Unit]
  Description=Polygon edge validator 1
  StartLimitIntervalSec=30
  StartLimitBurst=5

[Service]
  Restart=on-failure
  RestartSec=5s

  ExecStart=polygon-edge server --data-dir /srv/tank/edge-validator-${nodeId} --chain /srv/tank/edge-validator-${nodeId}/genesis.json --grpc-address :5001 --libp2p 0.0.0.0:30301 --jsonrpc 0.0.0.0:10001 --seal --log-level DEBUG

  Type=simple
  User=root

[Install]
  WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/polygon_edge_validator_1.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable polygon_edge_validator_1
sudo systemctl start polygon_edge_validator_1