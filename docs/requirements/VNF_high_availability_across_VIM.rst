.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

=======================================
VNF high availability across VIM
=======================================

Problem description
===================

Abstract
------------

a VNF (telecom application) should, be able to realize high availability
deloyment across OpenStack instances.

Description
------------
VNF (Telecom application running over cloud) may (already) be designed as
Active-Standby/Active-Active/N-Way to achieve high availability,

With a telecoms focus, this generally refers both to availability of service
(i.e. the ability to make new calls), but also maintenance of ongoing control
plane state and active media processing(i.e. “keeping up” existing calls).

Traditionally telecoms systems are designed to maintain state and calls across
pretty much the full range of single-point failures.  As listed this includes
power supply, hard drive, physical server or network switch, but also covers
software failure, and maintenance operations such as software upgrade.

To provide this support, typically requires state replication between
application instances (directly or via replicated database services, or via
private designed message format).  It may also require special case handling of
media endpoints, to allow transfer of median short time scales (<1s) without
requiring end-to-end resignalling (e.g.RTP redirection via IP / MAC address
transfers c.f VRRP).

With a migration to NFV, a commonly expressed desire by carriers is to provide
the same resilience to any single point(s) of failure in the cloud
infrastructure.

This could be done by making each cloud instance fully HA (a non-trivial task to
do right and to prove it has been done right) , but the preferred approach
appears to be to accept the currently limited availability of a given cloud
instance (no desire to radically rework this for telecoms), and instead to
provide solution availability by spreading function across multiple cloud
instances (i.e. the same approach used today todeal with hardware and software
failures).

A further advantage of this approach, is it provides a good basis for seamless
upgrade of infrastructure software revision, where you can spin up an additional
up-level cloud, gradually transfer over resources / app instances from one of
your other clouds, before finally turning down the old cloud instance when no
longer required.

If fast media / control failure over is still required (which many/most carriers
still seem to believe it is) there are some interesting/hard requirements on the
networking between cloud instances. To help with this, many people appear
willing to provide multiple “independent” cloud instances in a single geographic
site, with special networking between clouds in that physical site.
"independent" in quotes is because some coordination between cloud instances is
obviously required, but this has to be implemented in a fashion which reduces
the potential for correlated failure to very low levels (at least as low as the
required overall application availability).

Analysis of requirements to OpenStack
===========================
The VNF often has different networking plane for different purpose:

external network plane: using for communication with other VNF
components inter-communication plane: one VNF often consisted of several
components, this plane is designed for components inter-communication with each
other
backup plance: this plane is used for the heart beat or state replication
between the component's active/standy or active/active or N-way cluster.
management plane: this plane is mainly for the management purpose

Generally these planes are seperated with each other. And for legacy telecom
application, each internal plane will have its fixed or flexsible IP addressing
plane.

to make the VNF can work with HA mode across different OpenStack instances in
one site (but not limited to), need to support at lease the backup plane across
different OpenStack instances:

1) Overlay L2 networking or shared L2 provider networks as the backup plance for
heartbeat or state replication. Overlay L2 network is preferred, the reason is:
a. Support legacy compatibility: Some telecom app with built-in internal L2
network, for easy to move these app to VNF, it would be better to provide L2
network b. Support IP overlapping: multiple VNFs may have overlaping IP address
for cross OpenStack instance networking
Therefore, over L2 networking across Neutron feature is required in OpenStack.

2) L3 networking cross OpenStack instance for heartbeat or state replication.
For L3 networking, we can leverage the floating IP provided in current Neutron,
so no new feature requirement to OpenStack.

3) The IP address used for VNF to connect with other VNFs should be able to be
floating cross OpenStack instance. For example, if the master failed, the IP
address should be used in the standby which is running in another OpenStack
instance. There are some method like VRRP/GARP etc can help the movement of the
external IP, so no new feature will be added to OpenStack.


Prototype
-----------
    None.

Proposed solution
-----------

    requirements perspective It's up to application descision to use L2 or L3
networking across Neutron.

    For Neutron, a L2 network is consisted of lots of ports. To make the cross
Neutron L2 networking is workable, we need some fake remote ports in local
Neutron to represent VMs in remote site ( remote OpenStack ).

    the fake remote port will reside on some VTEP ( for VxLAN ), the tunneling
IP address of the VTEP should be the attribute of the fake remote port, so that
the local port can forward packet to correct tunneling endpoint.

    the idea is to add one more ML2 mechnism driver to capture the fake remote
port CRUD( creation, retievement, update, delete)

    when a fake remote port is added/update/deleted, then the ML2 mechanism
driver for these fake ports will activate L2 population, so that the VTEP
tunneling endpoint information could be understood by other local ports.

    it's also required to be able to query the port's VTEP tunneling endpoint
information through Neutron API, in order to use these information to create
fake remote port in another Neutron.

    In the past, the port's VTEP ip address is the host IP where the VM resides.
But the this BP https://review.openstack.org/#/c/215409/ will make the port free
of binding to host IP as the tunneling endpoint, you can even specify L2GW ip
address as the tunneling endpoint.

    Therefore a new BP will be registered to processing the fake remote port, in
order make cross Neutron L2 networking is feasible. RFE is registered first:
https://bugs.launchpad.net/neutron/+bug/1484005


Gaps
====
    1) fake remote port for cross Neutron L2 networking


**NAME-THE-MODULE issues:**

* Neutron

Affected By
-----------
    OPNFV multisite cloud.

References
==========

