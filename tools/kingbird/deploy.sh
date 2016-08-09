#!/bin/bash

set -o xtrace
set -o nounset
set -o pipefail

INSTALLER_IP=10.20.0.2

usage() {
    echo "usage: $0 -a <installer_ip>" >&2

}

error () {
    logger -s -t "deploy.error" "$*"
    exit 1
}

#Get options
while getopts ":a:" optchar; do
    case "${optchar}" in
        a)  installer_ip=${OPTARG} ;;
        *)  echo "Non-option argument: '-${OPTARG}'" >&2
            usage
            exit 2
            ;;
    esac
done

installer_ip=${installer_ip:-$INSTALLER_IP}

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

controller_ip=$(sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
'fuel node --env 1| grep controller | grep "True\|  1" | awk -F\| "{print \$5}" | tail -1' | \
sed 's/ //g') &> /dev/null

if [ -z $controller_ip ]; then
    error "The controller $controller_ip is not up. Please check that the POD is correctly deployed."
fi

# Copy install_kingbird.sh script to the controller
sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
"ssh $ssh_options ${controller_ip} \"cd /root/  && cat > install_kingbird.sh\"" < install_kingbird.sh &> /dev/null
# Set the rights and execute
sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
"ssh $ssh_options ${controller_ip} \"cd /root/ && chmod +x install_kingbird.sh\"" &> /dev/null
sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
"ssh $ssh_options ${controller_ip} \"cd /root/ && nohup /root/install_kingbird.sh > install.log 2> /dev/null\"" &> /dev/null
# Output here
sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
"ssh $ssh_options ${controller_ip} \"cd /root/ && cat install.log\""

sleep 5

engine_pid=$(sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} "ssh $ssh_options ${controller_ip} \"pgrep -f kingbird-engine || echo dead\"") &> /dev/null
api_pid=$(sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} "ssh $ssh_options ${controller_ip} \"pgrep -f kingbird-api || echo dead\"") &> /dev/null

if [ "$engine_pid" ==  "dead" ]; then
   error "Kingbird engine is not running."
fi

if [ "$api_pid" == "dead" ]; then
   error "Kingbird API is not running."
fi

echo "Deployment complete!"
