# Init variables from Bicep
managedIdentity=$1
vaultName=$2
nodeId=$3


# Install dependencies
sudo apt update
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

nodeId=$(( nodeId + 1 ))

az login --identity --username $managedIdentity

# Download Keys and genesis file
az keyvault secret download --vault-name ${vaultName} --file node${nodeId} --name node${nodeId}
az keyvault secret download --vault-name ${vaultName} --file genesis.json --name genesis

# Extract data 
base64 -d node${nodeId} > data.tar.gz
tar xvfz data.tar.gz -C /srv/tank

mv genesis.json /srv/tank/edge-validator-${nodeId}/genesis.json

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