#!/usr/bin/perl
#
#  XML-RPC eveny logger for Cleo batch system
#
#  Sends stats to remote XML-RPC server
#
#

use vars qw($cleo $server $server_url);

$cleo=1.0;

use Frontier::Client;
use Date::Format;

($server_url) = get_settings('','url');
$server_url ||= 'http://cluster.parallel.ru:8080/XMLRPC';


sub check_connection(){
  if(not defined $server){
    $server = Frontier::Client->new(url => $server_url);
  }
  return $server;
}

#cleo_log "STARTED\n";

#
#  Run task event.
#    args: entry
#
###############################################
sub post($){
  my ($entry)=@_;
  undef $@;
  if(check_connection() eq undef){
    cleo_log "Cannot connect XML-RPC server";
    return 0;
  }
  # logTaskStart (String cluster, String queue, int task_uid,
  # String processors, Date date, String user, int realCPU)

  undef $@;
  eval{
    unless (my $result = $server->call(
           'ant.logTaskStart',
           $server->string($entry->{cluster}),
           $server->string($entry->{queue}),
           $server->int($entry->{uid}),
           $server->string($entry->{nodes}),
           $server->date_time(time2str('%Y%m%dT%X',$entry-{time})),
           $server->string($entry->{user}),
           $server->int($entry->{np})
            )){
        cleo_log 'Result from server: '.$result;
    }
    return 0;
  };
  # error?
  if($@){
     cleo_log('Disconnected...');
     undef $server;
  }
  return 0;
}

# task end
sub ok($){
  my ($entry)=@_;
  undef $@;
  if(check_connection() eq undef){
    cleo_log "Cannot connect XML-RPC server";
    return 0;
  }
  # logTaskEnd (String cluster, String queue, int task_uid, String processors, Date date)

  undef $@;
  eval{
    unless (my $result = $server->call(
           'ant.logTaskEnd',
           $server->string($entry->{cluster}),
           $server->string($entry->{queue}),
           $server->int($entry->{uid}),
           $server->string($entry->{nodes}),
           $server->date_time(time2str('%Y%m%dT%X',get_time()))
           )){
        cleo_log 'Result from server: '.$result;
    }
    return 0;
  };
  # error?
  if($@){
     cleo_log('Disconnected...');
     undef $server;
  }
  return 0;
}

# task end - second case
sub fail($){
  return ok($_[0]);
}

# task add
sub add($){
  my ($entry)=@_;
  undef $@;
  if(check_connection() eq undef){
    cleo_log "Cannot connect XML-RPC server";
    return 0;
  }
  # logTaskEnd (String cluster, String queue, int task_uid, String processors, Date date)

  undef $@;
  eval{
    unless (my $result = $server->call(
           'ant.logTaskAdd',
           $server->string($entry->{cluster}),
           $server->string($entry->{queue}),
           $server->string($entry->{user}),
           $server->int($entry->{uid}),
           $server->string($entry->{np}),
           $server->date_time(time2str('%Y%m%dT%X',get_time()))
           )){
        cleo_log 'Result from server: '.$result;
    }
    return 0;
  };
  # error?
  if($@){
     cleo_log('Disconnected...');
     undef $server;
  }
  return 0;
}

# task del
sub del($){
  my ($entry)=@_;
  undef $@;
  if(check_connection() eq undef){
    cleo_log "Cannot connect XML-RPC server";
    return 0;
  }
  # logTaskEnd (String cluster, String queue, int task_uid, String processors, Date date)

  undef $@;
  eval{
    unless (my $result = $server->call(
           'ant.logTaskDel',
           $server->string($entry->{cluster}),
           $server->string($entry->{queue}),
           $server->int($entry->{uid}),
           $server->date_time(time2str('%Y%m%dT%X',get_time()))
           )){
        cleo_log 'Result from server: '.$result;
    }
    return 0;
  };
  # error?
  if($@){
     cleo_log('Disconnected...');
     undef $server;
  }
  return 0;
}
