#!/bin/bash

GIT_SERVER=git.xpin.io
FRP_VERSION=0.51.3
SWAP_FILE_SIZE=1G

# ------------- functions --------------
add_swap_file () {
    echo "Add swap file of size $SWAP_FILE_SIZE to system ..."
    fallocate -l $SWAP_FILE_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "Done"
}

install_webmin () {
    echo "Install webmin ..."
    sh -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list'
    curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
    apt-get update && apt-get install webmin -y

    #change webmin port
    sed -i -e 's/^port=[[:digit:]]*/port=10011/' /etc/webmin/miniserv.conf
    service webmin restart

    echo "Done"
}

install_frp () {
    echo "Install FRP  ..."
    curl -sSL https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/frp_${FRP_VERSION}_linux_amd64.tar.gz | tar zxvf - -C /usr/local
    mv /usr/local/frp_${FRP_VERSION}_linux_amd64 /usr/local/frp
    wget -c https://raw.githubusercontent.com/stexine/vps-setup/master/src/tpl/frpc.ini -O /usr/local/frp/frpc.ini
    wget -c https://raw.githubusercontent.com/stexine/vps-setup/master/src/tpl/frpc.service -O /etc/systemd/system/frpc.service
    sed -i.bak "s|<<FRP_USER>>|$HOST|g; s|<<FRP_SERVER>>|$FRP_SERVER|g; s|<<FRP_POST>>|$FRP_PORT|g; s|<<FRP_TOKEN>>|$FRP_KEY|g;" /usr/local/frp/frpc.ini > /usr/local/frp/frpc.ini
    systemctl start frpc
    systemctl enable frpc
    echo "Done"
}

install_portainer_agent() {
    docker run -d -p 9001:9001 --name portainer_agent --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker/volumes:/var/lib/docker/volumes portainer/agent:latest
}

install_bbr () {
    # install bbrplus, 2 -> no for kernel removeal -> restart -> 7 
    cd ~/ && wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}


clone_docker_setup () {

    echo "Start cloning docker repo ... "
    
    mkdir -p $HOME_DIR
    git clone https://${GIT_SERVER}/stexine/wxpanel.git $HOME_DIR
    sed -e "s|SERVER_HOST|$HOST|; s|SERVER_DOMAIN|$DOMAIN|; s|SERVER_SHELL|zsh|;" $HOME_DIR/src/tpl/setup.sh > $HOME_DIR/setup.sh
    cd $HOME_DIR
    ./setup.sh
}

change_ports () {
    # change sshd port
    sed -i -e 's/^#*Port[[:space:]{1,}].*/Port 10012/' /etc/ssh/sshd_config
    service sshd restart
}

setup_firewall () {
    # ------------ firewall ----------------
    apt-get install iptables-persistent netfilter-persistent -y
    iptables-restore < iptables.save
    iptables-save > /etc/iptables/rules.v4
}


echo ""
echo "========================================="
echo "=    Setup your new vps server!         ="
echo "=       by Stexine <stexine@gmail.com>  ="
echo "========================================="
echo ""

if [[ $( lsb_release -a | grep Distributor ) != *"Ubuntu"* ]]; then
    echo "Only Ubuntu is supported!"
    exit 1
fi

echo -n "This script will install GFW proxy software and Web server to your system, continue? (y/n): "
read CONT

if [[ $CONT != "y" ]]
then
    echo "Good Bye"
    exit 1
fi

echo -n "Enter the domain of the server? (domain.com): "
read DOMAIN

echo -n "Enter the host of the server? (www): "
read HOST

echo -n "Enter where wxpanel should be installed? (/var/local/wxpanel): "
read HOME_DIR

if [[ $HOME_DIR == "" ]]
then
    HOME_DIR=/var/local/wxpanel  
fi

echo -n "Add swap file of $SWAP_FILE_SIZE? (y/n): "
read SWAP

echo -n "Install Webmin? (y/n): "
read WEBMIN

echo -n "Install FRP client? (y/n): "
read FRP

if [[ $FRP == "y" ]]
then
    echo -n "Enter FRP Server address (host.domain.com): "
    read FRP_SERVER

    echo -n "Enter FRP Server port (8097): "
    read FRP_PORT

    if [[ $FRP_PORT == "" ]]
    then
        FRP_PORT=8097
    fi

    echo -n "Enter FRP Server KEY: "
    read FRP_KEY
fi

echo -n "Install BBR Plus? (y/n): "
read BBR

echo -n "Install portainer agent? (y/n): "
read PORTAINER

echo "Install os updates and basic packages ..."
echo ""
apt-get update && apt-get upgrade -y
apt-get install apt-transport-https ca-certificates curl software-properties-common supervisor -y
echo "Done"

# -------------- add swapfile ----------------------
if [[ $SWAP == "y" ]]
then
    add_swap_file
fi


# -------------- install webmin --------------------
if [[ $WEBMIN == "y" ]]
then
    install_webmin
fi

# -------------- install frp --------------------
if [[ $FRP == "y" ]]
then
    install_frp
fi

# -------------- install docker ---------------------
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Install docker, certbot ..."
apt-get update
apt-get install docker-ce docker-compose -y

if [[ $PORTAINER == "y" ]]
then
    install_portainer_agent
fi


clone_docker_setup

#--------------- install bbr ----------------
if [[ $BBR == "y" ]]
then
    install_bbr
fi

