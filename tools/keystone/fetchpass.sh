#!/bin/bash
#
# Author: Dimitri Mazmanov (dimitri.mazmanov@ericsson.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
#

# DISCLAIMER: This script is a dirty filthy hack! But we need it.
# Fetch service password from the configuration files and store them
# in a file to pass further down the build chain

GLANCE_CONF="/etc/glance/glance-registry.conf"
NOVA_CONF="/etc/nova/nova.conf"
NEUTRON_CONF="/etc/neutron/neutron.conf"
CINDER_CONF="/etc/cinder/cinder.conf"
HEAT_CONF="/etc/heat/heat.conf"
GLARE_CONF="/etc/glance/glance-glare.conf"
KEYSTONE_CONF='/etc/keystone/keystone.conf'
CEILOMETER_CONF='/etc/ceilometer/ceilometer.conf'
AODH_CONF='/etc/aodh/aodh.conf'

source openrc

# Always executed on controller
PASSWORD_FILE_ENC="/root/servicepass.ini"
PASSWORD_FILE="/root/passwords.ini"

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

bind_host=$(openstack endpoint list | grep keystone | grep public | cut -d '|' -f 8 | cut -d '/' -f 3 | cut -d ':' -f 1)

glance_password=$(iniget ${GLANCE_CONF} keystone_authtoken password)
nova_password=$(iniget ${NOVA_CONF} keystone_authtoken password)
cinder_password=$(iniget ${CINDER_CONF} keystone_authtoken password)
glare_password=$(iniget ${GLARE_CONF} keystone_authtoken password)
heat_password=$(iniget ${HEAT_CONF} keystone_authtoken password)
neutron_password=$(iniget ${NEUTRON_CONF} keystone_authtoken password)
ceilometer_password=$(iniget ${CEILOMETER_CONF} keystone_authtoken password)
aodh_password=$(iniget ${AODH_CONF} keystone_authtoken password)
#NOTE: can't find swift in /etc

cat <<EOT >> ${PASSWORD_FILE}
[DEFAULT]
identity_uri=${bind_host}
glance=${glance_password}
nova=${nova_password}
cinder=${cinder_password}
glare=${glare_password}
heat=${heat_password}
neutron=${neutron_password}
ceilometer=${ceilometer_password}
aodh=${aodh_password}
EOT

openssl enc -aes-256-cbc -salt -in ${PASSWORD_FILE} -out ${PASSWORD_FILE_ENC} -k multisite

rm ${PASSWORD_FILE}
