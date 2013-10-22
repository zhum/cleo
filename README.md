cleo
====

  Cleo is tasks manager for computational clusters. It is written by
Sergey Zhumatiy (serg@parallel.ru) in SRCC MSU.

  Cleo is licensed by GPL2. You should register on
http://parcon.parallel.ru/cleo.html for FREE.


INSTALLATION:
=============

  1. You must have perl 5.6 or higher installed on all nodes and head node.
You also must have installe perl modules Storable, Fcntl, POSIX, Time and IO.

  2. To correct work you should convert system include files into perl format.
This may be already is done by your Linux distributive or not. If not, you
can use this command: cd /usr/include; h2ph -r -l . (on each node).

     If it fails on some file, simply move this file into /tmp. Remember source
directory! Run h2ph again. After successfull h2ph move failed include files back.

  3. You can edit Makefile.conf to correct target directories of Cleo and
nodes names for authomatic copying Cleo agent to nodes. For authomatic
copying you must have passworless ssh configured.

  4. If you are upgrading from Cleo version 4 on lesser, you must run 'make compatible'.

  5. If you want to save Cleo version 4 files, run 'make backup'.

  6. !!! IMPORTANT !!!
     Save your original mpirun command, if it is localted in $CLEO_BASE/bin directory.
E.g. in /usr/local/bin. You can save it by running cp /usr/local/bin/mpirun /usr/local/bin/mpirun.original


  7. Run 'make', then 'make install'.

  8. If you did not use automatic copying to nodes, then you can copy agent
files:
     $(BINDIR)/cleo-mon to the same directory on nodes,
     $(SHARE_DIR)/Cleo/conn.pm to the same directory on nodes,
     /etc/init.d/cleo-mon.rc to /etc/init.d/cleo-mon on nodes.

  9. To make Cleo agents start automatically, create symlinks from
/etc/init.d/cleo-mon to /etc/rc3.d or /etc/init.d/rc3.d.
  If your distributive supports chkconfig, you can run
  chkconfig -a cleo-mon
  Make it on all nodes.

  10. To make cleo server start automatically, make symlink from
/etc/init.d/cleo.rc as in 9. Or run chkconfig -a cleo.rc.
This must be done only on head node.

  Now you must copy /etc/cleo.conf.example (or another example config) to
/etc/cleo.conf ant edit it for your config. Quick reference about config
file you can find in README.conf

  Then you can start agents on nodes by command /etc/init.d/cleo-mon start,
and server on head node by command /etc/init.d/cleo.rc start.


FINE TUNING
===========

  You can change or add your modules and scedulers to Cleo. Read
README-sceduler-create to information about scedulers. You can
use example-sceduler and base_sceduler files for starting.

  On most system events, such as start task or task end, Cleo can
execute custom modules methods. E.g. you can copy several files to
node local filesystem before task start. Read Modules-howto for
custom modules information.

