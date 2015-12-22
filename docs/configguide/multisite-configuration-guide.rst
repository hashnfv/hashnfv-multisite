.. two dots create a comment. please leave this logo at the top of each of your rst files.
.. image:: ../etc/opnfv-logo.png
  :height: 40
  :width: 200
  :alt: OPNFV
  :align: left
.. these two pipes are to seperate the logo from the first title
|
|
=============================
Multisite configuration guide
=============================

Multisite identity service management
=====================================

Goal
----

a user should, using a single authentication point be able to manage virtual
resources spread over multiple OpenStack regions.

Before you read
---------------

This chapter does not intend to cover all configuration of KeyStone and other
OpenStack services to work together with KeyStone.

This chapter focuses only on the configuration part should be taken into
account in multi-site scenario.

Please read the configuration documentation related to identity management
of OpenStack for all configuration items.

http://docs.openstack.org/liberty/config-reference/content/ch_configuring-openstack-identity.html

How to configure the database cluster for synchronization or asynchrounous
repliation in multi-site scenario is out of scope of this document. The only
remainder is that for the synchronization or replication, only Keystone
database is required. If you are using MySQL, you can configure like this:

In the master:

   .. code-block:: bash

      binlog-do-db=keystone

In the slave:

   .. code-block:: bash

      replicate-do-db=keystone


Deployment options
------------------

For each detail description of each deployment option, please refer to the
admin-user-guide.

-  Distributed KeyStone service with PKI token

   In KeyStone configuration file, PKI token format should be configured

   .. code-block:: bash

      provider = pki

   or

   .. code-block:: bash

      provider = pkiz

   In the [keystone_authtoken] section of each OpenStack service configuration
   file in each site, configure the identity_url and auth_uri to the address
   of KeyStone service

   .. code-block:: bash

      identity_uri = https://keystone.your.com:35357/
      auth_uri = http://keystone.your.com:5000/v2.0

   It's better to use domain name for the KeyStone service, but not to use IP
   address directly, especially if you deployed KeyStone service in at least
   two sites for site level high availability.

-  Distributed KeyStone service with Fernet token
-  Distributed KeyStone service with Fernet token + Async replication (
   star-mode).

   In these two deployment options, the token validation is planned to be done
   in local site.

   In KeyStone configuration file, Fernet token format should be configured

   .. code-block:: bash

      provider = fernet

   In the [keystone_authtoken] section of each OpenStack service configuration
   file in each site, configure the identity_url and auth_uri to the address
   of local KeyStone service

   .. code-block:: bash

      identity_uri = https://local-keystone.your.com:35357/
      auth_uri = http://local-keystone.your.com:5000/v2.0

   and especially, configure the region_name to your local region name, for
   example, if you are configuring services in RegionOne, and there is local
   KeyStone service in RegionOne, then

   .. code-block:: bash

      region_name = RegionOne

Revision: _sha1_

Build date: |today|
