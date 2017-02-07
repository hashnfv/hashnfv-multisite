.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

==============================
 Multisite centralized service
==============================


Problem description
===================

Abstract
--------

a user should have one centralized service for resources management and/or
replication(sync tenant resources like images, ssh-keys, etc) across multiple
OpenStack clouds.

Description
------------

For multisite management use cases, some common requirements in term of
centralized or shared services over the multiple openstack instances could
be summarized here.

A user should be able to manage all their virtual resouces from one
centralized management interface, at least to have a summarized view of
the total resource capacity and the live utilization of their virtual
resources, for example:

- Centralized Quota Management
  Currently all quotas are set for each region separataly. And different
  services (Nova, Cinder, Neutron, Glance, ...) have different quota to
  be set. The requirement is to provide global view for quota per tenant
  across multiple regions, and soft/hard quotas based on current usage for
  all regions for this tenant.

- A service to clone ssh keys across regions
  A user may upload keypair to access the VMs allocated for her. But if her
  VMs are spread in multiple regions, the user has to upload the keypair
  seperatly to different region. Need a service to clone the SSH key to
  desired OpenStack clouds.

- A service to sync images across regions
  In multi-site scenario, a user has to upload image seperatly to different
  region. There can be 4 cases need to be considered:
      No image sync
      Auto-sync of images
      Lazy sync - clone the requested image on demand.
      Controlled sync, where you can control propagation and rollback if
      problems.

- Global view for tenant level IP address / mac address space management
  If a tenant has networks in multiple region, and these networks are routable
  (for example, connected with VPN), then, IP address may be duplicated. Need
  a global view for IP address space management.
  If IP v4 used, this issue needs to be considered. For IPv6, it should als
  be managed. This requirement is important not only just for prevention of
  duplicate address.
  For security and other reasons it's important to know which IP Addresses
  (IPv4 and IPv6) are used in which region.
  Need to extend such requirement to floating and public IP Addresses.

- A service to clone security groups across regions
  No appropriate service to security groups across multiple region if the
  tenant has resources distributed, has to set the security groups in
  different region manually.

- A user should be able to access all the logs and indicators produced by
  multiple openstack instances, in a centralized way.

Requirement analysis
====================

All problems me here are not covered by existing projects in OpenStack.

Candidate solution analysis
---------------------------

- Kingbird[1][2]
  Kingbird is an centralized OpenStack service that provides resource
  operation and management across multiple OpenStack instances in a
  multi-region OpenStack deployment. Kingbird provides features like
  centralized quota management, centralized view for distributed virtual
  resources, synchronisation of ssh keys, images, flavors etc. across regions.

- Tricircle[3][4]
  Tricricle is to provide networking automation across Neutron in multi-region
  OpenStack deployments. Tricircle can address the challenges mentioned here:
  Tenant level IP/mac addresses management to avoid conflict across OpenStack
  clouds, global L2 network segement management and cross OpenStack L2
  networking, and make security group being sync-ed across OpenStack clouds.


Affected By
-----------
  OPNFV multisite cloud.

Conclusion
----------
  Kingbird and Tricircle are candidate solutions for these centralized
  services in OpenStack multi-region clouds.

References
==========
[1] Kingbird repository: https://github.com/openstack/kingbird
[2] Kingbird launchpad: https://launchpad.net/kingbird
[3] Tricricle wiki: https://wiki.openstack.org/wiki/Tricircle
[4] Tricircle repository: https://github.com/openstack/tricircle/
