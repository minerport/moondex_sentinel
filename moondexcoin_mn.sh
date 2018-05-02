echo "=================================================================="
echo "Moondexcoin MN Install"
echo "=================================================================="

#read -p 'Enter your masternode genkey you created in windows, then hit [ENTER]: ' GENKEY

echo "Installing packages and updates..."
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install git -y
sudo apt-get install nano -y
sudo apt-get install pwgen -y
sudo apt-get install dnsutils -y
sudo apt-get install zip unzip -y

echo "Packages complete..."

WALLET_VERSION='2.0.0.1'
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
PORT='8906'
RPCPORT='8960'
PASSWORD=`pwgen -1 20 -n`
if [ "x$PASSWORD" = "x" ]; then
    PASSWORD=${WANIP}-`date +%s`
fi

#begin optional swap section
echo "Setting up disk swap..."
free -h
sudo fallocate -l 4G /swapfile
ls -lh /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab sudo bash -c "
echo 'vm.swappiness = 10' >> /etc/sysctl.conf"
free -h
echo "SWAP setup complete..."
#end optional swap section

wget https://github.com/Moondex/MoonDEXCoin/releases/download/v${WALLET_VERSION}/linux-no-gui-v${WALLET_VERSION}.tar.gz

rm -rf moondex
mkdir moondex
tar -zxvf linux-no-gui-v${WALLET_VERSION}.tar.gz -C moondex

echo "Loading and syncing wallet"

echo "If you see *error: Could not locate RPC credentials* message, do not worry"
~/moondex/moondex-cli stop
sleep 10
echo ""
echo "=================================================================="
echo "DO NOT CLOSE THIS WINDOW OR TRY TO FINISH THIS PROCESS "
echo "PLEASE WAIT 5 MINUTES UNTIL YOU SEE THE RELOADING WALLET MESSAGE"
echo "=================================================================="
echo ""
~/moondex/moondexd -daemon
sleep 250
~/moondex/moondex-cli stop
sleep 20

cat <<EOF > ~/.moondexcore/moondex.conf
rpcuser=moondexcoin
rpcpassword=${PASSWORD}
EOF

echo "Reloading wallet..."
~/moondex/moondexd -daemon
sleep 30

echo "Making genkey..."
GENKEY=$(~/moondex/moondex-cli masternode genkey)

echo "Mining info..."
~/moondex/moondex-cli getmininginfo
~/moondex/moondex-cli stop

echo "Creating final config..."

cat <<EOF > ~/.moondexcore/moondex.conf
rpcuser=moondexcoin
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
server=1
daemon=1
listen=1
rpcport=${RPCPORT}
port=${PORT}
externalip=$WANIP
maxconnections=256
masternode=1
masternodeprivkey=$GENKEY
EOF

echo "Restarting wallet with new configs, 30 seconds..."
~/moondex/moondexd -daemon
sleep 30

echo "Installing sentinel..."
cd /root/.moondexcore
sudo apt-get install -y git python-virtualenv

sudo git clone https://github.com/moondexcoin/moondex_sentinel.git

wget https://github.com/Moondex/moondex_sentinel/archive/master.zip
unzip master.zip
mv moondex_sentinel-master moondex_sentinel

cd moondex_sentinel

export LC_ALL=C
sudo apt-get install -y virtualenv

virtualenv ./venv
./venv/bin/pip install -r requirements.txt

echo "moondex_conf=/root/.moondexcore/moondex.conf" >> /root/.moondexcore/moondex_sentinel/sentinel.conf

echo "Adding crontab jobs..."
crontab -l > tempcron
#echo new cron into cron file
echo "* * * * * cd /root/.moondexcore/moondex_sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> tempcron
echo "@reboot /bin/sleep 20 ; /root/moondex/moondexd -daemon &" >> tempcron

#install new cron file
crontab tempcron
rm tempcron

SENTINEL_DEBUG=1 ./venv/bin/python bin/sentinel.py
echo "Sentinel Installed"

echo "moondex-cli getmininginfo:"
~/moondex/moondex-cli getmininginfo

sleep 15

echo "Masternode status:"
~/moondex/moondex-cli masternode status

echo "If you get \"Masternode not in masternode list\" status, don't worry, you just have to start your MN from your local wallet and the status will change"
echo ""
echo "INSTALLED WITH VPS IP: $WANIP:$PORT"
sleep 1
echo "INSTALLED WITH MASTERNODE PRIVATE GENKEY: $GENKEY"
sleep 1
echo "rpcuser=moondexcoin"
echo "rpcpassword=$PASSWORD"