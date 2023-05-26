# Init variables from Bicep
managedIdentity=$1
vaultName=$2
validatorsAmount=$3

function installDependecies(){
    # Install dependencies
    mkdir -p /srv/tank
    sudo chown -R azureuser:sudo /srv/tank
    

    cd ~/
    mkdir -p src && cd src && wget https://github.com/0xPolygon/polygon-edge/releases/download/v0.9.0/polygon-edge_0.9.0_linux_amd64.tar.gz && tar xvf polygon-edge_0.9.0_linux_amd64.tar.gz
    sudo mv polygon-edge /usr/local/bin/

    # Install docker
    sudo apt-get remove docker docker-engine docker.io containerd runc

    sudo apt-get update


    sudo apt-get install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release -y 


    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y 

    # Docker compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    sudo apt install ncat -y
    sudo apt install jq -y

}

installDependecies


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

export folderName="edge-validator-"

function generateValidators() {
    amountOfValidators=$1

    polygon-edge polybft-secrets --insecure --data-dir /srv/tank/${folderName} --num $amountOfValidators

    az login --identity --username $managedIdentity

    i=1
    while [ $i -le $amountOfValidators ]
    do
        tar -czvf data${i}.tar.gz /srv/tank/${folderName}${i}
        base64 data$i.tar.gz > node$i
        az keyvault secret set --vault-name $vaultName --name node$i --file node$i
        ((i++))
    done

    
}

function initRootchain() {
    amountOfValidators=$1

    rewardWallet="0x3383e0EbB44d2929abD654cFe4DF52C818af3230"
    addressesToPremine="0x3383e0EbB44d2929abD654cFe4DF52C818af3230"
    amountToPremine=1000000000000000000000
    nativeTokenConfig="SuperTestCoin:STC:18"

    # Assemble the command for generating genesis
    validatorCommandLine=""
    validatorAddressesList=""
    validatorAmountToFundList=""

    counter=1
    
    while [ $counter -le $amountOfValidators ]
    do
        address=$(polygon-edge polybft-secrets --insecure --data-dir /srv/tank/${folderName}${counter} | grep address | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
        blsKey=$(polygon-edge polybft-secrets --insecure --data-dir /srv/tank/${folderName}${counter} | grep BLS | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
        nodeId=$(polygon-edge polybft-secrets --insecure --data-dir /srv/tank/${folderName}${counter} | grep Node | sed -e 's#.*=\(\)#\1#' | sed 's/ //g')
        ipv4=10.1.1.1$counter

        VALIDATOR="/ip4/${ipv4}/tcp/30301/p2p/${nodeId}:${address}:${blsKey}"

        validatorCommandLine="${validatorCommandLine} --validators ${VALIDATOR}"
        validatorAddressesList="${address},${validatorAddressesList}"
        validatorAmountToFundList="1000000000000000000000000,${validatorAmountToFundList}"

        ((counter++))
    done

    allowAddressList=${validatorAddressesList}

    mkdir -p /srv/tank/configs

    polygon-edge genesis --dir /srv/tank/configs/genesis.json --block-gas-limit 10000000 --epoch-size 10 \
        ${validatorCommandLine} \
        --consensus polybft \
        --reward-wallet ${rewardWallet}:1000000 \
        --transactions-allow-list-admin ${allowAddressList} \
        --transactions-allow-list-enabled ${allowAddressList} \
        --premine ${addressesToPremine}:${amountToPremine} --native-token-config ${nativeTokenConfig} &> genesis_output.log

    polygon-edge rootchain deploy --genesis /srv/tank/configs/genesis.json --json-rpc http://127.0.0.1:8545 --test &> contracts_output.log

    rootERC20=$(cat /srv/tank/configs/genesis.json | jq -r '.params.engine.polybft.bridge.nativeERC20Address')
    stakeManagerAddr=$(cat /srv/tank/configs/genesis.json | jq -r '.params.engine.polybft.bridge.stakeManagerAddr')
    customSupernetManagerAddr=$(cat /srv/tank/configs/genesis.json | jq -r '.params.engine.polybft.bridge.customSupernetManagerAddr')
    chainID=$(cat /srv/tank/configs/genesis.json | jq -r '.params.chainID')

    counter=1
    while [ $counter -le $amountOfValidators ]
    do
        polygon-edge rootchain fund \
            --native-root-token ${rootERC20} \
            --mint \
            --data-dir /srv/tank/${folderName}${counter} \
            --amount 1000000000000000000 &> fund_${counter}_output.log
        ((counter++))
    done

    polygon-edge polybft whitelist-validators \
        --addresses ${validatorAddressesList} \
        --supernet-manager ${customSupernetManagerAddr} \
        --private-key aa75e9a7d427efc732f8e4f1a5b7646adcc61fd5bae40f80d13c8419c9f43d6d \
        --jsonrpc http://127.0.0.1:8545 &> whitelist_output.log


    counter=1
    while [ $counter -le $amountOfValidators ]
    do
        echo "Registering validator: ${counter}"

        polygon-edge polybft register-validator \
            --supernet-manager ${customSupernetManagerAddr} \
            --data-dir /srv/tank/${folderName}${counter} \
            --jsonrpc http://127.0.0.1:8545 &> register_${counter}_output.log

        # Ignoring error as there is a bug within v0.9.0 of polygon-edge
        polygon-edge polybft stake \
            --data-dir /srv/tank/${folderName}${counter} \
            --amount 1000000000000000000000000 \
            --chain-id ${chainID} \
            --stake-manager ${stakeManagerAddr} \
            --native-root-token ${rootERC20} \
            --jsonrpc http://127.0.0.1:8545 &> stake_${counter}_output.log

        ((counter++))
    done

    polygon-edge polybft supernet \
        --private-key aa75e9a7d427efc732f8e4f1a5b7646adcc61fd5bae40f80d13c8419c9f43d6d \
        --genesis /srv/tank/configs/genesis.json \
        --supernet-manager ${customSupernetManagerAddr} \
        --stake-manager ${stakeManagerAddr} \
        --finalize-genesis-set \
        --enable-staking \
        --jsonrpc http://127.0.0.1:8545 &> finalize_output.log

    # Specify rootchain address in genesis
    jq --arg a "http://10.1.1.50:18545" '.params.engine.polybft.bridge.jsonRPCEndpoint = $a' /srv/tank/configs/genesis.json > "tmp" && mv tmp /srv/tank/configs/genesis.json

    # az keyvault secret set --vault-name $vaultName --name genesis --file /srv/tank/configs/genesis.json
}

generateValidators $validatorsAmount
initRootchain $validatorsAmount