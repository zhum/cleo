#
#
#  This is part of Cleo batch system project.
#  (C) Sergey Zhumatiy (serg@parallel.ru) 1999-2007
#
#
# You can redistribute and/or modify this program
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# See the GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

package cleosupport;

use strict;
use Exporter;

#require 'sys/syscall.ph';

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 5.23;
    eval "use lib '.'; use lib '__SHARED__';use cleovars $VERSION";
    if ($@) {
        die "$@\n";
    }
    1;
}

use Fcntl;
use IO::Socket;
use IO::Handle;
use IO::Select;
use XML::Writer;
use Mail::Mailer;
use File::Temp qw(tempfile);
use Cleo::Conn;
#use IPC::Msg;
#use IPC::SysV qw(IPC_PRIVATE);


use POSIX ":sys_wait_h";
use POSIX "strftime";
use Storable;
use locale;

#use Getopt::Std;

use vars qw(@non_saved_fields);

eval { &O_LARGEFILE(); };
if ($@) {
    eval "sub O_LARGEFILE(){return 0;}";
}

# do not save these fields in task entry
@non_saved_fields = ('pid');

@ISA    = ('Exporter');
@EXPORT = qw(
    &MODE_RUN_ALLOW &AUTORESTART &AUTORESTART_LOCK &MODE_QUEUE_ALLOW &SOFT_DIE
    &NEW_VERSION &min &qlog &slog &boot &qlog &launch
    &uid2user &get_uid &isadmin &candebug &daemonize &shuffle_array
    &shuffle_only_hosts &shuffle_hosts_alone
    &get_user_argv0_by_pid &new_count &new_count2
    &new_hash &push_to_queue &REAPER &do_reap &crash
    &kill_running &kill_supports &save_n_exit &save_line
    &load_line &save_state &load_state &generate_string
    &mode2text &load_conf_file &reload_users &reload_users_changes
    &load_user_conf &get_setting &set_default_values &fix_values &deldir
    &subst_task_prop &s_val &spaced2mpi &newpipe
    &make_subclusters &create_config &run_via_mons
    &run_task &execute_task &run_id &remove_id &req_child_pe
    &get_entry &del_from_queue
    &count_free &del_task &autoblock &set_entry_priority
    &set_priority &get_task_list &sub_exec &cleo_system
    &get_task_list_w_flags &new_mode &count_free_total
    &chld_req_tmout &dump_queue
    &block_task &test_block &block_pe &block_one_pe
    &send_to_channel &flush_channels &get_block_x &get_line
    &kill_conn &on_cluster_die &usecs &new_runned &find_runned
    &h_by_channel &channel_by_handle &create_conn $STATUS
    &recreate_plugins_and_ports &is_in_list
    &pack_value &unpack_value &kill_tree &count_user_np_used
    &block_delayed &actualize_cpu_blocks
    &sc_task_in &sc_task_at &sc_task_del &sc_next_time &sc_execute
    &load_exec_modules &do_exec_module &load_schedulers
    &count_enabled_cpus &check_detached &log_rotate
    &check_cpuh &count_runned &count_really_runned
    &rerun_task &calc_vars &violates &reopen_logs
    &count_reserved_for_id &count_reserved_own
    &every_nil_sub &nil_sub
    &cpulist2nodes &fix_prerun &calculate_estimated
    &mail_delay &mail_max_delay &flush_mails &send_mail
);

#&load_conf_section
#&move_to_queue &get_queue_type
#&eval_q_params

use vars qw($STATUS $SHORT_LOG %loaded_vars);

%def_global_settings = (
    add_pri_on_chld    => 20,
    adm_email          => 'root@localhost',
    admins             => ['root'],
    allowed_ips        => '127.0.0.1',
    attach_mask        => '',
    attach_parent_mask => '',
    attach_timeout     => 15,        # NODES timeout for collect task pids
    check_run_interval => 5,
                   # interval to check died runned tasks on localhost
    coll_nodes        => 0,
    compress_cmd      => 'bzip2 -c', # command to use compression
    compress_ext      => 'bz2',      # extension for compresed files
    count_first       => '',
    cpu_map_file      => '',
    debug_users       => ['root'],
    default_time      => 3600 * 100, #100 hours
    def_admview_flags => '',
    def_priority      => 10,
    def_queue         => 'main',
    def_view_flags    => '',
    empty_input       => '$dir/.cleo-$id-in',    # template for input fifo
    empty_timeout     => 15, # how many seconds wait for empty to run task
    exec_line         =>
        '/opt/mpich/bin/mpirun -np $n -machinefile $file $wrap $task',
    exec_modules_dir     => '__SHARED__',
    exec_modules_timeout => 5,
    exec_modules         => [],
    exec_write           => '',
    file_head            => '',
    file_line            => '',
    file_mask            => '',
    file_tail            => '',
    first_line           => '',
    force_foreign_run    => 1,
    gid                  => 65535,
    intra_timeout => 600, # default timeout for parent-childs interconnections
    kill_head_delay   => 15, #!!! new delay before HEAD process will be killed
    kill_mons_on_exit => 0,
    kill_script       => '',
    listen_number     => 5,   # listen queue length
    listen_rsh_number => 5,   # listen queue length for rsh connections
    log_file          => '/var/log/cleo.log',
    log_level         => 4,   #  log details level (0..5)
    mail_delay        => 30,  #  collent mail bodys for 30 seconds
    mail_max_delay    => 120, #  after 120 sec send mail anyway (stop collect)
    mail_server       => 'localhost', # send via localhost by default
    max_count         => 99000000,
    max_cpuh          => 0,   # cpu * hours

    max_ext_sched_err => 10,
    max_log_days      => 7*5,             # every 5 weeks
    max_log_size      => 1024*1024*1024,  # 1Gb
    max_np            => 100000,
    max_queue         => 16, # max FULL QUEUE LENGTH, when user cannot add task
    max_run           => 100000, # maximum tasks running
    max_short_log_days => 7*5,             # every 5 weeks
    max_short_log_size => 1024*1024*1024,  # 1Gb
    max_sum_np        => 100000,
    max_tasks         => 20,
    max_tasks_on_pe   => 2,
    max_time          => 3600 * 100,    #100 hours
    min_np            => 1,
    mon_back_exec     => '',
    mon_back_mail     => '',
    mon_block_delay   => 3,          # how many times to try to reconnect
                                   # failed node before block it
                                   # (see 'mon_fail_interval')
    mon_connect_timeout  => 60,    # timeout for monitor initial connection
    mon_connect_interval => 100,   # interval to try connect to monitor...
    mon_dead_exec        => '',
        #'echo \'Node $node is dead!\' |mail -s \'dead $node\' root',
    mon_dead_mail        =>
        "dead node(s)\nNode \$node is dead!\n",
    mon_delayed_block_exec => '',
        #'echo \'Cpu $cpu has been blocked by admin request "$reason" at $time\' |mail -s \'block $cpu\' root',
    mon_delayed_block_mail => "Block cpu\nCpu \$cpu has been blocked by admin request \"\$reason\" at \$time",
    mon_fail_exec     => '',
        #'echo \'Node $node has failed!\' |mail -s \'fail $node\' root',
    mon_fail_interval    => 120,   # time to sleep before reconnect failed mon
    mon_fast_raise_count => 4,
    mon_fast_raise_exec  => '',
        #'echo \'Node $node raises back very suspicious!\' |mail -s \'FAIL $node\' $adm_email',
    mon_fast_raise_mail  =>
        "Node FAIL\nNode \$node raises back very suspicious!",
    mon_node_port     => 5588,

    mon_ping_interval => 60,
    mon_port          => 5577,
    mon_rnd_ping      => 5,      # randomization of ping interval (seconds)
    mon_run_string    => 'echo ssh $node __SBIN__/cleo-mon',
    mon_run_timeout   => 10,      # kill dead task procersses in this time
    mon_timeout       => 30,      # timeout for monitor ping answer

###########################################
#     translated to monitors
    hard_kill_delay   => 60,    #!!! new delay before kill -9 will be sent
    mon_attach_tmout  => '',     # timeout for attching
    mon_dead_cleanup_time       => '',
    mon_debug_pc                => '',
    mon_filter_users            => 1, # unwanted pids: 0-ignore, 1- warn, 2- kill
    mon_global_rsh_command      => '',
    mon_hard_kill_after_head    => '', #interval to kill task after head death
    mon_init_conn_timeout       => '',
    mon_last_ran_check_interval => '',
    mon_log_kills               => '',
    mon_path_prepend  =>'',      # PATH part to prepend before exec
                                 # command on node (via_mons)
    mon_path_append   =>'.',     # PATH part to append before exec
                                 # command on node (via_mons)
    mon_pids_update_interval    => '',
    mon_rsh_command   => '/usr/local/bin/cleo-rsh',
    mon_smart_port    => '',     #
    mon_suexec_gid              => '',
############################################

    norootadm        => 0,
    nousers          => [],
    occupy_full_node => 0,
    one_report       => 0,
    outfile              => '$dir/$sexe.out',
    parent               => '',
    pe                   => [],
    pe_sel_die_count     => 10,
    pe_sel_method        => {},
    pe_select            => 'random',
    pid_file             => '/var/run/cleo.pid',
    port                 => 5252,
    post_exec_write      => '',
    priority             => 10,
    q_fail_exec          => '',
    q_just_exec          => '',
    q_ok_exec            => '',
    q_post_exec          => '',
    q_pre_exec           => '',
    queue_alt_save       => '/tmp/cleo-save',
    queue_save           => '/var/log/cleo-save',
    repfile              => '$dir/$sexe.rep',
    rerun_delay          => '10', # delay for rerunned tasks to waint in queue
    root_cluster_name    => 'main',
    rsh_cmd              => { 'mpich' => '$exe $mpich_args' },
    rsh_filter           => {},
    rsh_filter_die_count => 10,
    run_chunk_tmout      => 5,     # internal timeout in prerunning loop
    run_via_mons         => 0,
    pseudo_rsh_port      => 47000,
    scheduler            => 'base_sched',
    scheduler_timeout    => 15,    # scheduler timeout in seconds
    schedulers           => ['base_sched'],
    schedulers_dir       => '__SHARED__',
    short_log_file       => '/var/log/cleo-short.log',
    status_file          => '/tmp/cleo-status',
    sub_exec_timeout     => 15,
    task_local_renice    => 15, # local tasks processes priority
    time_qcheck          => 2,
    time_restrict_file   => '/etc/cleo-time-restrictions',
    timeout          => 10,                       # user connection timeout
    temp_dir         => '/tmp/cleo.$queue.$id',
    use_empty        => '__BIN__/empty-cleo',
    use_exec_modules => [],
    use_file         => 0,
    use_first_line   => 0,
    use_monitors     => 1,
    use_rsh_filter   => '',
    user_conf_file   => '.cleo',
    user_fail_exec   => '',
    user_just_exec   => '',
    user_kill_script => '',
    user_ok_exec     => '',
    user_post_exec   => '',
    user_pre_exec    => '',
    users            => [],
    verbose          => 1,
    wait_secs_to_kill_base_rsh => 20,
    xml_rights       => 0644,
    xml_statefile    => '/tmp/cleo-xml-status'
    );

%server_opt_types = (    #                  type/safe/sections
        # types: n-umeric, t-ext, h-ash, l-ist (via space), L-st (via comma)
        # sections: ''=all, 'q'=queues, 'g'=global, 'u'=users, 'p'=profiles,
        #           'U'=clusterusers, 'l'=local_user_file

    add_pri_on_chld        => [ 'i', 'y', 'gqpUu' ],
    adm_email              => [ 't', 'y', 'gq' ],
    admins                 => [ 'L', 'y', 'gq' ],
    allowed_ips            => [ 'L', 'y', 'g' ],
    attach_mask            => [ 't', 'y', '' ],
    attach_parent_mask     => [ 't', 'y', 'gq' ],
    attach_timeout         => [ 'n', 'y', '' ],
    check_run_interval     => [ 'n', 'y', '' ],
    coll_nodes             => [ 'n', 'y', '' ],
    count_first            => [ 'n', 'y', '' ],
    cpu_map_file           => [ 't', 'y', 'gpq' ],
    debug_users            => [ 'L', 'y', 'gq' ],
    def_admview_flags      => [ 't', 'y', 'gq' ],
    def_priority           => [ 'n', 'y', 'gqpUul' ],
    def_queue              => [ 't', 'y', '' ],
    def_view_flags         => [ 't', 'y', 'gquU' ],
    default_time           => [ 'n', 'y', '' ],
    empty_input            => [ 't', 'y', '' ],
    empty_timeout          => [ 'n', 'y', '' ],
    exec_line              => [ 't', 'y', 'gqpUu' ],
    exec_modules_dir       => [ 't', 'y', 'g' ],
    exec_modules_timeout   => [ 'n', 'y', 'g' ],
    exec_modules           => [ 'L', 'y', 'g' ],
    exec_module            => [ 'L', 'y', '' ],
    exec_write             => [ 't', 'y', '' ],
    file_head              => [ 't', 'y', '' ],
    file_line              => [ 't', 'y', '' ],
    file_mask              => [ 't', 'y', 'gq' ],
    file_tail              => [ 't', 'y', '' ],
    first_line             => [ 't', 'y', '' ],
    force_foreign_run      => [ 'n', 'y', 'gq' ],
    gid                    => [ 't', 'y', 'gqUu' ],
    hard_kill_delay        => [ 'n', 'y', '' ],
    intra_timeout          => [ 'n', 'y', 'g' ],
    kill_head_delay        => [ 'n', 'y', '' ],
    kill_mons_on_exit      => [ 'n', 'y', 'g' ],
    kill_script            => [ 't', 'y', 'gqpUu' ],
    listen_number          => [ 't', 'y', 'g' ],
    listen_rsh_number      => [ 't', 'y', 'g' ],
    log_file               => [ 't', 'y', 'g' ],
    log_level              => [ 'n', 'y', 'g' ],
    mail_delay             => [ 'n', 'y', 'g' ],
    mail_max_delay         => [ 'n', 'y', 'g' ],
    mail_server            => [ 't', 'y', 'g' ],
    max_count              => [ 'n', 'y', 'g' ],
    max_cpuh               => [ 'n', 'y', ''  ],
    max_ext_sched_err      => [ 'n', 'y', 'gq' ],
    max_log_days           => [ 'n', 'y', '' ],
    max_log_size           => [ 'n', 'y', '' ],
    max_np                 => [ 'n', 'y', '' ],
    max_queue              => [ 'n', 'y', '' ],
    max_run                => [ 'n', 'y', '' ],
    max_sum_np             => [ 'n', 'y', '' ],
    max_short_log_days     => [ 'n', 'y', 'g' ],
    max_short_log_size     => [ 'n', 'y', 'g' ],
    max_tasks              => [ 'n', 'y', '' ],
    max_tasks_on_pe        => [ 'n', 'y', '' ],
    max_time               => [ 'n', 'y', '' ],
    min_np                 => [ 'n', 'y', '' ],
    mon_back_exec          => [ 't', 'y', 'g' ],
    mon_back_mail          => [ 't', 'y', 'g' ],
    mon_block_delay        => [ 'n', 'y', 'g' ],
    mon_connect_timeout    => [ 'n', 'y', 'g' ],
    mon_connect_interval   => [ 'n', 'y', 'g' ],
    mon_dead_exec          => [ 't', 'y', 'g' ],
    mon_dead_mail          => [ 't', 'y', 'g' ],
    mon_delayed_block_exec => [ 'n', 'y', 'g' ],
    mon_delayed_block_mail => [ 'n', 'y', 'g' ],
    mon_fail_exec          => [ 't', 'y', 'g' ],
    mon_fail_mail          => [ 't', 'y', 'g' ],
    mon_fail_interval      => [ 'n', 'y', 'g' ],
    mon_fast_raise_count   => [ 'n', 'y', 'g' ],
    mon_fast_raise_exec    => [ 't', 'y', 'g' ],
    mon_fast_raise_mail    => [ 't', 'y', 'g' ],

    #                     mon_fast_raise_interval => ['n','y','g'],
    mon_node_port     => [ 'n', 'y', 'g' ],
    mon_path_prepend  => [ 't', 'y', 'g' ],
    mon_path_append   => [ 't', 'y', 'g' ],
    mon_ping_interval => [ 'n', 'y', 'g' ],
    mon_port          => [ 'n', 'y', 'g' ],
    mon_rnd_ping      => [ 'n', 'y', 'g' ],
    mon_rsh_command   => [ 't', 'n', 'qg' ],
    mon_run_string    => [ 't', 'y', 'g' ],
    mon_run_timeout   => [ 'n', 'y', 'g' ],
    mon_timeout       => [ 'n', 'y', 'g' ],

    mon_attach_tmout  => [ 'n', 'y', 'g' ],
    mon_smart_port    => [ 'n', 'y', 'g' ],
    mon_global_rsh_command      => [ 't', 'y', 'g' ],
    mon_init_conn_timeout       => [ 'n', 'y', 'g' ],
    mon_hard_kill_after_head    => [ 'n', 'y', 'g' ],
    mon_suexec_gid              => [ 'n', 'y', 'g' ],
    mon_debug_pc                => [ 'n', 'y', 'g' ],
    mon_last_ran_check_interval => [ 'n', 'y', 'g' ],
    mon_log_kills               => [ 'n', 'y', 'g' ],
    mon_dead_cleanup_time       => [ 'n', 'y', 'g' ],
    mon_filter_users            => [ 'n', 'y', 'g' ],
    mon_pids_update_interval    => [ 'n', 'y', 'g' ],


    #old                 mons_check_time      => ['n','y','g'],
    norootadm            => [ 'n', 'y', 'gq' ],
    nousers              => [ 'L', 'y', 'gq' ],
    occupy_full_node     => [ 'n', 'y', '' ],
    one_report           => [ 'n', 'y', '' ],
    outfile              => [ 't', 'y', '' ],
    parent               => [ 't', 'n', 'q' ],
    pe                   => [ 'L', 'n', 'q' ],
    pe_sel_die_count     => [ 'n', 'y', 'gq' ],
    pe_sel_method        => [ 'h', 'y', 'gq' ],
    pe_select            => [ 't', 'y', '' ],
    pid_file             => [ 't', 'y', 'g' ],
    port                 => [ 'n', 'y', 'g' ],
    post_exec            => [ 't', 'y', '' ],
    post_exec_write      => [ 't', 'y', '' ],
    priority             => [ 'n', 'y', '' ],
    q_fail_exec          => [ 't', 'y', 'gqpUu' ],
    q_just_exec          => [ 't', 'y', 'gqpUu' ],
    q_ok_exec            => [ 't', 'y', 'gqpUu' ],
    q_post_exec          => [ 't', 'y', 'gqpUu' ],
    q_pre_exec           => [ 't', 'y', 'gqpUu' ],
    queue_alt_save       => [ 't', 'y', 'g' ],
    queue_save           => [ 't', 'y', 'g' ],
    repfile              => [ 't', 'y', '' ],
    rerun_delay          => [ 'n', 'y', '' ],
    root_cluster_name    => [ 't', 'n', 'g' ],
    rsh_cmd              => [ 'h', 'y', 'gqp' ],
    rsh_filter           => [ 'h', 'y', '' ],
    rsh_filter_die_count => [ 'n', 'y', 'gqp' ],
    run_chunk_tmout      => [ 'n', 'y', 'g'],
    run_via_mons         => [ 'n', 'y', '' ],
    pseudo_rsh_port      => [ 'n', 'y', '' ],
    scheduler            => [ 't', 'y', 'gq' ],
    scheduler_timeout    => [ 'n', 'y', '' ],
    schedulers           => [ 'L', 'y', 'gq' ],
    schedulers_dir       => [ 't', 'y', 'gq' ],
    short_log_file       => [ 't', 'y', 'g' ],
    status_file          => [ 't', 'y', 'g' ],
    sub_exec_timeout     => [ 'n', 'y', '' ],
    task_local_renice    => [ 'n', 'y', '' ],
    time_qcheck          => [ 'n', 'y', 'gq' ],
    time_restrict_file   => [ 't', 'y', 'gq' ],
    timeout              => [ 'n', 'y', 'g' ],       # timeout for client connections
    temp_dir             => [ 't', 'y', 'gqpUu' ],
    use_empty            => [ 't', 'y', '' ],        # path to the 'empty' exe 
                                              #module (null if do not use empty)
    use_exec_modules           => [ 'L', 'y', '' ],
    use_file                   => [ 't', 'y', 'gqpUu' ],
    use_first_line             => [ 'n', 'y', '' ],
    use_monitors               => [ 'n', 'y', 'gqpUu' ],
    use_rsh_filter             => [ 't', 'y', '' ],
    user_conf_file             => [ 't', 'y', 'gquU' ],
    user_fail_exec             => [ 't', 'y', 'gqpUul' ],
    user_just_exec             => [ 't', 'y', 'gqpUul' ],
    user_kill_script           => [ 't', 'y', 'gqpuUl' ],
    user_ok_exec               => [ 't', 'y', 'gqpUul' ],
    user_post_exec             => [ 't', 'y', 'gqpUul' ],
    user_pre_exec              => [ 't', 'y', 'gqpUul' ],
    users                      => [ 'L', 'y', 'gq' ],
    verbose                    => [ 'n', 'y', 'g' ],
    wait_secs_to_kill_base_rsh => [ 'n', 'y', 'g' ],
    xml_rights                 => [ 't', 'y', 'g' ],
    xml_statefile              => [ 't', 'y', 'g' ]
    );

my %dump_q_trans = (

    #                  'nproc' => 'np',
    'time'    => 'start',
    'oldid'   => 'origid',
    'outfile' => 'out',
    'repfile' => 'rep',
    'own'     => 'ownnodes',
    'shared'  => 'sharednodes' );

my %xml_no_print = (
    'rsh_filter',  1,
    'start',       1,
    'time',        1,
    'added',       1,
    'own',         1,
    'shared',      1,
    'extranodes',  1,
    'task',        1,
    'blocks',      1,
    'timelimit',   1
    );

@log_prefixes = (
    '     ',    # ALL
    'ERROR',    # ERR
    'WARN ',    # WARN
    'INFO ',    # INFO
    'DEBUG',    # DEBUG
    'DEB2 '     # DEBUG2
);


#CONSTANTS
sub MODE_RUN_ALLOW()   { return 1; }
sub AUTORESTART()      { return 2; }
sub AUTORESTART_LOCK() { return 4; }
sub MODE_QUEUE_ALLOW() { return 8; }
sub SOFT_DIE()         { return 16; }
sub NEW_VERSION()      { return 32; }

sub pack_value( $ );
sub unpack_value( $$;$ );
sub make_subclusters($ );

my $daemonizing;
my %launch_pids;
my $log_time;

my $scheduler_prolog = <<_PROLOG;
use vars qw(\$__cleo_mod_error);

# id,pe_list
sub run( \$;\@ ){
  unless(defined(\$cleovars::ids{\$_[0]})){
    cleosupport::qlog("Bad id given by scheduler to run (\$_[0]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  \$cleovars::may_go=1;
  my \$id=shift \@_;
  if(main::try_to_run(\$cleovars::ids{\$id},\$cleovars::ids{\$id}->{gummy},\\\@_)){
     cleosupport::block_task(\$id, 1, '__scheduler__', 'Unsuccesfull run');
  }
  \$cleovars::q_change=1;
  return;
}

# id, reason
sub block( \$\$ ){
  my (\$id,\$reason)=\@_;

  unless(defined(\$cleovars::ids{\$_[0]})){
    cleosupport::qlog("Bad id given by scheduler to block (\$_[0]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  cleosupport::block_task(\$id,1,'__internal__',\$reason);
  \$cleovars::q_change=1;
  return;
}

# id, reason
sub unblock( \$\$ ){
  my (\$id,\$reason)=\@_;

  unless(defined(\$cleovars::ids{\$_[0]})){
    cleosupport::qlog("Bad id given by scheduler to unblock (\$_[0]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  cleosupport::block_task(\$id,0,'__internal__',\$reason);
  \$cleovars::q_change=1;
  return;
}

# id to move, id after which to move
sub move( \$\$ ){
  my (\$i,\$j)=\@_;

  return if (\$i==\$j);
  unless(defined(\$cleovars::ids{\$_[0]})){
    cleosupport::qlog("Bad id given by scheduler to move (\$_[0]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  if(\$_[1]<\$#cleovars::queue){
    cleosupport::qlog("Bad position given by scheduler to move (\$_[1]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  my (\$i,\$j);
  for(\$i=0; \$i<\$#cleovars::queue; ++\$i){
    last if(\$cleovars::queue[\$i]->{id} == \$_[0]);
  }
  if(\$i>=\$#cleovars::queue){
    cleosupport::qlog("Scheduler move: id not found in queue (\$_[0]). Ignore.\n", &cleovars::LOG_ERR());
    \$__cleo_mod_error=1;
    return;
  }
  if(\$j>=0){
    for(\$j=0; \$j<\$#cleovars::queue; ++\$j){
      last if(\$cleovars::queue[\$j]->{id} == \$_[1]);
    }
    if(\$j>=\$#cleovars::queue){
      cleosupport::qlog("Scheduler move: second id not found in queue (\$_[1]). Ignore.\n", &cleovars::LOG_ERR());
      \$__cleo_mod_error=1;
      return;
    }
  }
  elsif(\$j==-1){ #move to top
    splice \@cleovars::queue, \$i, 1;
    unshift \@cleovars::queue, \$cleovars::ids{\$_[0]};
    return;
  }
  else{ # move to bottom
    splice \@cleovars::queue, \$i, 1;
    push \@cleovars::queue, \$cleovars::ids{\$_[0]};
    return;
  }
  splice \@cleovars::queue, \$i, 1;
  if(\$i<\$j){#move lower
    splice \@cleovars::queue, \$j, 0, \$cleovars::ids{\$_[0]};
  }
  else{     #move upper
    splice \@cleovars::queue, \$j+1, 0, \$cleovars::ids{\$_[0]};
  }
}

# id, field
sub get_task_info( \$\$ ){
  if(exists(\$cleovars::ids{\$_[0]})){
    if(\$_[1] eq 'blocked'){
      return 1 if(defined \$cleovars::ids{\$_[0]}->{blocks}
                  and scalar(\@{\$cleovars::ids{\$_[0]}->{blocks}})>0);
      return 0;
    }
    elsif(exists(\$cleovars::ids{\$_[0]}->{\$_[1]})){
      if(ref(\$cleovars::ids{\$_[0]}->{\$_[1]}) ne ''){
        return Storable::thaw(Storable::freeze(\$cleovars::ids{\$_[0]}->{\$_[1]}));
      }
      return \$cleovars::ids{\$_[0]}->{\$_[1]};
    }
  }
  cleosupport::qlog("Scheduler gets invalid task field (\$_[0]/\$_[1]).\n", &cleovars::LOG_DEBUG());
  return undef;
}

# list free cpus
sub get_free_cpus( ){
    return cleosupport::get_free_cpus();
}

# id, field, value
sub set_task_info( \$\$\$ ){
  if(exists(\$cleovars::ids{\$_[0]}) and
     exists(\$cleovars::ids{\$_[0]}->{\$_[1]})){
    cleosupport::qlog("Scheduler sets task's '\$_[0]' field '\$_[1]' into '\$_[2]'.\n", &cleovars::LOG_DEBUG());
    \$cleovars::ids{\$_[0]}->{"\$_[1]"}=\$_[2];
    return;
  }
  cleosupport::qlog("Scheduler sets invalid task field (\$_[0]/\$_[1]).\n", &cleovars::LOG_DEBUG());
  return;
}

# id, field
sub get_task_attr( \$\$ ){
  if(exists(\$cleovars::ids{\$_[0]})){
    if(exists(\$cleovars::ids{\$_[0]}->{attrs}->{\$_[1]})){
      if(ref(\$cleovars::ids{\$_[0]}->{attrs}->{\$_[1]}) ne ''){
        return Storable::thaw(Storable::freeze(\$cleovars::ids{\$_[0]}->{attrs}->{\$_[1]}));
      }
      return \$cleovars::ids{\$_[0]}->{attrs}->{\$_[1]};
    }
  }
  return undef;
}

# id, field, value
sub set_task_attr( \$\$\$ ){
  if(exists(\$cleovars::ids{\$_[0]})){
    cleosupport::qlog("Scheduler sets task's '\$_[0]' attr '\$_[1]' into '\$_[2]'.\n", &cleovars::LOG_DEBUG());
    \$cleovars::ids{\$_[0]}->{attrs}->{"\$_[1]"}=\$_[2];
    return;
  }
  cleosupport::qlog("Scheduler sets attr for invalid task (\$_[0]/\$_[1]).\n", &cleovars::LOG_DEBUG());
  return;
}

# user, profile, field
sub get_user_profile_info( \$\$\$ ){
  if(exists(\$cleovars::useruid{\$_[0]})){
    my \$ret=cleosupport::get_setting(\$_[2],\$_[0],\$_[1]);
    return \$ret;
  }
  cleosupport::qlog("Scheduler gets info about nonuser (\$_[0]/\$_[1],\$_[2]).\n", &cleovars::LOG_DEBUG());
  return undef;
}

# user, field
sub get_user_info( \$\$ ){
  my \$p=__PACKAGE__;
  if(exists(\$cleovars::sched_user_info{\$p}->{\$_[0]}->{\$_[1]})){
    return \$cleovars::sched_user_info{\$p}->{\$_[0]}->{\$_[1]};
  }
  return get_user_profile_info(\$_[0],undef,\$_[1]);
}

# user, name, value
sub set_user_info( \$\$\$ ){
  my \$p=__PACKAGE__;
  \$cleovars::sched_user_info{\$p}->{\$_[0]}->{\$_[1]}=\$_[2];
}

# pe, filed
# (blocked,blocked_reasons,ids,own,max)
sub get_pe_info( \$\$ ){
#  if(exists(\$cleovars::pe{\$_[0]}) or exists(\$cleovars::blocked_pe{\$_[0]})){
  if(exists(\$cleovars::pe{\$_[0]})){
    if(\$_[1] eq 'blocked'){
      return 1 if exists(\$cleovars::blocked_pe_reasons{\$_[0]});
      return 0;
    }
    elsif(\$_[1] eq 'blocked_reasons'){
      if(exists(\$cleovars::blocked_pe_reasons{\$_[0]})){
        my \@ret=keys(\%{\$cleovars::blocked_pe_reasons{\$_[0]}});
        return \\\@ret;
      }
      return undef;
    }
    elsif(\$_[1] eq 'ids'){
      my \@ret=keys(\%{\$cleovars::pe{\$_[0]}->{ids}});
      return \\\@ret;
    }
    elsif(\$_[1] eq 'own'){
      return 1 if exists(\$cleovars::own{\$_[0]});
      return 0;
    }
    elsif(\$_[1] eq 'max'){
      return \$cleovars::pe{\$_[0]}->{max};
    }
  }
  cleosupport::qlog("Scheduler gets info about bad pe (\$_[0]/\$_[1]).\n", &cleovars::LOG_DEBUG());
  return undef;
}

sub cleo_log( \$ ){
  cleosupport::qlog("[int] \$_[0]\n",&cleovars::LOG_DEBUG());
}

sub list_running(){
  my (\$i,\@ret);

  foreach \$i (\@cleovars::running){
    push \@ret, Storable::thaw(Storable::freeze(\$cleovars::ids{\$i}));
  }
  return \@ret;
}

sub list_queued(){
  my (\$i,\@ret);

  foreach \$i (\@cleovars::queue){
    push \@ret, Storable::thaw(Storable::freeze(\$cleovars::ids{\$i}));
  }
  return \@ret;
}

sub list_future(){
  my (\$i,\%times);

  foreach \$i (\@cleovars::running){
    \$times{\$i->{id}}->{time}=\$i->{timelimit};
    \$times{\$i->{id}}->{np}=\$i->{np};
    \$times{\$i->{id}}->{user}=\$i->{user};
    \$times{\$i->{id}}->{npextra}=\$i->{npextra};
    \$times{\$i->{id}}->{id}=\$i->{id};
  }
  return \\\%times;
}

sub violates( \$;\$ ){
    return cleosupport::violates(\$_[0],\$_[1]);
}

sub MODE_RUN_ALLOW(){return cleosupport::MODE_RUN_ALLOW();}
sub MODE_QUEUE_ALLOW(){return cleosupport::MODE_QUEUE_ALLOW();}

sub get_mode(){
  return \$cleovars::mode;
}

sub save_data( \$\$ ){
  my \$p=__PACKAGE__;
  \$cleovars::sched_data{\$p}->{\$_[0]}=\$_[1];
}

sub get_data( \$ ){
  my \$p=__PACKAGE__;
  return \$cleovars::sched_data{\$p}->{\$_[0]};
}

sub disturb_at( \$ ){
  \$cleovars::sched_alarm=\$_[0];
}

sub get_time(){return \$cleovars::last_time;}

sub get_settings( \$;\@ ){
  my \$p=__PACKAGE__;
  my \@out;
  my \$user;
  if(\$_[0] eq '*' or \$_[0] eq ''){
   \$user='';
  }else{
   \$user=\$_[0];
  }
  shift \@_;
  foreach my \$i (\@_){
    push \@out, \&cleosupport::get_mod_setting(\$p,\$user,\$i);
  }
  return \@out;
}

# just fool-protect
sub alarm(){
  cleosupport::qlog("Module tries to call alarm function.\n", &cleovars::LOG_ERR());
}
# NEXT LINE 318
_PROLOG

#sub min( $$ ) {
#  return ( $_[0] > $_[1] ) ? $_[1] : $_[0];
#}

sub qlog( $;$ ) {
    return if ( $_[1] > $log_level );
    $log_time = localtime(time);
    $STATUS->printf(
        '[%s] %s%-8s:%s %s',
        $log_time,
        ( $dying == 1 ) ? 'x' : '',
        $log_prefix . $cluster_name,
        $log_prefixes[ $_[1] ],
        $global_log_prefix . $_[0] );
}

sub slog( $ ) {
    $log_time = localtime(time);
    $SHORT_LOG->printf( '[%s] %-8s:%s', $log_time, $cluster_name, $_[0] );
}

sub boot_qlog( $ ) {

    #  print BOOT_LOG "[".localtime(time)."] ",$_[0];
    print "[" . localtime(time) . "] ", $_[0];
}

sub count_enabled_cpus() {
    my $ret = 0;
    for my $i ( keys(%pe) ) {
        ++$ret unless ( $pe{$i}->{blocked} );
    }
    return $ret;

    #  return scalar(keys(%pe));
}

#
# opt arg: not flush data.
#
sub close_ports(;$){
    my $noflush=shift;
    my $i;

    if ($is_master) {
        if(defined $main::LST){
            $main::LST->disconnect($noflush);
        }
#        if(defined $main::MON){
#            $main::MON->disconnect($noflush);
#        }
        if(defined $main::Client){
            $main::Client->disconnect($noflush);
        }
        foreach my $i (values(%mons)){
            if(defined ($i->{conn})){
                $i->{conn}->disconnect($noflush);
            }
        }
    }
    foreach $i ( keys(%pe_sel_method) ) {
        $pe_sel_method{$i}->{conn}->disconnect($noflush);
    }
    foreach $i ( keys(%rsh_filter) ) {
        $rsh_filter{$i}->{conn}->disconnect($noflush);
    }

}

#
# Launch the program after waiting the time interval.
# Returns immediately.
#
# Args:  interval - in secs
#        command  - cmd to run
#        uniq     - the unique identificator
# Ret:   pid if succed, 0 if not
#
#######################################################################
sub launch( $$$ ) {

    # Time_interval, command_line, uniq_id

    my ( $time, $prog, $id ) = @_;
    my ( $i,    $p );

    qlog "LAUNCH '$prog' in $time seconds\n", LOG_INFO;
    for ( $i = 0; $i < 10; ++$i ) {
        $p = fork();
        last if ( ( defined $p ) and ( $p >= 0 ) );
        select( undef, undef, undef, 0.1 );
    }
    return 0 unless defined $p;    # FAIL 8(
    return 0 if ( $p < 0 );        # FAIL 8(
    if ($p>0) {                    # successful launch
        $launch_pids{$p} = 1;
        return $p;
    }

    close_ports(1);
    close STDIN;
    open( STDIN, "</dev/null" );

    $0         = "LAUNCH";
    $SIG{PIPE} = 'Ignore';
    $SIG{CHLD} = 'Ignore';
    $SIG{USR1} = 'Ignore';
    $SIG{USR2} = 'Ignore';
    $SIG{HUP}  = 'Ignore';
    $SIG{ABRT} = 'Ignore';
    $SIG{TERM} = 'Ignore';
    $SIG{QUIT} = 'Ignore';
    $SIG{BUS}  = 'Ignore';
    $SIG{SEGV} = 'Ignore';
    $SIG{FPE}  = 'Ignore';
    $SIG{INT}  = 'Ignore';
    $SIG{ILL}  = 'Ignore';

    #   # child process
    #   for ($i=0;$i<10;++$i) {
    #     $p = fork();
    #     last if((defined $p) and ($p>0));
    #     select(undef,undef,undef,0.1);
    #   }

    exit 0 unless defined $p;

    # #  print "$cluster_name seconf pid=$p\n" if $p;
    #   exit 0 if ($p!=0);

    #  if (1 || POSIX::setsid()!=-1) {
    if ($time) {
        unlink "/tmp/cleo-launch.$id";    # delete possible symlink
        open X, ">/tmp/cleo-launch.$id" or exit(1);    # create 'lock-file'
        close X;
        sleep $time;
        exit(0)
            unless -f "/tmp/cleo-launch.$id"
            ;    # exit, if launch is not nessesary
        unlink "/tmp/cleo-launch.$id";    # delete 'lock-file'
    }
    qlog "exec '$prog'\n", LOG_INFO;
    no strict;

    #    $ENV{PATH} =~ s/:\.:/:/g;
    #    $ENV{PATH} =~ s/^\.?://;
    #    $ENV{PATH} =~ s/:\.?$//;
    $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
  
    # allow to rwx new files/dirs for owner/group
    umask(002);

    exec($prog);                        # THE CULMINATION!
                                          #  }
    qlog "Failed exec '$prog' ($@)\n", LOG_ERR;
    exit 1;
}

sub uid2user( $ ) {
    return $_[0] if ( $_[0] =~ /\D/ );
    if ( exists( $username{ $_[0] } ) ) {
        return $username{ $_[0] };
    }
    return 'nobody';
}

#
# Updates and returns $user_np_used{user}
#
# Arguments: user (undef=all users)
#
#######################################################
sub count_user_np_used( ;$ ) {
    my ( $i, $user );
    $user = shift;

    %user_np_used = ();
    foreach $i (@running) {
        if ( ref( $i->{shared} ) ne 'ARRAY' ) {
            qlog "AAAAAAAAAAAAAAAAAA!!!!! $i->{id} ("
                . ref($i)
                . ") has bad {shared}\n", LOG_ERR;
            next;
        }
        if ( !defined $user
            or $i->{user} eq $user ) {
            $user_np_used{ $i->{user} } +=
                scalar( @{ $i->{own} } ) + scalar( @{ $i->{shared} } ) +
                $i->{npextra};
        }
    }
    foreach $i (@queue) {
        if ( $i->{state} eq 'prerun' ) {
            if ( ref( $i->{shared} ) ne 'ARRAY' ) {
                qlog "AAAAAAAAAAAAAAAAAA!!!!! $i->{id} ("
                    . ref($i)
                    . ") has bad {shared} (pre)\n", LOG_ERR;
                next;
            }
            if ( !defined $user
                or $i->{user} eq $user ) {
                $user_np_used{ $i->{user} } +=
                    scalar( @{ $i->{own} } ) + scalar( @{ $i->{shared} } ) +
                    $i->{npextra};
            }
        }
    }
    return $user_np_used{$user} if ( defined $user );
}

#
#  returns count of runned and prerunned
#  tasks of given user
#  (all if arg is undef or '')
#
#####################################
sub count_runned( $ ){
    my ( $ret, $i, $user );
    $user = shift;
    $ret=0;

    foreach $i (@running) {
        ++$ret if ( !defined $user
                    or $i->{user} eq $user );
    }
    foreach $i (@queue) {
        if($i->{state} eq 'prerun'){
            ++$ret if ( !defined $user
                        or $i->{user} eq $user );
        }
    }
    return $ret;
}

#
#  returns count of runned tasks of given user
#  (all if arg is undef or '')
#
#####################################
sub count_really_runned( $ ){
    my ( $ret, $i, $user );
    $user = shift;
    $ret=0;

    foreach $i (@running) {
        ++$ret if ( !defined $user
                    or $i->{user} eq $user );
    }
    return $ret;
}

#
# Returns true, if user is admin for given cluster (if cluster is empty - for entire system)
# Arguments: user, cluster
#
#################################
sub isadmin($;$ ) {
    my ( $user, $cluster ) = @_;

    return 1 if ( $user eq '__internal__' );
    return 1 if ( $user eq '__scheduler__' );
    return 1 if ( $rootisadm && ( $user eq 'root' ) );

    $user = uid2user($user);
    $cluster ||= get_setting('root_cluster_name');

#  qlog "Testing adm ($user) in (".join(';',@{$global_settings{admins}}).")\n", LOG_DEBUG;
    if (is_in_list( $user, $global_settings{admins} )
        || ($cluster
            ? is_in_list( $user, $cluster_settings{$cluster}->{admins} )
            : 0 )
        ) {
        return 1;
    }

    #  qlog "NOT!\n", LOG_DEBUG;
    return 0;
}

#
# Returns true, if user can debug given cluster (if cluster is empty - for entire system)
# Arguments: user, cluster
#
#################################
sub candebug($;$ ) {
    my ( $user, $cluster ) = @_;

    return 1 if ( $user eq '__internal__' );
    return 1 if ( $rootisadm && ( $user eq 'root' ) );

    $user = uid2user($user);
    $cluster ||= get_setting('root_cluster_name');
    if (is_in_list( $user, $global_settings{debug_users} )
        || ($cluster
            ? is_in_list( $user, $cluster_settings{$cluster}->{debug_users} )
            : 0 )
        ) {
        return 1;
    }
    return 0;
}

sub daemonize() {
    my ( $pid, $i );

    $daemonizing = 1;

    for ( $i = 0; $i < 10; ++$i ) {
        $pid = fork();
        if ( defined $pid ) {
            last if $pid >= 0;
        }
    }
    unless ( defined $pid ) {
        qlog "Cannot daemonize! So die...\n", LOG_ALL;
        save_n_exit();
    }
    unless ( $pid >= 0 ) {
        qlog "Cannot daemonize! So die...\n", LOG_ALL;
        save_n_exit();
    }
    exit(0) if $pid > 0;
    if ( POSIX::setsid() != -1 ) {
        $daemonizing = 0;
        return;
    }
    qlog "Cannot start session for daemonizing! So die...\n", LOG_ALL;
    save_n_exit();
}    # daemonize
##################################################################################
##################################################################################
##################################################################################
sub shuffle_array {    #fisher-yetz algorithm
                       # array is passed by reference!
    my $array = shift;
    my $i;

    return if ( scalar( @$array < 1 ) );
    @$i     = sort(@$array);
    @$array = @$i;
    for ( $i = @$array; --$i; ) {
        my $j = int rand( $i + 1 );
        next if $i == $j;
        @$array[ $i, $j ] = @$array[ $j, $i ];
    }
}

sub shuffle_only_hosts {

    # array is passed by reference!
    my $array = shift;

    my ( %tmparray, $a, $b );
    my ( $i,        $j, $host, $tmp, @sizes, @names, $size );

    return if ( scalar( @$array < 1 ) );

    shuffle_array($array);
    foreach $i (@$array) {
        ( $a, $b ) = ( $i =~ /^([^:]+)\:(\S+)/ );
        push @{ $tmparray{$a} }, $b;
    }

    foreach $i ( keys(%tmparray) ) {
        $size = scalar( @{ $tmparray{$i} } );
        for ( $j = 0; $j < scalar(@sizes); ++$j ) {
            last if $size >= $sizes[$j];
        }
        splice @sizes, $j, 0, scalar( @{ $tmparray{$i} } );
        splice @names, $j, 0, $i;
    }
    @$array = ();
    foreach $i (@names) {
        foreach $j ( @{ $tmparray{$i} } ) {
            push @$array, "$i:$j";
        }
    }
}    # shuffle_only_hosts

sub shuffle_hosts_alone {

    # array is passed by reference!
    my $array = shift;

    return if ( scalar( @$array < 1 ) );
    shuffle_array($array);

    my ( $i, $host, $id );
    my ( @new, %uniqs );

    for ( $i = 0; $i < $#$array + 1; ++$i ) {
        ( $host, $id ) = ( $array->[$i] =~ /^(\S+?)\:(\S+)/ );
        if ( exists $uniqs{$host} ) {
            push @new, $array->[$i];
        } else {
            $uniqs{$host} = $id;
        }
    }
    @$array = ();
    foreach $i ( keys(%uniqs) ) {
        push @$array, "$i:$uniqs{$i}";
    }
    push @$array, @new;

    qlog "Shuffle_hosts_alone: " . join( ',', @$array ) . "\n", LOG_DEBUG;
}    # shuffle_hosts_alone

#
#  Insert into sorted (accent) array new time
#
#  Args:  array, new element
#
##########################################
sub add_sorted_time($$){
  my ($array,$item)=@_;
  my $end=scalar(@$array);
  my $start=0;
  my $i;

  while($start<$end-1){
    $i=($start+$end)>>1;
    if($item->{time} < $array->[$i]->{time}){
      $end=$i;
    }
    else{
      $start=$i;
    }
  }
  if($item->{time} < $array->[$start]->{time}){
    $end=$start;
  }
  splice(@$array,$end,0,$item);
}

#
#  Calculates estimate execution times
#
#  Args: free np
#        new item (hash reference, with 'time' field)
#
############################################
sub calculate_estimated($){
  my $free=$_[0];
  my ($i,$cursor);
  my (%end_times, @sort_end_times);

  # remember running tasks
  foreach $i (@running){
    $end_times{$i->{id}}->{time}=$i->{timelimit};
    $end_times{$i->{id}}->{np}=$i->{np};
    $end_times{$i->{id}}->{npextra}=$i->{npextra};
  }

  foreach $i (@queue){
    $i->{estimated_run}=0;
  }

  # make 'index'...
  #@sort_end_times = sort {$a->{time} <=> $b->{time}} keys(%end_times);
  for $i (keys(%end_times)){
    add_sorted_time(\@sort_end_times, $end_times{$i});
  }

  # replay all
  while(@sort_end_times>0){
    # first task is ended
    $free+=$sort_end_times[0]->{np}+$sort_end_times[0]->{npextra};

    # can we run new task?
    foreach $i (@queue[$cursor .. $#queue]){
      # skip already taken in account
      next if($i->{estimated_run}>0); #!!!??? is it needed ???

      # too big task. go to next end time...
      last if($i->{np}>$free);

      # 'execute' task
      $free-=$i->{np};
      $i->{estimated_run}=$sort_end_times[0]->{time};

      # is there more tasks to check?
      return if($cursor>=$#queue);

      # add new end time
      $end_times{$i->{id}}->{time}=$i->{timelimit}+$i->{estimated_run};
      $end_times{$i->{id}}->{np}=$i->{np};
      $end_times{$i->{id}}->{npextra}=$i->{npextra};

      add_sorted_time(\@sort_end_times, $end_times{$i->{id}});
    }
    shift @sort_end_times;
  }
}

#################################################################################################
sub get_user_argv0_by_pid( $ ) {    # arg = pid

    my $pid = shift;
    my $cmdline;
    my @cmdline;

    #  my $uid;
    local $/;
    undef $/;

    open( PROC, "/proc/$pid/cmdline" ) or return [ 0, 0 ];
    $cmdline = <PROC>;
    @cmdline = split( /\0/, $cmdline );
    close PROC;

    $/ = "\n";
    open( PROC, "/proc/$pid/status" ) or return [ 0, 0 ];
    while (<PROC>) {
        if (/^Uid:\s+(\d+)/) {
            close PROC;

            #      $uid=getpwuid($1);
            return [ $1, $cmdline[0] ];
        }
    }
    close PROC;
    return [ 0, 0 ];
}    # get_user_argv0_by_pid

# sub eval_q_params($$$$$$$$ ){
#   #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  PROFILE !!!!!!!!!!!!!!!!!!!!!!!!!!
#   # refresh and write parameters for user $UID.
#   my ($user,$nice,$force_proc,$force_host,$outfile,$repfile,$tmpdir,$com_line)=@_;
#   #  load_user_conf($user);
#   #  qlog "*** $user\n";

#   $user=uid2user($user);
#   qlog "EXECLINE0: $$com_line\n", LOG_DEBUG;
#   $$nice       = 0 unless defined $$nice;
#   $$force_proc = '' unless defined $$force_proc;
#   $$force_host = '' unless defined $$force_host;
#   $$outfile    = get_setting('outfile',$user,$args->{profile}) unless defined $$outfile;
#   $$repfile    = get_setting('repfile',$user,$args->{profile}) unless defined $$repfile;
#   $$tmpdir     = get_setting('temp_dir',$user,$args->{profile}) unless defined $$tmpdir;
#   $$com_line   = get_setting('exec_line',$user,$args->{profile}) unless defined $$com_line;
#   qlog "EXECLINE: $$com_line\n", LOG_DEBUG;

# }                               # eval_q_params

#################################################################################################

sub new_count() {
    my $ret = $tcount;
    $tcount = 1 if ( ++$tcount > get_setting('max_count') );
    return $ret;
}

sub new_hash() {
    my $ret = $hashcount;
    $hashcount = 1 if ( ++$hashcount > get_setting('max_count') );
    return $ret . "_$cluster_name";
}

{
    my $count2 = 0;

    sub new_count2() {
        $count2 = 1 if ( ++$count2 > get_setting('max_count') );
        return $count2;
    }
};

sub push_to_queue( $ ) {
    my $entry = $_[0];

    my ( $b, $ret, $exe, $args, $sexe, $p, $max );

    # check for correctness...
    if ( !defined $entry->{task_args}
        or $entry->{np}   eq ''
        or $entry->{user} eq '' ){
            qlog "PUSH_TO_QUEUE: error(np=$entry->{np}, user=$entry->{user})", LOG_ERR;
            return 0;
    }

    $entry->{priority} =
        get_setting( 'priority', $entry->{user}, $entry->{profile} )
        if ( $entry->{priority} eq '' );

    qlog "Priority is set to '$entry->{priority}'\n", LOG_DEBUG;

    # old style
#    if(!defined $entry->{task_args}){
#        $entry->{task} =~ tr/\|\>\<\&\n\r/::::/d;
#        @{$entry->{task_args}} = split(/\s+/, $entry->{task});

#        $b = $entry->{task} . "\0";
#    }


    if ( $entry->{path} eq '' ) {
        $entry->{path} = $user_home{ $entry->{user} };
    } elsif ( $entry->{path} !~ m{^/} ) {
        $entry->{path} = "$user_home{$entry->{user}}/$entry->{path}";
    }

#    ( $p, $sexe, undef, $args ) =
#        ( $b =~ m{(\S*?)([^/\0\s]+)(\0|\s+)(.*\0)?} );
#    $sexe =~ s/\0//;
#    $args =~ s/\0//;
    $exe=$entry->{task_args}->[0];
    $max=$#{$entry->{task_args}};
#    $args='\''.join('\' \'',$entry->{task_args}->[1..$max]).'\'';

    if($exe =~ m{(.*?)([^/\0]+)$}){
        $entry->{sexe} = $2;
    }
    else{
        $entry->{sexe} = $exe;
    }

    qlog "PPP: '$p'; '$entry->{path}'; '$entry->{task_args}->[0]'\n", LOG_DEBUG2;

    #if ( $p !~ m{^/} ) {
    #    $p = "$entry->{path}/$p";
    #}
    #$p .= '/';
    #$p =~ s[(/{2,})][/]g;
    #$p =~ s[(/\./)][/]g;

    $entry->{owner}     ||= $cluster_name;
    $entry->{lastowner} ||= $cluster_name;
    $entry->{timelimit} ||=
        get_setting( 'max_time', $entry->{user}, $entry->{profile},
        $entry->{owner} );

    qlog "TimeLim: $entry->{timelimit}\n", LOG_DEBUG;

#    qlog "PARSE: '$entry->{task}' -> '$p';'$sexe';'$args'\n", LOG_DEBUG;
#    $exe = $p . $sexe;

    if ( $entry->{nice} eq '' ) {
        $entry->{nice} =
            get_setting( 'nice', $entry->{user}, $entry->{profile} );
    }
    if ( $entry->{gummy} eq '' ) {
        $entry->{gummy} = ( ( $entry->{owner} eq $cluster_name ) ? 0 : 1 );
    }
    if ( $entry->{force_proc} eq '' ) {
        $entry->{force_proc} =
            get_setting( 'force_proc', $entry->{user}, $entry->{profile} );
    }
    if ( $entry->{force_host} eq '' ) {
        $entry->{force_host} =
            get_setting( 'force_host', $entry->{user}, $entry->{profile} );
    }
    if ( $entry->{outfile} eq '' ) {
        $entry->{outfile} =
            get_setting( 'outfile', $entry->{user}, $entry->{profile} );
    }
    if ( $entry->{repfile} eq '' ) {
        $entry->{repfile} =
            get_setting( 'repfile', $entry->{user}, $entry->{profile} );
    }
    if ( $entry->{temp_dir} eq '' ) {
        $entry->{temp_dir} =
            get_setting( 'temp_dir', $entry->{user}, $entry->{profile} );
    }
    $entry->{com_line} =
        get_setting( 'exec_line', $entry->{user}, $entry->{profile} );

    $entry->{id} = $ret = new_count();
    $entry->{task}     = '\''.join('\' \'',@{$entry->{task_args}}).'\'';
    qlog "Push as $ret $entry->{user} $entry->{np} ".
         "($entry->{priority}) $entry->{task} ($entry->{com_line})\n",
         LOG_INFO;

    $entry->{dir}      = $entry->{path};
    $entry->{exe}      = $exe;
    #$entry->{sexe}     = $sexe;
    #$entry->{args}     = $args;
    $entry->{status}   = 0;
    $entry->{state}    = 'queued';
    $entry->{qtype}    = NATIVE_QUEUE;
    $entry->{core}     = 0;
    $entry->{signal}   = 0;
    $entry->{reserved} = 0;
    $entry->{own}      = [];
    $entry->{shared}   = [];
    $entry->{extranodes} = [];
    $entry->{added}    = $last_time;
    $entry->{blocks}   = [];

    $entry->{is_own} = (($entry->{lastowner} eq $cluster_name )?1:0);

    my $i;
    for ( $i = 0; $i < @queue; ++$i ) {

        last if ( $queue[$i]->{priority} < $entry->{priority} );
    }
    splice( @queue, $i, 0, $entry );

    $childs_info{$ret} = $entry;

    $ids{$ret} = $entry;
    qlog "NEW ID=$ret [$i]\n", LOG_INFO;

    qlog "Autoblocks: " . join( ";", keys(%autoblock) ) . ";\n", LOG_DEBUG;
    qlog "Autononblocks: " . join( ";", keys(%autononblock) ) . ";\n",
        LOG_DEBUG;
    qlog "All_autoblock: $all_autoblock;\n", LOG_DEBUG;
    if ( exists( $autoblock{ $entry->{user} } )
        or ( $all_autoblock && !exists( $autononblock{ $entry->{user} } ) ) )
    {
        if ( isadmin( $entry->{user} ) ) {
            qlog "Admin ($entry->{user}) task would not autoblock\n",
                LOG_INFO;
        } else {
            qlog "Autoblocking...\n", LOG_INFO;
            block_task( $ret, 1, '__internal__', 'autoblock' );
        }
    }
    save_state($cluster_name);

    $q_change = 1;
    return $ret;
}    # push_to_queue

sub REAPER {
    my $child;
    while ( ( $child = waitpid( -1, &WNOHANG ) ) > 0 ) {
        qlog "SIGCHLD: $child ($?)\n", LOG_DEBUG;
        if ($reaping2) {
            push @pre_reaped1,   $child;
            push @pre_reapcode1, $?;
        } else {
            push @pre_reaped2,   $child;
            push @pre_reapcode2, $?;
        }
    }
    qlog "Signal processing done\n", LOG_DEBUG;
    if ($reaping) {
        qlog "Reaping while reaper.\n", LOG_DEBUG;
        $new_reaped = 1;
    } else {
        push @reaped,   @pre_reaped2;
        push @reapcode, @pre_reapcode2;
        @pre_reaped2   = ();
        @pre_reapcode2 = ();
    }
    qlog "1st reaper done\n", LOG_DEBUG;
    $SIG{CHLD} = \&REAPER;    # still loathe sysV
}    # REAPER

sub do_reap {
    my ( $child, $tmp, $code );
    $reaping = 1;
MAIN_REAPER:
    while ( $child = shift @reaped ) {
        $code = shift @reapcode;
        qlog "SIGNAL chld: pid=$child, code=$code\n", LOG_INFO;
        foreach $tmp ( keys(%child_pids) ) {
            if ( $tmp == $child ) {

                # subluster died!!!
                qlog "Subcluster $child_pids{$tmp} died!\n", LOG_ERR;
                on_cluster_die( $child_pids{$tmp} );
                if ( $cluster_name eq $child_pids{$tmp} ) {
                    return;    # this is recreated subcluster!!!
                } else {
                    next MAIN_REAPER;
                }
            }
        }
        foreach $tmp ( keys(%pe_sel_method) ) {
            if ( $child == $pe_sel_method{$tmp}->{pid} ) {
                qlog "Info: pe_sel_method '$tmp' has died\n", LOG_ERR;
                next MAIN_REAPER;
            }
        }
        foreach $tmp ( keys(%rsh_filter) ) {
            if ( $child == $rsh_filter{$tmp}->{pid} ) {
                qlog "Info: rsh_filter '$tmp' has died\n", LOG_ERR;
                next MAIN_REAPER;
            }
        }
        foreach $tmp ( keys(%pids) ) {
            if ( $child == $pids{$tmp} ) {
                if ( exists $childs_info{$tmp} ) {
                    push @dead, $tmp;
                    $childs_info{$tmp}->{status} = $code >> 8;
                    $childs_info{$tmp}->{core}   = ( $code & 128 );
                    $childs_info{$tmp}->{signal} = ( $code & 127 );
                    qlog "SIGCHLD: PID=$child; ID=$tmp\n", LOG_DEBUG;
                    next MAIN_REAPER;
                } else {
                    qlog
                        "Task is already deleted, but I've got SIGCHLD from it...($tmp/$child)\n",
                        LOG_WARN;
                }
            }
        }
        foreach $tmp ( keys(%launch_pids) ) {
            if ( $child == $tmp ) {
                delete $launch_pids{$tmp};
                qlog "Launch dead ($tmp)\n", LOG_DEBUG;
            }
            next MAIN_REAPER;
        }
        qlog "Not my child dead??? ($child)\n", LOG_DEBUG;
        $check_running = 1 if $run_fase == 0;
    }

    #  qlog "2nd reaping done.\n";
    if ($new_reaped) {
        push @reaped,   @pre_reaped1;
        push @reapcode, @pre_reapcode1;
        @pre_reaped1   = ();
        @pre_reapcode1 = ();
        $reaping2      = 1;
        push @reaped,   @pre_reaped2;
        push @reapcode, @pre_reapcode2;
        @pre_reaped1   = ();
        @pre_reapcode1 = ();
        $reaping2      = 0;
        $new_reaped    = 0;
        qlog "New reaped pushed\n", LOG_DEBUG;
    }
    $reaping = 0;
}    # do_reap

sub crash() { qlog "CRASH!\n"; exit(1); }

sub kill_running {
    my ( $tmp, $ch );

    exit(0) if $daemonizing;
    $SIG{CHLD} = 'Ignore';

    for $ch (@running) {
        $tmp = get_setting( 'kill_script', $ch->{user}, $ch->{profile} );
        if ( $tmp ne '' ) {
            undef %subst_args;
            subst_task_prop( \$tmp, $ch, $ch->{time}, 0, 0 );
            launch( 0, $tmp, '' );
        }
        kill_tree( 9, $ch->{pid} );
    }
}    # kill_running

sub kill_supports() {
    my $tmp;
    foreach $tmp ( keys(%pe_sel_method) ) {
        kill_tree( 9, $pe_sel_method{$tmp}->{pid} );
    }
    foreach $tmp ( keys(%rsh_filter) ) {
        kill_tree( 9, $rsh_filter{$tmp}->{pid} );
    }
}    # kill_supports

sub save_n_exit {
    exit(0) if $daemonizing;
    $SIG{CHLD} = 'Ignore';
    $SIG{ $_[0] } = \&crash;

    qlog "Server killed by signal $_[0].\n";
    slog "Server killed by signal $_[0].\n";

    #  print "SIGNAL SIG$_[0] ($cluster_name)\n";

    main::stop_scheduler();
    &save_state($cluster_name);
    qlog "State is probably saved. I am exiting now...\n";

    #  print "SIGNAL processing ($cluster_name)\n";
    main::kill_mons() if ( get_setting('kill_mons_on_exit') );
    #kill_running();
    kill_supports();
    
    flush_mails(1);
    sleep 2;    # let all packets go out...
    qlog "Bye!\n";

    #  print "SIGNAL processing done ($cluster_name)\n";
    exit(0);
}    # save_n_exit

sub pack_value( $ ) {
    my ( $tmp, $i );

    if ( ref( $_[0] ) eq 'ARRAY' ) {
        $tmp = "\0A";
        for ( $i = 0; $i < scalar( @{ $_[0] } ); ++$i ) {
            $tmp .= pack_value( ${ $_[0] }[$i] );
        }
        $tmp .= "\0E";
        return $tmp;
    } elsif ( ref( $_[0] ) eq 'HASH' ) {
        $tmp = "\0H";
        foreach $i ( keys( %{ $_[0] } ) ) {
            $tmp .= "$i" . pack_value( $_[0]->{$i} );
        }
        $tmp .= "\0E";
        return $tmp;
    } elsif ( ref( $_[0] ) eq 'REF' ) {
        return undef;
    } elsif ( ref( $_[0] ) eq 'CODE' ) {
        return undef;
    } elsif ( ref( $_[0] ) eq 'GLOB' ) {
        return undef;
    } elsif ( $_[0] =~ y/\0\n\r// ) {
        $tmp = pack( 'u', $_[0] );
        $tmp =~ s/\n//g;
        return "\0U${tmp}\0E";
    }
    return "\0S" . $_[0] . "\0E";
}

#
#  Unpacks string encoded by pack_value
#  Args:
#         1 - reference to result variable (must be scalar!)
#         2 - string to decode
#         3 - (optional) index to start from
#  Ret:
#         new index in source string (just after final \0[E])
#
#######################################################
sub unpack_value( $$;$ ) {
    my ( $res, $val, $index ) = @_;
    my ( $tmp, $i2, $my_res );

    $index ||= 0;
    undef $$res;
    $tmp = substr( $val, $index, 1 );
    qlog( "UPCK: '" . substr( $val, $index ) . "'\n", LOG_DEBUG )
        if $debug{pc};
    if ( $tmp eq "\0" ) {    # complex type
        ++$index;
        $tmp = substr( $val, $index, 1 );
        ++$index;
        if ( $tmp eq 'E' ) {    #end mark
            return $index;
        } elsif ( $tmp eq "A" ) {    #array
            @$my_res = ();
            for ( ;; ) {
                if ( substr( $val, $index, 2 ) eq "\0E" ) {    #end
                    $index += 2;
                    last;
                }
                $index = unpack_value( \$tmp, $val, $index );

                #        last unless defined $tmp;
                push @$my_res, $tmp;
            }
            qlog( "Unpacked array\n", LOG_DEBUG ) if $debug{pc};
        } elsif ( $tmp eq "H" ) {    #hash
            my $key;
            %$my_res = ();
            for ( ;; ) {
                if ( substr( $val, $index, 2 ) eq "\0E" ) {    #end
                    $index += 2;
                    last;
                }
                $i2 = index( $val, "\0", $index );
                $i2 = length($val)
                    if ( $i2 < 0 );    #Ooops! Not found terminator
                $key = substr( $val, $index, $i2 - $index );

                $index = unpack_value( \$tmp, $val, $i2 );

                #        last unless defined $tmp;
                $my_res->{$key} = $tmp;
            }
            qlog( "Unpacked hash " . join( ';', keys(%$my_res) ) . "\n",
                LOG_DEBUG )
                if $debug{pc};
        } elsif ( $tmp eq "U" ) {    #uuencode
            $i2 = index( $val, "\0E", $index );
            $i2 = length($val) if ( $i2 < 0 );    #Ooops! Not found terminator
            $my_res = unpack( 'u', substr( $val, $index, $i2 - $index ) );
            $index = $i2 + 2;
            qlog( "Unpacked uu '$my_res'\n", LOG_DEBUG ) if $debug{pc};
        } elsif ( $tmp eq "S" ) {                 #simple scalar
            $i2 = index( $val, "\0E", $index );
            $i2 = length($val) if ( $i2 < 0 );    #Ooops! Not found terminator
            $my_res = substr( $val, $index, $i2 - $index );
            $index = $i2 + 2;
            qlog( "Unpacked '$my_res'\n", LOG_DEBUG ) if $debug{pc};
        } else {
            qlog "While decoding in pos $index '$val'\n", LOG_ERR;
            $my_res = '';
        }
    } else {    #simple scalar
        qlog "Malformed scalar! (" . substr( $val, $index, -1 ) . "\n",
            LOG_ERR;
    }
    $$res = $my_res;
    return $index;
}

sub save_line($$ ) {
    my ( $k, $v ) = @_;
    my $e = pack_value($v);
    qlog( "Packed $k as $e\n", LOG_DEBUG ) if $debug{pc};
    print SAV "$k: $e\n";
}

sub load_line($ ) {
    my $e;
    unpack_value( \$e, $_[0] );
    qlog( "Unpacked $_[0]\n", LOG_DEBUG ) if $debug{pc};
    return \$e;
}

# check element presence in given list
#
# Args: 
#    element
#    list ref
#
#  Ret:
#     1 = presented
#     0 = not
#############################################################
sub is_in_list( $$ ) {
    my $i;

    foreach $i ( @{ $_[1] } ) {
        return 1 if ( $i eq $_[0] );
    }
    return 0;
}

#
#  create xml-report
#
#  arg: fname - filename to write to
#
##################################################
sub save_xml_state( $ ){
    my $fname   = $_[0];
    my $XML;
    my ($newfile,$filename,$writer);

    my ( @free_own, @free_sh, $free_total, $free_shared_total, $id, $status,
        $count, $out, $blocked, $prevname, $cpu);
    my ( $i, $j, $k, $sec, $min, $day, $hr, $s, $tmp, $b, $w );

    eval{
        ($XML, $filename) = tempfile('cleoXML.XXXXXX', DIR =>'/tmp' );
        $writer = new XML::Writer(OUTPUT=>$XML, ENCODING=>'utf-8',
                                  DATA_MODE=>1, DATA_INDENT=>2);

        count_free( \@free_own, \%own );
        count_free( \@free_sh,  \%shared );
        $free_shared_total = max( 0, @free_sh - $reserved_shared );
        $free_total = $free_shared_total + @free_own;
        $blocked=scalar(grep($_->{blocked}, values(%pe)));

        $writer->xmlDecl();
        #$XML->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        
        $writer->startTag('cleo-state',
                          'last-update'=>"$last_time",
                          'queue'=>"$cluster_name");
        #$XML->print("<cleo-state last-update=\"$last_time\" queue=\"$cluster_name\">\n");
        $writer->startTag('cpus');
        $writer->startTag('cpu_statistics');
        $writer->dataElement('total-free',$free_total);
        #$XML->print("<cpus>\n <cpu_statistics>\n  <total-free>$free_total</total-free>\n");
        $writer->dataElement('shared-free',$free_shared_total);
        #$XML->print("  <shared-free>$free_shared_total</shared-free>\n");
        $writer->dataElement('shared-reserved',$reserved_shared);
        #$XML->print("  <shared-reserved>$reserved_shared</shared-reserved>\n");

        $writer->dataElement('total-number',scalar(keys(%pe)));
#        $XML->print("  <total-number>".scalar(keys(%pe))."</total-number>\n");
        $writer->dataElement('total-own',scalar(keys(%own)));
#        $XML->print("  <total-own>".scalar(keys(%own))."</total-own>\n");
        $writer->dataElement('total-shared',scalar(keys(%shared)));
#        $XML->print("  <total-shared>".scalar( keys(%shared) )."</total-shared>\n");

        $writer->dataElement('own-free',scalar(@free_own));
#        $XML->print("  <own-free>".scalar(@free_own)."</own-free>\n");

        $writer->dataElement('blocked-count',$blocked);
#        $XML->print("  <blocked-count>$blocked</blocked-count>\n");
        $blocked=scalar(grep($_->{blocked}, values(%own)));
        $writer->dataElement('own-blocked',$blocked);
#        $XML->print("  <own-blocked>$blocked</own-blocked>\n");
        $blocked=scalar(grep($_->{blocked}, values(%shared)));
        $writer->dataElement('shared-blocked',$blocked);
#        $XML->print("  <shared-blocked>$blocked</shared-blocked>\n");

        $tmp=0;   # total
        $b=0;     # own
        $w=0;     # shared
        for $i ( keys(%pe) ) {
            my $p = $pe{$i};
            next if $p->{blocked};
            if ( scalar( keys( %{ $p->{ids} } ) ) >= $p->{max} ){
                ++$tmp;
                if(exists($shared{$i})){
                    ++$w;
                }else{
                    ++$b;
                }
            }
        }
        $writer->dataElement('total-busy',$tmp);
#        $XML->print("  <total-busy>$tmp</total-busy>\n");
        $writer->dataElement('own-busy',$b);
#        $XML->print("  <own-busy>$b</own-busy>\n");
        $writer->dataElement('shared-busy',$w);
#        $XML->print("  <shared-busy>$w</shared-busy>\n");

        $writer->endTag('cpu_statistics');
#        $XML->print(" </cpu_statistics>\n");

    ###################  NODES  ###########################################
        $prevname='';
        foreach $i (sort(keys(%own),keys(%shared))){
            $b = $pe{$i}->{blocked}?1:0;
            $i =~ /^(.*):(.*)$/;
            if($1 ne $prevname){
                $writer->endTag('node') if $prevname ne '';
#                $XML->print(" </node>\n") if $prevname ne '';
                $writer->startTag('node', 'nodename'=>$1);
#                $XML->print(" <node nodename=\"$1\">\n");
                $prevname = $1;
            }
            my $t=exists($shared{$i})?'shared':'own';
            $w=exists($shared{$i})?0:1;
            $writer->startTag('cpu', 'id'=>$2, 'type'=>$t,
                              'own'=>$w, 'blocked'=>$b);
#            $XML->print("   <cpu id=\"$2\" type=\"$t\" own=\"$w\" blocked=\"$b\">\n");
            $writer->setDataMode(0);
            $writer->startTag('blocked');
            $writer->characters($b);
#            $XML->print("    <blocked>$b");
            if(exists($blocked_pe_reasons{$i})){
                foreach $j (keys( %{ $blocked_pe_reasons{$i} } )){
                     $writer->startTag('block_reason');
                        $writer->characters($j);
                     $writer->endTag('block_reason');
#                    $XML->print("<block_reason>$j</block_reason>");
                }
            }
            $writer->endTag('blocked');
            $writer->setDataMode(1);
            $writer->setDataIndent(2);
#            $XML->print("</blocked>\n");
##            $b=exists($shared{$i})?0:1;
##            $XML->print("    <own>$b</own>\n");
            $writer->endTag('cpu');
#            $XML->print("   </cpu>\n");
        }
        $writer->endTag('node') if $prevname ne '';
#        $XML->print(" </node>\n") if $prevname ne '';

    ######################  CPUS  #########################################
        $writer->endTag('cpus');
        $writer->startTag('tasks');
        $writer->startTag('tasks_statistics');
#        $XML->print("</cpus>\n<tasks>\n <tasks_statistics>\n");
        $i=scalar(@running) + scalar(@foreign) + scalar(@pending) + scalar(@queue);
        $writer->dataElement('tasks-total',$i);
#        $XML->print("  <tasks-total>$i</tasks-total>\n");
        $i=scalar(@running);
        $writer->dataElement('tasks-running',$i);
#        $XML->print("  <tasks-running>$i</tasks-running>\n");
    ##    $i = scalar(@foreign) + scalar(@pending) + scalar(@queue);
    ##    $XML->print(" <tasks-queued>$i</tasks-queued>\n");

        $writer->dataElement('tasks-prerun',0+grep( $_->{state} eq 'prerun', @queue));
#        $XML->print("  <tasks-prerun>".(0+grep( $_->{state} eq 'prerun', @queue)).
#                "</tasks-prerun>\n");
        $writer->dataElement('tasks-blocked',0+grep( $_->{blocked}!=0, @queue));
#        $XML->print("  <tasks-blocked>".(0+grep( $_->{blocked}!=0, @queue)).
#                "</tasks-blocked>\n");
        $writer->dataElement('tasks-queued',0+grep( $_->{state} eq 'queued', @queue));
#        $XML->print("  <tasks-queued>".(0+grep( $_->{state} eq 'queued', @queue)).
#                "</tasks-queued>\n");
        $writer->dataElement('tasks-completition',0);
#        $XML->print("  <tasks-completion>0</tasks-completion>\n");

        $writer->startTag('allautoblocks', 'on'=>$all_autoblock);
#        $XML->print("  <allautoblocks on=\"$all_autoblock\">\n");

        $writer->startTag('autoblocks');
#        $XML->print("   <autoblocks>\n");
        foreach $i (keys(%autoblock)){
            $writer->dataElement('user',$i);
            #$XML->print("   <user>$i</user>\n");
        }
        $writer->endTag('autoblocks');
#        $XML->print("   </autoblocks>\n");

        $writer->startTag('nonautoblocks');
#        $XML->print("   <nonautoblocks>\n");
        foreach $i (keys(%autononblock)){
            $writer->dataElement('user',$i);
#            $XML->print("    <user>$i</user>\n");
        }
        $writer->endTag('nonautoblocks');
#        $XML->print("   </nonautoblocks>\n");

        $writer->endTag('allautoblocks');
#        $XML->print("  </allautoblocks>\n");

        $writer->emptyTag('mode', 'raw-value'=>$mode,
                          'run'=>($mode & MODE_RUN_ALLOW )?'1':'0',
                          'queue'=>($mode & MODE_QUEUE_ALLOW )?'1':'0',
                          'autorestart'=>($mode & AUTORESTART )?'1':'0');
#        $XML->print("  <mode raw-value=\"$mode\"");
#        $XML->print(' run="'.(($mode & MODE_RUN_ALLOW )?'1':'0').'"');
#        $XML->print(' queue="'.(($mode & MODE_QUEUE_ALLOW )?'1':'0').'"');
#        $XML->print(' autorestart="'.(($mode & AUTORESTART )?'1':'0')."\"/>\n");

        $writer->startTag('time-restrictions', 'next'=>$next_restriction_time);
#        $XML->print("  <time-restrictions next=\"$next_restriction_time\">\n");
        foreach $i (@time_restrictions){
            $writer->startTag('restriction');
            $writer->dataElement('count',$i->{count});
#            $XML->print("   <restriction>\n   <count>$i->{count}</count>\n");
            $writer->dataElement('allow',$i->{allow});
#            $XML->print("    <allow>$i->{allow}</allow>\n");
            $writer->dataElement('start-every',$i->{timeb_every});
#            $XML->print("    <start-every>$i->{timeb_every}</start-every>\n");
            $writer->dataElement('end-every',$i->{timee_every});
#            $XML->print("    <end-every>$i->{timee_every}</end-every>\n");
            $writer->dataElement('start',$i->{timeb});
#            $XML->print("    <start>$i->{timeb}</start>\n");
            $writer->dataElement('end',$i->{timee});
#            $XML->print("    <end>$i->{timee}</end>\n");
            $writer->startTag('users');
#            $XML->print("    <users>\n");
            foreach $j (split(/\s+/,$i->{users})){
                $writer->dataElement('name',$j);
#                $XML->print("     <name>$j</name>\n");
            }
            $writer->endTag('users');
            $writer->endTag('restriction');
#            $XML->print("    </users>\n   </restriction>\n");
        }
        $writer->endTag('time-restrictions');
#        $XML->print("  </time-restrictions>\n");

        $writer->endTag('tasks_statistics');
#        $XML->print("</tasks_statistics>\n");

    ###################### SAVE TASKS  #########################################
        for $i ( @running, @foreign, @pending, @queue ) {
            $id = $i->{id};
            my $own=($i->{owner} eq $cluster_name)?1:0;
            $writer->startTag('task', 'id'=>$id, 'priority'=>$i->{priority},
                              'state'=>$i->{state}, 'own'=>$own,
                              'queue'=>$i->{queue});
#            $XML->print(" <task id=\"$id\" priority=\"$i->{priority}\"".
#           " state=\"$i->{state}\" own=\"$own\" queue=\"$i->{queue}\">\n");

            if ( ref( $i->{blocks} ) eq 'ARRAY' ) {
                foreach $j (@{$i->{blocks}}){
                    $j =~ /(.*):(.*)/;
                    $writer->startTag('block');
                    $writer->dataElement('who',$1);
#                    $XML->print("  <block>\n   <who>$1</who>\n");
                    $writer->dataElement('reason',$2);
                    $writer->endTag('block');
#                    $XML->print("   <reason>$2</reason>  </block>\n");
                }
            }

            $writer->startTag('nodes');
#            $XML->print(" <nodes>\n");
            foreach $cpu ( sort( @{$i->{own}},
                                 @{$i->{shared}},
                                 @{$i->{extranodes}})){
                $cpu =~ /^(.*):(.*)$/;
                $writer->emptyTag('item', 'node_name'=>$1, 'cpu_id'=>$2,
                                  'extra'=>is_in_list($cpu,$i->{extranodes})?1:0,
                                  'type'=>exists($shared{$cpu})?'shared':'own');
#                $XML->print(" <item node_name=\"$1\" cpu_id=\"$2\"");
#                if(is_in_list($cpu,$i->{extranodes})){
#                    $XML->print(" extra=\"1\"");
#                }
#                else{
#                    $XML->print(" extra=\"0\"");
#                }
#                if(exists($shared{$cpu})){
#                    $XML->print(" type=\"shared\"/>\n");
#                }
#                else{
#                    $XML->print(" type=\"own\"/>\n");
#                }
            }
            $writer->endTag('nodes');
#            $XML->print(" </nodes>\n");

            ($sec,$min,$hr,$day,$s,$tmp,$w)=localtime($i->{time});
            $tmp+=1900;
            ++$s;
            $writer->emptyTag('start', 'day'=>$day, 'month'=>$s,
                              'of_week'=>$w, 'hours'=>$hr, 'minutes'=>$min,
                              'seconds'=>$sec, 'year'=>$tmp,
                              'unixtime'=>$i->{time});
#            $XML->print(" <start day=\"$day\" month=\"$s\"");
#            $XML->print(" of_week=\"$w\" hours=\"$hr\" minutes=\"$min\"");
#            $XML->print(" seconds=\"$sec\" year=\"$tmp\" unixtime=\"$i->{time}\" />\n");

            if($i->{state} eq 'queued'){
                $b=$tmp; # save current year
                ($sec,$min,$hr,$day,$s,$tmp,$w)=gmtime($i->{timelimit});
                $tmp+=1900-$b; # how many years it will take?
                --$day;        # start from 0, not from 1
            }
            else{
                ($sec,$min,$hr,$day,$s,$tmp,$w)=localtime($i->{timelimit});
                $tmp+=1900;
            }
            ++$s;
            $writer->emptyTag('timelimit', 'day'=>$day, 'month'=>$s,
                          'of_week'=>$w, 'hours'=>$hr, 'minutes'=>$min,
                          'seconds'=>$sec, 'year'=>$tmp,
                          'unixtime'=>$i->{time});
#                $XML->print(" <timelimit day=\"$day\" month=\"$s\"");
#                $XML->print(" of_week=\"$w\" hours=\"$hr\" minutes=\"$min\"");
#                $XML->print(" seconds=\"$sec\" year=\"$tmp\" unixtime=\"$i->{timelimit}\" />\n");

            ($sec,$min,$hr,$day,$s,$tmp,$w)=localtime($i->{added});
            $tmp+=1900;
            ++$s;
            $writer->emptyTag('added', 'day'=>$day, 'month'=>$s,
                          'of_week'=>$w, 'hours'=>$hr, 'minutes'=>$min,
                          'seconds'=>$sec, 'year'=>$tmp,
                          'unixtime'=>$i->{time});
#            $XML->print(" <added day=\"$day\" month=\"$s\"");
#            $XML->print(" of_week=\"$w\" hours=\"$hr\" minutes=\"$min\"");
#            $XML->print(" seconds=\"$sec\" year=\"$tmp\" unixtime=\"$i->{added}\" />\n");

            $writer->dataElement('task_code',$i->{task});
#            $XML->print(" <task_code>$i->{task}</task_code>\n");

            foreach $tmp ( keys(%$i) ) {
                next if exists($xml_no_print{$tmp});

                if ( $dump_q_trans{$tmp} ne '' ){
                    $s = $dump_q_trans{$tmp};
                }
                else{
                    $s = $tmp;
                }
                if ( ref( $i->{$tmp} ) eq 'ARRAY' ) {
                    $writer->startTag($s);
#                    $XML->print("  <$s>\n");
                    foreach $k (@{ $i->{$tmp} }){
                        $writer->dataElement('item',$k);
#                        $XML->print("   <item>$k</item>\n");
                    }
                    $writer->endTag($s);
#                    $XML->print("  </$s>\n");
                } else {
                        $writer->dataElement($s,$i->{$tmp});
#                    $XML->print("  <$s>$i->{$tmp}</$s>\n");
                }
            }
            if(not exists($i->{blocked})){
                $writer->dataElement('blocked',0);
#                $XML->print("  <blocked>0</blocked>\n");
            }
            $writer->endTag('task');
#            $XML->print(" </task>\n");
        }
        $writer->endTag('tasks');
        $writer->endTag('cleo-state');
#        $XML->print("</tasks>\n");
#        $XML->print("</cleo-state>\n");

        $writer->end();
    #    flock( F, &Fcntl::LOCK_UN() );
        $XML->close() or qlog( "xml file closing failed\n", LOG_WARN );

    #    $newfile = new IO::File;
    #    unless ( $newfile->open($fname, O_TRUNC | O_WRONLY | O_CREAT | O_LARGEFILE)) {
    #        qlog "Warning! Cannot open xml file for writing! ($fname)\n",
    #            LOG_ERR;
    #        unlink($filename);
    #        return;
    #    }

        #delete old state file, if needed
        unlink($fname);

        # rename created from tempname
        unless(rename($filename,$fname)){
            qlog "Warning! Cannot open xml file for writing! ($fname)\n",
                LOG_ERR;
            unlink($filename);
            return;
        }
        chmod &get_setting('xml_rights'), $fname;
    };
}

sub save_state {
    my $name = $cluster_name;    #$_[0];

    my ( $block, $i );
    my ( $key, $val, @cal );
    @cal = caller(1);

    qlog "SAVE '$name' ($cal[2] -- $cal[3])\n", LOG_DEBUG2;
    if ( rename( "$queue_save.$name", "$queue_save.$name.bak" )
        || !-f $queue_save ) {
        unless ( open( SAV, ">$queue_save.$name" ) ) {
            print
                "Cannot save queue status to $queue_save.$name. Try to use $queue_alt_save.$name\n";
            qlog
                "Cannot save queue status to '$queue_save.$name'. Try to use '$queue_alt_save.$name'\n";
            open( SAV, ">$queue_alt_save.$name" )
                or die "Cannot save queue status to $queue_alt_save.$name.\n";
        }
        } else {
        print
            "Cannot to create backup. Try to save to $queue_alt_save.$name\n";
        qlog
            "Cannot to create backup. Try to save to '$queue_alt_save.$name'\n";
        open( SAV, ">$queue_alt_save.$name" )
            or die "Cannot save queue status to $queue_alt_save.$name.\n";
    }
    $block = '0';
    $block = '1' unless ( $mode & MODE_RUN_ALLOW );

    print SAV "$tcount $block\n";

    for ( $i = 0; $i < scalar(@running); ++$i ) {
        qlog "save $running[$i]->{id}\n", LOG_DEBUG2;
        if ( !defined $running[$i]->{id} ) {
            qlog "BAD SAVE ID - running $i\n";
            next;
        }

#    next if($running[$i]->{owner} ne $cluster_name); # don't save not own tasks!!!
        while ( ( $key, $val ) = each( %{ $running[$i] } ) ) {
            save_line( $key, $val );
        }
        print SAV "#\n";
    }
    for ( $i = 0; $i < scalar(@pending); ++$i ) {
        if ( !defined $pending[$i]->{id} ) {
            qlog "BAD SAVE ID - pending $i\n", LOG_ERR;
            next;
        }
        qlog "save $pending[$i]->{id}\n", LOG_DEBUG2;

#    next if($pending[$i]->{owner} ne $cluster_name); # don't save not own tasks!!!
        while ( ( $key, $val ) = each( %{ $pending[$i] } ) ) {
            save_line( $key, $val );
        }
        print SAV "#\n";
    }
    for ( $i = 0; $i < scalar(@queue); ++$i ) {
        if ( !defined $queue[$i]->{id} ) {
            qlog "BAD SAVE ID - queue $i\n", LOG_ERR;
            next;
        }
        qlog "save $queue[$i]->{id}\n", LOG_DEBUG;

#    next if($queue[$i]->{owner} ne $cluster_name); # don't save not own tasks!!!
        while ( ( $key, $val ) = each( %{ $queue[$i] } ) ) {
            next if is_in_list( $key, \@non_saved_fields );    # eq 'pid';
            save_line( $key, $val );
        }
        print SAV "#\n";
    }

    qlog "save settings\n", LOG_DEBUG2;

    # save global settings
    foreach $i ( keys(%global_settings) ) {
        save_line( $i, $global_settings{$i} );
    }
    if ( keys(%blocked_pe_reasons) > 0 ) {
        save_line( 'pe_blocks', \%blocked_pe_reasons );
    }
    save_line( 'id', 'global' );
    print SAV "#\n";

    # save cluster settings
    foreach $i ( keys( %{ $cluster_settings{$cluster_name} } ) ) {
        save_line( $i, $cluster_settings{$cluster_name}{$i} );
    }
    save_line( 'id', 'cluster' );
    print SAV "#\n";

    # save custom data
    # !!
    save_line( 'rsh_data',          \%main::rsh_data );
    save_line( 'autoblock',         \%autoblock );
    save_line( 'all_autoblock',     $all_autoblock );
    save_line( 'autononblock',      \%autononblock );
    save_line( 'time_restrictions', \@time_restrictions );

    save_line( 'id', 'custom_data' );
    print SAV "#\n";

    # save schedulers user data
    foreach $i ( keys(%sched_user_info) ) {
        save_line( $i, $sched_user_info{$i} );
    }
    save_line( 'id', 'sched_user_info' );
    print SAV "#\n";

    # save schedulers data
    foreach $i ( keys(%sched_data) ) {
        save_line( $i, $sched_data{$i} );
    }
    save_line( 'id', 'sched_data' );
    print SAV "#\n";
    close SAV;
    qlog "saving done\n", LOG_DEBUG;
}    # save_state

sub load_state {
    my $name = $_[0];
    my ( $x, $line, @blocks, $v, $k, $v2 );

    qlog "Load '$name'\n", LOG_DEBUG;
    unless ( open( SAV, "<$queue_save.$name" ) ) {

        qlog "Cannot open queue status file '$queue_save.$name'\n", LOG_DEBUG;
        return;
    }
    $x    = {};
    $line = <SAV>;

    unless ( $line =~ /^(\d+)\s*(\d)\s*(.*)?$/ ) {
        qlog "Bad queue status file '$queue_save.$name'\n", LOG_ERR;
        close SAV;
        return;
    }
    $tcount = $1;
    if ($2) {
        $mode |= MODE_RUN_ALLOW;
        $mode ^= MODE_RUN_ALLOW;
    }
    @blocks = split( /\s+/, $3 );
    foreach $x (@blocks) {
        block_pe( $x, 1, 0, "Old block" );
    }
    while (<SAV>) {
        if (/^\#$/) {    #entry end mark
            if ( $x->{id} eq 'global' ) {    # global settings
                delete $x->{id};
                eval {
                    if ( defined $x->{pe_blocks} ) {
                        foreach $k ( keys( %{ $x->{pe_blocks} } ) ) {
                            block_pe( $k, 1, 0,
                                keys( %{ $x->{pe_blocks}->{$k} } ) )
                                if ( keys( %{ $x->{pe_blocks}->{$k} } ) > 0 );
                        }
                    }
                };
                delete $x->{pe_blocks};
                foreach $k ( keys(%$x) ) {
                    $global_settings{$k} = $x->{$k} if ( $main::opts{r} );
                }
                $x = {};
                qlog( "Restored global settings\n", LOG_DEBUG2 );
            } elsif ( $x->{id} eq 'cluster' ) {    # cluster settings
                delete $x->{id};
                foreach $k ( keys(%$x) ) {
                    $cluster_settings{$cluster_name}{$k} = $x->{$k};
                }
                qlog( "Restored cluster settings\n", LOG_DEBUG2 );
            } elsif ( $x->{id} eq 'sched_user_info' ) {   # schedulers user data
                delete $x->{id};
                foreach $k ( keys(%$x) ) {
                    $sched_user_info{$k} = $x->{$k};
                }
                qlog( "Restored schedulers user data\n", LOG_DEBUG2 );
            } elsif ( $x->{id} eq 'sched_data' ) {        # schedulers data
                delete $x->{id};
                foreach $k ( keys(%$x) ) {
                    $sched_data{$k} = $x->{$k};
                }
                qlog( "Restored schedulers data\n", LOG_DEBUG2 );
            } elsif ( $x->{id} eq 'custom_data' ) {      # custom data
                delete $x->{id};
                foreach $k ( keys(%$x) ) {
                    if ( $k eq 'rsh_data' ) {
                        if ( ref( $x->{rsh_data} ) eq 'HASH' ) {
                            %main::rsh_data = %{ $x->{rsh_data} };
                        } else {
                            qlog "RSH_DATA saved as not a hash!\n", LOG_WARN;
                        }
                        next;
                    } elsif ( $k eq 'autoblock' ) {
                        if ( ref( $x->{autoblock} ) eq 'HASH' ) {
                            %main::autoblock = %{ $x->{autoblock} };
                        } else {
                            qlog "AUTOBLOCK saved as not a hash!\n", LOG_WARN;
                        }
                        next;
                    } elsif ( $k eq 'all_autoblock' ) {
                        $main::all_autoblock = $x->{all_autoblock};
                        next;
                    } elsif ( $k eq 'autononblock' ) {
                        if ( ref( $x->{autononblock} ) eq 'HASH' ) {
                            %main::autononblock = %{ $x->{autononblock} };
                        } else {
                            qlog "AUTONONBLOCK saved as not a hash!\n",
                                LOG_WARN;
                        }
                        next;
                    } elsif ( $k eq 'time_restrictions' ) {
                        if ( ref( $x->{time_restrictions} ) eq 'ARRAY' ) {
                            @main::time_restrictions =
                                @{ $x->{time_restrictions} };
                        } else {
                            qlog "TIME_RESTRICTIONS saved as not a hash!\n",
                                LOG_WARN;
                        }
                        next;
                    }
                    qlog "Strange custom data: '$k'\n", LOG_WARN;
                }
                qlog( "Restored custom data\n", LOG_DEBUG2 );
            } elsif ( ( $x->{id} > 0 )
                and (
                        ($x->{task} ne '')# <--- OLD STYLE. MUST BE DELETED
                        or
                        (defined $x->{task_args})
                    )
                and ($x->{np} >0)
                and ( $x->{user} ne '' ) ) {
                if ( defined( $x->{nproc} ) ) {  # backward compatibility mode
                    $x->{np} ||= $x->{nproc};
                    delete $x->{nproc};
                }
                if ( ref( $x->{blocks} ) ne 'ARRAY' ) {
                    undef $x->{blocks};
                    $x->{blocks} = [];
                    qlog "id $x->{id} had bad blocks...\n", LOG_ERR;
                }
                if ( ref( $x->{own} ) ne 'ARRAY' ) {
                    undef $x->{own};
                    $x->{own} = [];
                    qlog "id $x->{id} had bad list own nodes...\n", LOG_ERR;
                }
                if ( ref( $x->{shared} ) ne 'ARRAY' ) {
                    undef $x->{shared};
                    $x->{shared} = [];
                    qlog "id $x->{id} had bad shared nodes...\n", LOG_ERR;
                }
                if ( ref( $x->{extranodes} ) ne 'ARRAY' ) {
                    undef $x->{extranodes};
                    $x->{extranodes} = [];
                    qlog "id $x->{id} had bad extranodes...\n", LOG_ERR;
                }
                if ( $x->{state} eq 'run' ) {
                    my $t;
                    push @running, $x;
                    foreach $t (
                        @{ $x->{shared} },
                        @{ $x->{own} },
                        @{ $x->{extranodes} }
                        ) {
                        $pe{$t}->{ids}->{ $x->{id} } = $x->{pid};
                    }
                    if ( $x->{owner} ne $cluster_name ) {
                        for $t ( @{ $x->{shared} } ) {
                            $shared{$t}->{ids}->{ $x->{id} } = -1;
                        }
                        for $t ( @{ $x->{own} } ) {
                            $own{$t}->{ids}->{ $x->{id} } = -1;
                        }
                    }
                }

          #        elsif($x->{state} eq 'prerun' or $x->{state} eq 'waiting'){
          #          push @pending, $x;
          #        }
                else {
                    push @queue, $x;
                }
                $ids{ $x->{id} }         = $x;
                $childs_info{ $x->{id} } = $x;
                if ( exists $x->{oldid} and $x->{oldid} > 0 ) {
                    $extern_ids{ $x->{lastowner} }->{ $x->{oldid} } =
                        $x->{id};
                }
                qlog( "Restored: " . join( ':', %{$x} ) . "\n", LOG_DEBUG2 );
                } else {
                qlog "Invalid saved status file($x->{id}:".
                     "$x->{task}:$x->{np}:$x->{user})\n",
                    LOG_ERR;
            }
            $x = {};
        } elsif (/^(\S+)\:\s(.*)$/) {
            undef $v2;
            ( $k, $v ) = ( $1, $2 );
            $v2 = load_line($v);
            $x->{$k} = $$v2;
        } elsif (/^!(\S+)/) {
            qlog( "Section $1 found... Skip as unimplemented\n", LOG_WARN );
            last;
        } else {
            qlog "Wrong line in '$queue_save.$name' ($_)\n", LOG_ERR;
        }
    }
    if ( ref $x eq 'HASH' && scalar( %{$x} > 0 ) ) {
        qlog "Unclosed task entry\n", LOG_ERR;
        push( @queue, $x )
            if ( ($x->{id} > 0)
                and ($x->{task} ne '')
                and (defined $x->{task_args})
                and ($x->{np} > 0)
                and ($x->{user} ne ''));
        qlog "Restoring last: " . join( ':', %{$x} ) . "\n", LOG_DEBUG;
    }
    close SAV;
    qlog "Load status from '$queue_save.$name' successful\n";

    #  print "Load successfull\n";
}    # load_state

#
#  Fix pre-runned tasks state after (re)start
#
############################################
sub fix_prerun(){
    my $i;

    foreach $i (@queue){
        
        # simply reset state to queued
        if($i->{state} eq 'prerun'){
            $i->{state} = 'queued';
        }
        my @nodes= map {/^([^:]*)/, $1} (@{$i->{shared}},
                   @{$i->{own}},
                   @{$i->{extranodes}});
        main::new_req_to_mon(
                   'cancel_attach', $i,
                   \@nodes, SUCC_ALL | SUCC_OK,
                   undef, undef);
    }
}

#
#  cpus list (comma-separated string)-> nodes list (@array) 
#
########################################
sub cpulist2nodes($){
    my %cpus;
    map { $cpus{$_} = 1 } map { /^([^:]+)/; $1; }
      (split(/,/, $_[0]));
    return keys(%cpus);
}

#
#  Calculate some global variables
#
sub calc_vars(){
    my $i;

    $extra_nodes_used=0;
    foreach $i (@running){
        $extra_nodes_used+=$i->{npextra};
        
        $pids{$i->{id}}=$i->{pid};
    }
    
}

sub generate_string {
    my ( $i, $ret );

    for ( $i = 0; $i < 30; ++$i ) {
        $ret .= pack( "C", rand( 90 - 65 ) + 65 );
    }
    return $ret;
}

sub mode2text {
    my ($mode) = @_;
    my $ret;

    $ret = 'run new ';
    if ( $mode & MODE_RUN_ALLOW ) {
        $ret .= 'enabled';
    } else {
        $ret .= 'disabled';
    }
    if ( $mode & AUTORESTART ) {
        $ret .= '; autorestart activated';
    }
    unless ( $mode & MODE_QUEUE_ALLOW ) {
        $ret .= '; queueing disabled';
    }
    if ( $run_fase > 0 ) {
        $ret .= "; init fase $run_fase";
    }
    return $ret;
}    # mode2text

#
#  Loads config file.
#  args: 1 - opened file handle of file
#        2 - (opt) safety (1 - unsafe load, 0 - safe)
#        3 - (opt) username (user file load)
#
#  ret:  0 if success, 1 if fail to open file
#
################################################################
sub load_config( $;$$ ) {
    my ( $file, $unsafe, $user ) = @_;
    my $mode = 1
        ; # 1-server, 2-users, 3-clusters, 4-profiles, 5-hybride, 6-groups, 7-mod
    my ( $arg, $arg2, $q );
    my ( $var, $val,  $tmp );

    open( IN, "<$file" ) or return 1;

    # reset list of loaded lists
    %loaded_vars = ();

    while (<IN>) {
        chomp;
        next if (/^\s*\#/);
        next if (/^\s*$/);
        if ( $user eq '' ) {
            if (/^\s*\[(\S+)\]/) {    # new section
                if ( $1 eq 'server' ) {
                    $mode = 1;
                } elsif ( $1 eq 'users' ) {

                    #          print "Users!\n";
                    $mode = 2;
                } elsif ( $1 eq 'clusters' ) {

                    #          print "Clusters!\n";
                    $mode = 3;
                } elsif ( $1 eq 'profiles' ) {

                    #          print "Profiles!\n";
                    $mode = 4;
                } elsif ( $1 eq 'clusterusers' ) {

                    #          print "2222222!\n";
                    $mode = 5;
                } elsif ( $1 eq 'groups' ) {

                    #          print "Groups!\n";
                    $mode = 6;
                } elsif ( $1 eq 'mod' ) {

                    #          print "Groups!\n";
                    $mode = 7;
                } else {
                    qlog "Bad section name: $1\n", LOG_WARN;
                }
                next;
            }
        }

        if ( $mode == 1 ) {    # global (or user-file)
            unless ( $_ =~ m/^\s*(\S+)\s*\=\s*(.*)$/ ) {
                qlog "Bad string in server section: $_\n", LOG_ERR;
                next;
            }
            ( $var, $val ) = ( $1, $2 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            if ( $user ne '' ) {
                if ($tmp =
                    assign_new_value( \%{ $new_local_user_settings{$user} },
                        $var, $val, $unsafe, 'l' ) > 0
                    ) {
                    qlog "Bad ($tmp) option in user config ($user): '$_'\n",
                        LOG_WARN;
                }
            } else {
                if ($tmp = assign_new_value( \%new_global_settings,
                        $var, $val, $unsafe, 'g' ) > 0
                    ) {
                    qlog "Bad ($tmp) option in server section: '$_'\n",
                        LOG_WARN;
                }
            }
        } elsif ( $mode == 2 ) {    # users
            unless ( $_ =~ /^\s*(\S+)\.(\S+)\s*\=\s*(.*)$/ ) {
                qlog "Bad string in users section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $var, $val ) = ( $1, $2, $3 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            unless ( exists( $new_user_settings{$arg} ) ) {
                %{ $new_user_settings{$arg} } = ();
            }
            if ($tmp = assign_new_value( \%{ $new_user_settings{$arg} },
                    $var, $val, $unsafe, 'u' ) > 0
                ) {
                qlog "Bad ($tmp) option in users section: '$_'\n", LOG_WARN;
            }
        } elsif ( $mode == 3 ) {    # clusters
            unless (m/^\s*(\S+)\.(\S+)\s*\=\s*(.*)$/) {
                qlog "Bad string in clusters section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $var, $val ) = ( $1, $2, $3 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            qlog "CLUSTERS: $arg/$var/$val\n", LOG_DEBUG;
            unless ( exists( $new_cluster_settings{$arg} ) ) {
                %{ $new_cluster_settings{$arg} } = ();
            }
            if ($tmp = assign_new_value( \%{ $new_cluster_settings{$arg} },
                    $var, $val, $unsafe, 'q' ) > 0
                ) {
                qlog "Bad ($tmp) option in clusters section: '$_'\n",
                    LOG_WARN;
            }
        } elsif ( $mode == 4 ) {    # profiles
            unless (/^\s*(\S+)\.(\S+)\s*\=\s*(.*)$/) {
                qlog "Bad string in profile section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $var, $val ) = ( $1, $2, $3 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            unless ( exists( $new_profile_settings{$arg} ) ) {
                %{ $new_profile_settings{$arg} } = ();
            }
            if ($tmp = assign_new_value( \%{ $new_profile_settings{$arg} },
                    $var, $val, $unsafe, 'p' ) > 0
                ) {
                qlog "Bad ($tmp) option in profiles section: '$_'\n",
                    LOG_WARN;
            }
        } elsif ( $mode == 5 ) {    # clusterusers
            unless (m/^\s*(\S+)\.(\S+)\.(\S+)\s*\=\s*(.*)$/) {
                qlog "Bad string in clusterusers section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $arg2, $var, $val ) = ( $1, $2, $3, $4 );

            #queue,user,sname = val
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            unless ( exists( $new_clusteruser_settings{$arg}{$arg2} ) ) {
                %{ $new_clusteruser_settings{$arg}{$arg2} } = ();
            }
            if ($tmp =
                assign_new_value(
                    \%{ $new_clusteruser_settings{$arg}{$arg2} },
                    $var, $val, $unsafe, 'U' ) > 0
                ) {
                qlog "Bad ($tmp) option in clusterusers section: '$_'\n",
                    LOG_WARN;
            }
        } elsif ( $mode == 6 ) {    # groups
            unless (m/^\s*(\S+)\s*\=\s*(.*)$/) {
                qlog "Bad string in groups section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $val ) = ( $1, $2 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            unless ( exists( $new_groups{$arg} ) ) {
                @{ $new_groups{$arg} } = ();
            }
            push @{ $new_groups{$arg} }, split( /\ +|\,/, $val );
        } elsif ( $mode == 7 ) {    # mod
            qlog "LOADING: $_;\n";
            unless (m/^\s*(\S+)\.(\S+)\.(\S+)\.(\S+)\s*\=\s*(.*)$/) {

                #           mod   queue  user  name
                qlog "Bad string in mod section: $_\n", LOG_WARN;
                next;
            }
            ( $arg, $q, $arg2, $var, $val ) = ( $1, $2, $3, $4, $5 );
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            $new_mod_settings{$arg}{$q}{$arg2}{$var} = $val;
        }
    }
    close IN;
    return 0;
}

#
#  Assigns new value to hash element according %server_opt_types
#
#  args: 1 hash reference
#        2 hash key
#        3 value to be assigned
#        4 unsafe flag (0 - safe assign, 1 - forced)
#        5 (opt) section name (a letter)
#
#  ret:  returns 0 if succeed, -1 if safity is not satisfied, greater 1 if error
#        (1 - no such key in specified section;
#         2 - invalid numeric value
#         3 - invalid hash value
#         4 - unknown key
#         5 - invalid key type in proto descroption)
#
###########################################################
sub assign_new_value( $$$$;$ ) {
    my ( $hash, $key, $val, $unsafe, $s ) = @_;

    #  print "Assign: $key/$val [".join(';',keys(%$hash))."\n";
    if ( exists $server_opt_types{$key} ) {
        my ( $type, $safe, $section ) = @{ $server_opt_types{$key} };
        if ( !$unsafe && ( $safe ne 'y' ) ) {
            return -1;
        }
        if ( ( $s ne '' ) and ( $section ne '' ) and ( $section !~ m/$s/ ) ) {
            return 1;
        }

        if ( $type eq 't' ) {    # text

            #      if ($cumul) {
            #        $hash->{$key}.= $val;
            #      } else {
            $hash->{$key} = $val;

            #      }
        } elsif ( $type eq 'n' ) {    # numeric (unsigned integer)
            if ( $val !~ /^(\d+)/ ) {
                qlog
                    "Bad value for $key (must be numeric, but '$val' found)\n",
                    LOG_ERR;
                return 2;
            }
            $hash->{$key} = $1;
        } elsif ( $type eq 'i' ) {    # integer (may be signed)
            if ( $val !~ /^(\+|\-\d+)/ ) {
                qlog
                    "Bad value for $key (must be integer, but '$val' found)\n",
                    LOG_ERR;
                return 2;
            }
            $hash->{$key} = $1;
        } elsif ( $type eq 'h' ) {    # hash
            if ( $val !~ /^(\S+)\s+(.*)$/ ) {
                qlog "Bad value for $key (must be hash, but '$val' found)\n",
                    LOG_ERR;
                return 3;
            }
            $hash->{$key}->{$1} = $2;

            #    } elsif ($type eq 'l') {    # list via space
            #      if ($cumul) {
            #        push @{$hash->{$key}}, split(/\ +/,$val);
            #      } else {
            #        @{$hash->{$key}}=split(/\ +/,$val);
            #      }
        } elsif ( $type eq 'L' ) {    # list via coma, semicolon or space
                                      #      if ($cumul) {

            # delete old content of array, unless it is adding now
            @{ $hash->{$key} } = () unless exists $loaded_vars{$hash}->{$key};
            $loaded_vars{$hash}->{$key} = 1;

            push @{ $hash->{$key} }, split( /[\s\;\,]+/, $val );

            #      } else {
            #        @{$hash->{$key}}=split(/[\s\;\,]+/,$val);
            #      }
            qlog "LIST '$key' :" . join( ';', @{ $hash->{$key} } ) . ";\n",
                LOG_DEBUG;

            #    } elsif ($type eq "\@") {    # list via coma
            #      if ($cumul) {
            #        push @{$hash->{$key}}, split(/\,/,$val);
            #      } else {
            #        @{$hash->{$key}}=split(/\,/,$val);
            #      }
        } else {
            qlog "Unknown type specified in proto of $key! ($type)\n",
                LOG_ERR;
            return 5;
        }
    } else {

        #    qlog "Unknown key=$key\n";
        return 4;
    }
    return 0;
}

#
#  Substitutes groups names by their members
#
#  args: 1 - groups hash
#        2 - string of users
#
#  ret:  expanded string
#
#########################################################
sub expand_groups( $$ ) {
    my ( $g, $s ) = @_;

    eval { $$s =~ s[\+(\S+)][join(',',@{$g->{$1}})]eg; };
}

#
#  Substitutes groups names by their members in array
#
#  args: 1 - groups hash
#        2 - array of users
#
#  ret:  expanded array
#
#########################################################
sub expand_groups_array( $$ ) {
    my ( $g, $s ) = @_;
    my @ret;
    my $i;

    foreach $i (@$s) {
        if ( $i =~ s/^\+// ) {
            if ( exists( $g->{$i} ) ) {
                push @ret, @{ $g->{$i} };
            } else {
                qlog "Wrong group name: $i\n", LOG_WARN;
            }
        } else {
            push @ret, $i;
        }
    }
    return @ret;
}

#
#  Make post-load config corrections.
#
#  args: 1 - new settings hash
#        2 - new groups hash
#
#########################################################
sub post_load_config( $$ ) {
    my ( $new_settings, $groups ) = @_;

    my $i;
    my @tmp;
    my $list;

    if ( exists( $new_settings->{admins} )
        and ( ref( $new_settings->{admins} ) eq 'ARRAY' ) ) {
        @{ $new_settings->{admins} } =
            &expand_groups_array( \%new_groups,
            \@{ $new_settings->{admins} } );
        } else {
        undef $new_settings->{admins};
        @{ $new_settings->{admins} } = ();
    }
    if ( exists( $new_settings->{users} )
        and ( ref( $new_settings->{users} ) eq 'ARRAY' ) ) {
        @{ $new_settings->{users} } =
            &expand_groups_array( \%new_groups,
            \@{ $new_settings->{users} } );
        } else {
        undef $new_settings->{users};
        @{ $new_settings->{users} } = ();
    }
    if ( exists( $new_settings->{nousers} )
        and ( ref( $new_settings->{nousers} ) eq 'ARRAY' ) ) {
        @{ $new_settings->{nousers} } =
            &expand_groups_array( \%new_groups,
            \@{ $new_settings->{nousers} } );
        } else {
        undef $new_settings->{nousers};
        @{ $new_settings->{nousers} } = ();
    }

    if ( exists( $new_settings->{allowed_ip} ) ) {
        @tmp = @{ $new_settings->{allowed_ip} };
        undef $new_settings->{allowed_ip};
        $new_settings->{allowed_ip} = join( ' ', '', @tmp, '' );
    }
    if ( exists( $new_settings->{pid_file} ) && $is_master ) {
        my $old = $main::opt{i};
        $opts{i} = $new_settings->{pid_file};
        if ( open( PID, ">$opts{i}" ) ) {
            print PID $$;
            close PID;
            unlink("$old");
        } else {
            $opts{i} = $old;
            qlog "Cannot create pid file ($new_settings->{pid_file})\n";
        }
    }
    if ( exists( $new_settings->{queue_save} ) ) {
        my $old = $queue_save;
        $opts{'s'} = $queue_save = $new_settings->{queue_save};
        if ( open( SAVE, ">$queue_save-$cluster_name" ) ) {
            close SAVE;
        } else {
            $opts{'s'} = $queue_save = $old;
            qlog
                "Cannot create new save file ($new_settings->{queue_save})\n";
        }
    }
    if ( exists( $new_settings->{queue_alt_save} ) ) {
        my $old = $queue_save;
        $opts{a} = $queue_alt_save = $new_settings->{queue_save};
        if ( open( SAVE, ">$queue_alt_save-$cluster_name" ) ) {
            close SAVE;
            unlink("$queue_alt_save-$cluster_name");
        } else {
            $opts{a} = $queue_alt_save = $old;
            qlog
                "Cannot create new alt save file ($new_settings->{queue_alt_save})\n";
        }
    }
    if ( $is_master && exists( $new_settings->{pid_file} ) ) {
        my $old = $opts{i};
        $opts{i} = $new_settings->{pid_file};
        if ( open( PID, ">$opts{i}" ) ) {
            print PID $$;
            close PID;
        } else {
            qlog "Cannot create pid file ($opts{i})\n";
        }
    }
    if ( exists( $new_settings->{log_file} ) ) {
        my $old = $report_file;
        $opts{l} = $report_file = $new_settings->{log_file};
        $STATUS->close();
        unless ( $STATUS->open(">>$report_file") ) {
            $opts{l} = $report_file = $old;
            unless ( $STATUS->open(">>$report_file") ) {
                $STATUS->open(">>/dev/null");
            }
            qlog "Cannot create log file ($new_settings->{log_file})\n";
        }
    }
    if ( exists( $new_settings->{short_log_file} ) ) {
        my $old = $short_rep_file;
        $opts{L} = $short_rep_file = $new_settings->{short_log_file};
        $SHORT_LOG->close();
        unless (
            $SHORT_LOG->open(
                $short_rep_file, O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )
            ) {
            $opts{L} = $short_rep_file = $old;
            unless (
                $SHORT_LOG->open(
                    $short_rep_file,
                    O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )
                ) {
                $SHORT_LOG->open(">>/dev/null");
            }
            qlog "Cannot create log file ($new_settings->{short_log_file})\n";
        }
    }
    if ( exists( $new_settings->{max_time} ) ) {
        unless ( exists( $new_settings->{def_time} ) ) {
            $new_settings->{def_time} = $new_settings->{max_time};
        }
    } elsif ( exists( $new_settings->{ $new_settings->{def_time} } ) ) {
        unless ( exists( $new_settings->{max_time} ) ) {
            $new_settings->{max_time} = $new_settings->{def_time};
        }
    }

    if ( exists( $new_settings->{gid}) and ($new_settings->{gid} !~ m/^\d+$/) ) {
        $new_settings->{gid} = getgrnam($new_settings->{gid});
        $new_settings->{gid} = 65535 if($new_settings->{gid}==0);
    }

    if(exists ($new_settings->{log_level})){
        $log_level=$new_settings->{log_level};
    }
}

sub recreate_plugins_and_ports() {
    my $i;

    if ( exists( $global_settings{pe_sel_method} ) ) {
        foreach $i ( keys(%pe_sel_method) ) {
            kill_tree( 9, $pe_sel_method{$i}->{pid} );
        }
        undef %pe_sel_method;

        foreach $i ( keys( %{ $global_settings{pe_sel_method} } ) ) {
            &main::new_extern_shuffle($i);
        }
    }

    if ( $is_master && exists( $global_settings{rsh_filter} ) ) {
        foreach $i ( keys(%rsh_filter) ) {
            $rsh_filter{$i}->{conn}->disconnect if defined $rsh_filter{$i}->{conn};
            qlog "Killing rsh filter '$i' (pid $rsh_filter{$i}->{pid})\n";
            kill_tree( 9, $rsh_filter{$i}->{pid} );
        }
        undef %rsh_filter;

        foreach $i ( keys( %{ $global_settings{rsh_filter} } ) ) {
            $rsh_filter{$i}->{die_count} = 10;
            &main::new_rsh_filter($i);
        }
    }
    if($is_master){
        if(defined $main::LST){
            $main::LST->disconnect;
        }
        else{
            qlog "OPENING LISTEN SOCKET\n", LOG_DEBUG;
            $main::LST=new_listen Cleo::Conn(get_setting('port'),get_setting('listen_number'));
            unless(defined $main::LST){
                qlog "Cannot reopen listen socket!\n", LOG_ERR;
                exit(1);
            }
        }
        if($main::LST->listen){
            qlog "Cannot make listen socket! ($!)\n", LOG_ERR;
            exit(1);
        }
    }
}

#
#  Loads new config file and actualizes it.
#
#  args: 1 - unsafeness (opt)
#        by dafault is safe
#
#########################################################
sub load_conf_file(;$ ) {    # safe by default!
    my $unsafe = $_[0];
    my ( $i, $j, $k );

    {
        local $opts{v} = 1;
        boot_qlog "Loading global configuration...\n";
    }
    qlog "Load_conf! ($unsafe)\n", LOG_ALL;
    undef %new_groups;
    undef %new_global_settings;
    %new_global_settings = %def_global_settings;
    undef %new_cluster_settings;
    undef %new_user_settings;
    undef %new_profile_settings;
    undef %new_clusteruser_settings;
    undef %new_mod_settings;

    if ( load_config( $opts{c}, $unsafe ) == 0 ) {
        qlog "Load_conf2! ($unsafe)\n", LOG_DEBUG;

        $k = 1;
        for ( $i = 0; $k && $i < 10; ++$i ) {
            $k = 0;
            foreach $j ( keys(%new_groups) ) {
                $k += expand_groups( \%new_groups, \$new_groups{$j} );
            }
        }
        qlog( "Some groups may be cycled or misconfigured!\n", LOG_WARN )
            if ($k);

        qlog( "Load_conf3\n", LOG_DEBUG );

        # Now wipe all extern filters/plugins
        foreach $i ( keys(%pe_sel_method) ) {
            qlog(
                "Killing pe_sel_method '$i' (pid=$pe_sel_method{$i}->{pid})\n",
                LOG_INFO );
            kill_tree( 9, $pe_sel_method{$i}->{pid} );
        }
        undef %pe_sel_method;
        foreach $i ( keys( %{ $global_settings{rsh_filter} } ) ) {
            $rsh_filter{$i}->{conn}->disconnect if defined $rsh_filter{$i}->{conn};
            qlog "Killing rsh-filter '$i' (pid=$rsh_filter{$i}->{pid})\n",
                LOG_INFO;
            kill_tree( 9, $rsh_filter{$i}->{pid} );
        }
        undef %rsh_filter;

        qlog "Load_conf4\n", LOG_DEBUG;

        # Make post-load corrections
        post_load_config( \%new_global_settings, \%new_groups );
        if ( $cluster_name ne '' ) {
            post_load_conf_helper();
        } else {
            foreach $cluster_name ( keys(%new_cluster_settings) ) {
                post_load_conf_helper();
            }
            undef $cluster_name;
        }
        qlog "Load_conf5\n", LOG_DEBUG;

        $mon_ping_interval = $new_global_settings{mon_ping_interval};
        $max_mon_timeout   = $new_global_settings{mon_ping_interval} +
            $new_global_settings{mon_timeout};

        if ($unsafe) {
            qlog "Load_conf6\n", LOG_DEBUG;
            foreach $i ( keys(%new_cluster_settings) ) {
                if ( exists( $new_cluster_settings{$i}->{pe} ) ) {
                    qlog "pe_list for $i: "
                        . join( ',', @{ $new_cluster_settings{$i}->{pe} } )
                        . "\n", LOG_DEBUG;
                    push @{ $pe_list{$i} },
                        @{ $new_cluster_settings{$i}->{pe} };
                } else {
                    qlog "EMPTY CLUSTER $i...\n", LOG_ERR;
                    @{ $pe_list{$i} } = ();
                }
            }
            if ( exists( $new_global_settings{root_cluster_name} )
                and ( $new_global_settings{root_cluster_name} ne '' ) ) {
                $cluster_name = $new_global_settings{root_cluster_name};
                } else {
                $cluster_name = 'main';
            }
            qlog "Load_conf7\n", LOG_DEBUG;
            create_cluster_structure( \%new_cluster_settings );
        }
        qlog "Load_conf8\n", LOG_DEBUG;
        %global_settings      = %new_global_settings;
        %cluster_settings     = %new_cluster_settings;
        %user_settings        = %new_user_settings;
        %profile_settings     = %new_profile_settings;
        %clusteruser_settings = %new_clusteruser_settings;
        %mod_settings         = %new_mod_settings;
        $rootisadm            = !$global_settings{norootadm};
        qlog "Load_conf9\n", LOG_DEBUG;
    } else {
        boot_qlog "Failed '$opts{c}' - $!\n", LOG_ERR;
    }
    qlog "Load_conf done\n";
    qlog "admins: " . join( ';', @{ $global_settings{admins} } ) . "\n",
        LOG_INFO;
}

sub post_load_conf_helper() {
    my ( $i, $j, $k );
    post_load_config( \%new_global_settings, \%new_groups );
    for $i ( keys(%new_cluster_settings) ) {
        post_load_config( $new_cluster_settings{$i}, \%new_groups );
    }
    for $i ( keys(%new_user_settings) ) {
        post_load_config( $new_user_settings{$i}, \%new_groups );
    }
    for $i ( keys(%new_profile_settings) ) {
        post_load_config( $new_profile_settings{$i}, \%new_groups );
    }
    for $i ( keys(%new_clusteruser_settings) ) {
        for $j ( keys( %{ $new_clusteruser_settings{$i} } ) ) {
            post_load_config( $new_clusteruser_settings{$i}{$j},
                \%new_groups );
        }
    }
}

sub create_cluster_structure( $ ) {
    my $cluster_settings = $_[0];

    my ( $a, $p, $i );

    # Create subclusters structure
    foreach $i ( keys(%$cluster_settings) ) {
        qlog "init $i childs\n", LOG_DEBUG;
        @{ $clusters{$i}->{childs} } = ();
    }
    foreach $i ( keys(%$cluster_settings) ) {
        if ( exists( $cluster_settings->{$i}->{parent} )
            and ( $cluster_settings->{$i}->{parent} ne '' ) ) {
            push
                @{ $clusters{ $cluster_settings->{$i}->{parent} }->{childs} },
                $i;
        }
    }
    qlog "my childs: "
        . join( ',', @{ $clusters{$cluster_name}->{childs} } )
        . "\n", LOG_INFO;

    # Ok! clusters->{childs} are filled

    main::make_aliases($cluster_name);

    # Now all child_aliases are created

    %pe = ();
    if ( $cluster_name ne '' ) {
        foreach $a ( @{ $child_aliases{$cluster_name} } ) {
            foreach $p ( @{ $pe_list{$a} } ) { # $p - a node from this cluster
                push @{ $pe{$p}->{clusters} }, $a;    #
            }
        }

# Now pe{...}->{clusters} is an array with all cluster which contains this node

        foreach $a ( @{ $clusters{$cluster_name}->{childs} } )
        {    #for each subcluster of 1st level
            foreach $p ( @{ $pe_list{$a} } ) { # $p - a node from this cluster
                push @{ $pe{$p}->{level1} }, $a;
            }
        }

# Now pe{...}->{level1} is an array with child clusters which contains this node

        %shared = %own = ();

        #   foreach $p (@{$pe_list{$cluster_name}}) {
        #     %{$pe{$p}->{ids}}=();
        #     $pe{$p}->{max}=1;           #BUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #     if ($#{$pe{$p}->{clusters}}>0) {
        #       $shared{$p}=$pe{$p};
        #     } else {
        #       $own{$p}=$pe{$p};
        #     }
        #   }
    CCS_LST_LOOP:
        foreach my $p ( @{ $pe_list{$cluster_name} } ) {
            my ( $c_pe, $c_child );
            $pe{$p}->{max} = 1;    #BUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            foreach $c_pe ( @{ $pe{$p}->{clusters} } ) {
                foreach $c_child ( @{ $clusters{$cluster_name}{childs} } ) {
                    if ( $c_pe eq $c_child ) {
                        $shared{$p} = $pe{$p};
                        qlog "Node $p is shared by $c_child at least\n",
                            LOG_DEBUG;
                        next CCS_LST_LOOP;
                    }
                }
            }
            $own{$p} = $pe{$p};
            qlog "Node $p is my own!\n", LOG_DEBUG;
        }

        # Properly created %shared and %own
    }

    %the_nodes = ();
    foreach $i ( keys(%pe) ) {
        ( $a, $p ) = split( /\:/, $i );
        push @{ $the_nodes{$a} }, $p;
    }

    # Properly created %the_nodes
}    # ~create_cluster_structure

#
#  Updates information about user local settings
#
#  args:
#        1 - dont log. (opt., log by default)
#
##################################################
sub reload_users( ;$ ) {
    my $nolog = $_[0];

    my ( @users, $user, $dir, $tmp, $gid, $members );

    while (
        (   $user, undef, undef, $gid, undef, undef, undef, $dir, undef, undef
        )
        = getpwent()
        ) {
        push @users, $user;
        $user_home{$user}   = $dir;
        $usergid{$user}     = $gid;
        $user_groups{$user} = "$gid";
    }
    endpwent();
    while ( ( undef, undef,, $gid, undef, $members ) = getgrent() ) {
        foreach $tmp ( split( /\s/, $members ) ) {
            $user_groups{$tmp} .= " $gid";
        }
    }
    endgrent();
    foreach $user (@users) {
        $user_conf_time{$user} = $last_time;
        $useruid{$user}        = $tmp = getpwnam($user);
        $username{$tmp}        = $user unless $username{$tmp};
        load_user_conf( $user, $nolog );
    }    # ~foreach (loop on each user)
}    # reload_users

sub get_uid( $ ) {
    return $useruid{ $_[0] } if ( exists( $useruid{ $_[0] } ) );
    return $_[0] if ( $_[0] =~ /^\d+$/ );
    reload_users();
    return $useruid{ $_[0] } if ( exists( $useruid{ $_[0] } ) );
    qlog "Warning: Non-existent user ($_[0]). Use 65535.\n", LOG_WARN;
    return 65535;
}

#
#  Updates information about user local settings
#  if config files are changed
#
#  args:
#        1 - dont log. (opt., log by default)
#
##################################################
sub reload_users_changes( ;$ ) {
    my $nolog = $_[0];

    #  my (@users,$dir,$tmpconf,$gid,$members);
    my ( $user, $tmp, $fname );

#   while (($user,undef,undef,$gid,undef,undef,undef,$dir,undef,undef) = getpwent()) {
#     push @users, $user;
#     $user_home{$user}=$dir;
#     $user_groups{$user}="$gid";
#   }
#   endpwent();
#   while ((undef,$gid,undef,$members) = getgrent()){
#     foreach $tmp (split(/\s/,$members)){
#       $user_groups{$tmp}.=" $gid";
#     }
#   }
#   endgrent();

    $fname = get_setting( 'user_conf_file', $user );
    $fname = ".qconf" unless ($fname);
    $fname = "$user_home{$user}/$fname";
    foreach $user ( keys(%user_home) ) {
        (   undef, undef, undef, undef, undef, undef, undef,
            undef, undef, $tmp,  undef, undef, undef )
            = stat($fname);
        if ( $tmp > $user_conf_time{$user} ) {
            $user_conf_time{$user} = $tmp;
            load_user_conf( $user, $nolog );
        }
    }    # ~foreach (loop on each user)
}    # reload_users_changes

sub load_user_conf( $;$ ) {
    my ( $user, $nolog ) = @_;
    my $dir = $user_home{$user};
    my $mtime;
    my $fname = get_setting( 'user_conf_file', $user );

    $fname = ".qconf" unless ($fname);
    $fname = "$dir/$fname";

    unless ( -r $fname ) {
        return 0;
    }
    (   undef, undef, undef,  undef, undef, undef, undef,
        undef, undef, $mtime, undef, undef, undef )
        = stat($fname);
    return 0 if ( $mtime < $user_conf_time{$user} );

    qlog( "RELOAD USER's  $user config\n", LOG_INFO ) unless ($nolog);
    $user_conf_time{$user} = $mtime;

    undef %new_local_user_settings;
    return 0 if ( load_config( $fname, 0, $user ) );

    qlog(
        "Successful ("
            . join( ';', keys( %{ $new_local_user_settings{$user} } ) )
            . ")\n",
        LOG_DEBUG )
        unless ($nolog);

    # make corrections
    if ( $new_local_user_settings{$user}{priority} >
        get_setting( 'priority', $user ) ) {
        $new_local_user_settings{$user}{priority} =
            get_setting( 'priority', $user );
    }
    if ( $new_local_user_settings{$user}{def_priority} >
        get_setting( 'priority', $user ) ) {
        $new_local_user_settings{$user}{def_priority} =
            get_setting( 'def_priority', $user );
    }
    if ( $new_local_user_settings{$user}{max_np} >
        get_setting( 'max_np', $user ) ) {
        $new_local_user_settings{$user}{max_np} =
            get_setting( 'max_np', $user );
    }
    if ( $new_local_user_settings{$user}{max_sum_np} >
        get_setting( 'max_sum_np', $user ) ) {
        $new_local_user_settings{$user}{max_sum_np} =
            get_setting( 'max_sum_np', $user );
    }
    if ( $new_local_user_settings{$user}{max_cpuh} >
        get_setting( 'max_cpuh', $user ) ) {
        $new_local_user_settings{$user}{max_cpuh} =
            get_setting( 'max_cpuh', $user );
    }
    if ( $new_local_user_settings{$user}{max_tasks} >
        get_setting( 'max_tasks', $user ) ) {
        $new_local_user_settings{$user}{max_tasks} =
            get_setting( 'max_tasks', $user );
    }
    if ( $new_local_user_settings{$user}{max_time} >
        get_setting( 'max_time', $user ) ) {
        $new_local_user_settings{$user}{max_time} =
            get_setting( 'max_time', $user );
    }
    if ( $new_local_user_settings{$user}{default_time} >
        get_setting( 'max_time', $user ) ) {
        $new_local_user_settings{$user}{default_time} =
            get_setting( 'default_time', $user );
    }
    if ( $new_local_user_settings{$user}{max_tasks_on_pe} >
        get_setting( 'max_tasks_on_pe', $user ) ) {
        $new_local_user_settings{$user}{max_tasks_on_pe} =
            get_setting( 'max_tasks_on_pe', $user );
    }
    if ( $new_local_user_settings{$user}{max_queue} >
        get_setting( 'max_queue', $user ) ) {
        $new_local_user_settings{$user}{max_queue} =
            get_setting( 'max_queue', $user );
    }
    if ( $new_local_user_settings{$user}{exec_line} >
        get_setting( 'exec_line', $user ) ) {
        $new_local_user_settings{$user}{exec_line} =
            get_setting( 'exec_line', $user );
    }

    %{ $local_user_settings{$user} } = %{ $new_local_user_settings{$user} };

#   while (<CONF>) {              #while
#     if (/^\s*max_np\s*\=\s*(\d+)/) {
#       $user_settings{$user}{max_np}=$1 if($1<get_setting('max_np'));
#       next;
#     } elsif (/^\s*max_sum_np\s*\=\s*(\d+)/) {
#       $user_settings{$user}{max_sum_np}=$1 if($1<get_setting('max_np'));
#       next;
#     } elsif (/^\s*min_np\s*\=\s*(\d+)/) {
#       $user_settings{$user}{min_np}=$1;
#       next;
#     } elsif (/^\s*max_tasks\s*\=\s*(\d+)/) {
#       $user_settings{max_tasks}=$user;
#       next;
#     } elsif (/^\s*time\s*\=\s*(\d+)/) {
#       $user_settings{$user}{default_time}=$1 if($1<get_setting('max_time'));
#       next;
#     } elsif (/^\s*exec_line\s*\=\s*(.+)/) {
#       $user_settings{$user}{exec_line}=$1;
#       next;
#     } elsif (/^\s*write\s*\=\s*(.*)/) {
#       $user_settings{$user}{exec_write}=$1;
#       next;
#     } elsif (/^\s*post_exec\s*\=\s*(.*)/) {
#       $user_settings{$user}{post_exec_line}=$1;
#       next;
#     } elsif (/^\s*post_exec_write\s*\=\s*(.*)/) {
#       $user_settings{$user}{post_exec_write}=$1;
#       next;
#     } elsif (/^\s*kill_script\s*\=\s*(.*)/) {
#       $user_settings{$user}{kill_script}=$1;
#       next;
#     } elsif (/^\s*use_file\s*\=\s*(.*)/) {
#       $user_settings{$user}{use_file}=$1;
#       next;
#     } elsif (/^\s*file_head\s*\=\s*(.*)/) {
#       $user_settings{$user}{file_head}=$1;
#       next;
#     } elsif (/^\s*file_tail\s*\=\s*(.*)/) {
#       $user_settings{$user}{file_tail}=$1;
#       next;
#     } elsif (/^\s*file_line\s*\=\s*(.*)/) {
#       $user_settings{$user}{file_line}=$1;
#       next;
#     } elsif (/^\s*coll_nodes\s*\=\s*(.+)/) {
#       $user_settings{$user}{coll_nodes}=$1;
#       next;
#     } elsif (/^\s*outfile\s*\=\s*(.*)/) {
#       $user_settings{$user}{outfile}=$1;
#       next;
#     } elsif (/^\s*repfile\s*\=\s*(.*)/) {
#       $user_settings{$user}{repfile}=$1;
#       next;
#     } elsif (/^\s*tmp_dir\s*\=\s*(.*)/) {
#       $user_settings{$user}{tmp_dir}=$1;
#       next;
#     } elsif (/^\s*one_report\s*\=\s*(.+)/) {
#       $user_settings{$user}{one_report}=$1;
#       next;
#     } elsif (/^\s*max_queue\s*\=\s*(\d+)/) {
#       $user_settings{$user}{max_queue}=$1 if($1<get_setting('max_queue'));
#       next;
#     } elsif (/^\s*use_rsh_filter\s*\=\s*(\S+)/) {
#       $user_settings{$user}{use_rsh_filter}=$1;
#       next;
#     } elsif (/^\s*file_mask\s*\=\s*(\S+)/) {
#       $user_settings{$user}{file_mask}=$1;
#       next;
#     } elsif (/^\s*pe_select\s*\=\s*(\S+)/) {
#       $user_settings{$user}{pe_select}=$1;
#       next;
#     } elsif (/^\s*run_via_mons\s*\=\s*(\S+)/) {
#       $user_settings{$user}{run_via_mons}=$1;
#       next;
#     }
#   }
#   close CONF;
#   $rootisadm=!$global_settings{norootadm};
    return 1;
}    # load_user_conf

#
#  returns setting value
#
#  Args: name
#       [user_name]
#       [profile_name]
#       [queue_name]
#
sub get_setting( $;$$$ ) {
    my ( $sname, $user, $profile, $queue ) = @_;
    my ($q);

    $queue = '' if !defined $queue;
    $q = ( $queue ne '' ) ? $queue : $cluster_name;
    return $profile_settings{$profile}{$sname}
        if ( $profile ne '' and exists( $profile_settings{$profile}{$sname} ));
    return $local_user_settings{$user}{$sname}
        if ( ( $user ne '' )
             and exists( $local_user_settings{$user}{$sname} ) );
    return $clusteruser_settings{$q}{$user}{$sname}
        if ( ( $user ne '' )
             and exists( $clusteruser_settings{$q}{$user}{$sname} ) );
    return $user_settings{$user}{$sname}
        if ( ( $user ne '' ) and exists( $user_settings{$user}{$sname} ) );
    return $cluster_settings{$q}{$sname}
        if ( exists( $cluster_settings{$q}{$sname} ) );
    return $global_settings{$sname}
        if ( exists( $global_settings{$sname} ) );
    return undef;
}

##################################################
#
#  Reads settings for module
#
# Args:   - module name
#         - user name (may be undef or '*')
#         - setting name
#         - queue name (optional)
#
sub get_mod_setting( $$$;$ ) {
    my ( $mod, $user, $sname, $queue ) = @_;
    my ($q);

    $queue = '' if !defined $queue;
    $q = ( $queue ne '' ) ? $queue : $cluster_name;

    $mod =~ s/^.*:([^:]+)$/$1/;

    #  qlog "MOD_SETTINGS: $mod,$user,$sname,$q\n", LOG_DEBUG2;
    #  qlog join(';',keys(%mod_settings),"\n"), LOG_DEBUG2;
    #  qlog join(';',keys(%{$mod_settings{$mod}}),"\n"), LOG_DEBUG2;
    #  qlog join(';',keys(%{$mod_settings{$mod}{'*'}}),"\n"), LOG_DEBUG2;
    #  qlog join(';',keys(%{$mod_settings{$mod}{'*'}{'*'}}),"\n"), LOG_DEBUG2;

    return $mod_settings{$mod}{$q}{$user}{$sname}
        if ( exists( $mod_settings{$mod}{$q}{$user}{$sname} ) );
    return $mod_settings{$mod}{$q}{'*'}{$sname}
        if ( exists( $mod_settings{$mod}{$q}{'*'}{$sname} ) );
    return $mod_settings{$mod}{'*'}{$user}{$sname}
        if ( exists( $mod_settings{$mod}{'*'}{$user}{$sname} ) );
    return $mod_settings{$mod}{'*'}{'*'}{$sname}
        if ( exists( $mod_settings{$mod}{'*'}{'*'}{$sname} ) );
    return undef;
}

sub set_default_values {
    %global_settings = %def_global_settings;
}

#
#  deletes dir recursively as user
#  returns true if succeed, false if not
#
sub deldir($;$ ) {    #delete directory recursively
    my ( $arg, $u ) = @_;

    $arg =~ s{/+$}{};    # remove trailing slash(es)

    $arg =~ tr{\\\;\*\&\~\?\<\>\|\'\"\`}{}d;    # remove unliked symbols #`
    $arg =~ s{/\.\./}{}g;                       # remove updirs

    qlog "DELDIR '$arg'\n", LOG_INFO;
    unless ($arg) {
        qlog "Invalid arg for deldir: '$arg'\n", LOG_ERR;
        return 1;
    }

    if ( $arg eq '/' or $arg eq '/usr' or $arg eq '/var' or $arg eq '/etc' ) {
        qlog "DANGER!!!\n";
        return 3;
    }

    unless ( -d "/$arg" ) {
        qlog "No such dir '$arg'\n", LOG_ERR;
        return 2;
    }

    sub_exec( get_uid($u), $usergid{$u}, \&cleo_system, '/bin/rm', '-rf',
        "/$arg" );
    return 0 if ( -e "/$arg" );
    return 1;
}    # deldir

#
#  backslashes all spaces
#
sub space_quote( $ ){
    $_[0] =~ s/(\s)/\\$1/g;
    return $_[0];
}

{
    my $last_mtime = 0;

    sub subst_task_prop( $$$$;$ ) {    # txt, struct, time, totaltime, quote
        my $func;
        my ( $text, $child, $_time, $_total, $quote ) = @_;
        my ( $mapped_nodes, $map_file, $mtime, $i );

        if ( defined $child ) {
            if ($quote) {
                $func = sub { return quotemeta( $_[0] ); };
            } else {
                $func = sub { return $_[0]; };
            }

            $subst_args{id} = $func->( $child->{id} );

            $subst_args{adm_email} = get_setting('adm_email');

            $subst_args{queue_name} = $func->( $child->{owner} );
            $subst_args{queue}      = $func->( $child->{owner} );

            $subst_args{task_args}=();
            foreach $i (@{$child->{task_args}}){
                push @{$subst_args{task_args}}, $func->( $i );
            }

            $subst_args{user}   = $func->( $child->{user} );
            #$subst_args{task}   = $func->( $child->{task} ); #?????
            $subst_args{dir}    = $func->( $child->{dir} );
            $subst_args{status} = $func->( $child->{status} );
            $subst_args{core}   =
                $func->( $child->{core} ? 'core dumped' : '' );
            $subst_args{signal}  = $func->( $child->{signal} );
            $subst_args{outfile} = $func->( $child->{outfile} );
            $subst_args{repfile} = $func->( $child->{repfile} );
            $subst_args{np}      = $func->( $child->{np} );

            $subst_args{cpus} = $func->( $child->{nodes} );

            # node1:x,node1:y,...,nodeN:z
            $subst_args{spaced_cpus} = $subst_args{cpus};
            $subst_args{spaced_cpus} =~ s/\,/\ /g;
            $subst_args{nodes} = $func->( cpus2nodes( $child->{nodes} ) );

            # node1,node1,node1,node2,...,nodeN
            $subst_args{spaced_nodes} = $subst_args{nodes};
            $subst_args{spaced_nodes} =~ s/\,/\ /g;

            #node1:N1,node2:N2,node3:N3
            $subst_args{mpi_nodes} =
                $func->( cpus2uniq_nodes( $child->{nodes} ) );
            $subst_args{spaced_mpi_nodes} = $subst_args{mpi_nodes};
            $subst_args{spaced_mpi_nodes} =~ s/\,/\ /g;

            #node1,node2,node3
            $subst_args{uniq_nodes} = $subst_args{mpi_nodes};
            $subst_args{uniq_nodes} =~ s/:[^:,]+//g;
            $subst_args{spaced_uniq_nodes} = $subst_args{uniq_nodes};
            $subst_args{spaced_uniq_nodes} =~ s/\,/\ /g;

            $subst_args{file} = $func->( $child->{use_file} );

#            $subst_args{exe}     = $func->( $child->{exe} );
#            $subst_args{sexe}    = $func->( $child->{sexe} );
#            $subst_args{args}    = $func->( $child->{args} );

            $subst_args{exe}     = space_quote(
                                    $func->($child->{task_args}->[0]));
            $subst_args{sexe}    = $subst_args{exe};
            $subst_args{sexe}    =~ s/^.*\/(.*?)/$1/;
            my @args=map(space_quote($func->($_)),
                        @{$child->{task_args}});
            $subst_args{task}    = join(' ',@args);
            shift @args;
            $subst_args{args}    = join(' ',@args);

            $subst_args{path}    = space_quote($func->( $child->{path}));
            $subst_args{count}   = $func->( $child->{count} );
            $subst_args{home}    = space_quote(
                                    $func->($user_home{$child->{user}}));
            $subst_args{n}       = $func->( $child->{n} );
            $subst_args{nid}     = $func->( $child->{nid} );
            $subst_args{pid}     = $func->( $child->{pid} );
            $subst_args{special} = $func->( $child->{special} );
            $subst_args{cpu}     = $func->( $child->{node} );
            $subst_args{node}    = $func->( $child->{node} );
            ( $subst_args{node} ) = $subst_args{node} =~ /^([^\:]+)/;

            $map_file =
                get_setting( 'cpu_map_file', $child->{user},
                $child->{profile} );
            if ( $map_file ne '' ) {
                my %map;
#                (   undef, undef, undef, undef, undef,
#                    undef, undef, undef, undef, $mtime )
#                    = stat($map_file);
                #if ( $mtime > $last_mtime ) {
                    if ( open( MAP, "<$map_file" ) ) {
                        while (<MAP>) {
                            next unless (/(\S+)\s+(\S+)/);
                            $map{$1} = $2;
                        }
                        close MAP;
                    } else {
                        qlog "Cannot open map file! ($map_file)\n", LOG_ERR;
                    }
#                }
                $mapped_nodes = join( ',',
                    map { $map{$_}; } split( ',', $child->{full_nodes} ) );
                $subst_args{mapped_nodes} = $func->($mapped_nodes);
                ( $subst_args{mapped_node} ) =
                    map { $func->( $map{$_} ); }
                    "$child->{node}:$child->{nid}";
                qlog "MAP: $mapped_nodes\n", LOG_DEBUG;
            } else {
                $subst_args{mapped_nodes} = $subst_args{nodes};
                $subst_args{mapped_node}  = $subst_args{node};
            }
        }

        $subst_args{wrap}="cleo-wrapper.pl $child->{owner}:$child->{id}";

        $$text =~ s/\$([\w\d_]+)/'&s_val(\''.$1.'\')'/gee;
        $$text =~ s/\$\[([\d\s+*\/()xorand<>%-]+)\]/eval($1)/gee;
        $$text =~ s/\'/\"/g;
        #$$text =~ s/\\\$/\\ /g;
        if($main::debug{sbst}){
            foreach $i (sort(keys(%$child))){
                if(ref($child->{$i}) eq 'ARRAY'){
                    qlog "CH: $i=".join(';',@{$child->{$i}})."\n", LOG_DEBUG;
                }
                else{
                    qlog "CH: $i=$child->{$i}\n", LOG_DEBUG;
                }
            }
            foreach $i (sort(keys(%subst_args))){
                if(ref($subst_args{$i}) eq 'ARRAY'){
                    qlog "SA: $i=".join(';',@{$subst_args{$i}})."\n", LOG_DEBUG;
                }
                else{
                    qlog "SA: $i=$subst_args{$i}\n", LOG_DEBUG;
                }
            }
        }
   }    # subst_task_prop
}

sub s_val($ ) {
    my $v = $_[0];

    if ( exists( $subst_args{$v} ) ) {
        return $subst_args{$v};
    }
    return "\$" . $v;
}

#
#  converts string 'node1:x,node1:y,node2:x,node2:y,node2:z,node3:x' to
#                  'node1:2,node2:3:node3:1'
#
#
#############################
sub cpus2uniq_nodes( $ ) {
    my ($n) = @_;
    my %nodes;
    my ( $x, $y );

    foreach $x ( split( /\,/, $n ) ) {
        $x =~ s/:.*$//;
        ++$nodes{$x};
    }
    return join( ',', map {"$_:$nodes{$_}"} keys(%nodes) );
}

#
#  converts string 'node1:x,node1:y,node2:x,node2:y,node2:z,node3:x' to
#                  'node1,node1,node2,node2,node2,node3'
#
#
#############################
sub cpus2nodes( $ ) {
    my ($n) = @_;
    my @nodes;
    my ( $x, $y );

    foreach $x ( split( /\,/, $n ) ) {
        $x =~ s/:.*$//;
        push @nodes, $x;
    }
    return join( ',', @nodes );
}

#sub newpipe {
#    my ( $h1, $h2 );    #read/write
#    $h1 = new IO::Handle;
#    $h2 = new IO::Handle;
#    pipe( $h1, $h2 ) or die "Pipe\n";
#    my $io = select($h1);
#    $| = 1;
#    select($h2);
#    $| = 1;
#    select($io);
#    return ( $h1, $h2 );
#}

sub make_subclusters($ ) {    #parameter - name of cluster
    ($cluster_name) = @_;
    my ( $cur, $tmp, $pid );

    %child_pids = ();

    unless ( defined( @{ $clusters{$cluster_name}->{childs} } ) ) {
        @{ $clusters{$cluster_name}->{childs} } = ();
    }
    qlog "Cluster: $cluster_name {"
        . join( ';', @{ $clusters{$cluster_name}->{childs} } )
        . "}\n", LOG_DEBUG;

    for $cur ( @{ $clusters{$cluster_name}->{childs} } ) {

        # for all child clusters reqursively...

        my ( $pipe1, $pipe2, $tmp_pid );

        $pipe1 = new IO::Handle;
        $pipe2 = new IO::Handle;

        unless(socketpair($pipe1, $pipe2, AF_UNIX, SOCK_STREAM, PF_UNSPEC)){
            qlog "Cannot create socketpair in make_subclusters\n", LOG_ERR;
            return;
        }

        $pipe1->autoflush(1);
        $pipe2->autoflush(1);

        $tmp_pid = $$;
        $pid     = fork();
        die "Cannot fork!\n" unless defined $pid;
        die "Cannot fork!\n" if ( $pid < 0 );
        if ($pid) {

            #parent (master)
            qlog "Child forked (pid=$pid)\n", LOG_DEBUG;
            $child_pids{$pid} = $cur;

            $pipe1->fcntl( Fcntl::F_SETFL(),
                O_NONBLOCK() | $pipe1->fcntl( Fcntl::F_GETFL(), 0 ) );

            $down_ch{$cur} = new_handle Cleo::Conn($pipe1);
            next;
        }

        #only in child!!!
        qlog "My pid id $$, perent pid=$tmp_pid\n", LOG_INFO;
        $parent_pid = $tmp_pid;
        %down_ch=();

        $pipe2->fcntl( Fcntl::F_SETFL(),
            O_NONBLOCK() | $pipe2->fcntl( Fcntl::F_GETFL(), 0 ) );

        $up_ch        = new_handle Cleo::Conn($pipe2);
        $up_ch_select = IO::Select->new($pipe2);
        $up_ch->add_close_hook(\&main::del_from_up_select);

        undef %child_aliases;
        $parent_name = $cluster_name;

        make_subclusters($cur);

        #    for $tmp (@{$clusters{$cur}->{!pe-list}}){
        #      $pe{$tmp}={};
        #    }
        # make all others tunings.....................
        @{ $pe_list{$cluster_name} } = ();
        foreach my $i ( keys(%new_cluster_settings) ) {
            if ( exists( $new_cluster_settings{$i}->{pe} ) ) {
                push @{ $pe_list{$i} }, @{ $new_cluster_settings{$i}->{pe} };
            }
        }
        create_cluster_structure( \%cluster_settings );
        return;
    }
    $down_ch_select = IO::Select->new();
    while ( ( $cur, $tmp ) = each(%down_ch) ) {
        $down_ch_select->add( Cleo::Conn::get_h($tmp) );
        $tmp->add_close_hook(\&main::del_from_down_select);
    }

}    #~make_subclusters

#
#  Creates config file for task
#
#  Args: entry   - task hash
#        pes     - cpu list (array ref)
#        do      - 1/0 - actualy create file
#
#
sub create_config( $$$ ) {
    my ( $q_entry, $work_pe, $doit ) = @_;
    my ( @p,       $i,     $t,       %nids );

    if ( $t =
        get_setting( 'use_file', $q_entry->{user}, $q_entry->{profile} ) )
    {    #use config file

        undef %subst_args;
        subst_task_prop( \$t, $q_entry, 0, 0 );
        foreach $i ( @{$work_pe} ) {
            $i =~ /^([^:]+):(.*)/;
            push @p, $1;
            push @{ $nids{$1} }, $2;
        }
        $q_entry->{nodes}    = join( ',', @p );
        $q_entry->{use_file} = $t;

        return unless ($doit);

        qlog "Use conf-file $t\n";

        # security reasons

        unless ( open( CONF, ">$t" ) ) {
            qlog "Cannot create config file! ($t)\n", LOG_WARN;
            return;
        }

        if ( $t =
            get_setting( 'file_head', $q_entry->{user}, $q_entry->{profile} )
            ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            $t =~ s/\\n/\n/g;
            $t =~ s/\\t/\t/g;
            $t =~ s/\\r/\r/g;
            print CONF $t;
        }
        if ( $t =
            get_setting( 'file_line', $q_entry->{user}, $q_entry->{profile} )
            ) {
            my (%h,        @short_p, %u,     $a,
                $b,        $t2,      $count, $max,
                $collapse, $first,   $f_line );
            for $a (@p) {
                ++$h{$a};
                ++$u{$a};
            }
            foreach $a (@p) {
                next unless exists $u{$a};
                delete $u{$a};
                push @short_p, $a;
            }
            qlog "Creating: @p\n", LOG_DEBUG;
            $collapse =
                get_setting( 'coll_nodes', $q_entry->{user},
                $q_entry->{profile} );
            $first =
                get_setting( 'use_first_line', $q_entry->{user},
                $q_entry->{profile} );
            $f_line =
                get_setting( 'first_line', $q_entry->{user},
                $q_entry->{profile} );
            foreach $a (@short_p) {
                $b               = $h{$a};
                $q_entry->{node} = $a;
                $q_entry->{n}    = $b;
                $max             = $collapse ? 2 : $b + 1;
                for ( $count = 1; $count < $max; ++$count ) {
                    if ($first) {
                        qlog "USE_FIRST_LINE: $f_line;\n", LOG_DEBUG;
                        $t2    = $f_line;
                        $first = 0;
                    } else {
                        $t2 = $t;
                    }
                    $q_entry->{count} = $count;
                    $q_entry->{nid}   = pop @{ $nids{$a} };
                    qlog "NODE: $a/$q_entry->{nid} ($t)\n", LOG_DEBUG;
                    undef %subst_args;
                    subst_task_prop( \$t2, $q_entry, 0, 0 );
                    $t2 =~ s/\\n/\n/g;
                    $t2 =~ s/\\t/\t/g;
                    $t2 =~ s/\\r/\r/g;
                    print CONF $t2;
                    qlog "RESULT: $t2\n", LOG_DEBUG;
                }
            }
        }
        if ($t = (
                get_setting(
                    'file_tail', $q_entry->{user}, $q_entry->{profile} ) )
            ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            $t =~ s/\\n/\n/g;
            $t =~ s/\\t/\t/g;
            $t =~ s/\\r/\r/g;
            print CONF $t;
        }
        close(CONF);

        #    system("cp $q_entry->{use_file} /var/tmp");
        #    $<=$>=0; $(=$)=0;
    }
}

#
# Run task by queue entry using monitors
#
######################################################
{
    my $remote_pid = 70_000;

    sub run_via_mons( $ ) {

        #return 0    - run failed.
        #       #pid - Ok.
        #
        my $id = $_[0]->{id};

        if ( !exists( $childs_info{$id} ) ) {
            qlog "Run_via_mons: $id does not exisis\n", LOG_ERR;
            return -1;
        }

        $may_go   = 1;
        $q_change = 1;

        $remote_pid = 70_000 if ( ++$remote_pid > 1_000_000 );
        $ids{$id}->{pid} = $remote_pid;
        qlog "User $ids{$id}->{user} Task ["
            . $ids{$id}->{task_args}->[0]
            . "] on $ids{$id}->{np} proc.\n", LOG_DEBUG;
        foreach my $pe (
            @{ $ids{$id}->{shared} },
            @{ $ids{$id}->{own} },
            @{ $ids{$id}->{extranodes} }
            ) {
            $pe{$pe}->{ids}->{ $ids{$id}->{id} } =
                $remote_pid;    # add to processors pid of new task
        }
        if ( $ids{$id}->{owner} ne $cluster_name ) {
            foreach my $pe ( @{ $ids{$id}->{shared} } ) {
                $shared{$pe}->{ids}->{ $ids{$id}->{id} } =
                    $remote_pid;    # add to processors pid of new task
            }
            foreach my $pe ( @{ $ids{$id}->{own} } ) {
                $own{$pe}->{ids}->{ $ids{$id}->{id} } =
                    $remote_pid;    # add to processors pid of new task
            }
        }

        my @work_pe = sort( @{ $ids{$id}->{shared} }, @{ $ids{$id}->{own} } );
        qlog "SHARED: @{$ids{$id}->{shared}}; OWN: @{$ids{$id}->{own}}\n",
            LOG_DEBUG;

        sub_exec(get_uid($ids{$id}->{user}), $usergid{$ids{$id}->{user}},
                 \&create_config, $ids{$id}, \@work_pe, 1 );
        $childs_info{$id}->{node} = $work_pe[0];

        $childs_info{$id}->{nodes} = join( ',',
            sort( @{ $ids{$id}->{shared} }, @{ $ids{$id}->{own} } ) );
        $childs_info{$id}->{extranodes} = $ids{$id}->{extranodes};
        $childs_info{$id}->{npextra}    = $ids{$id}->{npextra};
        $childs_info{$id}->{state}      = 'prerun';
        $ids{$id}->{state}              = 'prerun';
        qlog "PID=$remote_pid  $childs_info{$id}->{nodes}\n", LOG_DEBUG;

        $pids{$id} = $remote_pid;

        #    {
        #      local $,=';'; print "+> ",%pids,"\n";
        #    }

  #    if (@{$q_entry->{shared}}>0) {
  #      #      my %args=('id' => $id);
  #      my %answ=('id'=>$id,'nodes'=>join(',',@{$q_entry->{shared}}));
  #      # tell children about run
  #      main::new_req_to_child('run_pre',\%answ,'__all__',0,SUCC_ALL|SUCC_OK,
  #                             \&nil_sub,\&every_nil_sub,
  #                             0,\&nil_sub
  #                            );
  #    }
        slog "RUN $id; $ids{$id}->{user}; $ids{$id}->{np}; ".
             join(' ',@{$ids{$id}->{task_args}})."\n";
        slog "RUN_NODES $id; $ids{$id}->{user}; $ids{$id}->{np}; ".
             "$ids{$id}->{npextra}; $childs_info{$id}->{nodes}; ".
             join(',',@{$ids{$id}->{extranodes}})."\n";

        if ( $cluster_name eq cleosupport::get_setting('root_cluster_name') )
        {

            #      move_to_queue($id,RUNNING_QUEUE);
            $ids{$id}->{state}         = 'run';
            $childs_info{$id}->{state} = 'run';

            remove_id($id);
            push @running, $ids{$id};

            $ids{$id}->{time} = $last_time;
            if ( $ids{$id}->{timelimit} > 0 ) {
                $ids{$id}->{timelimit} += $ids{$id}->{time};
                qlog
                    "TIMELIMIT: $ids{$id}->{timelimit} ($ids{$id}->{time})\n",
                    LOG_DEBUG;
            } else {
                qlog "TIMELIMIT: UNLIMITED\n", LOG_DEBUG;
            }

            #$ids{$id}->{timelimit}+=$ids{$id}->{time};

            $main::rsh_data{"$ids{$id}->{id}::$ids{$id}->{owner}"}
                ->{"np_free"} = $ids{$id}->{np} - 1;
            $main::rsh_data{"$ids{$id}->{id}::$ids{$id}->{owner}"}
                ->{"master"} = $work_pe[0];
            my %cpus;
            map { $cpus{$_} = 1 } map { /^([^:]+)/; $1; } @work_pe;
            @{ $main::rsh_data{"$ids{$id}->{id}::$ids{$id}->{owner}"}
                    ->{"nodesb"} } = keys(%cpus);

            if (    ( $ids{$id}->{use_rsh_filter} ne '' )
                and ( $ids{$id}->{second_run} eq '' ) ) {
                $ids{$id}->{file_mask} = cleosupport::get_setting(
                    'file_mask',          $ids{$id}->{user},
                    $ids{$id}->{profile}, $ids{$id}->{owner} );
                $ids{$id}->{count_first} = cleosupport::get_setting(
                    'count_first',        $ids{$id}->{user},
                    $ids{$id}->{profile}, $ids{$id}->{owner} );
                subst_task_prop( \$ids{$id}->{com_line}, $ids{$id}, 0, "" );
                @work_pe =
                    sort( @{ $ids{$id}->{shared} }, @{ $ids{$id}->{own} } );
                $ids{$id}->{rsh_num} = $ids{$id}->{np};
                $ids{$id}->{node}    = $work_pe[0];
                qlog "RF1\n", LOG_DEBUG;

                my $groups;
                foreach my $g ( split( /\s+/, $ids{$id}->{group} ) ) {
                    if ( $g =~ /^\d+$/ ) {
                        $groups .= "$g ";
                    } elsif ( exists $user_groups{$g} ) {
                        $groups .= "$user_groups{$g} ";
                    }
                }
                $ids{$id}->{group} = $groups;
                undef
                    %main::rsh_cmd_lines; #!!!! bugfix code. make it better...
                $ids{$id}->{suexec_gid} = $work_pe[0];

                qlog ">ADD NODES for $ids{$id}->{id}::$ids{$id}->{owner}: "
                    . join( ';', keys(%cpus) )
                    . "\n", LOG_DEBUG;
                qlog ">MASTER    for $ids{$id}->{id}::$ids{$id}->{owner}: "
                    . $main::rsh_data{"$ids{$id}->{id}::$ids{$id}->{owner}"}
                    ->{"master"} . "\n", LOG_DEBUG;

                my $request = Storable::thaw( Storable::freeze( $ids{$id} ) );
                main::new_req_to_mon(
                    'run',                          $request,
                    $work_pe[0],                    SUCC_ALL | SUCC_OK,
                    \&main::mon_run_handler,        undef,
                    get_setting('mon_run_timeout'), \&main::mon_run_handler );
                $main::rsh_pids{"$ids{$id}->{id}::$ids{$id}->{owner}"}
                    ->{master} = $work_pe[0];
                } else {
                my $tmp = $ids{$id}->{com_line};
                foreach my $i ( split( /\,/, $childs_info{$id}->{nodes} ) ) {
                    undef %subst_args if ( $ids{$id}->{second_run} eq '' );
                    $ids{$id}->{node}     = $i;
                    $ids{$id}->{com_line} = $tmp;
                    subst_task_prop( \$ids{$id}->{com_line},
                        $ids{$id}, 0, "" );
                    {
                        my $request =
                            Storable::thaw( Storable::freeze( $ids{$id} ) );
                        qlog "REQUESTING3($i): $request->{com_line}\n",
                            LOG_DEBUG;
                        main::new_req_to_mon(
                            'run',
                            $request,
                            $i,
                            SUCC_ALL | SUCC_OK,
                            \&main::mon_run_handler,
                            undef,
                            get_setting('mon_run_timeout'),
                            \&main::mon_run_handler );
                    }
                }
            }
        } else {

            # Not root queue. Send request to main.

            #      move_to_queue($id,PENDING_QUEUE);

            remove_id($id);
            push @running, $ids{$id};
            $ids{$id}->{state} = 'run';

            $ids{$id}->{time} = time;
            if ( $ids{$id}->{timelimit} > 0 ) {
                $ids{$id}->{timelimit} += $ids{$id}->{time};
                qlog
                    "TIMELIMIT: $ids{$id}->{timelimit} ($ids{$id}->{time})\n",
                    LOG_DEBUG;
            } else {
                qlog "TIMELIMIT: UNLIMITED\n", LOG_DEBUG;
            }

            main::answer_to_parent(
                cleosupport::get_setting('root_cluster_name'),
                0, 'run_via_mons', SUCC_OK, %{ $childs_info{$id} } );
        }
        dump_queue();
        return $remote_pid;
    }    # ~run_via_mons
}

#
# Run task by queue entry
#
# Returns <0 if error
#
######################################################
sub run_task( $ ) {

    my $q_entry = $_[0];
    my ( $pid, $id, $user, $real_tmp_dir, $t, $ret, $t2 );

    $id = $q_entry->{id};
    qlog "Run_task: $id\n", LOG_INFO;
    qlog ("Try to exec [$q_entry->{task_args}->[0]], ".
         "using outfile='$q_entry->{outfile}'\n", LOG_DEBUG)
         if ( $opts{v} );
    qlog ("repfile='$q_entry->{repfile}' tmp='$q_entry->{temp_dir}'\n",
         LOG_DEBUG)
         if ( $opts{v} );
    qlog("own: "
            . join( ',', @{ $q_entry->{own} } )
            . "\n[........................] shared: "
            . join( ',', @{ $q_entry->{shared} } ) . "\n",
        LOG_DEBUG )
        if ( $opts{v} );

    load_user_conf( $q_entry->{user}, 1 );
    #!!!r $reserved_shared -= $q_entry->{reserved};
    $q_entry->{reserved} = 0;
    for $t ( keys(%shared) ) {
        delete $shared{$t}->{ids}->{ $q_entry->{$id} };
    }

    # add extranodes, if needed.
    if (get_setting('occupy_full_node',
        $q_entry->{user},
        $q_entry->{profile})
        or $q_entry->{occupy_full_node}
        ) {

        # We need to 'occupy' all processors on used nodes!

        my ( %tnodes, $node, $i );

        foreach $t ( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) {
            $t =~ /(\S+)\:(\S+)/ or next;
            $node = $1;
            foreach $i ( @{ $the_nodes{$1} } ) {
                $tnodes{"$node:$i"} = 1;
            }
        }
        foreach $t ( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) {
            delete $tnodes{$t};
        }

        # test if some cpu are occupied by another task
        foreach $t (keys(%tnodes)){
            qlog "testing for extra $t: ".join(',',keys(%{$pe{$t}->{ids}})).";\n", LOG_DEBUG2;

            foreach $t2 (keys(%{$pe{$t}->{ids}})){
                next if($t2 eq $id);
                # this node is occupied
                delete $tnodes{$t};
            }
        }
        $q_entry->{extranodes}=[];
        if ( keys(%tnodes)>0 ) {

            # Some cpus are needed to be occupied

            push @{$q_entry->{extranodes}}, keys(%tnodes);
            $q_entry->{npextra} = scalar(@{$q_entry->{extranodes}});

            $extra_nodes_used += $q_entry->{npextra};
        }
        qlog "$extra_nodes_used extra cpus used\n", LOG_INFO;
        qlog "EXTRA CPUS:".join(',',sort(@{ $q_entry->{extranodes} })).".\n", LOG_DEBUG2;
    }

    if ( $q_entry->{owner} ne $cluster_name ) {

        # NOT OWN TASK! IT IS PRE-RUNNED! (as we hope)

        if ( $ids{$id}->{state} ne 'prerun' ) {
            qlog
                "Invalid request to run $id (from $q_entry->{owner}): state is $ids{$id}->{state}\n",
                LOG_WARN;
            return -1;
        }

        for $t (
            @{ $q_entry->{extranodes} },
            @{ $q_entry->{shared} },
            @{ $q_entry->{own} }
            ) {
            $pe{$t}->{ids}->{$id} = -1;
        }
        for $t ( @{ $q_entry->{shared} } ) {
            $shared{$t}->{ids}->{$id} = -1;
        }
        for $t ( @{ $q_entry->{own} } ) {
            $own{$t}->{ids}->{$id} = -1;
        }

        #    move_to_queue($id,RUNNING_QUEUE);
        remove_id($id);
        push @running, $ids{$id};
        $ids{$id}->{state} = 'run';

        $q_entry->{time} = time;
        $q_entry->{timelimit} += $q_entry->{time}
            if $q_entry->{timelimit} > 0;
        if ( $q_entry->{timelimit} > 0 ) {
            $q_entry->{timelimit} += $q_entry->{time};
            qlog "TIMELIMIT: $q_entry->{timelimit} ($q_entry->{time})\n",
                LOG_DEBUG;
        } else {
            qlog "TIMELIMIT: UNLIMITED\n", LOG_DEBUG;
        }
        slog "RUN_NOT_OWN $id; $q_entry->{user}; $q_entry->{owner}; ".
             "$q_entry->{np}+$q_entry->{npextra}; ".
             join(' ',@{$q_entry->{task_args}})."\n";
        main::scheduler_event(
            'event',
            {   type      => 'start',
                id        => $q_entry->{id},
                user      => $q_entry->{user},
                np        => $q_entry->{np},
                npextra   => $q_entry->{npextra},
                timelimit => $q_entry->{timelimit},
                time      => $last_time,
                nodes     => $q_entry->{nodes} } );
        count_user_np_used();
        return -1;
    }
    $real_tmp_dir = $q_entry->{temp_dir};
    undef %subst_args;
    subst_task_prop( \$real_tmp_dir, $q_entry, 0, 0 );
    $real_tmp_dir =~ s/\$\$/$$/g;
    undef %subst_args;
    subst_task_prop( \$q_entry->{outfile}, $q_entry, 0, 0 );
    undef %subst_args;
    subst_task_prop( \$q_entry->{repfile}, $q_entry, 0, 0 );

    if ( defined $q_entry->{empty_input} ) {
        undef %subst_args;
        subst_task_prop( \$q_entry->{empty_input}, $q_entry, 0, 0 );
    }

    if ( !$q_entry->{one_rep} ) {
        my $i;
        if ( ( -e $q_entry->{outfile} && ( $q_entry->{stdout} ne '' ) )
            || -e $q_entry->{repfile} ) {
            for ( $i = 1; $i < 65536; ++$i ) {
                last
                    unless ( -f "$q_entry->{outfile}.$i"
                    || -f "$q_entry->{repfile}.$i" );
            }
            if ( $i == 65536 ) {
                qlog "Too many outputs for user $q_entry->{user}!\n",
                    LOG_WARN;
                undef $i;
            }
            if ( $i > 0 ) {
                $q_entry->{outfile} .= ".$i";
                $q_entry->{repfile} .= ".$i";
            }
        }
    }
    qlog(
        "REAL outfile='$q_entry->{outfile}' repfile='$q_entry->{repfile}' tmp='$real_tmp_dir'\n",
        LOG_DEBUG )
        if ( $opts{v} );

    $q_entry->{temp_dir} = $real_tmp_dir;
    $user = $q_entry->{user};
    qlog
        "Was used by $user: $user_np_used{$user} ($q_entry->{np}+$q_entry->{npextra})\n",
        LOG_DEBUG;

    #  $user_np_used{$user}+=$q_entry->{np}+$q_entry->{npextra};
    qlog "Will be used by $user now: "
        . ( $user_np_used{$user} + $q_entry->{np} + $q_entry->{npextra} )
        . "\n", LOG_DEBUG;

    $q_change = 1;    # for @pending

    $q_entry->{no_run_again} = 1;

    # tell children about run if needed

    #  if (@{$q_entry->{shared}}>0) {
    {
        my %answ =
            ( 'id' => $id,
              'nodes' => join( ',', @{ $q_entry->{shared} },
                                    @{ $q_entry->{extranodes}} )
            );
        main::new_req_to_child(
            'run_pre',             \%answ,
            '__all__',             0,
            SUCC_ALL | SUCC_OK,    \&nil_sub,
            \&every_nil_sub, 0,
            \&nil_sub );
    }

    # do preparation tasks on nodes
    {
        #clone task info
        my $req=Storable::thaw( Storable::freeze( $q_entry ) );
        
        my @nodes=(@{ $q_entry->{shared}},
                   @{ $q_entry->{own}},
                   @{ $q_entry->{extranodes}});
        if ($is_master) {
            main::new_req_to_mon(
                'do_pre',
                $req,
                \@nodes,
                SUCC_ALL | SUCC_OK,
                \&main::mon_do_pre_handler,
                undef,
                get_setting('mon_timeout'),
                \&main::mon_do_pre_handler,
                'owner',           $q_entry->{owner},
                'id',              $id,
            );
        } else {
            main::answer_to_parent(
                cleosupport::get_setting('root_cluster_name'),
                0, 'init_attach', SUCC_OK, %req );
        }
    }
##########################################################################

    if ( $q_entry->{run_via_mons} ) {

      #
      # Initiate run
      #
      new_runned( $id, -1 );

      main::scheduler_event(
                           'event',
                           {   type      => 'start',
                               id        => $q_entry->{id},
                               user      => $q_entry->{user},
                               np        => $q_entry->{np},
                               npextra   => $q_entry->{npextra},
                               timelimit => $q_entry->{timelimit},
                               time      => $last_time,
                               nodes     => $q_entry->{nodes} } );

      # run using monitors!
      qlog "RUN_VIA_MONS\n", LOG_DEBUG;
      $q_entry->{group} =
        get_setting( 'gid', $q_entry->{user}, $q_entry->{profile} );
      $ret = run_via_mons($q_entry);
    } else {

        # Traditional run
        $q_entry->{nodes} =
            join( ',',
            sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) );
        my %cpus;
        map { $cpus{$_} = 1 }
            map { /^([^:]+)/; $1; }
            ( @{ $q_entry->{shared} }, @{ $q_entry->{own} } );
        my @nodes = sort keys %cpus;

        foreach my $pe (
            @{ $q_entry->{shared} },
            @{ $q_entry->{own} },
            @{ $q_entry->{extranodes} }
            ) {
            $pe{$pe}->{ids}->{$id} = -1;    # add to processors dummy pid
        }
        qlog "Traditional run on nodes: $q_entry->{nodes}\n", LOG_INFO;
        $q_entry->{state} = 'prerun';
        $t =
            cleosupport::get_setting( 'attach_mask', $q_entry->{user},
            $q_entry->{profile} );
        if ( $t ne '' ) {
            qlog "ATTACH ($t)\n", LOG_INFO;
            $q_entry->{attach_mask} = $t;
            my $t2;
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0, 1 );
            $t2 =
                cleosupport::get_setting( 'attach_parent_mask',
                $q_entry->{user}, $q_entry->{profile} );
            $q_entry->{parent_mask} = $t2;
            undef %subst_args;
            subst_task_prop( \$t2, $q_entry, 0, 0, 1 );
            my %args = (
                'exe_mask'    => $t,
                'parent_mask' => $t2,
                'user'        => $q_entry->{user},
                'id'          => $id,
                'owner'       => $q_entry->{owner},
                'nodes'       => $q_entry->{nodes} );

            if ($is_master) {
                main::new_req_to_mon(
                    'init_attach',
                    \%args,
                    \@nodes,
                    SUCC_ALL | SUCC_OK,
                    \&main::mon_init_attach_handler,
                    undef,
                    get_setting('mon_timeout'),
                    \&main::mon_init_attach_handler,
                    'owner',           $q_entry->{owner},
                    'nodes',           $q_entry->{nodes},
                    'id',              $id,
                    'tmout',           get_setting('attach_timeout',
                                                   $q_entry->{user},
                                                   $q_entry->{profile}
                                                   ));
                $ret = 0;
            } else {
                main::answer_to_parent(
                    cleosupport::get_setting('root_cluster_name'),
                    0, 'init_attach', SUCC_OK, %args );
                $ret = 0;
            }
        } else {
            $ret = execute_task($q_entry);
            if ( $ret <= 0 ) {

                #error
                $ret = 1;
            } else {
                $ret = 0;
            }
        }
    }
    count_user_np_used();
    qlog "RET=$ret\n";
    return $ret;
}    # run_task

#######################################################
#
#  executes task
#
#  Args: id = task id
#  Ret:  PID if task is runned
#        <=0   if fails
#

sub execute_task( $ ) {
    my ($q_entry) = @_;

    my ( $pid, $id, $t, $pipe_read, $pipe_write, $p, $pgrp );

    $id = $q_entry->{id};

    $q_change = 1;

    #
    #  Create config file...
    #
    my @work_pe = sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } );
    $q_entry->{node} = $work_pe[0];
    sub_exec(get_uid($q_entry->{user}), $usergid{$q_entry->{user}},
             \&create_config, $q_entry, \@work_pe, 1 );

    # prepare pidfile
    my $rand=int(rand(65536));
    my $pidfile = "/tmp/cleo-run-$id-$rand";
    $q_entry->{pidfile}=$pidfile;

    # do preparations in modules

    $t = get_setting( 'use_exec_modules', $q_entry->{user},
                      $q_entry->{profile} );
    if ( defined($t) ) {
        my $cancel=0;
        foreach my $i (@$t) {
            do_exec_module( $i, 'pre', $q_entry );
            if($exec_mod_cancel eq 'restart'){
                qlog "RESTART by EXEC_MODULE ($i). Not implemented now... Blocking.\n", LOG_INFO;
                #my $str="$q_entry->{id}:restart";
                #msgsnd($exec_queue, pack("l! a*",length($str),$str),1);
                $cancel=1;
                #!!!!
                #!  Workaround ONLY!!!!
                #!
                block_task($q_entry->{id},1,'__internal__','restart');
            }
            elsif($exec_mod_cancel eq 'cancel'){
                qlog "CANCEL by EXEC_MODULE ($i).\n", LOG_INFO;
                #my $str="$q_entry->{id}:cancel";
                #msgsnd($exec_queue, pack("l! a*",length($str),$str),1);
                $cancel=1;
                del_task($q_entry->{id},'__internal__','','','',
                         1,'pre-start failed');
            }
            elsif($exec_mod_cancel ne ''){
                qlog "BLOCK by EXEC_MODULE ($i).\n", LOG_INFO;
                #substr($exec_mod_cancel,MAX_QMSG)='' if
                #    length($exec_mod_cancel)>MAX_QMSG;
                #my $str="$q_entry->{id}:block:$exec_mod_cancel";
                #msgsnd($exec_queue, pack("l! a*",length($str),$str),1);
                $cancel=1;
                block_task($q_entry->{id},1,'__internal__',$exec_mod_cancel);
            }
        }
        # task cancelled, do not run!
        if($cancel==1){
            foreach my $i (@$t) {
                do_exec_module( $i, 'cancel', $q_entry, $exec_mod_cancel);
            }
            slog("CANCEL: $q_entry->{id}; $q_entry->{user}; ".
                 "$q_entry->{np}; ".
                 join(' ',@{$q_entry->{task_args}})."\n");
            return -1;
        }
    }



    #
    # Initiate run
    #
    new_runned( $id, -1 );

    main::scheduler_event(
                         'event',
                         {   type      => 'start',
                             id        => $q_entry->{id},
                             user      => $q_entry->{user},
                             np        => $q_entry->{np},
                             npextra   => $q_entry->{npextra},
                             timelimit => $q_entry->{timelimit},
                             time      => $last_time,
                             nodes     => $q_entry->{nodes} } );

    qlog "EXECUTING task $q_entry->{id} by $q_entry->{user} ($q_entry->{exe})\n",
        LOG_INFO;
    if ( $q_entry->{state} eq 'run' ) {
        qlog "Trying to run running task $id. Cancel.\n", LOG_ERR;
        return 0;
    }

    $pipe_read  = new IO::Handle;
    $pipe_write = new IO::Handle;

    unless(socketpair($pipe_read, $pipe_write, AF_UNIX, SOCK_STREAM, PF_UNSPEC)){
        qlog "Cannot create socketpair in execute_task\n", LOG_ERR;
        return;
    }

    $pipe_read->autoflush(1);
    $pipe_write->autoflush(1);
    $pipe_read->fcntl( Fcntl::F_SETFL(),
                O_NONBLOCK() | $pipe_read->fcntl( Fcntl::F_GETFL(), 0 ) );
    $pipe_write->fcntl( Fcntl::F_SETFL(),
                O_NONBLOCK() | $pipe_write->fcntl( Fcntl::F_GETFL(), 0 ) );

    $pid = fork();
    unless ( defined $pid ) {
        qlog "execute_task failed ($q_entry->{task_args}->[0])".
             " in fork\n", LOG_WARN;
        $q_entry->{special} = 'failed to fork new process ';
        del_task( $q_entry->{id} );
        dump_queue();
        return -1;
    }
    if ($pid) {    #parent

        $may_go = 1;

        if ( $pid < 0 ) {
            delete $pids{$id};
            qlog "Fork failed. User $q_entry->{user}".
                 " Task $q_entry->{task_args}->[0]\n",
                LOG_WARN;
            slog "RUN_FAIL $q_entry->{id}; $q_entry->{user}; ".
                 "$q_entry->{np}; ".
                 join(' ',@{$q_entry->{task_args}})."\n";
            return -2;
        }

        # correct pid (read it from empty)
        if ( $q_entry->{use_empty} ne '' ) {
            #local $SIG{ALRM} = sub { die "empty r/usr/share/alterator/build/ead timed out\n"; };
            my $timeout=time+get_setting('empty_timeout');
            local $log_prefix='[empty read]';
            my $line = undef; #$pipe_read->getline();;
            #alarm get_setting('empty_timeout');
            while ( !defined $line ) {
               last if(time>$timeout);
                #$line = $pipe_read->getline();
                if(open(PIDFILE,"<$pidfile")){
                    $line=<PIDFILE>;
                    if(defined $line){
                        if ($line =~ /PID=(\d+);PGRP=(\d+)/) {

                            # change pid!
                            $pid  = $1;
                            $pgrp = $2;
                            qlog "Got pid/gid from empty: $pid/$pgrp\n",
                                LOG_DEBUG;
                            close(PIDFILE);
                            last;
                        } else {
                            qlog "Bad pid line from empty: '$_'\n", LOG_ERR;
                            $line=undef;
                        }
                    }
                    close(PIDFILE);
                }
                select(undef,undef,undef,0.1);
            }
            #alarm 0;
            qlog "PID [not] read: $pid\n", LOG_DEBUG;
            $pipe_read->close();
        }
        $pids{$id} = $pid;
        #unlink($pidfile);

        #
        # Ok, write info about new child
        #
        qlog "User $q_entry->{user} Task ["
            . $q_entry->{task_args}->[0]
            . "] on $q_entry->{np} proc.\n", LOG_DEBUG;
        foreach my $pe (
            @{ $q_entry->{shared} },
            @{ $q_entry->{own} },
            @{ $q_entry->{extranodes} }
            ) {
            $pe{$pe}->{ids}->{$id} = $pid; # add to processors pid of new task
        }
        if ( $q_entry->{ $q_entry->{owner} ne $cluster_name } ) {
            foreach my $pe ( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) {
                $pe{$pe}->{ids}->{$id} = $pid;
            }
        }

        $q_entry->{pid}  = $pid;
        $q_entry->{pgrp} = $pgrp;

        #    move_to_queue($q_entry->{id},RUNNING_QUEUE);
        remove_id($id);
        push @running, $ids{$id};
        $ids{$id}->{state} = 'run';

        $childs_info{$id}->{time} = time;
        if ( $childs_info{$id}->{timelimit} > 0 ) {
            $childs_info{$id}->{timelimit} += $childs_info{$id}->{time};
            qlog
                "TIMELIMIT: $childs_info{$id}->{timelimit} ($childs_info{$id}->{time})\n",
                LOG_DEBUG;
        } else {
            qlog "TIMELIMIT: UNLIMITED\n", LOG_DEBUG;
        }

#        my @work_pe = sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } );
#        sub_exec(get_uid($q_entry->{user}), $usergid{$q_entry->{user}},
#                 \&create_config, $q_entry, \@work_pe, 0 );

        $childs_info{$id} = $q_entry;
        $childs_info{$id}->{nodes} =
            join( ',',
            sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) );
        $childs_info{$id}->{node} = $work_pe[0];

        #    $childs_info{$id}->{extranodes}=$q_entry->{extranodes};
        #    $childs_info{$id}->{npextra}=$q_entry->{npextra};
        #    $childs_info{$id}->{attach_mask}=$q_entry->{attach_mask};
        #    $childs_info{$id}->{parent_mask}=$q_entry->{parent_mask};
        qlog "EXEC PID=$pid       $childs_info{$id}->{nodes}\n", LOG_DEBUG;
        qlog "Using empty\n", LOG_DEBUG if ( $q_entry->{use_empty} );

        #    {
        #      local $,=';'; print "+> ",%pids,"\n";
        #    }
        slog "RUN $q_entry->{id}; $q_entry->{user}; $q_entry->{np}; ".
             join(' ',@{$q_entry->{task_args}})."\n";
        slog "RUN_NODES $q_entry->{id}; $q_entry->{user}; ".
             "$q_entry->{np}; $q_entry->{npextra}; $q_entry->{nodes}; "
             .join(',',@{$ids{$id}->{extranodes}})."\n";

        qlog "RUN $q_entry->{id}; $q_entry->{user}; $q_entry->{np}; ".
             join(' ',@{$q_entry->{task_args}})."\n";
        qlog "$id/$ids{$id}->{state}/$childs_info{$id}->{state}/$q_entry->{state}\n";
        dump_queue();
        return $pid;
    } else {    #child

        close_ports(1);
        #
        $log_prefix        = "[ex]";
        $global_log_prefix = '';
        
        # allow to rwx new files/dirs for owner/group
        umask(002);
        
        reload_users_changes(1);
        undef $q_entry->{nodes};
        $q_entry->{nodes} =
            join( ',',
            sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } ) );
        my $gid = get_setting( 'gid', $q_entry->{user}, $q_entry->{profile} );


        $t =
            get_setting( 'q_pre_exec', $q_entry->{user},
            $q_entry->{profile} );
        if ( $t ne '' ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            qlog "exec q_pre: '$t'\n", LOG_INFO;
            my $u=$q_entry->{user};
            sub_exec(0, 0, \&cleo_system, $t);
            qlog "Executed q_pre: '$t'\n", LOG_INFO;
        }
        $t =
            get_setting( 'q_just_exec', $q_entry->{user},
            $q_entry->{profile} );
        if ( $t ne '' ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            qlog "exec q_just (in 3 seconds): $t\n", LOG_INFO;
            launch( 3, $t, "q_just-$cluster_name.$q_entry->{id}" );
        }


        # Change task priority
        POSIX::nice(get_setting('task_local_renice',$q_entry->{user},
                    $q_entry->{profile}));

        # Change uid/gid and go to the workdir
        #
        $) = "$gid $gid $user_groups{$q_entry->{user}}";
        $( = $gid;
        $> = get_uid( $q_entry->{user} );
        $< = $>;

        qlog
            "Use uid=$<,$>; gid=$(,$) ($q_entry->{user}:$useruid{$q_entry->{user}}/$gid;$user_groups{$q_entry->{user}})\n",
            LOG_INFO;

        unless ( chdir $q_entry->{dir} ) {
            die "Cannot chdir $q_entry->{dir}\n";
        }

        # Create the environment
        if ( $q_entry->{env} ) {
            if ( ref( $q_entry->{env} ) eq 'ARRAY' ) {
                my @new_env;
                my $e;

                #      @new_env=split(/\0/,unpack("u",$q_entry->{env}));
                @new_env = @{ $q_entry->{env} };
                foreach $e (@new_env) {
                    $e =~ /(\S+)\s*\=(.*)/;
                    qlog( "ENV '$1' => '$2'\n", LOG_DEBUG2 )
                        if ( $debug{'env'} );
                    $ENV{$1} = $2 if ( $1 ne '' );
                }
            } else {
                qlog "Bad env :" . ref( $q_entry->{env} ) . "\n", LOG_ERR;
            }
        }

        qlog( "EXEC: " . join( '; ', %$q_entry ) . "\n", LOG_DEBUG )
            if ( $debug{'tsk'} );
#        my @work_pe = sort( @{ $q_entry->{shared} }, @{ $q_entry->{own} } );
#        $q_entry->{node} = $work_pe[0];
#        sub_exec(get_uid($q_entry->{user}), $usergid{$q_entry->{user}},
#                 \&create_config, $q_entry, \@work_pe, 1 );

        my $t =
            cleosupport::get_setting( 'user_pre_exec', $q_entry->{user},
            $q_entry->{profile} );
        if ( $t ne '' ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            qlog "user_exec_pre: '$t'\n", LOG_INFO;
            my $u=$q_entry->{user};
            sub_exec(get_uid($u), $usergid{$u},
                    \&cleo_system, $t);
            qlog "Executed user_exec_pre: '$t'\n", LOG_INFO;
        }
        $t =
            cleosupport::get_setting( 'user_just_exec', $q_entry->{user},
            $q_entry->{profile} );
        if ( $t ne '' ) {
            undef %subst_args;
            subst_task_prop( \$t, $q_entry, 0, 0 );
            qlog "exec just (in 3 seconds): $t\n", LOG_INFO;
            launch( 3, $t, "just-$cluster_name.$q_entry->{id}" );
        }

        # Just create report file
        open( Z, ">$q_entry->{repfile}" );
        close(Z);

        # Override temp dir
        if ( -e $q_entry->{temp_dir} ) {
            qlog
                "Temp dir '$q_entry->{temp_dir}' already exists! Reset to /tmp\n",
                LOG_WARN;
            $q_entry->{temp_dir} = "/tmp";
        }
        unless ( mkdir( $q_entry->{temp_dir}, 0700 ) ) {
            qlog
                "Cannot create temp dir '$q_entry->{temp_dir}'! Reset to /tmp\n",
                LOG_WARN;
            $q_entry->{temp_dir} = "/tmp";
        }
        $ENV{TEMP_DIR} = $q_entry->{temp_dir};

        # Correct the command line
        undef %subst_args;
        subst_task_prop( \$q_entry->{com_line}, $q_entry, 0, 0 );
        $q_entry->{com_line} =~ s/\0/\ /g;

        # %subst_args is filed now...
        # So, create ENVIRONMENT!
        #
        #foreach $t (keys(%subst_args)){
        #    $p=uc($t);
        #    $p='CLEO_'.$p;
        #    $ENV{$p} = $subst_args{$t};
        #}

        # Execute!
        qlog "Exec: '$q_entry->{com_line}'\n", LOG_INFO;
        qlog "Use empty\n", LOG_INFO if ( $q_entry->{use_empty} );
        qlog "UIDS uid=$>,$<; gid=$),$(\n", LOG_INFO;
        qlog "DIR:$q_entry->{dir}; PATH:$q_entry->{path}; ".
             "EXE:$q_entry->{exe};SEXE:$q_entry->{sexe}; ".
             "TASK:$q_entry->{task_args}->[0]\n",
            LOG_INFO;
        qlog "PATH: $ENV{PATH}\n",                                LOG_INFO;
        qlog "TEMP_DIR: $ENV{TEMP_DIR} ($q_entry->{temp_dir})\n", LOG_INFO;

        #    eval{close STDIN;};

        # create new command line with correct input and output file parameters

        #my $empty_exe = "$q_entry->{use_empty} -f -p ";
        my $empty_exe = "$q_entry->{use_empty} -f -r $pidfile ";

        eval { close STDOUT; };
        eval { close STDIN; };
        eval { close STDERR; };
        eval { close $SHORT_LOG; };


        if ( $q_entry->{stdin} ne '') {
            $q_entry->{stdin} =~ tr/\|\`\&\#\$\@\<\>//; 
            $empty_exe .= "-i $q_entry->{stdin}";
            open( STDIN,        "<$q_entry->{stdin}" )
                or open( STDIN, "</dev/null" );
        } else {
            $empty_exe .= "-i $q_entry->{empty_input}";
            open( STDIN, "</dev/null" );
        }
        if ( $q_entry->{stdout} ne '') {
            $q_entry->{stdout} =~ tr/\|\`\&\#\$\@\<\>//; 
            $empty_exe .= " -l $q_entry->{stdout}";
#            $outfile=$q_entry->{stdout};
            open( STDOUT,        ">$q_entry->{stdout}" )
                or open( STDOUT, ">/dev/null" );
            
        } else {
            $empty_exe .= " -l $q_entry->{outfile}";
#            $outfile=$q_entry->{outfile};
            open( STDOUT,        ">$q_entry->{outfile}" )
                or open( STDOUT, ">/dev/null" );
        }
        fcntl( STDOUT, F_SETFL, O_WRONLY | O_LARGEFILE );

        if ( $q_entry->{stderr} ne '') {
            $q_entry->{stderr} =~ tr/\|\`\&\#\$\@\<\>//; #`
            $empty_exe .= " -e $q_entry->{stderr}";
#            $errfile=$q_entry->{stderr};
            if ( !open( STDERR, ">$q_entry->{stderr}" ) ) {
                open( STDERR, ">/dev/null" );
            }
        }
        else{
           open( STDERR,        ">$q_entry->{outfile}" )
                or open( STDERR, ">/dev/null" );
        }
        fcntl( STDERR, F_SETFL, O_WRONLY | O_LARGEFILE );

        if ( $q_entry->{use_empty} ne '' ) {

            $q_entry->{com_line} = $empty_exe . ' -- ' . $q_entry->{com_line};
            qlog "EMEXEC: $q_entry->{com_line}\n", LOG_DEBUG;
        }
        else{
            qlog "EXEC: $q_entry->{com_line}\n", LOG_DEBUG;
        }
        eval { close $STATUS; };

#            # create out/err files before execution...
#            if($errfile ne ''){
#                if(open(ERRFILE,">$errfile")){
#                    POSIX::dup2( fileno(ERRFILE), 2 );
#                }
#            }
#            if($outfile ne ''){
#                if(open(OUTFILE,">$outfile")){
#                    POSIX::dup2( fileno(OUTFILE), 1 );
#                    if($errfile eq ''){
#                        POSIX::dup2( fileno(OUTFILE), 2 );
#                    }
#                }
#            }

#            POSIX::dup2( $pipe_write->fileno(), 1 );
#            POSIX::dup2( $pipe_write->fileno(), 2 );
#            autoflush STDOUT 1;

        no strict;
        exec( $q_entry->{com_line} );
        unlink("/tmp/cleo-launch.$cluster_name.$q_entry->{id}");
        exit(1);
    }
}

#
# Run new task by it's id
#
####################################################################################
sub run_id( $ ) {

    # IT CANNOT BE CALLED TO RUN PRE_RUNNED TASKS!!!!!!

    my ($id) = @_;
    my ( $i, $success, $p, $pid );

    qlog "Run_id from " . ( caller(1) )[2] . "  " . ( caller(1) )[3] . "\n",
        LOG_DEBUG;

    $i = $ids{$id};
    unless ($i) {
        qlog "Cannot run task with id '$id'\n", LOG_ERR;
        return 0;
    }
    return run_task($i);
}    # run_id

sub remove_id($;$ ) {

    # id, queue_type

    my ( $id, $type ) = @_;
    my $i;

    return unless ( exists $ids{$id} );
    $i = $ids{$id};

#  qlog "IDS RUNNING0:".join(',',map( {$_->{id}} @running))." \n", LOG_DEBUG2;
#   if ($i->{qtype}) {
#     if ($type && ($type ne $i->{qtype})) {
#       qlog "Remove id: called type=$type, and actually is $i->{type}\n", LOG_ERR;
#     }
#     $type=$i->{qtype};
#   } else {
#     qlog "Remove id: uninitialized queue type!\n", LOG_ERR;
#   }

    if ( $type eq NATIVE_QUEUE or !defined($type) ) {
        for ( $i = 0; $i < @queue; ++$i ) {
            if ( $queue[$i]->{id} == $id ) {
                main::scheduler_event(
                    'event',
                    {   type      => 'delete',
                        id        => $id,
                        user      => $queue[$i]->{user},
                        np        => $queue[$i]->{np},
                        timelimit => $queue[$i]->{timelimit} } );

                splice( @queue, $i, 1 );
                qlog "Deleted $id from native_queue\n", LOG_INFO;

                #return;
            }
        }
    }

    #   if ($type eq FOREIGN_QUEUE || !defined($type)) {
    #     for ($i=0; $i<@foreign;++$i) {
    #       if ($foreign[$i]->{id} == $id) {
    #         splice(@foreign,$i,1);
    #         qlog "Deleted $id from foreign_queue\n", LOG_INFO;
    #         #return;
    #       }
    #     }
    #   }
    #   if ($type eq PENDING_QUEUE || !defined($type)) {
    #     for ($i=0; $i<@pending;++$i) {
    #       if ($pending[$i]->{id} == $id) {
    #         splice(@pending,$i,1);
    #         qlog "Deleted $id from pending_queue\n", LOG_INFO;
    #         #return;
    #       }
    #     }
    #   }
    if ( $type eq RUNNING_QUEUE or !defined($type) ) {
        for ( $i = 0; $i < @running; ++$i ) {
            if ( $running[$i]->{id} == $id ) {
                main::scheduler_event(
                    'event',
                    {   type      => 'finish',
                        id        => $id,
                        user      => $running[$i]->{user},
                        np        => $running[$i]->{np},
                        timelimit => $running[$i]->{timelimit} } );
                splice( @running, $i, 1 );
                qlog "Deleted $id from running_queue\n", LOG_INFO;

                #return;
            }
        }
    }
    qlog "Remove id: $id done\n", LOG_DEBUG;

#  qlog "IDS RUNNING:".join(',',map( {$_->{id}} , @running))." \n", LOG_DEBUG2;
    return;
}

sub req_child_pe($$ ) {

    #  id  number
    my ( $id, $np ) = @_;
    my ( $i, $q_e );

    for ( $i = 0; $i < @queue; ++$i ) {
        if ( $queue[$i]->{id} == $id ) {
            $q_e = $queue[$i];
            last;
        }
    }
    unless ($q_e) {
        for ( $i = 0; $i < @foreign; ++$i ) {
            if ( $foreign[$i]->{id} == $id ) {
                $q_e = $foreign[$i];
                last;
            }
        }
    }
    unless ($q_e) {
        for ( $i = 0; $i < @pending; ++$i ) {
            if ( $pending[$i]->{id} == $id ) {
                $q_e = $pending[$i];
                last;
            }
        }
    }
    return unless $q_e;

    my $q_entry = {};
    %$q_entry = %$q_e;
    $q_entry->{np} = $np;

    $q_entry->{gummy}     = 1;
    $q_entry->{lastowner} = $cluster_name;
    $q_entry->{oldid}     = $id;
    main::new_req_to_child(
        'add',                          $q_entry,
        '__all__',                      0,
        SUCC_OK | SUCC_ALL,             \&main::chld_add_handler,
        \&main::chld_every_add_handler, get_setting('intra_timeout'),
        \&main::chld_add_handler,       'channel',
        '' );
}    # req_child_pe

sub get_entry($ ) {
    return undef unless exists $ids{ $_[0] };
    return $ids{ $_[0] };
}

# sub get_queue_type($ ){
#   foreach my $i (@queue) {
#     return NATIVE_QUEUE if($i->{id} eq $_[0]);
#   }
#   foreach my $i (@foreign) {
#     return FOREIGN_QUEUE if($i->{id} eq $_[0]);
#   }
#   foreach my $i (@pending) {
#     return PENDING_QUEUE if($i->{id} eq $_[0]);
#   }
#   foreach my $i (@running) {
#     return RUNNING_QUEUE if($i->{id} eq $_[0]);
#   }
#   return NOT_IN_QUEUE;
# }                               # get_queue_type

# sub move_to_queue($$;$ ){
#   my ($id,$q,$inhead)=@_;

#   qlog "MOVE: $id, $q\n", LOG_INFO;
#   return unless $ids{$id};
#   remove_id($id);
# #  my $ptr=(($q eq NATIVE_QUEUE)?\@queue:(($q eq FOREIGN_QUEUE)?\@foreign:
# #                                         (($q eq PENDING_QUEUE)?\@pending:\@running)));
#   my $ptr=($q eq NATIVE_QUEUE)?\@queue:\@running;
#   if($inhead){
#     unshift(@$ptr,$ids{$id});
#   }
#   else{
#     push @$ptr, $ids{$id};
#   }
# #  $ids{$id}->{state}=(($q eq NATIVE_QUEUE)?'queued':
# #                      (($q eq FOREIGN_QUEUE)?'prerun':
# #                       ($q eq PENDING_QUEUE)?'waiting':
# #                       'run'));
#   $ids{$id}->{qtype}=$q;
#   $q_change=1;
# #  dump_queue();
#   qlog "SET $id QUEUE TO $ids{$id}->{qtype}/$ids{$id}->{state}\n", LOG_DEBUG;
# }                               # move_to_queue

sub del_from_queue($ ) {

    # DOES NOT CORRECT $reserved_shared!!! Do it yoursef!
    my $id = shift;
    my $q  = get_entry($id);
    if ($q) {
        my ( %sc, $p, $p2 );
        if ( @{ $q->{shared} } > 0 or $q->{state} eq 'prerun' ) {
            qlog "DEL_FROM_Q: " . scalar( @{ $q->{shared} } ) . "\n",
                LOG_DEBUG;
            main::new_req_to_child(
                'del',
                { 'id' => $q->{id} },
                '__all__',
                0,
                SUCC_ALL | SUCC_OK,
                \&main::chld_del_handler,
                \&main::chld_every_del_handler,
                get_setting('intra_timeout'),
                \&main::chld_del_handler );
            qlog "Sent del subrequest to all childs\n", LOG_DEBUG;
        }

        for my $p ( keys(%pe) ) {
            delete $pe{$p}->{ids}->{$id}     if exists $pe{$p};
            delete $shared{$p}->{ids}->{$id} if exists $shared{$p};
            delete $own{$p}->{ids}->{$id}    if exists $own{$p};
        }
        remove_id($id);
        delete $childs_info{$id};
    }
    delete $ids{$id} if $ids{$id};
    $may_go   = 1;
    $q_change = 1;

}    # del_from_queue

sub count_free($$ ) {    # actually \@ and \%
    my ( $free, $pe ) = @_;    # in free returned list of nodes NAMES!!!!!!!!
    my ( $p, $i );             # free is POTENTIALLY free nodes for shared
                               # and really free for own ones.
    for $i ( keys(%$pe) ) {
        $p = $pe->{$i};
        next if $i eq '';      #BUG!!!!!!!!!!!!!!!!!!!!!!!
        next if $pe{$i}->{blocked};
        qlog(
            "CF_PE=$i; count="
                . scalar( keys( %{ $p->{ids} } ) )
                . " max:$p->{max}\n",
            LOG_DEBUG )
            if ( $debug{cf} );
        push( @$free, $i )
            if ( scalar( keys( %{ $p->{ids} } ) ) < $p->{max} );
    }
}    # count_free

#
#  returns count of own cpus, reserved for given task
#
#  Args: id    - task id
#
sub count_reserved_for_id($) {
    my $id = $_[0];
    my ($i, $ret, $cid);

    for $i (keys(%own)) {
        next if $own{$i}->{blocked};
        foreach $cid (keys(%{$own{$i}->{ids}})){
            ++$ret if $cid eq $id;
        }
    }
}   # count_reserved_for_id

#
#  returns count of reserved own cpus
#
sub count_reserved_own() {
    my ($i, $ret, $cid);

    for $i (keys(%own)) {
        next if $own{$i}->{blocked};
        foreach $cid (keys(%{$own{$i}->{ids}})){
            ++$ret if $own{$i}->{ids}->{$cid}==-1;
        }
    }
}   # count_reserved_for_id

####################################################
#
#  Delete given task
#
#  args:  id       - task id (all - del all tasks)
#         user     - which user tries to del task
#         mask     - regexp of task name
#         userlist - list of tasks owners (via space or comma)
#         rmask    - '' - all, 'r' - running, 'q' - queued
#         forced   - delete tasks from parent
#         reason   - description of deletion
#
sub del_task( $$;$$$$$ ) {
    my ( $id, $user, $mask, $userlist, $rmask, $forced, $reason ) = @_;
    my ( $success, $ret );
    my ( $ch, $i, $time, $h, $m, $s, $p, @ids, $all, $flag );
    my ( $shared_too, $del_count, %args );

    $user      = uid2user($user);
    $del_count = 0;
    qlog "Del_task: '$id' by $user ($mask/$userlist)\n", LOG_INFO;

    return "-You cannot use userlist in this request\n"
        if ( !isadmin($user) and ( $userlist ne '' ) );

    # get all requested ids. Check if 'all' are desired.
    @ids = split( /,/, $id );
    $all = 0;
    foreach $i (@ids) {
        $all = 1 if ( $i =~ /^all$/ );
        return "-Illegal id: $i\n" unless ( $i =~ /^(\d+|all)$/ );
    }

    # mark work fase
    $success = 2;

    # for all running tasks
    if ( ( $rmask eq '' ) || ( $rmask !~ /r/ ) ) {
        foreach $ch (@running) {
            next if ( $ch->{substate} eq 'deleting' );

            # matches id?
            if ( $all == 0 ) {
                $flag = 1;
                foreach $i (@ids) {
                    if ( $i eq $ch->{id} ) {
                        $flag = 0;
                        last;
                    }
                }
            }
            next if $flag;

   # the task was found, but bay be permissions wouldn't allow to delete it...
            $success = 3 unless $success == 1;

            # can do this?
            next if ( ( $ch->{user} ne $user ) and !isadmin($user) );

            # matches userlist?
            if ( $userlist ne '' ) {
                next if ( $userlist !~ /\b$ch->{user}\b/ );
            }

            # matches mask?
            if ( $mask ne '' ) {
                my $line = join(' ', @{$ch->{task_args}});
                next if ( $line !~ /$mask/ );
            }

            # do the deletion
            qlog "Del_task2: $ch->{id}\n", LOG_DEBUG;
            ++$del_count;

            if ( $ch->{pid} > 0 ) {

                # delete own task

                if ($reason) {
                    $ch->{special} = $reason;
                } else {
                    $ch->{special} = "Deleted by $user ";
                }

                $ch->{substate} = 'deleting';
                if ( $ch->{run_via_mons} ) {
                    main::answer_to_parent(
                        cleosupport::get_setting('root_cluster_name'),
                        0,
                        'del_mon_task',
                        SUCC_OK,
                        'id',
                        $ch->{id},
                        'mons',
                        $ch->{nodes} );

                    #!!!          push @dead, $ch->{id};
                } else {
                    if ( $ch->{attach_mask} ne '' ) {
                        main::answer_to_parent(
                            cleosupport::get_setting('root_cluster_name'),
                            0,
                            'del_mon_task',
                            SUCC_OK,
                            'id',
                            $ch->{id},
                            'mons',
                            $ch->{nodes} );

                        #            push @dead, $ch->{id};
                    }
                    sc_task_in( get_setting('kill_head_delay'),
                        \&delayed_kill_head, $user, $ch );
                }

                qlog "x\n", LOG_DEBUG2;

            } else {

                #delete not own task...
                if ( $ch->{fictive} ) {
                    push @dead, $ch->{id};
                    qlog "DDD PUSH_TO DEAD\n", LOG_DEBUG2;
                } else {
                    del_from_queue( $ch->{id} );
                    qlog "DDDDDDDDD\n", LOG_DEBUG2;
                }
            }
            qlog "xxx\n", LOG_DEBUG2;
            $success = 1;
            $ch->{time_to_delete} =
                $last_time + get_setting('kill_head_delay');
        }
        qlog "xx2\n", LOG_DEBUG2;
    }

    # for queued tasks
    if ( ( $rmask eq '' ) || ( $rmask !~ /q/ ) ) {
        for $ch ( @queue, @pending, @foreign ) {

            # matches id?
            if ( $all == 0 ) {
                $flag = 1;
                foreach $i (@ids) {
                    if ( $i eq $ch->{id} ) {
                        $flag = 0;
                        last;
                    }
                }
            }
            next if $flag;

   # the task was found, but bay be permissions wouldn't allow to delete it...
            $success = 3 unless $success == 1;

            # can do this?
            next if ( ( $ch->{user} ne $user ) and !isadmin($user) );

            # matches userlist?
            if ( $userlist ne '' ) {
                next if ( $userlist !~ /\b$ch->{user}\b/ );
            }

            # matches mask?
            if ( $mask ne '' ) {
                my $line = join(' ', @{$ch->{task_args}});
                next if ( $line !~ /$mask/ );
            }

            # delete not own task?
            next
                if ($ch->{old_id} > 0
                and !$forced
                and !isadmin( $user, $cluster_name ) );

            # do the deletion
            ++$del_count;

            # correct reserved shared
            #!!!r $reserved_shared -= $ch->{reserved};
            $ch->{reserved} = 0;
            for $p ( @{ $ch->{own} } ) {
                delete $own{$p}->{ids}->{ $ch->{id} } if exists $own{$p};
                delete $pe{$p}->{ids}->{ $ch->{id} };
            }
            for $p ( @{ $ch->{shared} } ) {
                delete $shared{$p}->{ids}->{ $ch->{id} }
                    if exists $shared{$p};
                delete $pe{$p}->{ids}->{ $ch->{id} };
                $shared_too = 1;
            }
            $shared_too = 1 if ( $ch->{state} eq 'prerun' );

            #      del_from_queue($id);
            if ($shared_too) {
                for $p ( @{ $clusters{$cluster_name}->{childs} } ) {
                    $args{'id'} = $ch->{id};
                    main::new_req_to_child(
                        'del',
                        \%args,
                        '__all__',
                        0,
                        SUCC_OK | SUCC_ANY,
                        \&main::chld_del_handler,
                        \&main::chld_every_del_handler,
                        get_setting('intra_timeout'),
                        \&main::chld_del_handler );
                }
            }
            if ( $ch->{run_via_mons} && ( $ch->{state} eq 'prerun' ) ) {
                main::answer_to_parent(
                    cleosupport::get_setting('root_cluster_name'),
                    0,
                    'del_mon_task',
                    SUCC_OK,
                    'id',
                    $ch->{id},
                    'mons',
                    $ch->{nodes} );
            }
            del_from_queue( $ch->{id} );

            #qlog "DDDDDDD2\n", LOG_DEBUG;
            $success = 1;
        }
    }
    if ( $success == 1 ) {
        $may_go   = 1;
        $q_change = 1;
        qlog "Deleted $del_count task(s).\n", LOG_INFO;
        return "+Deleted $del_count task(s).\n";
    } elsif ( $success == 2 ) {
        qlog "Nothing deleted.\n", LOG_INFO;
        return "-No such task(s) found.\n";
    } elsif ( $success == 3 ) {
        qlog "Nothing deleted. Wrong permissions\n", LOG_INFO;
        return "-Wrong permissions. No tasks deleted.\n";
    }
    qlog "Not deleted - no task.\n", LOG_INFO;
    return "-No such task(s)\n";
}    # del_task

sub delayed_kill_head($$) {
    my ( $user, $ch ) = @_;

    return unless exists $childs_info{ $ch->{id} };

    # call killscript!
    my $tmp;
    $tmp = cleosupport::get_setting( 'kill_script', $user, $ch->{profile} );
    qlog "KILLSCRIPT2 for $ch->{id} '$tmp'\n", LOG_DEBUG;

    if ( $tmp ne '' ) {
        undef %subst_args;
        subst_task_prop(
            \$tmp,
            $childs_info{ $ch->{id} },
            $childs_info{ $ch->{id} }->{time}, "" );
        qlog "exec killscript: '$tmp'\n", LOG_INFO;
        launch( 0, "$tmp", "$cluster_name.0000-$ch->{id}" );
    } else {
        my $delay = get_setting('kill_head_delay');

        if ( $childs_info{ $ch->{id} }->{final_kill} ) {
            kill_tree( 9, $childs_info{ $ch->{id} }->{pid} );
            push @dead, $ch->{id};
        } else {
            kill_tree( 15, $childs_info{ $ch->{id} }->{pid} );    #TERM
            $childs_info{ $ch->{id} }->{final_kill} = 1;
            sc_task_in( $delay, \&delayed_kill_head, $user, $ch );
            $childs_info{ $ch->{id} }->{substate}       = 'deleting';
            $childs_info{ $ch->{id} }->{time_to_delete} = $last_time + $delay;
        }
    }
}

sub autoblock( $$$ ) {
    my ( $userlist, $val, $name ) = @_;
    $userlist =~ tr/\n\r\0//d;
    my @users = split( /(\s|,)+/, $userlist );
    my $i;

    $name = uid2user($name);
    qlog "autoblock: '$userlist' $val by $name\n", LOG_DEBUG;
    if ( !isadmin($name) ) {
        return "-You are not authorized to do this!";
    }
    if ( $val == 0 ) {    #unset autoblock
        foreach $i (@users) {
            delete $autoblock{$i};
        }
        block_task( 'all', 0, '__internal__', 'autoblock', $userlist );
        $q_change=1;
    }
    if ( $val == 1 ) {    #set autoblock
        foreach $i (@users) {
            $autoblock{$i} = 1;
        }
    }
    if ( $val == 2 ) {    #unset autononblock
        foreach $i (@users) {
            delete $autononblock{$i};
        }
    }
    if ( $val == 3 ) {    #set autononblock
        foreach $i (@users) {
            $autononblock{$i} = 1;
        }
    }
    if ( $val == 4 ) {    #unset all_autoblock
        $all_autoblock = 0;
        block_task( 'all', 0, '__internal__', 'autoblock' );
        $q_change=1;
    }
    if ( $val == 5 ) {    #set all_autoblock
        $all_autoblock = 1;
    } else {
        qlog "Wrong value for autoblock ($val)\n", LOG_ERR;
    }
    $q_change = 1;
    return "+$cluster_name: autoblock for $userlist "
        . ( $val ? "" : "re" )
        . "was set";
}    #~autoblock

sub set_entry_priority( $$$$ ) {
    my ( $queue, $i, $value, $user ) = @_;
    my ( $e, $max_pri );

    $user    = uid2user($user);
    $max_pri =
        cleosupport::get_setting( 'priority', $user,
        $queue->[$i]->{profile} );
    $e = $queue->[$i];
    if ( !isadmin($user) ) {
        if ( $e->{user} ne $user ) {
            qlog "Set_pri: cannot gain priveleges ($user)\n", LOG_WARN;
            return "-You have no permission to do this\n";
        }
        if ( $value > $max_pri ) {
            return "-Maximum priority for you is $max_pri\n";
        }
    }
    $e->{priority} = $value;
    splice( @$queue, $i, 1 );
    for ( $i = 0; $i < @$queue; ++$i ) {
        last if ( $queue->[$i]->{priority} < $value );
    }
    splice( @$queue, $i, 0, $e );
    qlog "successfull\n", LOG_DEBUG2;

    #  qlog ">> ".join(';',map {$_->{id}} @$queue)." <<\n", LOG_DEBUG;
    $q_change = 1;
    return "+Ok\n";
}

sub set_priority( $$$ ) {
    my ( $id, $value, $user ) = @_;
    my ($i);

    $user = uid2user($user);
    qlog "set_priority: '$id' ($value)\n", LOG_INFO;
    return "-Illegal id: $id\n" unless ( $id =~ /^\d+$/ );
    for ( $i = 0; $i < scalar(@queue); ++$i ) {
        return set_entry_priority( \@queue, $i, $value, $user )
            if ( $queue[$i]->{id} == $id );
    }
    for ( $i = 0; $i < scalar(@pending); ++$i ) {
        return set_entry_priority( \@pending, $i, $value, $user )
            if ( $pending[$i]->{id} == $id );
    }
    for ( $i = 0; $i < scalar(@foreign); ++$i ) {
        return set_entry_priority( \@foreign, $i, $value, $user )
            if ( $foreign[$i]->{id} == $id );
    }
    qlog "Set_priority: task $id
         not found\n", LOG_DEBUG;
    return "-No such task\n";
}    # set_priority

#
#
#  Change task attribute (for tasks in current queue only!)
#
#  Args:  id      task id
#         attr    attribute name
#         val     attribute value
#         user    user, who requests change
#
#  Return: status string (starts with '-' = bad, '+' - OK).
#
sub set_attribute( $$$$ ) {
    my ( $id, $attr, $value, $user ) = @_;
    my ( $e,  $max );

    $user = uid2user($user);
    $e    = get_entry($id);

    # does this task exist?
    unless ( defined $e ) {
        return "-No such task\n";
    }

    # which attribute is changing?
    if ( $attr eq 'timelimit' ) {

        # check validity...
        if ( $value < 0 ) {
            return "-Invalid value: $value\n";
        }

        $max = cleosupport::get_setting( 'max_time', $user );
        if ( !isadmin($user) ) {
            if ( $e->{user} ne $user ) {
                qlog "chattr: cannot gain priveleges ($user)\n", LOG_WARN;
                return "-You have no permission to do this\n";
            }
            if ( $value > $max ) {
                return "-Maximum timelimit for you is $max\n";
            }
        }
        if ( $value == 0 ) {
            $e->{timelimit} = 0;
        } else {
            if ( $e->{state} eq 'run' ) {
                $e->{timelimit} = $e->{time} + $value;
            } else {
                $e->{timelimit} = $value;
            }
        }
    } else {
        qlog "Bad attr name: $attr ($id/$user)\n";
        return "-Bad attribute ($attr)\n";
    }
    qlog "chattr successfull (id=$e->{id} val=$e->{timelimit})\n", LOG_DEBUG;
    $q_change = 1;
    return "+Ok\n";
}

sub get_task_list($$ ) {
    my ( $full, $tech ) = @_;
    my ( $x, $s, $day, $hr, $min, $sec, @out );

    push @out, "Queue: $cluster_name\n";
    if ($tech) {
        my ( @free_own, @free_sh, $free_total, $free_shared_total, $id,
            $status );

        count_free( \@free_own, \%own );
        count_free( \@free_sh,  \%shared );
        $free_shared_total = max( 0, @free_sh - $reserved_shared );
        $free_total = $free_shared_total + @free_own;
        push @out,
            "Free: $free_total (shared: free $free_shared_total; reserved $reserved_shared)\n";
        push @out,
            "Detailed: own="
            . scalar(@free_own)
            . " shared="
            . scalar(@free_sh) . "\n";
    }

    unless ( @running + @foreign + @pending + @queue ) {
        push @out, "No tasks.\n";
        return join( '', @out );
    }
    if (@running) {
        $" = ";";
        push @out, ">>> Running " . scalar(@running) . " tasks(s):\n";
        push @out, " ID   :User      :NP : Time      :Task\n";
        foreach $x (@running) {
            ( $sec, $min, $hr, undef, undef, undef, undef, $day ) =
                gmtime( $last_time - $x->{time} );
            $hr += $day * 24;
            $s = sprintf(
                " %-5d:%-10s:%-3d: %3d:%02d:%02d :%s%s%s\n",
                $x->{id}, $x->{user},
                @{ $x->{own} } + @{ $x->{shared} },    #$x->{np},
                $hr, $min, $sec,
                $x->{oldid}
                ? ( $tech ? "[$x->{owner}/$x->{oldid}]" : '*' )
                : '',
                $tech ? "[$x->{blocked}]" : '',
                $x->{sexe} );
            push @out, $s;
            if ($full) {
                my $line = join(' ',@{$x->{task_args}});
                $s = sprintf( "Out: %s\nTask: %s\n",
                    $x->{outfile}, $line );
                push @out, $s;
                push @out,
                    "Nodes: @{$x->{own}}"
                    . ( @{ $x->{shared} } ? "(@{$x->{shared}})" : "" ) . "\n";
            }
            if ($full) {
                push @out,
                    "----------------------------------------------------------------------\n";
            }
        }
    }
    if ( @foreign + @pending + @queue ) {
        $x = scalar(@foreign) + scalar(@pending) + scalar(@queue);
        push @out, "### Queued $x tasks(s):";
        push @out,
            scalar(@foreign) . ";" . scalar(@pending) . ";" . scalar(@queue)
            if $tech;
        push @out, "\n";
        qlog "--- Queued $x tasks(s) :$#foreign; $#pending; $#queue;\n",
            LOG_DEBUG;
        push @out, " ID   :User      :NP :Pri:Task\n";
        for $x ( @foreign, @pending, @queue ) {
            $s = sprintf(
                " %-5d:%-10s:%-3d:%-3d:%s%s%s\n",
                $x->{id},
                $x->{user},
                $x->{np},
                $x->{priority},
                $x->{oldid}
                ? ( $tech ? "[$x->{owner}/$x->{oldid}]" : '*' )
                : '',
                $tech ? "[$x->{blocked}]" : '',
                $x->{sexe} );
            push @out, $s;
            if ($tech) {
                $s = sprintf(
                    "   Got: %-2d;  Owner:%s; Queue: $x->{state}\n",
                    @{ $x->{shared} } + @{ $x->{own} },
                    $x->{lastowner} );
                push @out, $s;
            }
        }
        push @out,
            "----------------------------------------------------------------------\n";
    }
    return join( '', @out );
}    # get_task_list

#
# flags:
#   f: foreign tasks
#   o: own tasks
#   p: processors stat
#   P: global processors stat
#   m: default timelimit
#   M: maximum timelimit
#   O: other stats/limits (user info)
#   s: runing mode
#   B: blocked pe
#   b: blocked tasks
#   u=u1;u2;... list of users
# for every task:
#   c: used cpus
#   C: custom fields
#   >: outfile
#   r: repfile
#   w: workdir
#   F: full task line

#
# Returns string with formatted task list.
# Parameters of output are formed from flags (argument)
#
#################################
sub get_task_list_w_flags($$ ) {
    my ( $user, $flags ) = @_;
    my ( %users, $x, @out, $u, $flag );
    my ( @free_own, @free_sh, $free_total, $free_shared_total, $id, $status );

    $user = uid2user($user);
    push @out, "Queue: $cluster_name\n";

    while ( $flags =~ s/u=([^;]+);// ) {
        $users{$1} = 1;
    }

    qlog "_w_ $flags\n", LOG_DEBUG;
    unless ( ( $flags =~ /o/ ) or ( $flags =~ /f/ ) or ( keys(%users) ) ) {
        if ( isadmin($user) ) {
            $flags .= 'fo';
        } else {
            $flags .= 'o';
            $x = get_setting( 'def_show_foreign_too', $user );
            $flags .= 'f' if ($x);
        }
    }

    if ( $flags =~ /p|P/ ) {
        count_free( \@free_own, \%own );
        count_free( \@free_sh,  \%shared );
        $free_shared_total = max( 0, @free_sh - $reserved_shared );
        $free_total = $free_shared_total + @free_own;
        if ( $flags =~ /P/ ) {
            push @out,
                "Free: $free_total\nShared_free: $free_shared_total\nShared_reserved: $reserved_shared\n";
            push @out, "Total_own: " . scalar( keys(%own) ) . "\n";
            push @out, "Total_shared: " . scalar( keys(%shared) ) . "\n";
            push @out,
                "Num_blocked: "
                . scalar( grep { $pe{$_}->{blocked} } keys(%pe) ) . "\n";
        }
        if ( $flags =~ /p/ ) {
            push @out,
                "Free_own: "
                . join( ',', @free_own )
                . "\nFree_shared="
                . join( ',', @free_sh ) . "\n";
        }
        push @out, "Used_extra: $extra_nodes_used\n";
    }

    if ( $flags =~ /m/ ) {
        push @out,
            "Def_timelimit: "
            . get_setting( 'default_time', $user, '', $cluster_name ) . "\n";
    }
    if ( $flags =~ /M/ ) {
        push @out,
            "Max_timelimit: "
            . get_setting( 'max_time', $user, '', $cluster_name ) . "\n";
    }
    if ( $flags =~ /O/ ) {
        push @out,
            "Max_np: "
            . get_setting( 'max_np', $user, '', $cluster_name ) . "\n";
        push @out,
            "Max_queue: "
            . get_setting( 'max_queue', $user, '', $cluster_name ) . "\n";
        push @out,
            "Max_sum_np: "
            . get_setting( 'max_sum_np', $user, '', $cluster_name ) . "\n";
        push @out,
            "Max_CPU_hours: "
            . get_setting( 'max_cpuh', $user, '', $cluster_name ) . "\n";
        push @out,
            "Max_tasks: "
            . get_setting( 'max_tasks', $user, '', $cluster_name ) . "\n";
        push @out,
            "Priority: "
            . get_setting( 'priority', $user, '', $cluster_name ) . "\n";
        push @out,
            "Def_priority: "
            . get_setting( 'def_priority', $user, '', $cluster_name ) . "\n";
        foreach $x ( keys( %{ $sched_user_info{$cluster_name}->{$user} } ) ) {
            push @out,
                "$x: " . $sched_user_info{$cluster_name}->{$user}->{$x} . "\n";
        }
    }

    if ( $flags =~ /s/ ) {
        push @out,
            "Blocked: " . ( ( $mode & MODE_QUEUE_ALLOW ) ? '0' : '1' ) . "\n";
        push @out,
            "Norun: " . ( ( $mode & MODE_RUN_ALLOW ) ? '0' : '1' ) . "\n";
    }

    if ( $flags =~ /B/ ) {

        #    push @out, "Blocked_pe: ".join(',',sort(keys(%blocked_pe)))."\n";
        push @out,
            "Blocked_pe: "
            . join( ',', sort( grep { $pe{$_}->{blocked} } keys(%pe) ) )
            . "\n";
    }
    if ( $flags =~ /b/ ) {
        my @tmp;
        foreach $x ( @running, @foreign, @pending, @queue ) {
            push @tmp, "$x->{id}:" . join( '#', @{ $x->{blocks} } )
                if ( $x->{blocked} );
        }
        push @out, "Blocked_tasks: " . join( '&', @tmp ) . "\n";
    }

    if ( $flags =~ /o|f/ or keys(%users) ) {
        my ( $own, $foreign );
        $own     = ( $flags =~ /o/ );
        $foreign = ( $flags =~ /f/ );

        push @out, "Running: " . scalar(@running) . "\n";

        #    push @out,"Pre-runned: ".scalar(@foreign)."\n";
        #    push @out,"Pending: ".scalar(@pending)."\n";
        push @out,
            "Pre-runned: "
            . scalar( grep( { $_->{state} eq 'prerun' } @queue ) ) . "\n";
        push @out,
            "Pending: "
            . scalar( grep( { $_->{state} eq 'blocked' } @queue ) ) . "\n";
        $x = scalar(@foreign) + scalar(@queue);
        push @out, "Queued: $x\n";
        foreach $x ( @running, @foreign, @pending, @queue ) {
            $flag = 0;
            $flag = 1 if ( $own && ( $x->{user} eq $user ) );
            $flag = 1 if ( $foreign && ( $x->{user} ne $user ) );
            $flag = 1 if ( exists $users{$user} );
            next unless $flag;
            push @out,
                "Id: $x->{id}\nState: $x->{state}\nUser: $x->{user}\nNp: $x->{np}\n";
            push @out,
                "Extracpus: ".scalar(@{$x->{extranodes}})."\n";
            push @out,
                "Time: $x->{time}\nBlocked: $x->{blocked}\nOwner: $x->{owner}\nOwner_id: $x->{oldid}\n";
            push @out, "Short_exe: $x->{sexe}\nPriority: $x->{priority}\n";
            push @out, "Added: $x->{added}\n";
            push @out, "Timelimit: $x->{timelimit}\n";
            push @out, "Estimated_run: $x->{estimated_run}\n";

            if ( ref( $x->{blocks} ) eq 'ARRAY' ) {
                push @out, "Blocks: " . join( '#', @{ $x->{blocks} } ) . "\n";
            } else {
                push @out, "Blocks: \n";
            }
            if ( $flags =~ /c/ ) {
                push @out, "Cpus: ",
                    join( ',', @{$x->{own}}, @{$x->{shared}}, @{$x->{extranodes}}), "\n";
            }
            if ( $flags =~ /\>/ ) {
                push @out, "Out: $x->{outfile}\n";
            }
            if ( $flags =~ /r/ ) {
                push @out, "Rep: $x->{repfile}\n";
            }
            if ( $flags =~ /w/ ) {
                push @out, "Work: $x->{dir}\n";
            }
            if ( $flags =~ /F/ ) {
                push @out, join(' ', 'Full:', @{$x->{task_args}})."\n";
            }
        }
    }
    return join( '', @out );
}    # get_task_list_w_flags

sub new_mode($$$ ) {
    my ( $user, $set, $clear ) = @_;
    my $old;

    $user = uid2user($user);
    if ( !isadmin($user) ) {
        return "You are not authorized to change server mode ($user).\n";
    }
    $old = mode2text($mode);
    $mode |= $clear;
    $mode ^= $clear;
    $mode |= $set;
    qlog "MODE $old -> " . mode2text($mode) . "\n", LOG_DEBUG;
    $may_go = 1 if ( $set || $clear );
    $q_change = 1;
    return "New mode: " . mode2text($mode) . " (Was: $old)\n";
}    # new_mode

sub count_free_total($$ ) {
    my ( $free_total, $free_shared ) = @_;

    $$free_total  = 0;
    $$free_shared = 0;
    foreach my $p ( keys(%shared) ) {
        next if ( $shared{$p}->{blocked} );
        $$free_total  += $shared{$p}->{max};
        $$free_shared += $shared{$p}->{max};
    }
    foreach my $p ( keys(%own) ) {
        next if ( $own{$p}->{blocked} );
        $$free_total += $own{$p}->{max};
    }

#  qlog "__ $$free_total $$free_shared [".join(';',keys(%shared))."][".join(';',keys(%shared))."]\n", LOG_DEBUG2;
#  foreach my $p (@foreign,@running) {
    foreach my $p (@running) {
        $$free_total -=
            scalar( @{ $p->{shared} } ) + scalar( @{ $p->{own} } );
        $$free_shared -= scalar( @{ $p->{shared} } );
    }
    foreach my $p (@queue) {
        next if $p->{state} ne 'prerun';
        $$free_total -=
            scalar( @{ $p->{shared} } ) + scalar( @{ $p->{own} } );
        $$free_shared -= scalar( @{ $p->{shared} } );
    }
}    # count_free_total

#
# DEFAULT TIMEOUT REACTION PROCEDURE
#
sub chld_req_tmout {
    qlog "answer from childs timed out!\n", LOG_DEBUG;
}

#
#  Dump queue status
#
#
###########################################
sub dump_queue {

    if((my $f=get_setting('xml_statefile')) ne ''){
        save_xml_state($f.".$cluster_name");
    }

    my $fname   = get_setting('status_file') . ".$cluster_name";
    my @blocked = grep { $pe{$_}->{blocked} } keys(%pe);

    unless ( sysopen F, $fname, O_WRONLY | O_CREAT | O_LARGEFILE ) {
        qlog "Warning! Cannot open dump file for writing! ($fname)\n",
            LOG_ERR;
        return;
    }

    my ( @free_own, @free_sh, $free_total, $free_shared_total, $id, $status,
        $count, @out );
    my ( $x, $sec, $min, $day, $hr, $s, $tmp );

    qlog "DUMP '$fname'\n", LOG_DEBUG2;
    count_free( \@free_own, \%own );
    count_free( \@free_sh,  \%shared );
    $free_shared_total = max( 0, @free_sh - $reserved_shared );
    $free_total = $free_shared_total + @free_own;
    push @out,
        "[global]\nfree= $free_total\nshared_free= $free_shared_total\nshared_reserved= $reserved_shared\n";
    push @out,
        "total_own= "
        . scalar( keys(%own) )
        . "\ntotal_shared= "
        . scalar( keys(%shared) ) . "\n";
    push @out, "lastupdate= $last_time\n";

    #  push @out, "blocked_pe= ".join(',',sort(keys(%blocked_pe)))."\n";
    push @out, "blocked_pe= " . join( ',', sort(@blocked) ) . "\n";
    {
        my $delimiter = "";
        push @out, "blocked_pe_reasons=";
        foreach $x ( sort( keys(%blocked_pe_reasons) ) ) {
            push @out, "${delimiter}${x}|"
                . join( ";", sort( keys( %{ $blocked_pe_reasons{$x} } ) ) );
            $delimiter = ",";
        }
        push @out, "\n";
    }
    push @out, "own_pe= " . join( ',',    sort( keys(%own) ) ) . "\n";
    push @out, "shared_pe= " . join( ',', sort( keys(%shared) ) ) . "\n";
    push @out,
        "own= " . scalar(@free_own) . "\nshared= " . scalar(@free_sh) . "\n";
    push @out, "blocked= " . scalar(@blocked) . "\n";

    push @out,
        "tasks= "
        . (
        scalar(@running) + scalar(@foreign) + scalar(@pending) +
            scalar(@queue) )
        . "\n";
    push @out, "running= " . scalar(@running) . "\n";
    $x = scalar(@foreign) + scalar(@pending) + scalar(@queue);
    push @out, "queued= $x\n";

    if ($log_level>=LOG_DEBUG2){
        foreach my $i (@queue) {
            eval { qlog "$i->{id}:$i->{state}\n", LOG_DEBUG2; };
        }
        qlog "--------\n", LOG_DEBUG2;
        foreach my $i (@running) {
            eval { qlog "$i->{id}:$i->{state}\n", LOG_DEBUG2; };
        }
    }
    push @out,
        "foreign= " . ( 0 + grep( $_->{state} eq 'prerun', @queue ) ) . "\n";
    push @out,
        "pending= " . ( 0 + grep( $_->{state} eq 'blocked', @queue ) ) . "\n";
    push @out,
        "queue= " . ( 0 + grep( $_->{state} eq 'queued', @queue ) ) . "\n";
    push @out, "mode= $mode\n";
    push @out, "autoblocks= " . join( ",", keys(%autoblock) ) . ";\n";
    push @out, "autononblocks= " . join( ",", keys(%autononblock) ) . ";\n";
    push @out, "all_autoblock= $all_autoblock;\n";
    push @out, "norun= " . ( ( $mode & MODE_RUN_ALLOW ) ? '0' : '1' ) . "\n";
    push @out,
        "noqueue= " . ( ( $mode & MODE_QUEUE_ALLOW ) ? '0' : '1' ) . "\n";
    push @out,
        "autorestart= " . ( ( $mode & AUTORESTART ) ? '1' : '0' ) . "\n";

    for ( $x = 0; $x < scalar(@time_restrictions); ++$x ) {
        push @out,
            "time_restriction.$x= "
            . "$time_restrictions[$x]->{count}/"
            . "$time_restrictions[$x]->{allow}/"
            . "$time_restrictions[$x]->{timeb_every}/"
            . "$time_restrictions[$x]->{timee_every}/"
            . "$time_restrictions[$x]->{timeb}/"
            . "$time_restrictions[$x]->{timee}/"
            . "$time_restrictions[$x]->{users} ("
            . localtime( $time_restrictions[$x]->{timeb} ) . "/"
            . localtime( $time_restrictions[$x]->{timee} ) . ")\n";
    }
    push @out,
        "next_restriction_time= $next_restriction_time ("
        . localtime($next_restriction_time) . ")\n";

    for $x ( @running, @foreign, @pending, @queue ) {
        $id = $x->{id};
        push @out, "[task.$id]\n";

        #    qlog "[task.$id]; ".join(",",keys(%$x))."\n";

        if ( ref( $x->{blocks} ) ne 'ARRAY' ) {
            qlog "EEEEEEEEEEEEEE $id (" . ref( $x->{blocks} ) . ")\n",
                LOG_DEBUG2;
            push @out, "blockslist.$id = \n";
        } else {
            if ( scalar( @{ $x->{blocks} } ) > 0 ) {
                push @out,
                    "blockslist.$id = "
                    . join( '#', @{ $x->{blocks} } ) . "\n";
            }
        }
        foreach $tmp ( keys(%$x) ) {
            $s = $tmp;
            $s = $dump_q_trans{$tmp} if ( $dump_q_trans{$tmp} ne '' );
            if ( ref( $x->{$tmp} ) eq 'ARRAY' ) {
                push @out, "$s.$id = " . join( ';', @{ $x->{$tmp} } ) . "\n";
            } else {
                push @out, "$s.$id = $x->{$tmp}\n";
            }
        }
    }

    #  print "---------------------\n";
#
#  LOCK DOWSN'T WORK OVER NFS!!!
#
#    $count = 10;
#    while ( !flock( F, &Fcntl::LOCK_EX() | &Fcntl::LOCK_NB() )
#        and ( $count > 0 ) ) {
#        --$count;
#        select( undef, undef, undef, 0.1 );
#    }
#    if ($count) {
#        my $oldf = select(F);
        $s = join( '', @out );
#        $| = 1;
        sysseek F, 0, 0;
        syswrite F, $s, length($s);
        truncate F, length($s);
#        select($oldf);
#        flock( F, &Fcntl::LOCK_UN() );
#    } else {
#        qlog "Warning! Cannot lock dump file ($fname)\n", LOG_WARN;
#    }
    close(F) or qlog( "File closing failed\n", LOG_WARN );
    qlog "DUMP done\n", LOG_DEBUG;
}    # dump_queue

#
#  (Un)Block task
#   args:  id     - task id or 'all'
#         val     - 1=block 0=unblock
#        user     - do it as user 'user'
#     [reason]    - reson to (un)block task
#      [umask]    - list users to match
#      [tmask]    - task name mask
#
sub block_task( $$$;$$$ ) {
    my ( $id, $val, $user, $reason, $usermask, $taskmask ) = @_;

    my ( $q, $block_count, @tasks, $un, $u, $r, $comment );

    $user        = uid2user($user);
    $block_count = 0;
    $comment     = 'Probably you have no rights to do this';

    qlog "BLOCK_TASK $id/$val/$user ($reason)\n", LOG_INFO;

    if ( !isadmin( $user, $cluster_name ) && $usermask ) {
        return
            "-You cannot use user-masking blocking, because you have not rights for it!\n";
    }
    if ( $id ne 'all' ) {
        my @list = split( /\,/, $id );
        foreach $id (@list) {
            $q = get_entry($id);
            next unless defined $q;
            push @tasks, $q;
        }
    } else {
        push @tasks, @queue, @pending, @foreign;
    }
    return "-No task matched!\n" unless (@tasks);

BLOCK_TASKS_LOOP:
    foreach $q (@tasks) {
        if ( isadmin( $user, $cluster_name ) ) {
            next if ( $usermask && ( $usermask !~ /\b$q->{user}\b/ ) );
        } else {
            next if ( $q->{user} ne $user );
        }
        if ( $taskmask ne ''){
            my $line = join(' ', @{$q->{task_args}});
            next if( $line !~ /$taskmask/ );
        }
        if ( ref( $q->{blocks} ) ne 'ARRAY' ) {
            undef $q->{blocks};
            $q->{blocks} = [];
        }
        if ($val) {    # blocking
            my $x;
            foreach $x ( @{$q->{blocks}} ) {
                ( $u, $r ) = ( $x =~ /([^:]+):(.*)/ );    # user:reason
                if ( ( $u eq $user ) && ( $r eq $reason ) ) {
                    qlog "Already blocked by $u for $r\n", LOG_WARN;
                    $comment =
                        "Task $q->{id} is already blocked by $u for '$r'";
                    next BLOCK_TASKS_LOOP;

  #            return "-This task is already blocked by this reason by you\n";
                }
            }
            my $block = "$user:$reason";
            qlog "blocked for '$reason' by $user\n", LOG_INFO;
            push @{ $q->{blocks} }, $block;
            ++$block_count;
        } else {    # unblock
            if ( isadmin( $user, $cluster_name ) && ( $reason eq 'Total' ) ) {
                $q->{blocks} = [];
                $q->{blocked} = 0;
            } else {
                for ( my $i = 0; $i < @{ $q->{blocks} }; ++$i ) {
                    if ( !defined ${ $q->{blocks} }[$i] ) {
                        $comment = "Task $q->{id} is not blocked";
                        next;
                    }
                    ${ $q->{blocks} }[$i] =~ /([^:]+):(.*)/;
                    if (   ( $1 eq $user )
                        && ( ( $2 eq $reason ) || ( $reason eq 'Total' ) ) ) {
                        splice( @{ $q->{blocks} }, $i, 1 );
                        redo;
                    }
                }
                ++$block_count;
            }
        }
        qlog "BLOCK SUCCEED for $q->{id}/$q->{user}/$q->{sexe} ("
            . scalar( @{ $q->{blocks} } )
            . ")\n", LOG_DEBUG;
        $q->{blocked} = scalar( @{ $q->{blocks} } );
    }

    $may_go = 1 if ($block_count);

    if ( ( $id ne 'all' ) && ( $block_count == 0 ) ) {
        return "-$comment\n";
    }
    if ($val) {
        $un = '';
    } else {
        $un = 'un';
    }
    dump_queue() if $block_count;
    #$q_change = 1;
    return "+$block_count tasks ${un}blocked.\n";
}

#
#  Tests if this block type is set on task
#
#  Args: id     - task id
#        user   - set by user (undef = any)
#        reason - by this reason (undef = any)
#
######################################
sub test_block( $$$ ) {
    my ( $id, $user, $reason ) = @_;

    # user or reason may be undef -> any

    my $x;
    my $q = get_entry($id);

    return undef unless $q;

    $user = uid2user($user);
    foreach $x ( @{ $q->{blocks} } ) {
        $x =~ /([^:]+):(.*)/;
        if ( ( !defined $reason ) or ( $2 eq $$reason ) ) {
            if ( ( !defined $user ) or ( $1 eq $$user ) ) {
                $$user   = $1 if defined $user;
                $$reason = $2 if defined $reason;
                return 1;
            }
        }
    }
    return 0;
}

{
    my %to_block;
    my $next_time_to_block = 0;

    sub block_delayed() {
        return unless $next_time_to_block;

        if ( $last_time > $next_time_to_block ) {
            $next_time_to_block = 0;
            foreach my $i ( keys(%to_block) ) {
                if ( $to_block{$i}->{time} < $last_time ) {
                    block_pe( $i, 1, 0,
                        keys( %{ $to_block{$i}->{reason} } ) );
                    delete $to_block{$i};
                } elsif ( $next_time_to_block == 0
                    || $to_block{$i}->{time} < $next_time_to_block ) {
                    $next_time_to_block =
                        $to_block{$i}->{time};    # new min time to block
                }
            }
        }
    }

    # No intervals allowed!
    sub old_delayed_block_pe( $$ ) {
        my $t = $last_time + get_setting("mon_block_delay");
        qlog "Delayed block for $_[0] ($_[1])\n", LOG_INFO;
        if ( exists $the_nodes{ $_[0] } ) {
            qlog "PES: " . join( ',', @{ $the_nodes{ $_[0] } } ) . "\n",
                LOG_DEBUG2;
            foreach my $i ( @{ $the_nodes{ $_[0] } } ) {
                $to_block{"$_[0]:$i"}->{time} = $t;
                $to_block{"$_[0]:$i"}->{reason}->{ $_[1] } = 1;
            }
        } else {
            $to_block{ $_[0] }->{time} = $t;
            $to_block{ $_[0] }->{reason}->{ $_[1] } = 1;
        }
        if ( $next_time_to_block == 0 || ( $t < $next_time_to_block ) ) {
            $next_time_to_block = $t;
        }
    }

#
#  Blocks node or processor set
#
#  Args: pe         - list via ',' of intervals or processor/nodes names
#                     intervals are in format: a..b
#        val        - 1=block 0=unblock
#        when_free  - 1=block only when processor is free (otherwise remember this request)
#        reasons    - [opt] array. list of reasons
#
    sub block_pe( $$$;@ ) {
        my ( $pe, $val, $when_free, @reasons ) = @_;

        my @intervals;
        my ( $un, $a, $a1, $a2, $a3, $b, $b1, $b2, $b3, $i );
        my $result_count = 0;

        if ($val) {
            $un = '';
        } else {
            $un = 'un';
        }

        foreach $a (@reasons) {
            if ( $a ne '' ) {
                if ( $a !~ /^[\w+ !.<>()?\-\\\/\[\]]+$/ ) {
                    qlog
                        "BLOCK_PE: Bad reason ($a). Do not ${un}block $pe.\n",
                        LOG_WARN;
                    return "-Bad reason: $a\n";
                }
            }
        }

        # Split list to elements
        @intervals = split( /\,/, $pe );

        #Foreach list element...
        foreach $i (@intervals) {
            if ( $i =~ /(\S+)\.\.(\S+)/ ) {    # Interval
                ( $a, $b ) = ( $1, $2 );
                qlog "BLOCK_NODE: '$a .. $b'\n", LOG_DEBUG;
                ( $a1, $a2, $a3 ) = ( $a =~ /(\D*)(\d+)(\D*)/ );
                ( $b1, $b2, $b3 ) = ( $b =~ /(\D*)(\d+)(\D*)/ );
                if ( ( $a1 ne $b1 ) || ( $a3 ne $b3 ) || ( $a2 > $b2 ) ) {
                    return
                        "-Invalid interval '$i'! ($result_count processor(s) ${un}blocked).\n";
                }
                for ( $i = $a2; $i <= $b2; ++$i ) {
                    $result_count +=
                        block_one_pe( "${a1}${i}${a3}", $val, $when_free,
                        @reasons );
                }
            } else {    # Single node/pe
                qlog "BLOCK_NODE: $i\n", LOG_INFO;
                $result_count +=
                    block_one_pe( $i, $val, $when_free, @reasons );
            }
        }
        if ($result_count) {
            $q_change = 1;
            $may_go   = 1;
            return "+$result_count processor(s) ${un}blocked.\n";
        } else {
            return "-No such processor(s)...\n";
        }
    }

    #
    # Block only one processor or node (no intervals)
    #
    # Args: node      - processor or node name
    #       val       - 1=block 0=unblock
    #       when_free - 1=block only whe processor is free
    #       reasons   - [opt] array. List of reasons
    #
    sub block_one_pe( $$$;@ ) {
        my ( $node, $val, $when_free, @reasons ) = @_;

        my ( $x, $i, %del, $pe, @pes, $result_count, $delayed_count, $h );

        $h = $result_count = $delayed_count = 0;

        if ( $#reasons < 0 ) {
            if ($val) {
                push @reasons, "__internal__";
            } else {
                push @reasons, "ALL";
            }
        }
        qlog "BLOCK_ONE_PE: $node/$val when_free=$when_free reasons="
            . join( ";", @reasons )
            . "\n", LOG_DEBUG;
        @pes = ();
        if ( exists $the_nodes{$node} ) {
            qlog "PES: " . join( ',', @{ $the_nodes{$node} } ) . "\n",
                LOG_DEBUG2;
            foreach $i ( @{ $the_nodes{$node} } ) {
                push @pes, "$node:$i";
            }
        } elsif ( exists $pe{$node} ) {
            push @pes, $node;
        } else {
            qlog "No such processor: $node. Ignore.\n", LOG_INFO;
            return 0;
        }
        if ($val) {
            foreach $pe (@pes) {
                if ( exists( $pe{$pe} ) ) {
                    if ( $when_free and keys( %{ $pe{$pe}->{ids} } ) > 0 ) {

                        # DO NOT BLOCK IT NOW!!! Only when it will be free...
                        foreach $i (@reasons) {
                            $pe{$pe}->{block_when_free}->{$i} = 1;
                            ++$result_count;
                        }
                        qlog
                            "BLOCK_PE: processor '$pe' will be blocked when it will be free\n",
                            LOG_INFO;
                        next;
                    }

                    # delete tasks, occured on these nodes
                    if($val!=NO_DEL_TASKS){
                        for $i ( keys( %{ $pe{$pe}->{ids} } ) ) {
                            $del{$i} = 1;
                        }
                        foreach $i ( keys(%del) ) {
                            del_or_restart_task( $i, "Node $pe has been blocked");
#                            del_or_restart_task( $i, '__internal__', '', '', '', 0,
#                                "Node $pe has been blocked"
#                            );
                        }
                    }
                    foreach $i (@reasons) {
                        $blocked_pe_reasons{$pe}->{$i} = 1;
                    }
                    $pe{$pe}->{blocked} = 1;
                    ++$result_count;
                } else {
                    qlog "BLOCK_PE: No such processor '$pe'\n", LOG_WARN;
                }
            }
        } else {    # unblock
            my ( $flag, $c_pe, $c_child );
            foreach $pe (@pes) {
                if ( $pe{$pe}->{blocked} ) {
                    ++$result_count;
                    foreach $i (@reasons) {
                        if ( $i eq 'ALL' ) {
                            %{ $blocked_pe_reasons{$pe} } = ();
                            last;
                        }
                        delete $blocked_pe_reasons{$pe}->{$i};
                    }
                    next
                        if (
                        scalar( keys( %{ $blocked_pe_reasons{$pe} } ) ) > 0 );
                    delete $blocked_pe_reasons{$pe};
                    $pe{$pe}->{blocked} = 0;

                } else {

                    # not blocked yet

                    if ( exists( $to_block{$pe} ) ) {
                        qlog "Cancel delayed block $pe\n", LOG_INFO;
                        foreach $i (@reasons) {
                            if ( $i eq 'ALL' ) {
                                delete $to_block{$pe};
                                last;
                            }
                            delete $to_block{$pe}->{reason}->{$i};
                        }
                        if (scalar( keys( %{ $to_block{$pe}->{reason} } ) ) >
                            0 ) {
                            qlog "Still delayed cause "
                                . join( ',',
                                keys( %{ $to_block{$pe}->{reason} } ) )
                                . "\n", LOG_INFO;
                            next;
                        }
                        delete $to_block{$pe};
                        ++$result_count;
                        ++$delayed_count;
                    } elsif ( exists( $pe{$pe} )
                        and exists( $pe{$pe}->{block_when_free} ) ) {
                        foreach $i (@reasons) {
                            delete $pe{$pe}->{block_when_free}->{$i};
                        }
                    } else {
                        qlog "BLOCK_PE: No such processor or already unblocked '$pe'\n", LOG_WARN;

                        #        return "-No such processor!\n";
                    }
                }
            }
        }
        qlog "List of delayed blocks: " . join( ",", keys(%to_block) ) . "\n",
            LOG_DEBUG;
        if ( $result_count - $delayed_count > 0 ) {
            foreach $i (@reasons) {
                my %args = (
                    'pe', $node, 'val', $val, 'safe', $when_free, 'reason', $i
                );
                qlog
                    "BLOCK_PE: send to childs ($pe) [$when_free] reason='$i'\n",
                    LOG_DEBUG;
                &main::new_req_to_child(
                    'block_pe',
                    \%args,
                    '__all__',
                    1,
                    SUCC_OK | SUCC_ALL,
                    \&main::chld_block_pe_handler,
                    \&every_nil_sub,
                    get_setting('intra_timeout'),
                    \&main::chld_block_pe_handler );
            }
        }
        $may_go = 1;
        return $result_count;
    }

    sub actualize_cpu_blocks( @ ) {
        my @pe = @_;
        my ( $i, $j, $exe );

        unless ( scalar(@pe) ) {
            push @pe, keys(%the_nodes);
        }

        foreach $i (@pe) {
            next
                unless ( defined( $pe{$i}->{block_when_free} )
                and keys( %{ $pe{$i}->{block_when_free} } ) );
            if ( keys( %{ $pe{$i}->{ids} } ) ) {
                qlog
                    "Node $i has some tasks running. Blocks are not actualized\n",
                    LOG_INFO;
                next;
            }

            # DO THE BLOCKING!!!!

            $pe{$i}->{blocked} = 1;

            #      $blocked_pe{$i}=$pe{$i};
            #      delete $pe{$i} if exists $pe{$i};
            #      delete $shared{$i} if exists $shared{$i};
            #      delete $own{$i} if exists $own{$i};
            foreach $j ( keys( %{ $pe{$i}->{block_when_free} } ) ) {
                $blocked_pe_reasons{$i}->{$j} = 1;
            }
            delete $pe{$i}->{block_when_free};

            $exe = get_setting('mon_delayed_block_exec');
            if ( $exe ne '' ) {
                my $entry;
                $entry->{'cpu'}    = $i;
                $entry->{'node'}   = $i;
                $entry->{'reason'} = $j;
                $entry->{'time'}   = $last_time;
                undef %subst_args;
                subst_task_prop( \$exe, $entry, 0, 0 );
                launch( 0, $exe, '' );
            }
            qlog "Node's $i block(s) actualized\n", LOG_INFO;
        }
    }
};

#
#  Called when a subcluster dies. It tries to recreate it...
#
#############################################################
sub on_cluster_die( $ ) {
    qlog "You must restart Cleo now!\n", LOG_ERR;
}

sub usecs() {
    my $time;
    my @time2;

    $time = pack( "LL", () );

    syscall( &SYS_gettimeofday, $time, 0 ) != -1 or die "gettimeofday: $!";

    @time2 = unpack( "LL", $time );
    $time2[1] /= 1_000_000;
    return $time2[0] + $time2[1];
}

#
#  Add id to 'runned' list
#  Args: id    - id to add
#        code  - exit code
#  Ret: if all is OK               0
#       if error (already added)  -1
#
##################################################
sub new_runned( $$ ) {
    my $i = find_runned( $_[0] );
    $_[1] = 0 unless defined $_[1];
    if ( $i >= 0 ) {    #Ooops... There is the one already
        qlog "Newrun entry already exists! ($i) $_[0]\n", LOG_ERR;
        return -1;
    }
    unshift @runned_list, { 'id' => $_[0], 'exitcode' => $_[1] };
    $#runned_list = $runned_list_len;
    return 0;
}

#
#  Search 'runned' list for id
#  Args: id    - id to find
#  Ret: if not found   -1
#       if found       index in runned_list
#
##################################################
sub find_runned( $ ) {
    my $i;
    for ( $i = 0; $i < $runned_list_len; ++$i ) {
        next unless defined $runned_list[$i];
        return $i if ( $_[0] == $runned_list[$i]->{id} );
    }
    return -1;
}

# new version of communicative subroutines

{

    #  my %buffers;
    #  my %channels;
    my %tmplines;
    my %connections;
    my %conn_by_h;
    my $next_conn = 1;

    my $counter   = 0;
    my $unflushed = 0;

    #
    # Sends packet to channel
    #
    # Args:
    #        handle: Cleo::Conn
    #        data:   what to send
    #
    # Ret:   Unsent buffer, if there was an error.
    #
    ############################################
    sub send_to_channel( $$ ) {
        my ( $h, $out ) = @_;
        my $incomplete = 0;
        my ( $ch, $b );

        #    qlog "SEND ($out)\n" if $debug{yy};

        unless ( exists $connections{$h} ) {
            qlog "Undefined channel given... "
                . ( caller(1) )[3] . ";"
                . ( caller(2) )[3]
                . "\n", LOG_WARN;
            return undef;
        }
        $ch = $connections{$h}->{channel};
        if ( $connections{$h}->{buf} ne '' ) {

    #      qlog ("YAHOO! Try to send the rest...\n", LOG_DEBUG) if $debug{yy};
            $incomplete = 1;
        }

        $connections{$h}->{buf} .= $out;

        undef $!;
        undef $@;

        unless ( $ch->opened ) {
            qlog "Write to closed channel. "
                . ( caller(1) )[3] . ";"
                . ( caller(2) )[3]
                . "Ignore\n", LOG_WARN;
            main::mark_channel_dead($h);
            $b = \$connections{$h}->{buf};
            delete $conn_by_h{ $connections{$h}->{channel} };
            delete $connections{$h};
            delete $tmplines{$h};
            return $b;
        }
        my $tmp = 0;
        while ( scalar( $connections{$h}->{buf} ) ) {

            $tmp = syswrite( $ch, $connections{$h}->{buf} );
            if ( $tmp < 1 ) {
                last;
            }
            $connections{$h}->{buf} = substr( $connections{$h}->{buf}, $tmp );
        }

        #    qlog "SEND2\n" if $debug{yy};

        if ( $tmp < 1 ) {
            if ( $error_codes{$!} > 0 ) {
                qlog "Channel is dead.[$!]\n", LOG_WARN;
                main::mark_channel_dead($ch);
                $b = \$connections{$h}->{buf};
                delete $conn_by_h{ $connections{$h}->{channel} };
                delete $connections{$h};
                delete $tmplines{$h};
                return $b;
            } else {
                qlog "Write delayed($!)\n", LOG_WARN;
                $unflushed = 1;
            }
        }

        #    elsif ($incomplete) {
        #      qlog ("YAHOO! Succeeded\n", LOG_DEBUG) if $debug{yy};
        #    }
        return undef;
    }    #~send_to_channel

    #
    # Flushes all unsent packets to channels
    #
    ############################################
#    sub flush_channels( ) {
#        my ( $ch, $h, $b );
#        my $incomplete = 0;
#        my $tmp;

#        $unflushed = 0;

 #           qlog "FLUSH\n" if $debug{yy};

#        foreach $h ( keys(%connections) ) {
#            $ch = $connections{$h}->{channel};
#            if ( $connections{$h}->{buf} ne '' ) {

        #qlog ("YAHOO(flush)! Try to send the rest...\n", LOG_DEBUG) if $debug{yy};
#                $incomplete = 1;
#            } else {
#                next;
#            }

#            undef $!;
#            undef $@;

#            $tmp = 0;

#            eval {
#                while ( $connections{$h}->{buf} ne '' ) {
#                    qlog "FLUSH1\n" if $debug{yy};
#                    $tmp = syswrite( $ch, $connections{$h}->{buf} );
#                    if ( $tmp < 1 ) {
#                        last;
#                    }
#                    $connections{$h}->{buf} =
#                        substr( $connections{$h}->{buf}, $tmp );
#                }

                        qlog "FLUSH3\n" if $debug{yy};
#                if ( $tmp < 1 ) {
#                    if ( $error_codes{$!} > 0 ) {
#                        qlog "Channel is dead.(flush)[$!]\n", LOG_WARN;
#                        main::mark_channel_dead($h);
#                        delete $conn_by_h{ $connections{$h}->{channel} };
#                        delete $connections{$h};
#                        delete $tmplines{$h};
#                        next;
#                    } else {
#                        qlog "Write delayed(flush)[$!] ($ch)\n", LOG_WARN;
#                        $unflushed = 1;
#                    }
#                } elsif ($incomplete) {
#                    qlog( "YAHOO(flush)! Succeeded\n", LOG_DEBUG )
#                        if $debug{yy};
#                }
#            };
#            if ($@) {
#                qlog "Error(flush): $@"
#                    . ( caller(1) )[3] . ";"
#                    . ( caller(2) )[3]
#                    . "\n", LOG_WARN;
#            }
#        }
#    }    # ~flush_channels

    #####################################################################
    #
    # Gets the block from channel (ends with 'end\n')
    #
    # arg: the Cleo::Conn
    # ret - pointer to list of lines without 'end\n' as last line...
    #     - pointer to empty list if nothing were readed...
    #     - undef if error was occured (no more reading can be done)
    #####################################################################
    sub get_block_x($ ) {

        my $h  = $_[0];
        my ( $line, $tmpchar, $incomplete, $error, $success, $tmp, $any,
            @ret );

        $tmp=$h->read;
        if ( $tmp eq '' ) {
            if($_[0]->get_state ne 'ok'){
                my $host=$_[0]->get_peer;
#                qlog( "Try to read dead channel ($host)\n", LOG_DEBUG );
                return undef;
            }
        }
        else{
            $tmp =~ s{^(.*?end\n)}{}s; #!!!!!!!!!!!!!!!! BUG!!!!!!!
            $h->unread($tmp);
            my $r = $1;
            if ( $r ne '' ) {
                @ret = split( /\n/, $r );
                return \@ret;
            }
        }
        return [];
    }    #~get_block_x

    #
    #  Reads line from opened descriptor
    #
    #  Arg: Cleo::Conn
    #  Ret: full readed line without "\n" at end,
    #       undef if line is readed not fully, or error
    #########################
    sub get_line($ ) {
        my $h  = $_[0];

        my ( $tmp, $line );
        $tmp=$h->read;
        return undef if !defined $tmp;

        if($tmp =~ s/^([^\n]*)\n//s){
            $h->unread($tmp);
            return $1;
        }
        $h->unread($tmp);
        return undef;
    }

    #
    # Closes channel
    #
    ############################################
    sub kill_conn( $ ) {
        return if !defined $_[0];
        return if !exists $connections{ $_[0] };
        delete $conn_by_h{ $connections{ $_[0] }->{channel} };
        $@ = '';
        eval {
            local $SIG{ALRM} = sub { die "kill_conn\n" };
            alarm 5;
            qlog "CLOSING\n", LOG_DEBUG;
            $connections{ $_[0] }->{channel}->flush();
            close( $connections{ $_[0] }->{channel} );
        };
        alarm 0;
        if ( $@ ne '' or $! ne '' ) {
            qlog "WHILE CLOSE: $@ ($!)\n", LOG_WARN;
        }
        delete $tmplines{ $_[0] };
        delete $connections{ $_[0] };
        qlog "CLOSING SUCCEED\n", LOG_DEBUG;
    }

    #
    # Creates new channel (from file descriptor)
    #
    ############################################
    sub create_conn( $ ) {
        my $ret = $next_conn;
        %{ $connections{$ret} } = ( 'channel' => $_[0], 'buffer' => [] );
        $conn_by_h{ $_[0] } = $ret;
        while ( exists $connections{$next_conn} ) {
            ++$next_conn;
            $next_conn = 0 if ( $next_conn >= 65500 );
        }
        return $ret;
    }

    #
    # Gives channel id by file handle (from select e.g.)
    #
    ##############################################
    sub channel_by_handle( $ ) {
        return $conn_by_h{ $_[0] } if exists $conn_by_h{ $_[0] };

        my @cal = caller(1);
        qlog "cannot get channel by handle ($cal[2] -- $cal[3])\n", LOG_ERR;
        return undef;
    }

    #
    # Gives file handle by channel
    #
    ##############################################
    sub h_by_channel( $ ) {
        return $connections{ $_[0] }->{channel}
            if exists $connections{ $_[0] };
        return undef;
    }
};

#
#  Check if detached processes (via empty e.g.) are finished
#
#######################################################
sub check_detached(){
    my $id;

    foreach $id (keys(%pids)){
        next if $pids{$id}>=MAX_CLEO_ID;
        next if kill 0, $pids{$id};

        # No such process anymore!

        # Don't try delete it second time...
        next if(!exists $ids{$id});

        # Delete this task!
        push @dead, $id;
        $childs_info{$id}->{status} = 0;
        $childs_info{$id}->{core}   = 0;
        $childs_info{$id}->{signal} = 0;
        qlog "NO_SIGCHILD: PID=$pids{$id}; ID=$id\n", LOG_DEBUG;
    }
}

#
#  Kills process and all it's children
#  Args: pid    - pid to kill
#
##################################################
sub kill_tree ($$) {
    my ( $signum, $pid ) = @_;
    my (%childs,         # list pid's childs (including itself)
        @system_pids,    # list of all pids
        %childs_of,      # list of parents for all pids
        %new_childs,     # temp list
        @new_pids );                   # temp list
    my ( $i, $j );

    return if ( $pid == 0 );

    qlog "KILL_TREE: $pid [$signum]\n", LOG_DEBUG;
    if ( opendir PROC, "/proc" ) {
        @system_pids = grep {/^\d/} readdir(PROC);
        closedir PROC;
    } else {
        @system_pids = ($pid);
    }

    foreach $i (@system_pids) {
        next if !defined $i;
        if ( !open( P, "</proc/$i/status" ) ) {
            next;
        }
        while (<P>) {
            if (/^PPid\:\s*(\d+)/) {
                push @{ $childs_of{$1} }, $i;
                last;
            }
        }
        push @new_pids, $i;
        close P;
    }

    @system_pids = @new_pids;
    %childs      = ( $pid => 1 );
    %new_childs  = ( $pid => 1 );

    do {
        @new_pids = keys(%new_childs);
        undef %new_childs;
        foreach $i (@new_pids) {
            foreach $j ( @{ $childs_of{$i} } ) {
                next
                    if ( exists( $childs{$j} ) or exists( $new_childs{$j} ) );
                $childs{$j} = $new_childs{$j} = 1;
            }
        }
    } while ( keys(%new_childs) );

    foreach $i ( keys(%childs) ) {
        kill $signum, $i;
    }
    undef @system_pids;
    undef %childs_of;
    undef %childs;
    undef %new_childs;
    undef @new_pids;

}    # ~kill_tree

#
#  Load modules for pre/post/etc-exec actions
#
#  Args: none
#
####################################
sub load_exec_modules() {
    my $dir   = get_setting('exec_modules_dir');
    my $mlist = get_setting('exec_modules');
    my ( $i, $j, $m, $v, @content, @newmlist );

    if ( scalar(@$mlist) ) {
        {
            no strict 'refs';
            qlog "Load exec modules.\n", LOG_INFO;
            foreach $i (@$mlist) {
                $m = $i;
                $m =~ tr/./_/;
                $m =~ tr/a-zA-Z_0-9/_/c;
                push @newmlist, $m;
                if ( open( F, "$dir/$i" ) ) {
                    qlog "Loading $i...\n", LOG_INFO;
                    @content = <F>;
                    close F;

#          chomp @content;
#          qlog join('',"\npackage CleoExecModule::$m;\n",@content,"\n"), LOG_DEBUG2;
                    eval join( '',
                        "package CleoExecModule::$m;\n",
                        "sub cleo_log( \$ ){cleosupport::qlog(\"MOD: \$_[0]\",cleovars::LOG_INFO);};\n",
                        "sub get_time(){return \$cleovars::last_time;};\n",
                        "sub cancel_task( \$ ){ \$cleovars::exec_mod_cancel=\$_[0]; };\n",
                        @content,
                        "\n" );
                    $v = "CleoExecModule::" . $m;
                    if ($@) {
                        qlog "Failed to load $i: $@\n", LOG_WARN;
                    } elsif ( defined ${ $v . "::cleo" } ) {
                        qlog "Loaded exec module $i (version "
                            . ${ $v . "::cleo" }
                            . ")\n", LOG_INFO;
                        $exec_modules{$i} = $v;
                        foreach $j ( "pre", "post", "ok", "fail", "cancel" ) {
                            if ( $v->can($j) ) {
                                qlog "Defined $i/$j()\n", LOG_DEBUG;

            #                *{$exec_modules{$i}->{$j}} =\&{$v."::$j"};
            #                qlog "Defined $i/$j ($exec_modules{$i}->{$j})\n";
                            } else {
                                qlog "Dumbed $i/$j\n", LOG_WARN;
                                *{ $v . "::$j" } = sub ( $ ) { return 1; };
                            }
                        }
                    } else {
                        qlog "Missing version\n", LOG_WARN;
                    }
                } else {
                    qlog "Module '$i' not found.\n", LOG_WARN;
                }
            }
        };
        @$mlist = @newmlist;
    }
}

#
#  Do action in exec_module
#
#  Args:
#       $module - name of module
#       $action - name of action (pre, post, ok, fail, cancel)
#       $task   - taskinfo
#
#  Return:
#             zero  if ok
#         non zero  if fail
#
####################################
sub do_exec_module( $$$;@ ) {
    my ($mod,$act,$task,@args)=@_;

    $exec_mod_cancel='';
    return -1 unless ( defined( $exec_modules{ $mod } ) );
    my $t =
        Storable::thaw( Storable::freeze( $task ) )
        ;    # clone... Do no allow to change original.
    my $m   = $exec_modules{ $mod };
    my $res = -1;
    qlog "DO_EXEC_MODULE ($mod/$act)[$m]\n", LOG_DEBUG2;
    eval {
        local $SIG{ALRM}=sub{ die "exec_module '$m' timed out\n"; };
        no strict "refs";
        alarm get_setting('exec_modules_timeout');
        $res = ( $m . "::$act" )->($t,@args);
    };
    alarm 0;
    return $res;
}

#
#  Load external schedulers
#
#  Args: none
#
####################################
sub load_schedulers( ) {
    my $dir   = get_setting('schedulers_dir');
    my $mlist = get_setting('schedulers');

    my ( $i, $m, $v, @content, @newmlist );

    if ( scalar(@$mlist) ) {
        {
            no strict 'refs';
            my ( %l1, @l2 );

            # kill duplicates
            foreach $i (@$mlist) {
                next if ( exists $l1{$i} );
                push @l2, $i;
                $l1{$i} = 1;
            }
            @$mlist = @l2;

            qlog "Load external schedulers (" . join( ',', @$mlist ) . ")\n",
                LOG_INFO;
            foreach $i (@$mlist) {
                $m = $i;
                $m =~ tr/./_/;
                $m =~ tr/a-zA-Z_0-9/_/c;
                push @newmlist, $m;
                if ( open( F, "<$dir/$i" ) ) {
                    qlog "Loading scheduler $i...\n", LOG_INFO;
                    @content = <F>;
                    close F;

       #          chomp @content;
       #          qlog join('',"\npackage CleoScheduler::$m;\n",@content,"\n");
                    eval join( '',
                        "package CleoScheduler::$m;\n",
                        $scheduler_prolog, @content, "\n" );
                    $v = "CleoScheduler::" . $m;
                    if ($@) {
                        qlog "Failed to load $i: $@\n", LOG_WARN;
                    } elsif ( defined ${ $v . "::cleo" } ) {
                        qlog "Loaded scheduler $i (version "
                            . ${ $v . "::cleo" }
                            . ")\n", LOG_INFO;
                        $ext_sched{$i} = $v;
                        if ( $v->can('do_schedule') ) {
                            qlog "Defined $i/do_schedule()\n", LOG_DEBUG;
                        } else {
                            qlog "Not found do_schedule. Unload.\n", LOG_WARN;
                            delete $ext_sched{$i};
                        }
                        for my $sub ( 'event', 'start', 'stop', 'select_cpus' ) {
                            if ( $v->can($sub) ) {
                                qlog "Defined $i/$sub()\n", LOG_DEBUG;
                            } else {
                                qlog "Dumbed $i/$sub\n", LOG_WARN;
                                *{ $v . "::$sub" } = sub () { return 0; };
                            }
                        }
                    } else {
                        qlog "Missing version\n", LOG_WARN;
                    }
                } else {
                    qlog "Scheduler '$i' not found in dir '$dir'.\n", LOG_WARN;
                }
            }
        };
        @$mlist = @newmlist;
    }
}

#
#
#  Unblock reruned task after some delay
#  called from rerun_task only
#
sub _unblock_reruned($$){
    if(exists($ids{$_[0]})){
        block_task($_[0],0,'__internal__',$_[1]);
    }
}
####################################################
#
#  Delete or try to restart given task
#
#  args:  id       - task id (all - del all tasks)
#         reason   - description of deletion
#
sub del_or_restart_task( $$ ) {
    my ( $id, $reason ) = @_;

    if(!exists($ids{$id})){
        qlog "Cannot del or rerun task $id - task does not exists\n", LOG_ERR;
        return;
    }

    # check rerun attribute
    my $a=$ids{$id}->{attrs}->{'rerun'};
    if($a==0){
      # delete task
      del_task($id,'__internal__', undef, undef, undef, 0, $reason);
      return;
    }

    # rerun task!
    rerun_task($id,$a,$reason);
}


#
#  Cancel task running and redirect it in queue again
#
#  Args:
#         id      - task id
#         delay   - delay in secs to block task in queue
#                   (0-noblock, -1 = permanent block)
#         reason  - task block reason
###########################################################
sub rerun_task($$$){
    my ($id,$delay,$reason)=@_;

    if(!exists($ids{$id})){
        qlog "Cannot rerun task $id - task does not exists\n", LOG_ERR;
        return;
    }
    #qlog "ERROR: Not implemented task rerun ($id)\n";
    #del_task($id,'__internal__', undef, undef, undef, 0, 'Fail to run, cannot rerun task');

    # delete id from queue/running
    remove_id($id);

    # restore it to queue
    #!!!! skip already unshifted other tasks with the same reason!!!!
    unshift @queue, $ids{$id};
    $ids{$id}->{state}='queued';

    # permanent block task in queue
    if($delay<0){
        block_task($id,1,'__internal__',$reason);
    }
    # block task for some time
    elsif($delay>0){
        block_task($id,1,'__internal__',$reason);
        sc_task_in($delay,\&_unblock_reruned,$id,$reason);
    }
    # delay==0 -> do not block task

    $q_change=1;
}

#
#  Executes given subroutine in subprocess with dropped priveleges
#  NOTE!!! This subroutine WAITS for subprocess end!
#
#  Args: uid - user id
#        gid - group id
#        sub - reference to subroutine to execute
#        args - list of arguments to subroutine
# Ret:   0 if LAUCNCH was succesfull, 1 if not.
#
#########################################################
sub sub_exec( $$$;@ ) {

    my ( $i, $p );

    if ( ref( $_[2] ) ne 'CODE' ) {
        qlog "sub_exec: Not a code refence! ("
            . ( caller(1) )[2] . "  "
            . ( caller(1) )[3]
            . "\n", LOG_ERR;
        return 1;
    }
    for ( $i = 0; $i < 10; ++$i ) {
        $p = fork();
        last if ( ( defined $p ) and ( $p >= 0 ) );
        select( undef, undef, undef, 0.1 );
    }
    return 1 unless defined $p;    # FAIL 8(
    return 1 if ( $p < 0 );        # FAIL 8(
    if ($p>0) {                    # successful launch
        $launch_pids{$p} = 1;
        eval {
            my $tmout = get_setting('sub_exec_timeout');
            local $SIG{ALRM} = sub { die "sub_exec time exceeded\n"; };
            alarm $tmout;
            waitpid $p, 0;
        };
        alarm 0;
        kill_tree( 9, $p );
        qlog( "sub_exec: $@", LOG_ERR ) if $@;
        return 0;
    }

    close_ports(1);
    close STDIN;
    open( STDIN, "/dev/null" );

    $0         = "SUB_EXEC ($_[0])";
    $SIG{PIPE} = 'Ignore';
    $SIG{CHLD} = 'Ignore';
    $SIG{USR1} = 'Ignore';
    $SIG{USR2} = 'Ignore';
    $SIG{HUP}  = 'Ignore';
    $SIG{ABRT} = 'Ignore';
    $SIG{TERM} = 'Ignore';
    $SIG{QUIT} = 'Ignore';
    $SIG{BUS}  = 'Ignore';
    $SIG{SEGV} = 'Ignore';
    $SIG{FPE}  = 'Ignore';
    $SIG{INT}  = 'Ignore';
    $SIG{ILL}  = 'Ignore';

    $< = $> = $_[0];
    shift;
    $( = $) = $_[0];
    shift;
    my $code = $_[0];
    shift;

    # allow to rwx new files/dirs for owner/group
    umask(002);
        
    &$code(@_);
    alarm 0;
    exit(0);
}

#
#  Simple wrapper to 'exec' (for sub_exec)
#
########################################
sub cleo_system( @ ) {
    exec @_;
}

{
    my @sc_tasks;
    my $sc_next_time = 0;
    my $sc_next_id   = 1;

    #
    #  Add task to execute in N seconds
    #
    #  Args: $secs  - time in seconds after which the task will be executed
    #        $subr  - link to subroutine to execute
    #        @args  - optional list of arguments to subroutine
    #  Ret:         - task id
    #
    ########################################
    sub sc_task_in( $$;@ ) {
        sc_task_at( $last_time + $_[0], $_[1], @_[ 2 .. $#_ ] );
    }    #~sc_task_in

    #
    #  Add task to execute at specified time
    #
    #  Args: $secs  - time (UNIX time) at which the task will be executed
    #        $subr  - link to subroutine to execute
    #        @args  - optional list of arguments to subroutine
    #  Ret:         - task id (0 if error)
    #
    ########################################
    sub sc_task_at( $$;@ ) {
        if ( ref( $_[1] ) ne 'CODE' ) {
            qlog "Not a subroutine refence passed to sc_task_at ("
                . ( caller(1) )[2]
                . ")\n", LOG_ERR;
            return 0;
        }
        my @args  = @_[ 2 .. $#_ ];
        my $ret   = $sc_next_id;
        my %entry = (
            'sub'  => $_[1],
            'args' => \@args,
            'time', $_[0], 'id' => $sc_next_id );
        push @sc_tasks, \%entry;
        if ( ++$sc_next_id > 65_530 ) {
            $sc_next_id = 1;
        }
        sc_update_next_time();
        qlog "Added $_[0] ($sc_next_time)\n", LOG_DEBUG2 if ( $debug{sc} );
        return $ret;
    }    # ~sc_task_at

    #
    #  Deletes task by id
    #
    ########################################
    sub sc_update_next_time() {
        $sc_next_time = 0;
        foreach my $i (@sc_tasks) {
            if ( ( $i->{time} < $sc_next_time ) or ( $sc_next_time == 0 ) ) {
                $sc_next_time = $i->{time};
            }
        }
        qlog "NEXT_TIME: $sc_next_time\n", LOG_DEBUG2 if ( $debug{sc} );
    }

    #
    #  Deletes task by id
    #
    #  Args: $id  - id of task to del or 'all' (delete all tasks)
    #  Ret:  0 if success, 1 otherwise.
    #
    ########################################
    sub sc_task_del( $ ) {
        if ( $_[0] eq 'all' ) {
            qlog "Deleted all internal tasks.\n", LOG_INFO;
            @sc_tasks     = ();
            $sc_next_time = 0;
            return 0;
        }
        for ( my $i = 0; $i <= $#sc_tasks; ++$i ) {
            if ( $sc_tasks[$i]->{id} == $_[0] ) {
                splice( @sc_tasks, $i, 1 );
                sc_update_next_time();
                return 0;
            }
        }
        return 1;
    }    # ~sc_task_del

    #
    #  Returns time of next task execution
    #
    ########################################
    sub sc_next_time() { return $sc_next_time; }

    #
    #  Executes tasks
    #
    #  Args: 1 - (optional) force execution of all tasks
    #
    ########################################
    sub sc_execute( ;$ ) {
        my $force = $_[0];

        return if ( $sc_next_time == 0 or $last_time < $sc_next_time );

        my @old_sc_tasks;
        my @new_sc_tasks;
        push @old_sc_tasks, @sc_tasks;
        undef @sc_tasks;
        for ( my $i = 0; $i <= $#old_sc_tasks; ++$i ) {
            if ( ( $old_sc_tasks[$i]->{time} <= $last_time ) or $force ) {
                eval {
                    $old_sc_tasks[$i]->{sub}
                        ->( @{ $old_sc_tasks[$i]->{args} } );
                };
            } else {
                push @new_sc_tasks, $old_sc_tasks[$i];
            }
        }
        @sc_tasks = ( @new_sc_tasks, @sc_tasks );
        sc_update_next_time();
    }    # ~sc_execute

};

#
#
#  Returns 'available' cpus*hours for given user
#  -1 = infinite (not limited)
#
#  Args = username, [profile]
#
###################################################################
sub check_cpuh( $;$ ){
    my ($user, $profile) = @_;
    my $max_cpuh = get_setting('max_cpuh',$user,$profile);
    my $real_np;

    return -1 if($max_cpuh==0);

    my ($ret, $i);
    $ret=0;

    if(defined $user){

        # check all tasks
        foreach $i (values(%ids)) {
            next if ( ($i->{state} eq 'queued')
                   or ($i->{state} eq 'blocked'));
            next if ( $i->{user} ne $user );
            next if ( $i->{timelimit}==0 );

            # tasks is startin/running/endind and belongs to user...
            # COUNT it!
            $real_np=$i->{np}+scalar(@{$i->{extranodes}});
            $ret += ($real_np*($i->{timelimit}-$i->{time}))/3600;
        }
    }
    $ret = $max_cpuh - $ret;

    qlog("Check_cpuh: user=$user. CPUH: $ret\n", LOG_DEBUG) if($debug{ch});
    return $ret>=0 ? $ret : 0;
}

#
#
#  Actually do the file rotate.
#  Input filename is "base". Acual file must have .rot extention and
#  will be renamed to <base>.<YYYY-MM-DD>.bz2
#
###################################################################
sub do_rotate( $ ){
    my $file=$_[0];
    my $cmd=get_setting('compress_cmd');
    my $ext=get_setting('compress_ext');
    my @tim=localtime();
    my $date=strftime("%Y-%m-%d", $tim[0], $tim[1], $tim[2], $tim[3], $tim[4], $tim[5]);

    qlog "Rotating '$file'\n", LOG_INFO;
    
    # tell childrens to reopen logs
    main::new_req_to_child( 'reopen_logs', {},
                      '__all__',          1,
                      SUCC_ALL | SUCC_OK, \&nil_sub,
                      \&every_nil_sub,    1,
                      \&nil_sub );
    
    launch(0,"/bin/sh -c '$cmd < \"${file}.rot\" > \"${file}.$date.$ext\" && rm \"${file}.rot\"'",'logrotate');
}

#
#
#  Check, if log files neede to be rotated and does the rotation
#
###################################################################
sub log_rotate(){
    my ($ltime,$stime,$lsize,$ssize,$time,$size,$rot);

    # get logs sizes and creation times
    (undef,undef,undef,undef,undef,undef,undef,
     $lsize,undef,undef,$ltime,undef,undef)=lstat($report_file);
    (undef,undef,undef,undef,undef,undef,undef,
     $ssize,undef,undef,$stime,undef,undef)=lstat($short_rep_file);

    # do time check for main log
    $time=get_setting('max_log_days');
    $size=get_setting('max_log_size');
    $rot=0;
    eval{
        if($time>0){
            if($ltime+$time*24*3600 < $last_time){
                if(rename($report_file,"$report_file.rot")){
                    $STATUS->close;
                    unless($STATUS->open($report_file,
                        O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )){
                            $STATUS->open('/dev/null', O_WRONLY);
                            send_mail(get_setting('adm_email'),'cleo error',
                                'Cannot recreate log file');
                            #my $mailcmd='mail -s "" '.get_setting('adm_email');
                            #launch(0,"echo 'Cannot recreate log file' | $mailcmd",'mail');
                    }
                    do_rotate($report_file);
                }
                else{
                    qlog "Cannot rename '$report_file'\n", LOG_ERR;
                }
                $rot=1;
            }
        }
        # do size check for main log
        if($size>0 and $rot==0){
            if($lsize > $size){
                if(rename($report_file,"$report_file.rot")){
                    $STATUS->close;
                    unless($STATUS->open($report_file,
                        O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )){
                            $STATUS->open('/dev/null', O_WRONLY);
                            send_mail(get_setting('adm_email'),'cleo error',
                                'Cannot recreate log file');
                            #my $mailcmd='mail -s "cleo error" '.get_setting('adm_email');
                            #launch(0,"echo 'Cannot recreate log file' | $mailcmd",'mail');
                    }
                    do_rotate($report_file);
                }
                else{
                    qlog "Cannot rename '$report_file'\n", LOG_ERR;
                }
            }
        }

        # do time check for short log
        $time=get_setting('max_short_log_days');
        $size=get_setting('max_short_log_size');
        $rot=0;
        if($time>0){
            if($stime+$time*24*3600 < $last_time){
                if(rename($short_rep_file,"$short_rep_file.rot")){
                    $SHORT_LOG->close;
                    unless($SHORT_LOG->open($short_rep_file,
                        O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )){
                            $SHORT_LOG->open('/dev/null', O_WRONLY);
                            send_mail(get_setting('adm_email'),'cleo error',
                                'Cannot recreate log file');
                            #my $mailcmd='mail -s "cleo error" '.get_setting('adm_email');
                            #launch(0,"echo 'Cannot recreate log file' | $mailcmd",'mail');
                    }
                    do_rotate($short_rep_file);
                }
                else{
                    qlog "Cannot rename '$short_rep_file'\n", LOG_ERR;
                }
                $rot=1;
            }
        }
        # do size check for short log
        if($size>0 and $rot==0){
            if($ssize > $size){
                if(rename($short_rep_file,"$short_rep_file.rot")){
                    $SHORT_LOG->close;
                    unless($SHORT_LOG->open($short_rep_file,
                        O_WRONLY | O_CREAT | O_APPEND | O_LARGEFILE )){
                            $SHORT_LOG->open('/dev/null', O_WRONLY);
                            send_mail(get_setting('adm_email'),'cleo error',
                                'Cannot recreate log file');
                            #my $mailcmd='mail -s "cleo error" '.get_setting('adm_email');
                            #launch(0,"echo 'Cannot recreate log file' | $mailcmd",'mail');
                    }
                    do_rotate($short_rep_file);
                }
                else{
                    qlog "Cannot rename '$short_rep_file'\n", LOG_ERR;
                }
            }
        }
    };
    if($@){
        qlog "ROTATING ERROR: $!\n";
    }

} # ~log_rotate

#
#  Checks if given task execution violates
#  any restrictions.
#
#  Args:
#         id    - task id
#         block - [opt] !0= block task if violation found
#
#  Ret:
#        1 if violates
#        2 if task was deleted during test
#        0 if not
#
sub violates( $;$ ){
  if(exists($ids{$_[0]})){
    my ($tmp, $np_real);
    my $q_entry=$ids{$_[0]};

    # is blocked?
    return 1 if((ref($q_entry->{blocks}) eq 'ARRAY') 
                and scalar(@{$q_entry->{blocks}})>0);

    # not fits?
    if($q_entry->{lastowner} eq $cluster_name
       and count_enabled_cpus()<$q_entry->{np}){
      block_task($q_entry->{id},1,'__internal__','wait for blocked cpus')
        if($_[1]);

      return 1;
    }

    # is time restriced?
    if (main::check_time_restrictions($q_entry)) {
      block_task($q_entry->{id},1,'__internal__','time restrictions')
        if($_[1]);

      return 1;
    }

    # is cpu limited by system?
    $tmp=get_setting('max_sum_np',$q_entry->{user},$q_entry->{profile});
    if ($tmp>0 and $user_np_used{$q_entry->{user}}+$q_entry->{np}>$tmp) {
      if($_[1]){
        block_task($q_entry->{id},1,'__internal__','maximum np reached');
      }
      return 1;
    }

    # is cpu*hours limited by system?

    $tmp=check_cpuh($q_entry->{user});
    $np_real=$q_entry->{np}+scalar(@{$q_entry->{extranodes}});
    if ($tmp>-1 and ($q_entry->{timelimit}*$np_real)>$tmp*3600) {
      if($_[1]){
        block_task($q_entry->{id},1,'__internal__','maximum cpu*hours reached');
      }
      return 1;
    }


    $tmp=get_setting('max_run',$q_entry->{user},$q_entry->{profile});
    if ($tmp>0 and count_runned($q_entry->{user})>$tmp) {
      if($_[1]){
        block_task($q_entry->{id},1,'__internal__','maximum runned reached');
      }
      return 1;
    }

    if(main::can_run($q_entry)) {
      my $dep=main::test_dependencies($q_entry);
      if ($dep==1) {
        if($_[1]){
          block_task($q_entry->{id},1,'__internal__','wait for dependency');
#          move_to_queue($q_entry->{id},PENDING_QUEUE());
        }
        return 1;
      }
      if($dep==2) {
        qlog("Delete by dependency\n");
        del_task($q_entry->{id},'__internal__');
        return 2;
      }
    }
    return 0;
  }
}

#
#  Try to reopen log files
#
#  Ret: string with text status (+/- at start = ok/fail)
#
sub reopen_logs(){
        unless ( $cleosupport::STATUS->close() ) {
            return "-Cannot close status file!!!\n";
        }
        unless ( $cleosupport::STATUS->open(
                     $report_file, O_WRONLY|O_CREAT|O_APPEND|O_LARGEFILE)
            ) {
            return "-Cannot reopen status file!!!\n";
        }
        unless ( $cleosupport::SHORT_LOG->close() ) {
            return "-Cannot close short status file!!!\n";
        }
        unless (
              $cleosupport::SHORT_LOG->open(
                  $short_rep_file, O_WRONLY|O_CREAT|O_APPEND|O_LARGEFILE)
            ) {
            return "-Cannot reopen short status file!!!\n";
        }
        return "+ok\nLogs recreated.\n";
}

{
    my %mails;
    my %mails_lt;
    my %mails_ft;
    
#
#
#   Send emails, grouping mail texts if needed
#
#   Args: email_addr(default=admin email), subject, text
#
sub send_mail($$$){
    my ($addr,$subj,$text)=@_;
    
    if($addr eq ''){
        $addr=get_setting('adm_email');
    }
    if(not exists $mails{$addr}->{$subj}){
        $mails_ft{$addr}->{$subj}=$last_time;
    }
    $mails{$addr}->{$subj} .= $text."\n";
    $mails_lt{$addr}->{$subj} = $last_time;
    qlog "Added mail to $addr ($subj)\n", LOG_DEBUG;
}


#
#  Actually send mails
#
#  Arg: 1=force mail send
#
sub flush_mails(;$){
    my ($subj, $addr, $mailer);
    my $delay    = get_setting('mail_delay');
    my $max_delay= get_setting('mail_max_delay');

    # loop by all addresses
    foreach $addr (keys(%mails)){
        my @addr_list= split(/,/, $addr);
        
        # loop by mails
        foreach $subj (keys(%{$mails{$addr}})){
            
            # is it time to send?
            if( $last_time>$mails_lt{$addr}->{$subj}+$delay or
                $last_time>$mails_ft{$addr}->{$subj}+$max_delay or
                $_[0]>0)
            {
                
                # send the mail!
                my $mailer=undef;
                my %headers=('To'=>     \@addr_list,
                             'From'=>   'root',
                             'Subject'=>$subj);
                my $server=get_setting('mail_server');
                if($server ne ''){
                    eval{
                        local $SIG{__DIE__} = sub{return;};
                        $mailer=new Mail::Mailer('smtp','Server' => $server);
                        $mailer->open(\%headers);
                    };
                    # if fail, try to send via sendmail/qmail...
                    if(not defined $mailer){
                        $server='';
                    }
                }
                
                # try to send via local [send]mail command
                if($server eq ''){
                    eval{
                        $mailer=new Mail::Mailer;
                        $mailer->open(\%headers);
                    }
                }
                # error?
                if($@){
                    qlog "Cannot send mail: $@\n", LOG_ERR;
                    %mails=();
                    %mails_lt=();
                    %mails_ft=();
                    return;
                }
                $mailer->print($mails{$addr}->{$subj});
                if($mailer->close){
                    
                    qlog "Flushed mail to $addr ($subj)\n", LOG_DEBUG;
                    # mail sent! Now delete it from system
                    delete $mails{$addr}->{$subj};
                    delete $mails_lt{$addr}->{$subj};
                    delete $mails_ft{$addr}->{$subj};
                    next;
                }
                # cannot send...
                qlog "Cannot send mail to $addr: $!\n", LOG_ERR;
            }
        }
        
        # delete empty mail addresses...
        if(%{$mails{$addr}}==0){
            delete $mails{$addr};
            delete $mails_lt{$addr};
            delete $mails_ft{$addr};
        }
    }
}
}

#
#  Returns list of free cpus
#  [ ret valuse = reference to names array]
#
sub get_free_cpus(){
    my @free;
    
    count_free( \@free, \%pe );
    return \@free;
}

sub nil_sub() { }

sub every_nil_sub( $$$$ ) {
    return $_[3];
}

1;
