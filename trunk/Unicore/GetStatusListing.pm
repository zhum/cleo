package GetStatusListing;            # SPECIALISATION FOR CLEO

require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(get_status_listing);

#use Reporting qw(start_report failed_report ok_report debug_report);
use Reporting qw(debug_report failed_report ok_report start_report command_report);

use strict;

# Queries the BSS for the state of (at least) all UNICORE jobs
# and returns a list of their identifier together with the
# stats.
#
# Called in response to a #TSI_JOBQUERY

# uses functions from Reporting

# No args
#
# Returns void to TSI
#         fail/success to NJS and a list of jobs
#
#        First line is "QSTAT",
#        followed by a line per found job, first word is BSS job identifier
#        and the second word is one of RUNNING, QUEUED or SUSPENDED
#
#        List must include all Unicore jobs (but can contain  extra jobs)
#
sub get_status_listing {

    my($command, @output, $result, $bssid, $queue, $bssid, $state, $data, $ustate);
    
    start_report("Finding all jobs from UNICORE");
    
    # Get all the processes on the system, with sufficient information
    # to be able to derive the Unicore ones

    # Form the request command. 
    $command = "$main::qstat_cmd";

    command_report($command);

    @output = `($command) 2>&1`;

    # Parse output
    if($? != 0) {
         failed_report(join('',@output));
    }
    else {
        # Command succeeded. Parse the output and return
        # a line for each job found with two words, the first
        # is the job id the second its UNICORE state

        # Ouput we expect:
        #
	# zam285.zam.kfa-juelich.de:
	#                                                                    Req'd  Req'd   Elap
	# Job ID               Username Queue    Jobname    SessID NDS   TSK Memory Time  S Time
	# -------------------- -------- -------- ---------- ------ ----- --- ------ ----- - -----
	# 83.zam285.zam.kfa-ju rbreu    batch    New_Script  16522     1  -- 1000mb 00:00 C 00:00
	# 83.zam285.zam.kfa-ju rbreu    batch    torque_tes  16864     1  --    --  01:00 R   --
	# 84.zam285.zam.kfa-ju rbreu    batch    torque_tes    --      1  --    --  01:00 Q   --

	#Queue: main
	#Running: 22; Queued: 6; Pre-runned: 6; Free: 3784 of 5040+0 (256 blocked)
	#Running:
	#ID   :      User: NP:      Time :      Timelimit: Task
	#8403 :      swan:  6:   3:49:26 :Sep 22 23:54:14: abinip
	#8487 :  kuzanyan: 96:   3:47:39 :Sep 24 15:56:01: main.out
	#Queued:
	#ID   :      User: NP:Pri:     When added:    Timelimit: Task
	#7796 :   voronov:  1: 10:Sep 20 14:27:02:   0:00:20:00: !solver
	#7853 :   voronov:  1: 10:Sep 20 14:28:48:   0:00:20:00: !solver
	#=======================================
	#         
	#
        # There can be many TSIs running, return about all Jobs

        $result = "QSTAT\n";
 #       $_ = $output;
	$ustate='UNKNOWN';
	$queue='main';

	foreach my $line (@output){
		if($line =~ /^Queue:\s*(\S+)/){
			$queue=$1;
		}elsif($line =~ /^Running:\s*$/){
			$ustate='RUNNING';
		}elsif($line =~ /^Queued:\s*$/){
			$ustate='QUEUED';
		}elsif($line =~ /(\d+)\s*:\s*(\S+)\s*:\s*(\d+)\s*:/){
			$bssid="$queue.$1";

			# Absent statuses are treated as unknown as status will contain a number
#			$ustate = "UNKNOWN";
#
#			$ustate = "QUEUED"  if $state =~ /Q|T|W/;
#
#			$ustate = "RUNNING" if $state =~ /R|E/ ;
#
#			$ustate = "SUSPENDED" if $state =~ /S|H/ ;

			# Add to the returned lines
			$result = "$result $bssid $ustate\n";
		}

	}

        print main::CMD_SOCK $result;
        debug_report("qstat executed OK");
    }
}

#                  Copyright (c) Fujitsu Ltd 2000 - 2002
#
#     Use and distribution is subject to the Community Source Licence (LICENCE.FLE)
#                                                       
#         Further information is available from www.unicore.eu
#
