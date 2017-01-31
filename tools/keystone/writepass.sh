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
set -o errexit
set -o nounset
set -o pipefail

PASSWORD_FILE_ENC="/root/servicepass.ini"
PASSWORD_FILE="/root/passwords.ini"

function ini_has_option {
    local file=$1
    local section=$2
    local option=$3
    local line
    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    [ -n "$line" ]
}

# Get an option from an INI file
# iniget config-file section option
function iniget {
    local xtrace
    xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local line

    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    echo ${line#*=}
    $xtrace
}

# Set an option in an INI file
# iniset [-sudo] config-file section option value
#  - if the file does not exist, it is created
function iniset {
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    if ! grep -q "^\[$section\]" "$file" 2>/dev/null; then
        echo -e "\n[$section]" >>"$file"
    fi
    if ! ini_has_option "$file" "$section" "$option"; then
        sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        local sep=$(echo -ne "\x01")
        # Replace it
        sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file"
    fi
}

function decode_passwords() {
    openssl enc -aes-256-cbc -d -in ${PASSWORD_FILE_ENC} -out ${PASSWORD_FILE} -k multisite
}

function write_controller() {
    # For each slave region the following files must be updated on each controller.
    iniset "/etc/glance/glance-registry.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT glance)
    iniset "/etc/glance/glance-api.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT glance)
    iniset "/etc/glance/glance-glare.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT glare)
    iniset "/etc/heat/heat.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT heat)
    iniset "/etc/nova/nova.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT nova)
    iniset "/etc/nova/nova.conf" neutron password $(iniget ${PASSWORD_FILE} DEFAULT neutron)
    iniset "/etc/cinder/cinder.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT cinder)
    iniset "/etc/neutron/neutron.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT neutron)
    iniset "/etc/ceilometer/ceilometer.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT ceilometer)
    iniset "/etc/aodh/aodh.conf" keystone_authtoken password $(iniget ${PASSWORD_FILE} DEFAULT aodh)
}

function restart_controller() {
    service nova-api restart
    service nova-cert restart
    service nova-conductor restart
    service nova-novncproxy restart
    service nova-consoleauth restart

    service neutron-server restart
    service heat-api restart
    service heat-engine restart
    service glance-api restart
    service glance-registry restart
    service glance-glare restart

    service cinder-api restart
    service cinder-volume restart
    service cinder-scheduler restart
    service cinder-backup restart

    # corosync resources
    crm resource restart p_ceilometer-agent-central
    crm resource restart p_aodh-evaluator
}

function write_compute() {
    iniset "/etc/nova/nova.conf" neutron password $(iniget ${PASSWORD_FILE} DEFAULT neutron)
}

function restart_compute() {
    service nova-compute restart
}

#begin
decode_passwords

# are we on the controller?
if pgrep -f nova-api > /dev/null
then
    write_controller
    restart_controller
else
    write_compute
    restart_compute
fi
