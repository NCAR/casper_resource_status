# casper_resource_status
This Perl script generates an html table showing the current node and batch queue usage on NCAR's Casper cluster. 
The script is executed every 5 minutes via cron by user 'csgteam'. 

On GLADE, the script's source is in the file /glade/u/home/csgteam/scripts/queue_status_dav/casper_resource_status.pl

The output html table is written to /glade/u/home/csgteam/scripts/queue_status_dav/nodes_table.html
and embedded in the CISL Resource Status page, https://www2.cisl.ucar.edu/user-support/cisl-resource-status

# Usage
For typical production execution:
/glade/u/home/csgteam/scripts/queue_status_dav/casper_resource_status.pl

There are two optional parameters, "use_qstat_cache" and "test_mode", that were added to aid in
development and debugging.
/glade/u/home/csgteam/scripts/queue_status_dav/casper_resource_status.pl -test_mode
Dumps print output to terminal and writes output files to the local working directory. 
There is a known side effect using this where an empty output log file is generated.

/glade/u/home/csgteam/scripts/queue_status_dav/casper_resource_status.pl -use_qstat_cache
makes use of existing output *.out files (see bbelow) to reduce queries
against the PBS database. This also turns on test mode.

# Output files
In addition to "queues_table_ch.html" 8 temporary output files are re-generated in each execution.
![alt text](https://github.com/mickcoady/casper_resource_status/blob/main/queue_status_dav_files.png "output files")


# Example output html table
![alt text](https://github.com/mickcoady/casper_resource_status/blob/main/ExampleScreenShot.png "Example table")


