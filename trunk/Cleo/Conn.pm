#
#
#
#
#   peer, port,
#
#
#
package Cleo::Conn;

use strict;
use Exporter;

use IO::Socket::INET 1.29;
use IO::Select;
use Tie::RefHash;
use POSIX;

use vars qw($VERSION @ISA @EXPORT $conn_timeout);

#
#  States: dead ---> connecing -> ok
#           ^    \-> listen ->-/  |
#           \---------------------/
#
#
#

#my $_d=0;
#sub logit{
#    print STDERR $_[0] if(_d);
#}


# closed connections with not sended data
my @_closed_connections;

my %_conn_by_h;
tie %_conn_by_h, "Tie::RefHash";

# conn, IO::Socket
sub _add_conn{
    $_conn_by_h{$_[1]}=$_[0];
#!    print "ADD: {$_[1]}=$_[0]\n;";
}

# IO::Socket
sub _del_conn{
    delete $_conn_by_h{$_[0]};
#!    print "DEL: $_[0]\n;";
}

$VERSION=1.1;
@ISA=();
@EXPORT = qw(new new_handle new_listen connect disconnect get_peer get_port
             set_port set_peer get_state get_h get_conn set_timeout
             listen accept send read unread flush allflush
             add_close_hook del_close_hooks);
# private

    # close connection if possible
    # if not - save buffer and description
    #
    # Args: self, flag(do not flush)
    #
    sub _safe_close($;$) {
        my ($self,$noflush)=@_;
        
        $self->_do_close_hooks();
        # try to send rest of data
        if(($noflush!=0) or ($self->flush()!=0)){
            # some data was not sent
            push @_closed_connections, [$self->{handle},$self->{sbuffer}];
        }
        else{
            eval{$self->{handle}->close if defined($self->{handle});};
        }
    }

    # flush and possibly close all saved connections
    sub _flush_saved {
        my $i;
        my @_new_closed;
        my ($res,$len);

        for $i (@_closed_connections){

            $len=length $i->[1];

            next if not defined $i->[0];
            if(not $i->[0]->opened()){
                _del_conn($i->[0]);
                undef $i->[0];
                undef $res;
            }
            else{
                #try to send
                $res = $i->[0]->syswrite($i->[1]) if(defined $i->[1]);
            }
            if(!defined $res){
                # ERROR
                if(!defined $res and ($! == EAGAIN)){
                    # try again later
                    push @_new_closed, $i;
                    next;
                }
                # unrecoverable error
                eval{$i->[0]->close};
            }
            elsif($res<$len){
                # some data has been not sent
                substr($i->[1],0,$res)='';
                push @_new_closed, $i;
            }
        }
        @_closed_connections=@_new_closed;
    }
    
    #
    #  do some work before closing
    #
    sub _do_close_hooks($){
        my $self=shift;
        my $h;

        return unless defined $self->{handle};
        foreach $h (@{$self->{close_hooks}}){
            if(ref($h) eq 'CODE'){
                $h->($self->{handle});
            }
        }
        del_close_hooks($self);
    }

    # constructor
    # opt args: peer, port
    sub new {
        my $self ={};
        $self->{peer} = $_[1];
        $self->{port} = $_[2];
        $self->{state}='dead';
        $self->{handle}=undef;
        $self->{sbuffer}='';
        $self->{rbuffer}='';
        $self->{conn_timeout}=60;
        $self->{close_hooks}=();

        bless($self);

        return $self;
    }

    # constructor
    # args: port [num listens]
    sub new_listen {
        my $self ={};
        undef $self->{peer};
        $self->{port} = $_[1];
        $self->{listen} = $_[2];
        $self->{state}='dead';
        $self->{handle}=undef;
        $self->{sbuffer}='';
        $self->{rbuffer}='';

        bless($self);
        return $self;
    }

    # constructor
    # args: IO::Handle
    sub new_handle {
        my $self ={};
        undef $self->{peer};
        $self->{file} = 1;
        $self->{state}='ok';
        $self->{handle}=$_[1];
        $self->{sbuffer}='';
        $self->{rbuffer}='';

        _add_conn($self,$_[1]);
        bless($self);
        return $self;
    }

    sub DESTROY{
        my $self=shift;
        if(defined $self->{handle}){
            _del_conn($self->{handle});
            _safe_close($self);
        }

        # send all unsent data
        allflush();
        _flush_saved();
    }

    # set peername and port
    sub set_peer{
        $_[0]->{peer}=$_[1];
    }
    sub set_port{
        $_[0]->{port}=$_[1];
    }

    sub set_timeout{
        $_[0]->{conn_timeout}=$_[1];
    }
    # get peername and port
    sub get_peer{
        return $_[0]->{peer};
    }
    sub get_port{
        return $_[0]->{port};
    }

    # - dead
    # - ok
    # - connecting
    # - listen
    #
    sub get_state{
        my $self=shift;

        if($self->{state} eq 'connecting'){
            if($self->{handle}->connected){
                $self->{state} = 'ok';
            }
            # timed out?
            elsif($self->{conn_time}+$self->{conn_timeout}<time()){
                # still connecting...
                _do_close_hooks($self);
                _del_conn($self);
                $self->{handle}->close;
                delete $self->{handle};
                $self->{state}='dead';
            }

        }
        return $self->{state};
    }

    # try to connect
    #
    # !!!!  NOTE  !!!!
    # handle can be changed!
    #
    #
    #
    sub connect{
        my $self=shift;

        return 0 if($self->{state} eq 'ok');

        # already connecting?
        if(defined $self->{handle}){
            if($self->{handle}->connected){
                $self->{state} = 'ok';
                return 0;
            }
            # timed out?
            if($self->{conn_time}+$self->{conn_timeout}>time()){
                # still connecting...
                return 1;
            }
            _do_close_hooks($self);
            _del_conn_($self->{handle});
            $self->{handle}->close;
            undef $self->{handle};
        }

        # new connect attempt
        $self->{conn_time}=time();
        $self->{handle} = IO::Socket::INET->new(
            PeerAddr => $self->{peer},
            PeerPort => $self->{port},
            Proto    => 'tcp',
            Reuse => 1,
            Blocking => 0 );

        if(defined $self->{handle}){
            _add_conn($self,$self->{handle});
            $self->{state}= 'connecting';
            $self->{handle}->blocking(0);
            return 0 ;
        }
        else{
            #!print "Cannot connect to $self->{peer}:$self->{port} ($!)\n";
        }
        return 1;
    }

    #
    # optional arg: do NOT flush data before closing connection.
    #
    sub disconnect{
        my $self=shift;
        my $no_flush=shift;

        return 0 if($self->{state} eq 'dead');

        # close connection
        if(defined $self->{handle}){
            $self->flush unless $no_flush;
            _del_conn($self->{handle});

            _safe_close($self,$no_flush);
            _flush_saved();
        }
        undef $self->{handle};
        $self->{state}='dead';
    }

    #
    #  optional argument - adderss binding
    #
    sub listen{
        my $self=shift;
        my $addr=shift;

        $addr |= '0.0.0.0';

        if(defined $self->{handle}){
            _do_close_hooks($self);
            _del_conn($self->{handle});
            $self->{handle}->close;
        }
        $self->{listen} |= 1;
        $self->{handle}=IO::Socket::INET->new(
                Listen     => $self->{listen},
                LocalPort  => $self->{port},
                LocalAddr  => $addr,
                Proto      => 'tcp',
                ReuseAddr  => 1,
                #ReusePort  => 1,
                Blocking   => 0 );
        return 1 unless defined $self->{handle};

        _add_conn($self,$self->{handle});
        $self->{state}='listen';
        return 0;
    }

    sub accept{
        my $self=shift;

        return undef unless $self->{state} eq 'listen';
        my $h=$self->{handle}->accept();

        if(defined $h){
            my $new_conn={};

            $h->blocking(0);
            $new_conn->{peer} = $h->peerhost;
            $new_conn->{port} = $h->peerport;
            $new_conn->{state}='ok';
            $new_conn->{handle}=$h;
            $new_conn->{sbuffer}='';
            $new_conn->{rbuffer}='';
            $new_conn->{conn_timeout}=60;

            bless($new_conn);
            _add_conn($new_conn,$h);

            return $new_conn;
        }
        return undef;
    }

    # push to send-buffer
    sub send{
        my $self=shift;
        $self->{sbuffer} .= $_[0];
    }

    #actually send
    #
    #  ret: 0=OK, 1=FAIL
    #
    sub flush{
        my $self=shift;
        my ($res,$len);

        $len=length $self->{sbuffer};
        return 0 if $len==0;

        return 1 unless $self->{state} eq 'ok';

        if(not $self->{handle}->opened()){
            _do_close_hooks($self);
            _del_conn($self->{handle});
            undef $self->{handle};
            $self->{state}='dead';
            undef $res;
        }
        else{
            #try to send
            $res = $self->{handle}->syswrite($self->{sbuffer})
              if(defined $self->{sbuffer});
        }
        if(!defined $res){
            # ERROR
            return 1 if((!defined($res)) and ($! == EAGAIN));
            if($self->{file}){
                _del_conn($self->{handle});
                $self->{state}='dead';

                # gently close handler
                _safe_close($self,1);
                _flush_saved();

                undef $self->{handle};
                return 1;
            }

            # it is a socket. try to reconnect later
            _do_close_hooks($self);
            $self->disconnect(1);
            if($self->{listen}){
                $self->listen();
            }
            return 1;
        }
        # sent
        substr($self->{sbuffer},0,$res)='';

        _flush_saved();
        return 0;
    }

    #
    # ret: undef= FAIL
    #      else = readed text
    #
    sub read{
        my $self=shift;
        my ($res,$readed);

        if($self->get_state() ne 'ok'){
            $readed=$self->{rbuffer};
            $self->{rbuffer}='';
            return $readed if $readed ne '';
            return undef;
        }

        $res = $self->{handle}->sysread($readed,8192);
#        logit("SYSREAD=$readed.\n");
        if((!defined $res) or ($res==0)){
            # ERROR or EOF
            if(!defined $res and ($! == EAGAIN)){
                # nothing was readed
                $readed=$self->{rbuffer};
                $self->{rbuffer}='';
                return $readed;
            }

            $self->{state}='dead';
            $readed=$self->{rbuffer};
            $self->{rbuffer}='';

            if($self->{file}){
                _del_conn($self->{handle});
                _safe_close($self);
                _flush_saved();
                undef $self->{handle};

                return $readed if $readed ne '';
                return undef;
            }

            # it is a socket. try to reconnect later
            _do_close_hooks($self);
            $self->disconnect;
            _flush_saved();
            return $readed if $readed ne '';
            return undef;
        }

        _flush_saved();
        $readed=$self->{rbuffer}.$readed;
        $self->{rbuffer}='';
        return $readed;
    }

    sub unread{
        my $self=shift;
        $self->{rbuffer}=$_[0];
    }

    sub get_h{
        return $_[0]->{handle};
    }

    sub get_conn{
        shift if($_[0] eq 'Cleo::Conn');
        if(defined $_conn_by_h{$_[0]}){
            return $_conn_by_h{$_[0]};
        }
        return undef;
    }

    sub allflush{
        foreach my $i (keys(%_conn_by_h)){
            $_conn_by_h{$i}->flush() if defined $_conn_by_h{$i};
        }
        _flush_saved();
    }
    
    #
    #  add some action before closing
    #
    sub add_close_hook($$){
        push @{$_[0]->{close_hooks}}, $_[1];
    }

    #
    #  delete all actions before closing
    #
    sub del_close_hooks($){
        @{$_[0]->{close_hooks}}=();
    }
1;

__END__

=HEAD1 EXAMPLE

use IO::Select;
use Cleo::Conn;

$x=new Cleo::Conn("localhost",2525);
$x->set_timeout(5);
$x->connect;

while(($st=$x->get_state) ne 'ok'){
  print "$st\n";
  if($st eq 'dead'){
    $x->connect;
  }
  sleep 2;
}
print "Connected\n";
$s=new IO::Select($x->get_h);

do {
  @a=$s->can_read;
  sleep 1;
}while @a<1;

$q=Cleo::Conn->get_conn($a[0]);
if(defined $q){
  print $q->get_peer()."\n";
}
else{
  print "ERROR\n";
}
