# casper_resource_status
This Perl script generates an html table showing the current node and batch queue usage on NCAR's Casper cluster. 
The script is executed every 5 minutes via cron by user 'csgteam'. 

On GLADE, the script's source is in the file /glade/u/home/csgteam/scripts/queue_status_dav/casper_resource_status.pl

The output html table is written to /glade/u/home/csgteam/scripts/queue_status_dav/nodes_table.html
and embedded in the CISL Resource Status page, https://www2.cisl.ucar.edu/user-support/cisl-resource-status
