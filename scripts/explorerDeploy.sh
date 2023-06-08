# Install
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

mkdir -p blockscout && cd blockscout

echo "version: '3.8'

services:
  db:
    image: postgres:13.6
    restart: always
    container_name: 'postgres'
    command: postgres -c 'max_connections=1000'
    environment:
        POSTGRES_PASSWORD: ''
        POSTGRES_USER: 'postgres'
        POSTGRES_HOST_AUTH_METHOD: 'trust'
    volumes:
      - ./postgres-data:/var/lib/postgresql/data

  blockscout:
    depends_on:
      - db
    image: blockscout/blockscout:4.1.5
    restart: always
    container_name: 'blockscout'
    links:
      - db:database
    command: 'mix do ecto.create, ecto.migrate, phx.server'
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    # env_file:
    #   -  ./envs/common-blockscout.env
    logging:
      driver: "json-file"
      options:
        max-size: "2048m"
    environment:
        ETHEREUM_JSONRPC_VARIANT: 'geth'
        BLOCK_TRANSFORMER: 'clique'
        COIN: 'TOKEN'
        COIN_NAME: 'TOKEN'
        ETHEREUM_JSONRPC_HTTP_URL: http://10.1.1.21:10001/
        DATABASE_URL: postgresql://postgres:@db:5432/blockscout?ssl=false
        ECTO_USE_SSL: 'false'
        SECRET_KEY_BASE: '56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN'
    ports:
      - 4010:4000" | sudo tee docker-compose.yml > /dev/null

sudo docker-compose up -d