.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

=======================================
 Multisite identity service management
=======================================

Glossary
========

There are 3 types of token supported by OpenStack KeyStone
    **UUID**

    **PKI/PKIZ**

    **FERNET**

Please refer to reference section for these token formats, benchmark and
comparation.


Problem description
===================

Abstract
------------

a user should, using a single authentication point be able to manage virtual
resources spread over multiple OpenStack regions.

Description
------------

- User/Group Management: e.g. use of LDAP, should OPNFV be agnostic to this?
  Reusing the LDAP infrastructure that is mature and has features lacking in
Keystone (e.g.password aging and policies). KeyStone can use external system to
do the user authentication, and user/group management could be the job of
external system, so that KeyStone can reuse/co-work with enterprise identity
management. KeyStone's main role in OpenStack is to provide
service(Nova,Cinder...) aware token, and do the authorization. You can refer to
this post https://blog-nkinder.rhcloud.com/?p=130.Therefore, LDAP itself should
be a topic out of our scope.

- Role assignment: In case of federation(and perhaps other solutions) it is not
  feasible/scalable to do role assignment to users. Role assignment to groups
  is better. Role assignment will be done usually based on group. KeyStone
  supports this.

- Amount of inter region traffic: should be kept as little as possible,
  consider CERNs Ceilometer issue as described in
http://openstack-in-production.blogspot.se/2014/03/cern-cloud-architecture-update-for.html

Requirement analysis
===========================

- A user is provided with a single authentication URL to the Identity
  (Keystone) service. Using that URL, the user authenticates with Keystone by
requesting a token typically using username/password credentials. The keystone
server validates the credentials, possibly with an external LDAP/AD server and
returns a token to the user. With token type UUID/Fernet, the user request the
service catalog. With PKI tokens the service catalog is included in the token.
The user sends a request to a service in a selected region including the token.
Now the service in the region, say Nova needs to validate the token. Nova uses
its configured keystone endpoint and service credentials to request token
validation from Keystone. The Keystone token validation should preferably be
done in the same region as Nova itself. Now Keystone has to validate the token
that also (always?) includes a project ID in order to make sure the user is
authorized to use Nova. The project ID is stored in the assignment backend -
tables in the Keystone SQL database. For this project ID validation the
assignment backend database needs to have the same content as the keystone who
issued the token.

- So either 1) services in all regions are configured with a central keystone
  endpoint through which all token validations will happen. or 2) the Keystone
assignment backend database is replicated and thus available to Keystone
instances locally in each region.

  Alt 2) is obviously the only scalable solution that produce no inter region
traffic for normal service usage. Only when data in the assignment backend is
changed, replication traffic will be sent between regions. Assignment data
includes domains, projects, roles and role assignments.

Keystone deployment:

    - Centralized: a single Keystone service installed in some location, either
      in a "master" region or totally external as a service to OpenStack
      regions.
    - Distributed: a Keystone service is deployed in each region

Token types:

    - UUID: tokens are persistently stored and creates a lot of database
      traffic, the persistence of token is for the revoke purpose. UUID tokens
are online validated by Keystone, each API calling to service will ask token
validation from KeyStone. Keystone can become a bottleneck in a large system
due to this. UUID token type is not suitable for use in multi region clouds at
all, no matter the solution used for the Keystone database replication (or
not). UUID tokens have a fixed size.

    - PKI: tokens are non persistent cryptographic based tokens and offline
      validated (not by the Keystone service) by Keystone middleware
which is part of other services such as Nova. Since PKI tokens include endpoint
for all services in all regions, the token size can become big.There are
several ways to reduce the token size, no catalog policy, endpoint filter to
make a project binding with limited endpoints, and compressed PKI token - PKIZ,
but the size of token is still predictable, make it difficult to manage. If no
catalog applied, that means the user can access all regions, in some scenario,
it's not allowed to do like this.

    - Fernet: tokens are non persistent cryptographic based tokens and online
      validated by the Keystone service. Fernet tokens are more lightweigth
then PKI tokens and have a fixed size.

    PKI (offline validated) are needed with a centralized Keystone to avoid
inter region traffic. PKI tokens do produce Keystone traffic for revocation
lists.

    Fernet tokens requires Keystone deployed in a distributed manner, again to
avoid inter region traffic.

    Cryptographic tokens brings new (compared to UUID tokens) issues/use-cases
like key rotation, certificate revocation. Key management is out of scope of
this use case.

Database deployment:

    Database replication:
    -Master/slave asynchronous: supported by the database server itself
(mysql/mariadb etc), works over WAN, it's more scalable
    -Multi master synchronous: Galera(others like percona), not so scalable,
for multi-master writing, and need more parameter tunning for WAN latency.
    -Symmetrical/asymmetrical: data replicated to all regions or a subset,
in the latter case it means some regions needs to access Keystone in another
region.

    Database server sharing:
    In an OpenStack controller normally many databases from different
services are provided from the same database server instance. For HA reasons,
the database server is usually synchronously replicated to a few other nodes
(controllers) to form a cluster. Note that _all_ database are replicated in
this case, for example when Galera sync repl is used.

    Only the Keystone database can be replicated to other sites. Replicating
databases for other services will cause those services to get of out sync and
malfunction.

    Since only the Keystone database is to be sync replicated to another
region/site, it's better to deploy Keystone database into its own
database server with extra networking requirement, cluster or replication
configuration. How to support this by installer is out of scope.

    The database server can be shared when async master/slave repl is used, if
global transaction identifiers GTID is enabled.


Candidate solution analysis
------------------------------------

-  KeyStone service (Distributed) with Fernet token

    Fernet token is a very new format, and just introduced recently,the biggest
gain for this token format is :1) lightweight, size is small to be carried in
the API request, not like PKI token( as the sites increased, the endpoint-list
will grows  and the token size is too long to carry in the API request) 2) no
token persistence, this also make the DB not changed too much and with light
weight data size (just project. User, domain, endpoint etc). The drawback for
the Fernet token is that token has to be validated by KeyStone for each API
request.

    This makes that the DB of KeyStone can work as a cluster in multisite (for
example, using MySQL galera cluster). That means install KeyStone API server in
each site, but share the same the backend DB cluster.Because the DB cluster
will synchronize data in real time to multisite, all KeyStone server can see
the same data.

    Because each site with KeyStone installed, and all data kept same,
therefore all token validation could be done locally in the same site.

    The challenge for this solution is how many sites the DB cluster can
support. Question is aksed to MySQL galera developers, their answer is that no
number/distance/network latency limitation in the code. But in the practice,
they have seen a case to use MySQL cluster in 5 data centers, each data centers
with 3 nodes.

    This solution will be very good for limited sites which the DB cluster can
cover very well.

-  KeyStone service(Distributed) with Fernet token + Async replication (
   multi-cluster mode).

    We may have several KeyStone cluster with Fernet token, for example,
cluster1 ( site1, site2, … site 10 ), cluster 2 ( site11, site 12,..,site 20).
Then do the DB async replication among different cluster asynchronously.

    A prototype of this has been down on this. In some blogs they call it
"hybridreplication". Architecturally you have a master region where you do
keystone writes. The other regions is read-only.
http://severalnines.com/blog/deploy-asynchronous-slave-galera-mysql-easy-way
http://severalnines.com/blog/replicate-mysql-server-galera-cluster

    Only one DB cluster (the master DB cluster) is allowed to write(but still
multisite, not all sites), other clusters waiting for replication. Inside the
master cluster, "write" is allowed in multiple region for the distributed lock
in the DB. But please notice the challenge of key distribution and rotation for
Fernet token, you can refer to these two blogs: http://lbragstad.com/?p=133,
http://lbragstad.com/?p=156

-  KeyStone service(Distributed) with Fernet token + Async replication (
   star-mode).

    one master KeyStone cluster with Fernet token in two sites (for site level
high availability purpose), other sites will be installed with at least 2 slave
nodes where the node is configured with DB async replication from the master
cluster members, and one slave’s mater node in site1, another slave’s master
node in site 2.

    Only the master cluster nodes are allowed to write,  other slave nodes
waiting for replication from the master cluster ( very little delay) member.
But  the chanllenge of key distribution and rotation for Fernet token should be
settled, you can refer to these two blogs: http://lbragstad.com/?p=133,
http://lbragstad.com/?p=156

    Pros.
    Why cluster in the master sites? There are lots of master nodes in the
cluster, in order to provide more slaves could be done with async. replication
in parallel.  Why two sites for the master cluster? to provide higher
reliability (site level) for writing request.
    Why using multi-slaves in other sites. Slave has no knowledge of other
slaves, so easy to manage multi-slaves in one site than a cluster, and
multi-slaves work independently but provide multi-instance redundancy(like a
cluster, but independent).

    Cons. The distribution/rotation of key management.

-  KeyStone service(Distributed) with PKI token

    The PKI token has one great advantage is that the token validation can be
done locally, without sending token validation request toKeyStone server. The
drawback of PKI token is 1) the endpoint list size in the token. If a project
will be only spread in very limited site number(region number), then we can use
the endpoint filter to reduce the token size, make it workable even a lot of
sites in the cloud. 2) KeyStone middleware(the old KeyStone client, which
co-locate in Nova/xxx-API) will have to send the request to the KeyStone server
frequently for the revoke-list, in order to reject some malicious API request,
for example, a user has be deactivated, but use an old token to access
OpenStack service.

    For this solution, except above issues, we need also to provide KeyStone
Active-Active mode across site to reduce the impact of site failure. And the
revoke-list request is very frequently asked, so the performance of the
KeyStone server needs also to be taken care.

    Site level keystone load balance is required to provide site level
redundancy. Otherwise the KeyStone middleware will not switch request to the
health KeyStone server in time.

    This solution can be used for some scenario, especially a project only
spread in limited sites ( regions ).

    And also the cert distribution/revoke to each site / API server for token
validation is required.

-  KeyStone service(Distributed) with UUID token

    Because each token validation will be sent to KeyStone server,and the token
persistence also makes the DB size larger than Fernet token, not so good as the
fernet token to provide a distributed KeyStone service. UUID is a solution
better for small scale and inside one site.

    Cons: UUID tokens are persistently stored so will cause a lot of inter
region replication traffic, tokens will be persisted for authorization and
revoke purpose, the frequent changed database leads to a lot of inter region
replication traffic.

-  KeyStone service(Distributed) with Fernet token + KeyStone federation You
    have to accept the drawback of KeyStone federation if you have a lot of
sites/regions. Please refer to KeyStone federation section

-  KeyStone federation
    In this solution, we can install KeyStone  service in each site and with
its own database. Because we have to make the KeyStone IdP and SP know each
other, therefore the configuration needs to be done accordingly, and setup the
role/domain/group mapping, create regarding region in the pair.As sites
increase, if each user is able to access all sites, then full-meshed
mapping/configuration has to be done. Whenever you add one more site, you have
to do n*(n-1) sites configuration/mapping. The complexity will be great enough
as the sites number increase.

    KeyStone Federation is mainly for different cloud admin to borrow/rent
resources, for example, A company and B company, A private cloud and B public
cloud, and both of them using OpenStack based cloud. Therefore a lot of mapping
and configuration has to be done to make it work.

-  KeyStone service (Centralized)with Fernet token

    cons: inter region traffic for token validation, token validation requests
from all other sites has to be sent to the centralized site. Too frequent inter
region traffic.

-  KeyStone service(Centralized) with PKI token

    cons: inter region traffic for tokenrevocation list management, the token
revocation list request from all other sites has to be sent to the centralized
site. Too frequent inter region traffic.

-  KeyStone service(Centralized) with UUID token

    cons: inter region traffic for token validation, the token validation
request from all other sites has to be sent to the centralized site. Too
frequent inter region traffic.

Prototype
-----------
    A prototype of the candidate solution "KeyStone service(Distributed) with
Fernet token + Async replication ( multi-cluster mode)" has been executed Hans
Feldt and Chaoyi Huang, please refer to https://github.com/hafe/dockers/ . And
one issue was found "Can't specify identity endpoint for token validation among
several keystone servers in keystonemiddleware", please refer to the Gaps
section.

Gaps
====
    Can't specify identity endpoint for token validation among several keystone
servers in keystonemiddleware.


**NAME-THE-MODULE issues:**

* keystonemiddleware

  * Can't specify identity endpoint for token validation among several keystone
  * servers in keystonemiddleware:
  * https://bugs.launchpad.net/keystone/+bug/1488347

Affected By
-----------
    OPNFV multisite cloud.

Conclusion
-----------

    As the prototype demonstrate the cluster level aysn. replication capability
and fernet token validation in local site is feasible. And the candidate
solution "KeyStone service(Distributed) with Fernet token + Async replication (
star-mode)" is simplified solution of the prototyped one, it's much more easier
in deployment and maintenance, with better scalability.

    Therefore the candidate solution "KeyStone service(Distributed) with Fernet
token + Async replication ( star-mode)" for multsite OPNFV cloud is
recommended.

References
==========

    There are 3 format token (UUID, PKI/PKIZ, Fernet) provided byKeyStone, this
blog give a very good description, benchmark and comparation:
    http://dolphm.com/the-anatomy-of-openstack-keystone-token-formats/
    http://dolphm.com/benchmarking-openstack-keystone-token-formats/

    To understand the benefit and shortage of PKI/PKIZ token, pleaserefer to :
    https://www.mirantis.com/blog/understanding-openstack-authentication-keystone-pk

    To understand KeyStone federation and how to use it:
    http://blog.rodrigods.com/playing-with-keystone-to-keystone-federation/

    To integrate KeyStone with external enterprise ready authentication system
    https://blog-nkinder.rhcloud.com/?p=130.

    Key repliocation used in KeyStone Fernet token
    http://lbragstad.com/?p=133,
    http://lbragstad.com/?p=156

    KeyStone revoke
    http://specs.openstack.org/openstack/keystone-specs/api/v3/identity-api-v3-os-revoke-ext.html
