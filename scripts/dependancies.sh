# Install Polygon Edge and dependancies
sudo apt install ncat jq wget -y

cd ~/
mkdir -p src && cd src && wget https://github.com/0xPolygon/polygon-edge/releases/download/v0.9.0/polygon-edge_0.9.0_linux_amd64.tar.gz && tar xvf polygon-edge_0.9.0_linux_amd64.tar.gz
sudo mv polygon-edge /usr/local/bin/

# Install docker
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y