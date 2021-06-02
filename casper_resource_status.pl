#!/usr/bin/perl
use strict;
use Switch;
#use warnings; 

 
my $targetdir = " ";
my $logfilename = " ";

my $tmpdatestamp=`date "+%m%d%y_%R"`;
chomp $tmpdatestamp;

#
# Check for optional arguments - only "-use_qstat_cache" and "-test_mode" are valid
#
my $nArgs = scalar @ARGV;
print "\nnumber of input arguments = $nArgs   (@ARGV) \n";

my $testing_mode = 0;
my $use_qstat_cache = 0; 

use Getopt::Long;
GetOptions( 'use_qstat_cache' => \$use_qstat_cache,
	        'test_mode' => \$testing_mode);
print ("after GetOptions   use_qstat_cache = $use_qstat_cache  testing_mode = $testing_mode \n\n"); 

if ( $nArgs > 0 ) {
	if ($use_qstat_cache == 1) {
        $testing_mode = 1;
        print "Will use existing qstat cache files. \n";
    } 
    if ($testing_mode == 1) {
    	print "Will run in test mode. \n";
    } 
    if (($use_qstat_cache+$testing_mode) == 0) {
    	print "\nInvalid option(s). Only valid options are '-use_qstat_cache'and '-test_mode'.\n";
    	exit;
    }
}

#
# Set up output file names and directories
#
if ($testing_mode == 1) {
	use Cwd qw(cwd);
	$targetdir = cwd;
	$logfilename = $targetdir . "/" . $tmpdatestamp . ".log";
} else {
	$targetdir = "/glade/u/home/csgteam/scripts/queue_status_dav";
	$logfilename = "/glade/scratch/csgteam/ca_queue_status_logs/" . $tmpdatestamp . ".log";
}

#
# if running in "production" mode send print diagnostics output to $logfilename, otherwise
# just echo to terminal
#
print "\noutput target directory: $targetdir \n";
print "output log file: $logfilename \n\n\n";
open(my $LOG, '>>', $logfilename) or die "Could not open file '$logfilename' $! \n";
select $LOG;
if ($testing_mode == 1) {
	select STDOUT;    # send print output to terminal
}

my $timeout = 60;   # seconds to wait for "qstat" and "pbsnodes" commands to return
#$timeout = 1;      # Short timeout for testing purposes only 

#
# STATUSFILE is a simple text file version of the output html file that will be accessed
# by users with a command script "show_status".
#
open HTMLFILE, ">$targetdir/nodes_table.html" or die "Could not open file HTMLFILE $!";
open STATUSFILE, ">$targetdir/tmp_show_status.out" or die "Could not open file STATUSFILE $!";

my $qstat_out_len = 0;
my $nodestate_out_len = 0;

## my @all_share_queue_reservations;
## my @share_queue_reservations;
my @all_reservations;
my @reservations;
my %q;

my $color = "#000000";
my $PBSbin = "/opt/pbs/bin";
my $qstatcmd = "/glade/u/apps/ch/opt/usr/bin/qstat";

my $nNodes_Free = 0;
my $nNodes_PartialUsed = 0;
my $nNodes_100Used = 0;
my $nNodes_offline = 0;

#
# generate the files with PBS qstat and pbsnodes command output. These files will be parsed repeatedly
#
eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        
        # throttle the demand on the PBS server
        my $sleepcmd = "sleep 10";
        if ($testing_mode == 1) {
        	$sleepcmd = "sleep 1";
        }
        
##      Not using this function yet.  May opt to use it at some point in the future to 
##      programmatically determine all queue names.
##      my @queuenames = `$PBSbin/qstat -Q \@casper | grep "Exe\*" | grep -v Type`;
##      print "queuenames = \n", @queuenames, "\n";

        
        if ($use_qstat_cache == 0) {
			`timeout -s SIGKILL $timeout $qstatcmd \@casper | grep -vi "job id" | grep ".casper-pbs" > "$targetdir/qstat.out"`;

			`timeout -s SIGKILL $timeout $qstatcmd \@casper -n -w | grep " R "> "$targetdir/qstat-wn.out"`;

			`ssh casper timeout -s SIGKILL $timeout $PBSbin/pbsnodes -a | grep "state = " | grep -v comment | grep -v last_state_change_time | sort | uniq -c > "$targetdir/nodestate.out"`;

			`ssh casper timeout -s SIGKILL $timeout $PBSbin/pbsnodes -a > "$targetdir/pbsnodes-a.out"`;

			`ssh casper timeout -s SIGKILL $timeout $PBSbin/pbsnodes -aSj -D "," > "$targetdir/pbsnodes-aSj.out"`;

			`ssh casper timeout -s SIGKILL $timeout $PBSbin/pbsnodes -l > "$targetdir/pbsnodes-l.out"`;

            `ssh casper timeout -s SIGKILL $timeout $PBSbin/pbs_rstat | grep '[RS][0-9][0-9]' | grep " RN " | awk '{print \$2}' > "$targetdir/pbs_reservations.out"`;
        }

        alarm 0;
};

$nNodes_offline = `cat "$targetdir/pbsnodes-l.out" | wc -l`;
chomp $nNodes_offline;

$qstat_out_len = `wc -l $targetdir/qstat.out`;
$nodestate_out_len = `grep state $targetdir/nodestate.out | wc -l`;


if ($@ | ($nodestate_out_len == 0) | ($qstat_out_len == 0)) {
	# qstat and/or pbsnodes command timed out or did not return anything useful
	if ( ($nodestate_out_len == 0) | ($qstat_out_len == 0) ) { $@ = "alarm\n";}
	die unless $@ eq "alarm\n"; # propagate unexpected errors

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900; $mon++;
	my $datestamp = sprintf('%02d:%02d %02d/%02d/%04d',$hour,$min,$mon,$mday,$year);

	print HTMLFILE qq{
	<body>
		<style type="text/css">
			table {
			  width: 600px;
			  border-collapse: collapse;
			  font-family: "Lucida Sans Unicode","Lucida Grande",Verdana,Arial,Helvetica,sans-serif;
			  font-size: 0.75em;
			}
		</style>
			
		<table style="width: 600px; border="2" cellpadding="3">
			<tbody>
				<tr valign="middle">
					<td style="text-align: left;"><img src="https://www.cisl.ucar.edu/uss/resource_status_table/light_red.gif" width="25" /></td>
					<td style="text-align: left;">
						The Casper job scheduling system was not responding as of $datestamp.<br />
						If the problem persists, users will receive email updates through our Notifier service.<br />
						qstat_out_len = $qstat_out_len     nodestate_out_len = $nodestate_out_len<br />
					</td>
				</tr>
			</tbody>
		</table>
	};
	close (HTMLFILE);
	
	print STATUSFILE "  \n";
	print STATUSFILE " The Casper job scheduling system was not responding as of $datestamp. \n";
	print STATUSFILE " If the problem persists, users will receive email updates through our Notifier service. \n";
	print STATUSFILE "  \n";
	close (STATUSFILE);
	
	print "\nqstat and/or pbsnodes commands timed out or did not return anything useful\n";
	print "processing was aborted. \n\n";
	
} else {   # PBS commands did not time out so proceed
	
    my $nNodes_runningjobs = `cat "$targetdir/qstat-wn.out" | grep " R " | awk '{print \$12 }' | tr + '\n' | cut -d "/" -f 1 | sort | uniq | wc -l`;
    chomp $nNodes_runningjobs;
    
    $nNodes_Free = `cat "$targetdir/pbsnodes-aSj.out" | grep -c " free                 0     0"`;
	chomp $nNodes_Free;
    
    $nNodes_PartialUsed = `cat "$targetdir/pbsnodes-aSj.out" | grep " free " | grep -v "free                 0     0" | wc -l`;
	chomp $nNodes_PartialUsed;
	
	$nNodes_100Used = `cat "$targetdir/pbsnodes-aSj.out" | grep -c job-busy`;
	chomp $nNodes_100Used;
	
	my $tot_Casper_nodes = `ssh casper $PBSbin/pbsnodes -a | grep Mom | wc -l`;
    chomp $tot_Casper_nodes;
	
    print "number of PBS nodes = $tot_Casper_nodes \n";
	print "nNodes_Free         = $nNodes_Free \n";
	print "nNodes_PartialUsed  = $nNodes_PartialUsed \n";
	print "nNodes_100Used      = $nNodes_100Used \n";
	print "nNodes_runningjobs  = $nNodes_runningjobs\n\n";
    
    
	my @nodes_jobs  = `cat "$targetdir/nodestate.out" | grep "job-busy" | grep -v down | grep -v offline | awk '{ print \$1 }'`;
	
	my $nNodes_jobs = 0;
	foreach my $nnodes_job (@nodes_jobs) {
		$nNodes_jobs += $nnodes_job;
	}
	
	@reservations = `cat "$targetdir/pbs_reservations.out"`;
    print scalar @reservations; print " running reservations found \n";
    print @reservations, "\n";
   
	my $nNodes_reserved = 0;
    my $nJobs_reservations = 0;
    my $nResNodes_jobs = 0;
    
    my @reservedNodes_list = `ssh casper $PBSbin/pbs_rstat -F | grep resv_nodes | awk '{print \$3}' | sed 's/(//g'  | awk '{sub (/+/, "\\n"); print}' | cut -d ":" -f1`;	
    my $num_reservations = scalar @reservedNodes_list;
    print "number of reservations found = $num_reservations \n";
    print "reservedNodes_list = \n @reservedNodes_list \n";
    
	foreach my $res (@reservations) {
		chomp $res;
        my $nNodes_reservation = `ssh casper timeout -s SIGKILL $timeout $PBSbin/pbs_rstat -F $res | grep nodect | awk '{ print \$3 }'`;
		chomp $nNodes_reservation;
		print "number of nodes in reservation $res:  $nNodes_reservation \n";
        
        $nNodes_reserved += $nNodes_reservation;
        
		my $num_running_jobs = `cat "$targetdir/qstat.out" | grep $res | grep " R " | wc -l`;
		chomp $num_running_jobs;
		$nJobs_reservations += $num_running_jobs;
		print "number of running jobs in reservation $res:  $num_running_jobs \n";
		
		my @jobids;
		my $nresnodes = `grep $res "$targetdir/qstat-wn.out" | awk '{ print \$6 }'`;
		chomp $nresnodes;
		if ($nresnodes > 0) {
			print "reservation $res found in qstat-wn.out   nresnodes = $nresnodes \n";
			@jobids = `grep $res "$targetdir/qstat-wn.out" | awk '{ print \$1 }' | cut -d '.' -f 1`;
			print "            jobids = @jobids";
		}
		$nResNodes_jobs += $nresnodes;
	}
	
    print "\nTotal number of reserved nodes:  $nNodes_reserved \n";
    print "Total number of reserved nodes in use = $nResNodes_jobs \n";
    print "Total number of jobs running in reservations = $nJobs_reservations \n\n";
    
	
	print "According to pbsnodes command: \n";
	print "number of PBS nodes   = $tot_Casper_nodes \n";
	print "number of nodes free  = $nNodes_Free \n";
	print "number of nodes busy  = $nNodes_jobs \n";
	print "number of nodes offline  = $nNodes_offline \n";
	print "number of nodes reserved = $nNodes_reserved \n";
	my $tmp_nodecount = $nNodes_Free + $nNodes_jobs + $nNodes_offline + $nNodes_reserved;
	print "total number of nodes accounted for by pbsnodes = $tmp_nodecount\n\n";
	
	
	my $run_htc    = `cat "$targetdir/qstat.out" | grep " R htc" | wc -l`;         chomp $run_htc;
	my $run_vis    = `cat "$targetdir/qstat.out" | grep " R vis" | wc -l`;         chomp $run_vis;
	my $run_rda    = `cat "$targetdir/qstat.out" | grep " R rda" | wc -l`;         chomp $run_rda;
	my $run_gpgpu  = `cat "$targetdir/qstat.out" | grep " R gpgpu" | wc -l`;       chomp $run_gpgpu;
	my $run_lrgmem = `cat "$targetdir/qstat.out" | grep " R largemem"  | wc -l`;   chomp $run_lrgmem;
	my $run_mixgpu = `cat "$targetdir/qstat.out" | grep " R mixgpu"  | wc -l`;     chomp $run_mixgpu; 
	
	my $tot_jobs_running = 0;
	print "jobs running in htc queue    = $run_htc\n";     
	print "jobs running in vis queue    = $run_vis\n";      
	print "jobs running in gpgpu queue  = $run_gpgpu\n";
	print "jobs running in rda queue    = $run_rda\n"; 
	print "jobs running in largemem     = $run_lrgmem\n";
	print "jobs running in mixgpu       = $run_mixgpu\n";
	print "jobs running in reservations = $nJobs_reservations\n";
	
	
	$tot_jobs_running = $run_htc + $run_vis + $run_rda + $run_gpgpu + $run_lrgmem + $run_mixgpu + $nJobs_reservations;
	print "number of batch jobs running = $tot_jobs_running \n\n";
	

	# output the html
	# the loop through the queues also counts the number of users ($q{$queue}[3]) for each queue.
	# the "if" portion of those statements avoids displaying "0" for empty queues.
	
	print HTMLFILE q{
			<body>
			<style type="text/css">
			table {
				width: 600px;
				border-collapse: collapse;
				font-family: "Lucida Sans Unicode","Lucida Grande",Verdana,Arial,Helvetica,sans-serif;
			}
			</style>
	
			<table style="width: 600px; height: 320px;" border="2" cellpadding="3">
			<tbody style="text-align: center">
			<tr $color>
				<td><strong>System</strong></td>
				<td><strong>Queue</strong></td>
				<td><strong>Jobs<br>Running</strong></td>
				<td><strong>Jobs<br>Queued</strong></td>
				<td><strong>Jobs<br>Held</strong></td>
				<td><strong>Users</strong></td>
			</tr>
	};
	print STATUSFILE "  \n";
	print STATUSFILE "       Queue      Jobs      Jobs     Jobs    Users \n";
	print STATUSFILE "               Running      Queued   Held \n";
	
	# forces a particular order on the queues in the table.
	# inserts "-" in place of blanks/zeros. 
	my @queues = qw(htc vis gpgpu rda largemem mixgpu reservations);

	foreach my $queue (@queues) {
		
		$q{$queue}[0] = '-' unless ($q{$queue}[0]);   # number of jobs running in $queue
		$q{$queue}[1] = '-' unless ($q{$queue}[1]);   # number of nodes in running jobs in $queue
		$q{$queue}[2] = '-' unless ($q{$queue}[2]);   # number of jobs queued in $queue
		$q{$queue}[3] = '-' unless ($q{$queue}[3]);   # number of jobs held in $queue
		$q{$queue}[4] = '-' unless ($q{$queue}[4]);   # number of unique users with jobs in $queue
		
		if ($queue =~ m/htc|vis|gpgpu|rda|largemem|mixgpu/) {
			my $queue_name = $queue;
			
			$q{$queue}[0] = `cat "$targetdir/qstat.out" | grep $queue_name | grep " R " | wc -l`;
			$q{$queue}[2] = `cat "$targetdir/qstat.out" | grep $queue_name | grep " Q " | wc -l`;
			$q{$queue}[3] = `cat "$targetdir/qstat.out" | grep $queue_name | grep " H " | wc -l`;
			$q{$queue}[4] = `cat "$targetdir/qstat.out" | grep $queue_name | awk '{ print \$3 }' | sort | uniq | wc -l`;  # number of unique users
			print "queue: $queue   number of unique users = $q{$queue}[4]";

			my $queue_node_count = int(`cat "$targetdir/qstat-wn.out" | grep $queue_name | grep " R " | awk '{print \$12}' | cut -d '/' -f 1 | sort | uniq -c | wc -l`); 
			
			chomp $queue_node_count;
			print "                unique node count = $queue_node_count\n";
			$q{$queue}[1] = $queue_node_count;
			
		}  # for htc, vis, gpgpu, largemem, rda, mixgpu queues
		
		else {
			my $queue_name = "reservations";
			my $nResJobs_Q = 0;
			my $nUnique_Users = 0;
			
			foreach my $res (@reservations) {
				chomp $res;
				
				my $njobs_queued = `cat "$targetdir/qstat.out" | grep $res | grep " Q " | wc -l`;
				chomp $njobs_queued;
				$nResJobs_Q += $njobs_queued;
				
				my $nusers = `cat "$targetdir/qstat.out" | grep $res | awk '{ print \$2 }' | sort | uniq | wc -l`;  # this reservations number of unique users
				chomp $nusers;
				$nUnique_Users += $nusers;
			}
				
			$q{$queue}[0] = $nJobs_reservations;
			$q{$queue}[1] = $nResNodes_jobs;
			$q{$queue}[2] = $nResJobs_Q;
			$q{$queue}[3] = 0;                  # For now assuming that no reservation jobs are on hold.
			$q{$queue}[4] = $nUnique_Users;
			print "reservation: $queue   number of unique users = $q{$queue}[4]";
			
		}  # for reservations
		print "\n";
			
	}   # foreach queue - htc | vis| gpgpu | rda | mixgpu | largemem | reservations
		
	
	# determine if any queues are completely empty of any jobs - those entries will skipped.
	my $numRows = 18;
	foreach my $queue (@queues) {
		if ( ($q{$queue}[0] + $q{$queue}[2] + $q{$queue}[3]) == 0 ) {  # count number of jobs running, queued or held
			$numRows--;
			print "no jobs found for queue $queue - will not be reported \n";
		}
        else {
            my $tmp_njobs = $q{$queue}[0] + $q{$queue}[2] + $q{$queue}[3];
            print "queue $queue  has a total number of $tmp_njobs jobs\n";
        }
	}
	
    print "\ntable will have $numRows rows\n";
	print HTMLFILE qq{
		 <tr $color>
			<td rowspan="$numRows">Casper<br />
				<img src="https://www.cisl.ucar.edu/uss/resource_status_table/light_green.gif" width="25">
			</td>
		 </tr>
	};
    print "Green light written to table\n\n";

	
	foreach my $queue (@queues) {
		if ( ($q{$queue}[0] + $q{$queue}[2] + $q{$queue}[3]) > 0 ) {
			print HTMLFILE qq{
				<tr $color>
					<td>$queue</td> 
					<td>$q{$queue}[0]</td>       <!--- number of jobs running            -->
					<td>$q{$queue}[2]</td>       <!--- number of jobs queued             -->
					<td>$q{$queue}[3]</td>       <!--- number of jobs held               -->
					<td>$q{$queue}[4]</td>       <!--- number of users w/ jobs in queue  -->
				</tr>
			};
			printf STATUSFILE "%12s %9d %8d %8d %8d %8d \n", $queue, $q{$queue}[0], $q{$queue}[2], $q{$queue}[3], $q{$queue}[4];
		}
	}

	my $total_jobs   = 0;
	my $total_nodes  = 0;
	my $total_queued = 0;
	my $total_held   = 0;
	my $total_users  = 0;
	
	foreach my $queue (@queues) {
		$total_jobs   += $q{$queue}[0];
		$total_nodes  += $q{$queue}[1];
		$total_queued += $q{$queue}[2];
		$total_held   += $q{$queue}[3];
		$total_users  += $q{$queue}[4];
	}
	
	print HTMLFILE qq{
			<tr $color>
				<td><strong>Totals</strong></td>
				<td><strong> $total_jobs </strong></td>
				<td><strong> $total_queued </strong></td>
				<td><strong> $total_held </strong></td>
				<td><strong> $total_users </strong></td>
			</tr>
			};
	printf STATUSFILE "---------------------------------------------------------- \n";
	printf STATUSFILE "      Totals ";
	printf STATUSFILE "%9d %8d %8d %8d %8d \n\n", $total_jobs, $total_queued, $total_held, $total_users;

	
	# Add the "Node Activity" table.  Assuming that both the number of free nodes and the number 
	# of nodes allocated for the share queue but not in use will always be greater than zero.
	print HTMLFILE qq{
		<tr bgcolor="#D3D3D3">
			<td colspan="6"; style='border-bottom:none'>  </td>
			<!-- td colspan="6">  </td -->
		</tr>
		<tr $color>
			<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
			<td colspan="2"><font size="3"><strong>Node Activity</strong></font></td>
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		</tr>
		
	};
	
	printf STATUSFILE "Node Activity: \n"; 
	printf STATUSFILE "           Free %5d \n", $nNodes_Free;

	
	my $Total_Node_Count = $nNodes_Free + $nNodes_PartialUsed + $nNodes_100Used + $nNodes_offline + $nNodes_reserved;
	print "Total_Node_Count = $Total_Node_Count \n";
#	if ($Total_Node_Count != $tot_Casper_nodes) {
#		$Total_Node_Count = $tot_Casper_nodes;
#	}
	
	
	print HTMLFILE qq{	
		 <tr $color>
		 	<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
			<td rowspan="1"><font size="3">All 36 CPUs in Use</td>
			<td colspan="1"> $nNodes_100Used </font></td>
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		 </tr>
		 
		 <tr $color>
		 	<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
			<td rowspan="1">1-35 CPUs in Use</td>
			<td colspan="1"> $nNodes_PartialUsed </font></td>
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		 </tr>
		 
		 <tr $color>
			<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
			<td rowspan="1">0 CPUs in Use</td>
			<td colspan="1"> $nNodes_Free </td>
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		 </tr>
		 
         <tr $color>
            <td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
            <td rowspan="1">Reserved / In Use</td>
            <td colspan="1"> $nNodes_reserved / $nResNodes_jobs</td>
            <td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
         </tr>
         
         <tr $color>
		 	<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
			<td rowspan="1">Down/Offline</td>
			<td colspan="1"> <font color="#ff0000"> $nNodes_offline </font></td>
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		 </tr>
		 
		 <tr $color>
		 	<td colspan="1"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3"> </td>
			<td rowspan="1"> <font size="3"> <strong>Total Nodes</strong> </font> </td>
			<td colspan="1"> <strong> $Total_Node_Count </strong> </td> 
			<td colspan="3"; style='border-bottom:none;border-top:none'; bgcolor="#D3D3D3">  </td>
		 </tr>
	};
	printf STATUSFILE "   Down/Offline %5d \n\n", $nNodes_offline;


	my $datestamp=`date "+%l:%M %P %Z %a %b %e %Y"`;   # used for display in HTML table
	print HTMLFILE qq{
			<tr>
				<td colspan="7">Updated $datestamp</td>
			</tr>
			</tbody>
			</table>
	};
	#printf STATUSFILE "Updated  %s \n\n", $datestamp;
	
	close (HTMLFILE);
	close (STATUSFILE);
	select STDOUT;
	
	my $cmd = "cp $targetdir/tmp_show_status.out $targetdir/show_status.out";
	my $noopt = `$cmd`;

	if ($testing_mode == 0) { 
		my $cmd = "rm -f $logfilename";
#		my $noopt = `$cmd`;
	}

}
