# Init variables from Bicep
managedIdentity=$1
vaultName=$2
nodeId=$3
storageAccountName=$4

nodeId=$(( nodeId + 1 ))

# Install dependencies
mkdir -p /srv/tank/edge-rpc
sudo chown -R azureuser:sudo /srv/tank

sudo apt update
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity --username $managedIdentity

# Install dependecies 
sudo apt install jq -y

# Download Keys and genesis file
# az keyvault secret download --vault-name ${vaultName} --file genesis.json --name genesis
accountKey=$(az storage account keys list --account-name ${storageAccountName} | jq -r '.[0].value')
az storage blob download  --account-name ${storageAccountName} --account-key ${accountKey}  --container-name configs --name genesis.json  --file /srv/tank/edge-rpc/genesis.json


# Launch RPC node
echo "[Unit]
  Description=Polygon edge RPC node 1
  StartLimitIntervalSec=30
  StartLimitBurst=5

[Service]
  Restart=on-failure
  RestartSec=5s

  ExecStart=polygon-edge server --data-dir /srv/tank/edge-rpc --chain /srv/tank/edge-rpc/genesis.json --grpc-address :5001 --libp2p 0.0.0.0:30301 --jsonrpc 0.0.0.0:10001 --log-level DEBUG

  Type=simple
  User=root

[Install]
  WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/polygon_edge_rpc_1.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable polygon_edge_rpc_1
sudo systemctl start polygon_edge_rpc_1