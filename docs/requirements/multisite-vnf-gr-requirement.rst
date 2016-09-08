.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

=========================================
 Multisite VNF Geo site disaster recovery
=========================================

Glossary
========


There are serveral concept required to be understood first
    **Volume Snapshot**

    **Volume Backup**

    **Volume Replication**

    **VM Snapshot**

Please refer to reference section for these concept and comparison.


Problem description
===================

Abstract
------------

a VNF (telecom application) should, be able to restore in another site for
catastrophic failures happened.

Description
------------
GR is to deal with more catastrophic failures (flood, earthquake, propagating
software fault), and that loss of calls, or even temporary loss of service,
is acceptable. It is also seems more common to accept/expect manual /
administrator intervene into drive the process, not least because you don’t
want to trigger the transfer by mistake.

In terms of coordination/replication or backup/restore between geographic
sites, discussion often (but not always) seems to focus on limited application
level data/config replication, as opposed to replication backup/restore between
of cloud infrastructure between different sites.

And finally, the lack of a requirement to do fast media transfer (without
resignalling) generally removes the need for special networking behavior, with
slower DNS-style redirection being acceptable.

This use case is more concerns about cloud infrastructure level capability to
support VNF geo site redundancy

Requirement and candidate solutions analysis
============================================

For VNF to be restored from the backup site for catastrophic failures,
the VNF's bootable volume and data volumes must be restorable.

There are three ways of restorable boot and data volumes. Choosing the right
one largely depends on the underlying characteristics and requirements of a
VNF.

1. Nova Quiesce + Cinder Consistency volume snapshot+ Cinder backup
   1).GR(Geo site disaster recovery )software get the volumes for each VM
   in the VNF from Nova
   2).GR software call Nova quiesce API to quarantee quiecing VMs in desired
   order
   3).GR software takes snapshots of these volumes in Cinder (NOTE: Because
   storage often provides fast snapshot, so the duration between quiece and
   unquiece is a short interval)
   4).GR software call Nova unquiece API to unquiece VMs of the VNF in reverse
   order
   5).GR software create volumes from the snapshots just taken in Cinder
   6).GR software create backup (incremental) for these volumes to remote
   backup storage ( swift or ceph, or.. ) in Cinder
   7).if this site failed,
   7.1)GR software restore these backup volumes in remote Cinder in the
   backup site.
   7.2)GR software boot VMs from bootable volumes from the remote Cinder in
   the backup site and attach the regarding data volumes.

Pros: Quiesce / unquiesce api from Nova, make transactional snapshot
of a group of VMs is possible, for example, quiesce VM1, quiesce VM2,
quiesce VM3, snapshot VM1's volumes, snapshot VM2's volumes, snapshot
VM3's volumes, unquiesce VM3, unquiesce VM2, unquiesce VM1. For some
telecom application, the order is very important for a group of VMs
with strong relationship.

Cons: Need Nova to expose the quiesce / unquiesce, fortunately it's alreay
there in Nova-compute, just to add API layer to expose the functionality.
NOTE: It's up to the DR policy and VNF character. Some VNF may afford short
unavailable for DR purpose, and some other may use the standby of the VNF
or member of the cluster to do disaster recovery replication to not interfere
the service provided by the VNF. For these VNFs which can't be quieced/unquiece
should use the option3 (VNF aware) to do the backup/replication.

Requirement to OpenStack: Nova needs to expose quiesce / unquiesce api,
which is lack in Nova now.

Example characteristics and requirements of a VNF:
    - VNF requires full data consistency during backup/restore process -
      entire data should be replicated.
    - VNF's data changes infrequently, which results in less number of volume
      snapshots during a given time interval (hour, day, etc.);
    - VNF is not highly dynamic, e.g. the number of scaling (in/out) operations
      is small.
    - VNF is not geo-redundant, does not aware of available cloud replication
      mechanisms, has no built-in logic for replication: doesn't pre-select the
      minimum replication data required for restarting the VNF in a different
      site.
      (NOTE: The VNF who can perform such data cherry picking should consider
      case 3)

2. Nova Snapshot + Glance Image + Cinder Snapshot + Cinder Backup
    - GR software create VM snapshot in Nova
    - Nova quiece the VM internally
      (NOTE: The upper level application or GR software should take care of
      avoiding infra level outage induced VNF outage)
    - Nova create image in Glance
    - Nova create a snapshot of the VM, including volumes
    - If the VM is volume backed VM, then create volume snapshot in Cinder
    - No image uploaded to glance, but add the snapshot in the meta data of the
      image in Glance
    - GR software to get the snapshot information from the Glance
    - GR software create volumes from these snapshots
    - GR software create  backup (incremental) for these volumes to backup
      storage( swift or ceph, or.. ) in Cinder if this site failed,
    - GR software restore these backup volumes to Cinder in the backup site.
    - GR software boot vm from bootable volume from Cinder in the backup site
      and attach the data volumes.

Pros: 1) Automatically quiesce/unquiesce, and snapshot of volumes of one VM.

Cons: 1) Impossible to form a transactional group of VMs backup.  for example,
         quiesce VM1, quiesce VM2, quiesce VM3, snapshot VM1, snapshot VM2,
         snapshot VM3, unquiesce VM3, unquiesce VM2, unquiesce VM1. This is
         quite important in telecom application in some scenario
      2) not leverage the Cinder consistency group.
      3) One more service Glance involved in the backup. Not only to manage the
         increased snapshot in Cinder, but also need to manage the regarding
         temporary image in Glance.

Requirement to OpenStack: None.

Example: It's suitable for single VM backup/restore, for example, for the small
scale configuration database virtual machine which is running in active/standby
model. There is very rare use case for application that only one VM need to be
taken snapshot for back up.

3. Selective Replication of Persistent Data
    - GR software creates datastore (Block/Cinder, Object/Swift, App Custom
      storage) with replication enabled at the relevant scope, for use to
      selectively backup/replicate desire data to GR backup site
       - Cinder : Various work underway to provide async replication of cinder
         volumes for disaster recovery use, including this presentation from
         Vancouver http://www.slideshare.net/SeanCohen/dude-wheres-my-volume-open-stack-summit-vancouver-2015
       - Swift : Range of options of using native Swift replicas (at expense of
         tighter coupling) to replication using backend plugins or volume
         replication
       - Custom : A wide range of OpenSource technologies including Cassandra
         and Ceph, with fully application level solutions also possible
    - GR software get the reference of storage in the remote site storage
    - If primary site failed,
       - GR software managing recovery in backup site gets references to
         relevant storage and passes to new software instances
       - Software attaches (or has attached) replicated storage, in the case of
         volumes promoting to writable.

Pros:  1) Replication will be done in the storage level automatically, no need
          to create backup regularly, for example, daily.
       2) Application selection of limited amount of data to replicate reduces
          risk of replicating failed state and generates less overhear.
       3) Type of replication and model (active/backup, active/active, etc) can
          be tailored to application needs

Cons:  1) Applications need to be designed with support in mind, including both
          selection of data to be replicated and consideration of consistency
       2) "Standard" support in Openstack for Disaster Recovery currently
          fairly limited, though active work in this area.

Requirement to OpenStack: save the real ref to volume admin_metadata after it
has been managed by the driver    https://review.openstack.org/#/c/182150/.

Prototype
-----------
    None.

Proposed solution
-----------

    requirements perspective we could recommend all three options for different
    sceanrio, that it is an operator choice.
    Options 1 & 2 seem to be more about replicating/backing up any VNF, whereas
    option 3 is about proving a service to a replication aware application. It
    should be noted that HA requirement is not a priority here, HA for VNF
    project will handle the specific HA requirement. It should also be noted
    that it's up to specific application how to do HA (out of scope here).
    For the 3rd option, the app should know which volume has replication
    capability, and write regarding data to this volume, and guarantee
    consistency by the app itself. Option 3 is preferrable in HA scenario.


Gaps
====
    1) Nova to expose quiesce / unquiesce API:
       https://blueprints.launchpad.net/nova/+spec/expose-quiesce-unquiesce-api
    2)  Get the real ref to volume admin_metadata in Cinder:
       https://review.openstack.org/#/c/182150/


**NAME-THE-MODULE issues:**

* Nova

Affected By
-----------
    OPNFV multisite cloud.

References
==========

   Cinder snapshot ( no material/BP about snapshot itself availble from web )
   http://docs.openstack.org/cli-reference/content/cinderclient_commands.html


   Cinder volume backup
   https://blueprints.launchpad.net/cinder/+spec/volume-backups

   Cinder incremtal backup
   https://blueprints.launchpad.net/cinder/+spec/incremental-backup

   Cinder volume replication
   https://blueprints.launchpad.net/cinder/+spec/volume-replication

    Create VM snapshot with volume backed ( not found better matrial to explain
    the volume backed VM snapshot, only code tells )
    https://bugs.launchpad.net/nova/+bug/1322195

    Cinder consistency group
    https://github.com/openstack/cinder-specs/blob/master/specs/juno/consistency-groups.rst
