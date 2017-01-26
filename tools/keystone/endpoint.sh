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

# Ensure that openrc containing OpenStack environment variables is present.
source openrc

# if running as part of Jenkins job, create the file in WORKSPACE
WORKSPACE=${WORKSPACE:-/root}
ENDPOINT_FILE="${WORKSPACE}/endpoints.ini"

# Endpoints. Dynamically get IP addresses from another service (keystone)
ENDPOINT_PUBLIC_URL=$(openstack endpoint list | grep keystone | grep public | cut -d '|' -f 8 | cut -d '/' -f 3 | cut -d ':' -f 1)
ENDPOINT_ADMIN_URL=$(openstack endpoint list | grep keystone | grep admin | cut -d '|' -f 8 | cut -d '/' -f 3 | cut -d ':' -f 1)
ENDPOINT_INTERNAL_URL=$(openstack endpoint list | grep keystone | grep internal | cut -d '|' -f 8 | cut -d '/' -f 3 | cut -d ':' -f 1)

cat <<EOT >> ${ENDPOINT_FILE}
[DEFAULT]
public_url=${ENDPOINT_PUBLIC_URL}
admin_url=${ENDPOINT_ADMIN_URL}
private_url=${ENDPOINT_INTERNAL_URL}
os_region=${OS_REGION}
EOT
