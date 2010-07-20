#!/usr/bin/perl

my %tests=(
    perl  => 'Perl version must be 5.6.1 or greater',
    fcntl => 'Your system does not have Fcntl perl module',
    posix => 'Your system does not have POSIX perl module',
    storable => 'Your system does not have Storable perl module',
    socket => 'Version of IO::Socket::INET module must be 1.29 or higher',
    syslog =>'Your system does not have Sys::Syslog perl module',
    timelocal=>'Your system does not have Time::Local perl module',
    syswait=>'Your perl does not understand POSIX ":sys_wait_h"',
    refhash=>'Your system does not have Tie::RefHash perl module',
    );

eval "
    use 5.6.1;
    delete \$tests{perl};
";
eval "
    use Fcntl;
    delete \$tests{fcntl};
";
eval "
    use POSIX;
    delete \$tests{posix};
";
eval "
    use Storable;
    delete \$tests{storable};
";
eval "
    use IO::Socket::INET 1.29;
    delete \$tests{socket};
";
eval "
    use Sys::Syslog;
    delete \$tests{syslog};
";
eval "
    use Time::Local;
    delete \$tests{timelocal};
";
eval "
    use POSIX \":sys_wait_h\";
    delete \$tests{syswait};
";
eval "
    use Tie::RefHash;
    delete \$tests{refhash};
";

if(scalar %tests > 0){
    print join("\n", "Some requirements are not satisfied:\n",
               values(%tests),"\n");
    exit(1);
}
exit(0);
