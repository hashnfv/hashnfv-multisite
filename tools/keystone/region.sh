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
source openrc

# This script registers a new OpenStack region in Keystone.
# It relies on availability of the following environment variables
#
# $NEW_PUBLIC_URL - public URL for the OpenStack services
# $NEW_INTERNAL_URL - internal URL for the OpenStack services
# $NEW_ADMIN_URL - admin URL for the OpenStack services. Typically the same as internal URL
# $NEW_REGION - new region name. E.g. RegionTwo
#
# Invoke the script on the master region - the region which hosts a centralized Keystone instance.
# Additional services can be register using the following pattern:
#
# openstack endpoint create --publicurl "" --adminurl "" --internalurl "" --region ${region} <service>

# Always executed on controller
ENDPOINT_FILE="/root/endpoints.ini"

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

error () {
    logger -s -t "registration.error" "$*"
    exit 1
}

public_url=$(iniget ${ENDPOINT_FILE} DEFAULT public_url)
internal_url=$(iniget ${ENDPOINT_FILE} DEFAULT internal_url)
admin_url=$(iniget ${ENDPOINT_FILE} DEFAULT admin_url)
region=$(iniget ${ENDPOINT_FILE} DEFAULT os_region)

if [ -z $public_url || -z $internal_url || -z $admin_url || -z $region ]; then
    error "The provided endpoint information is incomplete. Please che the values for public_url, admin_url, internal_url and os_region."
fi

# Nova
openstack endpoint create nova public "http://${public_url}:8774/v2.1" --region ${region}
openstack endpoint create nova admin "http://${admin_url}:8774/v2.1" --region ${region}
openstack endpoint create nova internal "http://${internal_url}:8774/v2.1" --region ${region}

openstack endpoint create compute_legacy public "http://${public_url}:8774/v2/%(tenant_id)s" --region ${region}
openstack endpoint create compute_legacy admin "http://${admin_url}:8774/v2/%(tenant_id)s" --region ${region}
openstack endpoint create compute_legacy internal "http://${internal_url}:8774/v2/%(tenant_id)s" --region ${region}

# Neutron
openstack endpoint create neutron public "http://${public_url}:9696" --region ${region}
openstack endpoint create neutron admin "http://${admin_url}:9696" --region ${region}
openstack endpoint create neutron internal "http://${internal_url}:9696" --region ${region}

# Cinder
openstack endpoint create cinder public "http://${public_url}:8776/v1/%(tenant_id)s" --region ${region}
openstack endpoint create cinder admin "http://${admin_url}:8776/v1/%(tenant_id)s" --region ${region}
openstack endpoint create cinder internal "http://${internal_url}:8776/v1/%(tenant_id)s" --region ${region}

openstack endpoint create cinderv2 public "http://${public_url}:8776/v2/%(tenant_id)s" --region ${region}
openstack endpoint create cinderv2 admin "http://${admin_url}:8776/v2/%(tenant_id)s" --region ${region}
openstack endpoint create cinderv2 internal "http://${internal_url}:8776/v2/%(tenant_id)s" --region ${region}

openstack endpoint create cinderv3 public "http://${public_url}:8776/v3/%(tenant_id)s" --region ${region}
openstack endpoint create cinderv3 admin "http://${admin_url}:8776/v3/%(tenant_id)s" --region ${region}
openstack endpoint create cinderv3 internal "http://${internal_url}:8776/v3/%(tenant_id)s" --region ${region}

# Glance
openstack endpoint create glance public "http://${public_url}:9292" --region ${region}
openstack endpoint create glance admin "http://${admin_url}:9292" --region ${region}
openstack endpoint create glance internal "http://${internal_url}:9292" --region ${region}

# Heat
openstack endpoint create heat public "http://${public_url}:8004/v1/%(tenant_id)s" --region ${region}
openstack endpoint create heat admin "http://${admin_url}:8004/v1/%(tenant_id)s" --region ${region}
openstack endpoint create heat internal "http://${internal_url}:8004/v1/%(tenant_id)s" --region ${region}

openstack endpoint create heat-cfn public "http://${public_url}:8000/v1" --region ${region}
openstack endpoint create heat-cfn admin "http://${admin_url}:8004/v1/%(tenant_id)s" --region ${region}
openstack endpoint create heat-cfn internal "http://${internal_url}:8004/v1/%(tenant_id)s" --region ${region}

# Swift
openstack endpoint create swift public "http://${public_url}:8080/v1/AUTH_%(tenant_id)s" --region ${region}
openstack endpoint create swift admin "http://${admin_url}:8080/v1/AUTH_%(tenant_id)s" --region ${region}
openstack endpoint create swift internal "http://${internal_url}:8080/v1/AUTH_%(tenant_id)s" --region ${region}

openstack endpoint create swift_s3 public "http://${public_url}:8080" --region ${region}
openstack endpoint create swift_s3 admin "http://${admin_url}:8080" --region ${region}
openstack endpoint create swift_s3 internal "http://${internal_url}:8080" --region ${region}

# Glare
openstack endpoint create glare public "http://${public_url}:9494" --region ${region}
openstack endpoint create glare admin "http://${admin_url}:9494" --region ${region}
openstack endpoint create glare internal "http://${internal_url}:9494" --region ${region}

# Ceilometer
openstack endpoint create ceilometer public "http://${public_url}:8777" --region ${region}
openstack endpoint create ceilometer admin "http://${admin_url}:8777" --region ${region}
openstack endpoint create ceilometer internal "http://${internal_url}:8777" --region ${region}

#Aodh
openstack endpoint create aodh public "http://${public_url}:8042" --region ${region}
openstack endpoint create aodh admin "http://${admin_url}:8042" --region ${region}
openstack endpoint create aodh internal "http://${internal_url}:8042" --region ${region}
