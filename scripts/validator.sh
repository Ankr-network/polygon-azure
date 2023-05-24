
polygon-edge polybft-secrets --insecure --data-dir /srv/tank/my-supernet --num 1 &> pubkeys.txt
pubKey=$(cat pubkeys.txt | grep address | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
blsKey=$(cat pubkeys.txt | grep BLS | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
nodeId=$(cat pubkeys.txt | grep Node | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
ipv4=$(curl -s ifconfig.me) # Or private address

export VALIDATOR="/ip4/${ipv4}/tcp/30301/p2p/${nodeId}:${pubKey}:${blsKey}"
export rewardWallet=0xBFAcaFf6dCb2E982329a7a807eD610f1EBBC23fB

nativeTokenConfig="SuperTestCoin:STC:18"



############################# Can be run on rootchain server then transfer all keys and genesis #############################

# Collect validator info
# Define premine and allowed list
polygon-edge genesis --dir /srv/tank/my-supernet/genesis.json --block-gas-limit 10000000 --epoch-size 10 --validators "${VALIDATOR_ONE}" --validators "${VALIDATOR_TWO}" --validators "${VALIDATOR_THREE}" --validators "${VALIDATOR_FOUR}" --consensus polybft --reward-wallet ${rewardWallet}:1000000 --transactions-allow-list-admin 0xBFAcaFf6dCb2E982329a7a807eD610f1EBBC23fB,0x3383e0EbB44d2929abD654cFe4DF52C818af3230,0x13a090Bc0A5b1777125270843dCdE524b74bF990 --transactions-allow-list-enabled 0xBFAcaFf6dCb2E982329a7a807eD610f1EBBC23fB,0x3383e0EbB44d2929abD654cFe4DF52C818af3230,0x13a090Bc0A5b1777125270843dCdE524b74bF990 --premine 0x3383e0EbB44d2929abD654cFe4DF52C818af3230:1000000000000000000000 --native-token-config ${nativeTokenConfig}

# Fund Validators, run on each machine, replace json rpc address
polygon-edge rootchain fund --data-dir /srv/tank/my-supernet --amount 1000000000000000000 --json-rpc http://167.172.150.71:18545

# Go to rootchain
# Copy the genesis with all contracts deployed from rootchain
# TODO

# Get all variables from genesis
rootERC20=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.nativeERC20Address')
stakeManagerAddr=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.stakeManagerAddr')
customSupernetManagerAddr=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.engine.polybft.bridge.customSupernetManagerAddr')
chainID=$(cat /srv/tank/my-supernet/genesis.json | jq -r '.params.chainID')

## Register each validator
polygon-edge polybft register-validator \
    --supernet-manager ${customSupernetManagerAddr} \
    --data-dir /srv/tank/my-supernet \
    --jsonrpc http://167.172.150.71:18545 

## Stake each validator on rootchain
polygon-edge polybft stake --data-dir /srv/tank/my-supernet/ \
    --amount 1000000000000000000000000 \
    --chain-id ${chainID} \
    --stake-manager ${stakeManagerAddr} \
    --native-root-token ${rootERC20} \
    --jsonrpc http://167.172.150.71:18545 

############################# Can be run on rootchain server then transfer all keys and genesis #############################


# Launch validator node
echo "[Unit]
  Description=Polygon edge validator 1
  StartLimitIntervalSec=30
  StartLimitBurst=5

[Service]
  Restart=on-failure
  RestartSec=5s

  ExecStart=polygon-edge server --data-dir /srv/tank/my-supernet --chain /srv/tank/my-supernet/genesis.json --grpc-address :5001 --libp2p 0.0.0.0:30301 --jsonrpc 0.0.0.0:10001 --seal --log-level DEBUG

  Type=simple
  User=root

[Install]
  WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/polygon_edge_validator_1.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable polygon_edge_validator_1
sudo systemctl start polygon_edge_validator_1