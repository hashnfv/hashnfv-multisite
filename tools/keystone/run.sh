#!/bin/bash
#
# Author: Dimitri Mazmanov (dimitri.mazmanov@ericsson.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
#

set -o xtrace
set -o nounset
set -o pipefail


# This script proxies execution of other scripts through fuel node
# onto the destination node.
# Usage: run.sh (controller|compute) <runnable_script.sh>

INSTALLER_IP=10.20.0.2
# Runs on the jumphost
# if running as part of Jenkins job, read and create the files from/in WORKSPACE
export WORKSPACE=${WORKSPACE:-"/root"}

usage() {
    echo "usage: $0 -a <installer_ip> -t (controller|compute) -r <runnable_script.sh> -d <data_file> -o <output_file>" >&2
}

error () {
    logger -s -t "deploy.error" "$*"
    exit 1
}

if [ $# -eq 0 ]; then
   usage
   exit 2
fi

while [[ $# -gt 0 ]]; do
case $1 in
    -i|--installer)
    installer_ip="$2"
    shift # past argument
    ;;
    -t|--target)
    target="$2"
    shift # past argument
    ;;
    -r|--runnable)
    runnable="$2"
    shift # past argument
    ;;
    -d|--data)
    data="$2"
    shift # past argument
    ;;
    -o|--output)
    output="$2"
    shift # past argument
    ;;
    *)
    echo "Non-option argument: '-${OPTARG}'" >&2
    usage
    exit 2
    ;;
esac
shift # past argument or value
done

installer_ip=${installer_ip:-$INSTALLER_IP}
data=${data:-""}
output=${output:-""}

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

function run_on_target() {
    # Copy the script to the target
    sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
    "ssh $ssh_options $1 \"cd /root/  && cat > ${runnable}\"" < ${runnable} &> /dev/null
    if [ -n "${data}" ]; then
        # Copy any accompanying data along with the script
        sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
        "ssh $ssh_options $1 \"cd /root/  && cat > ${data}\"" < ${data} &> /dev/null
    fi
    # Set the rights and execute
    sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
    "ssh $ssh_options $1 \"cd /root/ && chmod +x ${runnable}\"" &> /dev/null
    sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
    "ssh $ssh_options $1 \"cd /root/ && nohup ${runnable} > ${runnable}.log 2> /dev/null\"" &> /dev/null
    # Output here
    sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
    "ssh $ssh_options $1 \"cd /root/ && cat ${runnable}.log\""

    if [ -n "${output}" ]; then
        #Fetch output file
        sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
        "ssh $ssh_options $1 \"cat /root/${output}\"" > ${WORKSPACE}/${output}
    fi
    
}

target_info=$(sshpass -p r00tme ssh 2>/dev/null $ssh_options root@${installer_ip} \
fuel node list| grep ${target} | grep "True\|  1" | awk -F\| "{print \$5}" | \
sed 's/ //g') &> /dev/null

for machine in ${target_info} ; do
    run_on_target $machine
done