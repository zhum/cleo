#
#  This is part of Cleo batch system project.
#  (C) Sergey Zhumatiy (serg@parallel.ru) 1999-2009
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
package cleovars;
use strict;
use Exporter;

use vars qw($VERSION @ISA @EXPORT);
BEGIN{
  $VERSION=5.30;
};

@ISA = ('Exporter');

@EXPORT = qw(
             $VARIANT
             %exec_modules
             $port $tcount $max_count $mode $dying $die_pipe
             %pe %blocked_pe $num_free $use_file $usage $cur $hashcount
             $master $root_pid $is_master $parent_name $parent_pid
             $cluster_name $root_cluster_name %child_aliases %down_ch
             $up_ch $down_ch_select $up_ch_select
             %clusters %the_nodes
             %user_home %useruid %usergid %username %childs %childs_info
             @dead %user_conf_time $extra_nodes_used %blocked_pe_reasons
             %opts $check_time $may_go
             $queue_save $queue_alt_save $report_file $short_rep_file
             %shuffle_algorithms $shuffle_alg %child_pids %autoblock
             $all_autoblock %autononblock @time_restrictions
             %user_coll_nodes %user_maxnp %user_np_used %error_codes
             $safe_reload $q_change $run_fase
             $rootisadm $log_prefix

             %schedule %pending_schedule %foreign_schedule
             %acc_user_all %acc_user %user_groups %ext_sched

             @chld_req_q @chld_answ_q %chld_wait @reaped @reapcode
             @pre_reaped1 @pre_reaped2 @pre_reapcode1 @pre_reapcode2
             $reaping $reaping2 $new_reaped $next_restriction_time

             @pending @foreign @running @queue

             %wait_run %pe_list @for_parent @for_childs
             $reserved_shared %shared %own %ids %pids %extern_ids

             $foreign_schedule_proc $pending_schedule_proc $schedule_proc

             %requests $def_queue %usergroup $check_running

             &NATIVE_QUEUE &FOREIGN_QUEUE &PENDING_QUEUE
             &NOT_IN_QUEUE &RUNNING_QUEUE
             &min &max

             $mons_wait %mons $last_time %mon_recievers
             %parent_recievers $mon_ping_interval
             %mons_wait $Mons_select $RSH_select @mon_req_q $max_mon_timeout

             %server_opt_types %user_opt_types %profile_opt_types %clusters_opt_types

             %profile_settings %global_settings %user_settings %cluster_settings
             %def_global_settings %pe_sel_method %local_user_settings
             %clusteruser_settings %mod_settings

             %new_profile_settings %new_global_settings %new_user_settings
             %new_cluster_settings %new_local_user_settings
             %new_clusteruser_settings %new_groups %new_mod_settings

             %childs_wait %rsh_filter %subst_args

             &SUCC_OK &SUCC_FAIL &SUCC_COND &SUCC_RET
             &SUCC_ALL &SUCC_FIRST &SUCC_ANY &SUCC_WAIT

             @runned_list $runned_list_len
             $dump_flag $my_name

             %debug $log_level @log_prefixes $global_log_prefix

             $sched_alarm %sched_user_info %sched_data

             $exec_mod_cancel $exec_queue %mod_timers

             &LOG_DEBUG2 &LOG_DEBUG &LOG_INFO &LOG_WARN &LOG_ERR &LOG_ALL
             &NO_DEL_TASKS
             &MAX_QMSG &MAX_CLEO_ID &MAX_SCHED_ITERATIONS
            );


use vars qw($port $mon_port $allowed_ip $timeout $max_np $min_np $max_queue
            $tcount $max_count $mode %pe $mon_ping_interval
            $num_free $use_file $usage $one_report $file_head $file_tail
            $file_line $cur $master $def_queue $coll_nodes $dying $die_pipe $q_change
            $hashcount %user_coll_nodes $extra_nodes_used $rootisadm
            $exec_mod_cancel $exec_queue);

use vars qw($root_pid $is_master $parent_name $parent_pid $cluster_name
            $root_cluster_name %child_aliases %down_in %down_out $up_in $up_out
            $down_in_select $down_out_select $up_out_select $up_in_select %clusters);

use vars qw(
            %profile_settings %global_settings %user_settings %cluster_settings
            %def_global_settings
            %user_conf_time %mod_timers
            @runned_list $runned_list_len
            %acc_user_all %acc_user
           );

use vars qw(%user_maxnp %user_exec_line %user_post_exec_line %user_outfile
            %user_repfile %user_use_file %user_file_head %user_file_line
            %user_file_tail %user_time %user_post_exec_write %user_exec_write
            %user_shuffle %user_maxnp %user_np_used %user_tmp_dir %user_home
            %useruid %username %user_one_report %user_def_queue
            %childs_wait %error_codes @time_restrictions $next_restriction_time
           );
#^ for per-user's options
#Misc vars...
use vars qw(%childs %childs_info @dead); #childs = hash of arrays pe, on which this child is working on...
#childs_info = hash    {user/dir/nproc/task/out/time}

use vars qw($exec_line $post_exec_line $post_exec_write $tmp_dir $version);
#the lines to execute client task and to notify user

use vars qw($opt_p $opt_s $opt_a $opt_x $opt_l $opt_c $opt_i $opt_v); #command line options
use vars qw($check_time $may_go $check_running $safe_reload  @reaped @reapcode);
use vars qw($queue_save $queue_alt_save $report_file);
use vars qw(%shuffle_algorithms $shuffle_alg %rsh_filter);
use vars qw(%child_pids);

use vars qw(
            %mon_recievers @for_mons %mons_wait $Rsh_select $Mons_select $run_fase
            %schedule %pending_schedule $pending_schedule_proc $schedule_proc
            %foreign_schedule $foreign_schedule_proc %the_nodes
            %wait_run %pe_sel_method %user_groups $max_mon_timeout
            %pe_list %shared %own %ids %pids %extern_ids
            $reserved_shared %requests

            $all_autoblock %autononblock %autoblock
            @pre_reaped1 @pre_reaped2 @pre_reapcode1 @pre_reapcode2
            $reaping $reaping2 $new_reaped

            @foreign @pending @queue @running

            %parent_recievers %subst_args
            %server_opt_types %user_opt_types %profile_opt_types %clusters_opt_types

            $debug_cf $debug_nc $debug_yy $log_level @log_prefixes $global_log_prefix

            $VARIANT
            %exec_modules %ext_sched

            $sched_alarm %sched_user_info %sched_data

            $dump_flag $my_name
           );

sub FOREIGN_QUEUE() {return 'foreign_queue';}
sub PENDING_QUEUE() {return 'pending_queue';}
sub NATIVE_QUEUE()  {return 'native_queue';}
sub RUNNING_QUEUE() {return 'running_queue';}
sub NOT_IN_QUEUE()  {return 'not_queue';}

sub SUCC_OK()  {return 1;}
sub SUCC_FAIL(){return 0;}
sub SUCC_COND(){return 3;}

sub SUCC_ALL()   {return 8;}  #get all answers
sub SUCC_FIRST() {return 4;}  #get first answer
sub SUCC_ANY()   {return 0;}  #get first wanted answer
sub SUCC_RET()   {return 16;} #get answers till EPP in returned hashe 'success' is false
sub SUCC_WAIT()  {return 28;}

sub LOG_ALL      {return 0;}
sub LOG_ERR      {return 1;}
sub LOG_WARN     {return 2;}
sub LOG_INFO     {return 3;}
sub LOG_DEBUG    {return 4;}
sub LOG_DEBUG2   {return 5;}

sub MAX_QMSG()   {return 1024;}

sub MAX_CLEO_ID(){return 99_000_000;}

sub NO_DEL_TASKS {return 1250;} #magic value...

sub min($$ ){return ($_[0]>$_[1])?$_[1]:$_[0];}
sub max($$ ){return ($_[0]<$_[1])?$_[1]:$_[0];}

sub MAX_SCHED_ITERATIONS {return 10;}
1;
