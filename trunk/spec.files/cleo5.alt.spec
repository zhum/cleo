Summary: Cleo batch system. Server part.
Name: cleo-server
Version: 5.23c
Release: alt1
License: GPL
Group: System/Servers
Source: cleo-%{version}.tgz

%define _perl_lib_path %_libexecdir/cleo
%define _mpi_group mpi

# Automatically added by buildreq on Thu Mar 13 2008 (-bi)
BuildRequires: fakeroot perl-Storable perl4-compat

%description
  Cleo is the batch system for computing clusters. This package contains
server components, default scheduler and base client programs.


%package -n cleo-agent
Summary: Cleo batch system. Agent part.
Group: System/Servers

%description -n cleo-agent
  Cleo is the batch system for computing clusters. This package contains
host agent components.

%package -n cleo-common
Summary: Cleo batch system. Common files.
Group: System/Servers

%description -n cleo-common
  Cleo is the batch system for computing clusters. This package contains
files, used by all cleo components.

%pre
/usr/sbin/groupadd -r -f %_mpi_group ||:

%prep
%setup -q -n cleo-%version
#%%patch0 -p1
#%%patch1 -p1

%build
mv cleo.rc-alt cleo.rc
mv cleo-mon.rc-alt cleo-mon.rc
make RCDIR=%_initdir CHECK=no

%install
fakeroot make DESTDIR=%buildroot RCDIR=%_initdir CHECK=no install \
	{,MAN}USER=root {,MAN}GROUP=root


%files -n cleo-server
%doc README COPYING
#%%doc cleo-%version/man/ant-mon.1
%_sbindir/cleo

%config %attr(0644,root,root) /etc/cleo.conf

#/etc/sysconfig/cleo
%_initdir/cleo
%_sbindir/cleo-mode
%_bindir/cleo-autoblock
%_bindir/cleo-blockcpu
%_bindir/cleo-blocktask
%_bindir/cleo-client
%_bindir/cleo-priority
%_bindir/cleo-stat
%_bindir/cleo-reporter
%_bindir/cleo-terminal
%_bindir/cleo-freeze
%_bindir/qsub-cleo
%_bindir/qstat-cleo
%_bindir/qdel-cleo
%_docdir/cleo/cleo.conf.example
%_docdir/cleo/cleo.conf.example-mpich
%_docdir/cleo/cleo.conf.example-mvs
%_docdir/cleo/cleo.conf.example-sci
%_docdir/cleo/example-scheduler
%_perl_lib_path/cleosupport.pm
%_perl_lib_path/cleovars.pm
%_perl_lib_path/base_sched
%_perl_lib_path/listfile_mod
%attr(0745,root,%_mpi_group) %_bindir/mpirun
%attr(0755,root,%_mpi_group) %_bindir/cleo-submit
%_bindir/tasks
%_mandir/man1/cleo-autoblock.1.gz
%_mandir/man1/cleo-blockcpu.1.gz
%_mandir/man1/cleo-blocktask.1.gz
%_mandir/man1/cleo-mode.1.gz
%_mandir/man1/cleo-freeze.1.gz
%_mandir/man1/cleo-priority.1.gz
%_mandir/man1/mpirun.1.gz
%_mandir/man1/tasks.1.gz

%_docdir/cleo/Admguide.pdf
%_docdir/cleo/CleoOptions.doc
%_docdir/cleo/Extern-shuffle.txt
%_docdir/cleo/LICENSE
%_docdir/cleo/COPYING
%_docdir/cleo/Modules-howto
%_docdir/cleo/README
%_docdir/cleo/README-listfile
%_docdir/cleo/README-empty
%_docdir/cleo/README-scheduler-create
%_docdir/cleo/doubler_sched

%files -n cleo-agent
%_initdir/cleo-mon
%_sbindir/cleo-mon

%files -n cleo-common
%_perl_lib_path/Cleo/Conn.pm
%_perl_lib_path/Cleo/State.pm
%_bindir/empty-cleo
%_bindir/cleo-wrapper

%changelog
* Mon Aug 16 2010 Sergey Zhumatiy <zhum@altlinux.org> 5.24b-alt1
- POSIX support added
- statistics improved
- rerun fully implemented

* Mon Sep 21 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.23b-alt1
- file close hooks added

* Wed Jun 23 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.22b-alt1
- rerun on bad start implemented
- fixed reopen log bug
- empty much cpu consumption fixed

* Wed May 06 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.22a-alt1
- reopen logs fixed
- extra cpus are taken in account as used cpus now
- tasks accepts attributes now
- agent restarts after some (3 by default) critical errors
- cleosupport: count_runned func is added
- all cleo parameters is passed to any executed program via CLEO_* vars
- extra cpus are printes as used in 'tasks'

* Thu Dec 18 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.20a-alt1
- fixed ugly logrotate bug
- hopely fixed misworked attaching to new task processes

* Thu Oct 09 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13b-alt1
- incorrect task processes attaching fixed

* Mon Sep 22 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13a-alt2
- cleo-blockcpu fixed

* Fri Aug 22 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13a-alt1
- cpu-per-hour limit added

* Thu Jul 24 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12c-alt4
- Logrotate added
- Unique task identificators initially added

* Tue Mar 25 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12-alt3
- Compatibility dependencies added

* Mon Mar 24 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12-alt2
- Minor optimizations

* Thu Mar 13 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12-alt1
- Initial build
