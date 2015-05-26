Summary: Cleo batch system. Server part.
Name: cleo-server
Version: 5.30c
Release: 1
License: GPL
Group: Network Servers
Source: cleo-%{version}.tgz
BuildRoot: /tmp/%{name}-%{version}
BuildRequires: gcc, glibc-devel, make
Requires: perl-MailTools, perl-Authen-PAM, perl-XML-Writer

%define wwwgroup www-data
%define wwwuser www-data

%if 0%{?fedora_version} || 0%{?centos_version} || 0%{?rhel_version} || 0%{?fedora} || 0%{?rhel}
BuildRequires: shadow-utils, httpd
%define wwwgroup apache
%define wwwuser apache
%define wwwroot /var/www/
%define cgiroot /var/www/cgi-bin
%endif

%if 0%{?suse_version}
BuildRequires:  pwdutils, apache2
%define wwwgroup wwwrun
%define wwwuser wwwrun
%define wwwroot /var/www/
%define cgiroot /var/www/cgi-bin
%endif


%define buildroot /tmp/%{name}-%{version}
%define perl_lib_path %_libexecdir/cleo
%define libroot /var/lib/cleo-viz
%define _initdir /etc/init.d
%define _mpi_group mpi

%description
  Cleo is the batch system for computing clusters. This package contains
server components, default scheduler and base client programs.


%package -n cleo-agent
Summary: Cleo batch system. Agent part.
Group: Network Servers

%description -n cleo-agent
  Cleo is the batch system for computing clusters. This package contains
host agent components.

%package -n cleo-common
Summary: Cleo batch system. Common files.
Group: Network Servers

%description -n cleo-common
  Cleo is the batch system for computing clusters. This package contains
files, used by all cleo components.

%package -n cleo-viz
Summary: Cleo batch system. Web-interface
Group: Network Servers

%description -n cleo-viz
  Cleo is the batch system for computing clusters. This package contains
web-interface script.

%pre

%prep
%setup -q -n cleo-%version
#%patch0 -p1
#%patch1 -p1

%build
make RCDIR=%_initdir SHAREDDIR=%perl_lib_path CHECK=no \
    {,MAN}USER=root {,MAN}GROUP=root INSTALL_FLAGS='' INSTALL_MANS='' \
    DOCDIR=%_docdir WWWROOT=%wwwroot CGIROOT=%cgiroot WWWGROUP=%wwwgroup WWWUSER=%wwwuser

%install
make DESTDIR=%buildroot RCDIR=%_initdir SHAREDDIR=%perl_lib_path CHECK=no \
    {,MAN}USER=root {,MAN}GROUP=root INSTALL_FLAGS='' INSTALL_MANS='' \
    DOCDIR=%_docdir WWWROOT=%wwwroot CGIROOT=%cgiroot WWWGROUP=%wwwgroup WWWUSER=%wwwuser install

make DESTDIR=%buildroot RCDIR=%_initdir SHAREDDIR=%perl_lib_path CHECK=no \
    {,MAN}USER=root {,MAN}GROUP=root INSTALL_FLAGS='' INSTALL_MANS='' \
    DOCDIR=%_docdir WWWROOT=%wwwroot CGIROOT=%cgiroot WWWGROUP=%wwwgroup WWWUSER=%wwwuser rpminstall-viz

%clean
rm -rf $RPM_BUILD_ROOT

%files -n cleo-server
%defattr(-, root, root)


%doc README COPYING
#%doc cleo-%version/man/ant-mon.1
%config %attr(0644,root,root) /etc/cleo.conf
%_sbindir/cleo
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
%_docdir/cleo/cleo.conf.example
%_docdir/cleo/cleo.conf.example-mpich
%_docdir/cleo/cleo.conf.example-mvs
%_docdir/cleo/cleo.conf.example-sci
%_docdir/cleo/example-scheduler
%perl_lib_path/cleosupport.pm
%perl_lib_path/cleovars.pm
%perl_lib_path/base_sched
%perl_lib_path/listfile_mod
%attr(0745,root,%_mpi_group) %_bindir/mpirun
%attr(0755,root,%_mpi_group) %_bindir/cleo-submit
%_bindir/tasks
%_mandir/man1/*
%_bindir/qdel-cleo
%_bindir/qstat-cleo
%_bindir/qsub-cleo
%_sbindir/cleo-script-run

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

%if 0%{?suse_version}
%dir %_libexecdir/cleo/
%dir %_docdir/cleo/
%endif

%files -n cleo-agent
%defattr(-, root, root)

%_initdir/cleo-mon
%_sbindir/cleo-mon

%files -n cleo-common
%defattr(-, root, root)

%perl_lib_path/Cleo/Conn.pm
%perl_lib_path/Cleo/State.pm
%_bindir/empty-cleo
%_bindir/cleo-wrapper

%if 0%{?suse_version}
%dir %perl_lib_path/Cleo/
%dir %wwwroot/img
%dir %wwwroot/jq
%endif

%files -n cleo-viz
%defattr(-, www-data, www-data)
#%cgiroot/cleo-viz.cgi
#%wwwroot/cleoviz.css
#%wwwroot/img/*.png
#%wwwroot/jq/jq*
#%libroot/*
%attr(0755,%wwwuser,%wwwgroup) %cgiroot/cleo-viz.cgi
%attr(0644,%wwwuser,%wwwgroup) %wwwroot/cleoviz.css
%attr(0644,%wwwuser,%wwwgroup) %wwwroot/img/*.png
%attr(0644,%wwwuser,%wwwgroup) %wwwroot/jq/jq*
%attr(0644,%wwwuser,%wwwgroup) %libroot/*
%if 0%{?suse_version}
%dir %libroot
%dir %wwwroot
%dir %cgiroot
%endif

%changelog
* Fri May 22 2015 Sergey Zhumatiy <zhum@parallel.ru> 5.20c
- spec fixed

* Tue Jan 18 2011 Sergey Zhumatiy <zhum@altlinux.org> 5.20a-alt1
- visualization added (web-interface)

* Mon Sep 21 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.23b-alt1
- file close hooks added

* Thu Sep 17 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.23a-alt1
- some fixes
- environment variables added

* Thu Jun 18 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.22b-alt1
- rerun on bad start implemented
- fixed reopen log bug
- empty much cpu consumption fixed

* Wed May 06 2009 Sergey Zhumatiy <zhum@altlinux.org> 5.22a
- reopen logs fixed
- extra cpus are taken in account as used cpus now
- tasks accepts attributes now
- agent restarts after some (3 by default) critical errors
- cleosupport: count_runned func is added
- all cleo parameters is passed to any executed program via CLEO_* vars
- extra cpus are printes as used in 'tasks'

* Thu Dec 18 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.20a
- attaching fixed
- wrapper mechanism added: all tasks now tells monitors about runs
- last_attach added - now unrecognized processes can be attache to last task if they matches
- filter_users added - unwanted unmatched processes can be detectd and killed
- some tunings were made

* Thu Oct 09 2008 ergey Zhumatiy <zhum@altlinux.org> 5.13b
- bad nodes attaching fixed

* Mon Sep 22 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13a
- cleo-blockcpu fixed

* Fri Aug 22 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13a
- cpu-per-hour limit added

* Thu Jul 24 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12c
- Logrotate added
- Unique task identificators initially added

* Tue Mar 25 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.13
- suse port

* Tue Mar 25 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12
- Compatibility dependencies added

* Mon Mar 24 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12
- Minor optimizations

* Thu Mar 13 2008 Sergey Zhumatiy <zhum@altlinux.org> 5.12
- Initial build
