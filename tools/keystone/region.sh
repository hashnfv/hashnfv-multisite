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

public_url=${NEW_PUBLIC_URL}
internal_url=${NEW_INTERNAL_URL}
admin_url=${NEW_ADMIN_URL}
region=${NEW_REGION}

# Nova
openstack endpoint create --publicurl "http://${public_url}:8774/v2.1" --adminurl "http://${admin_url}:8774/v2.1" --internalurl "http://${internal_url}:8774/v2.1" --region ${region} nova
openstack endpoint create --publicurl "http://${public_url}:8774/v2/%(tenant_id)s" --adminurl "http://${admin_url}:8774/v2/%(tenant_id)s" --internalurl "http://${internal_url}:8774/v2/%(tenant_id)s" --region ${region} compute_legacy
# Neutron
openstack endpoint create --publicurl "http://${public_url}:9696" --adminurl "http://${admin_url}:9696" --internalurl "http://${internal_url}:9696" --region ${region} neutron
# Cinder
openstack endpoint create --publicurl "http://${public_url}:8776/v1/%(tenant_id)s" --adminurl "http://${admin_url}:8776/v1/%(tenant_id)s" --internalurl "http://${internal_url}:8776/v1/%(tenant_id)s" --region ${region} cinder
openstack endpoint create --publicurl "http://${public_url}:8776/v2/%(tenant_id)s" --adminurl "http://${admin_url}:8776/v2/%(tenant_id)s" --internalurl "http://${internal_url}:8776/v2/%(tenant_id)s" --region ${region} cinderv2
openstack endpoint create --publicurl "http://${public_url}:8776/v3/%(tenant_id)s" --adminurl "http://${admin_url}:8776/v3/%(tenant_id)s" --internalurl "http://${internal_url}:8776/v3/%(tenant_id)s" --region ${region} cinderv3
# Glance
openstack endpoint create --publicurl "http://${public_url}:9292" --adminurl "http://${admin_url}:9292" --internalurl "http://${internal_url}:9292" --region ${region} glance
# Heat
openstack endpoint create --publicurl "http://${public_url}:8004/v1/%(tenant_id)s" --adminurl "http://${admin_url}:8004/v1/%(tenant_id)s" --internalurl "http://${internal_url}:8004/v1/%(tenant_id)s" --region ${region} heat
openstack endpoint create --publicurl "http://${public_url}:8000/v1" --adminurl "http://${admin_url}:8000/v1" --internalurl "http://${internal_url}:8000/v1" --region ${region} heat-cfn
# Swift
openstack endpoint create --publicurl "http://${public_url}:8080/swift/v1" --adminurl "http://${admin_url}:8080/swift/v1" --internalurl "http://${internal_url}:8080/swift/v1" --region ${region} swift
# Glare
openstack endpoint create --publicurl "http://${public_url}:9494" --adminurl "http://${admin_url}:9494" --internalurl "http://${internal_url}:9494" --region ${region} swift