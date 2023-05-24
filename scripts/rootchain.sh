# Start rootchain server

echo "[Unit]
  Description=rootchain server devnet 1
  StartLimitIntervalSec=30
  StartLimitBurst=5

[Service]
  Restart=on-failure
  RestartSec=5s

  ExecStart=polygon-edge rootchain server  --data-dir /srv/tank/rootchain

  Type=simple
  User=root

[Install]
  WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/polygon_rootchain_1.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable polygon_rootchain_1
sudo systemctl start polygon_rootchain_1

# Expose rootchain json rpc port to 18545

echo "[Unit]
  Description=Port tunnel for polygon rootchain
  StartLimitIntervalSec=30
  StartLimitBurst=5

[Service]
  Restart=on-failure
  RestartSec=5s

  ExecStart=ncat -k -l --verbose -p 18545 -c \"ncat 127.0.0.1 8545\"

  Type=simple
  User=root

[Install]
  WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/polygon_rootchain_netcat_1.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable polygon_rootchain_netcat_1
sudo systemctl start polygon_rootchain_netcat_1

# Deploy contracts to rootchain, need to get genesis from validators
polygon-edge rootchain deploy --genesis /srv/tank/my-supernet/genesis.json --json-rpc http://127.0.0.1:8545 --test

rootERC20=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.nativeERC20Address')
stakeManagerAddr=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.stakeManagerAddr')
customSupernetManagerAddr=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.customSupernetManagerAddr')
chainID=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.chainID')

# Private key here is used, is the default one of test account, consider changing it
polygon-edge polybft whitelist-validators \
    --private-key aa75e9a7d427efc732f8e4f1a5b7646adcc61fd5bae40f80d13c8419c9f43d6d \
    --addresses ${VALIDATOR_KEY_ONE},${VALIDATOR_KEY_TWO},${VALIDATOR_KEY_THREE},${VALIDATOR_KEY_FOUR} \
    --supernet-manager ${customSupernetManagerAddr} --jsonrpc http://127.0.0.1:8545

# Return back to validators


# Finalize validator set and genesis file
polygon-edge polybft supernet \
    --private-key aa75e9a7d427efc732f8e4f1a5b7646adcc61fd5bae40f80d13c8419c9f43d6d \
    --supernet-manager ${customSupernetManagerAddr} \
    --stake-manager ${stakeManagerAddr} \
    --finalize-genesis-set \
    --enable-staking \
    --jsonrpc http://127.0.0.1:8545