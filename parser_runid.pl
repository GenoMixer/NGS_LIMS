#!/usr/bin/perl
# version 1.0 2016.07.12
##############################

# Table with Run_IDs 


use PARS16;

GetOptions (
        'new|n' => \$new,
        "help|h|?"  => \$help ) or show_help();

show_help() if($help);


my $dbh=db_connect( ) ;
exit ( 3 ) unless( $dbh );


# read all dirs in runfolder
my $dir=$Paths->{RUNFOLDER};
my @ls;
unless( opendir(DIR, $dir) ) {
	w2log( "can't opendir $dir: $!" );
	return 0;
}
	@ls=grep { /$globmask/ && -d "$dir/$_" } readdir(DIR) ;
closedir DIR;

# looking for all saved run_id in table runfolder

my $sql ="SELECT run_id from runfolder ;";
my $sth = $dbh->prepare( $sql );
my $rv;
unless ( $rv = $sth->execute(  ) || $rv < 0 ) {
	w2log ( "Sql( $sql ) Someting wrong with database  : $DBI::errstr" );
	exit 4;
}

my @RUN_IDs=();
my $hrow;
while ( $hrow=$sth->fetchrow_hashref ){
	push( @RUN_IDs, $hrow->{run_id} ) ;
}
foreach $runId ( @ls ) {	
	next if( grep{ /^$runId$/ } @RUN_IDs ) ; # save only new run_id
	print "$runId\n" if($new);

	if( parse_runfolder ( $dbh, $runId ) ) {
		$dbh->commit();
	} else {
		$dbh->rollback();
	}	
}
	
if( !$new ) {
	foreach $runId ( @ls ) {
		print "$runId\n";
	}
}	

# all ok
db_disconnect( $dbh );
exit(0);





sub show_help {
        print STDERR "
		Search and insert run_id in to table Runfolder. 
		Usage: $0 [--new] [--help]
		where
		--new show only new inserted run_id dirs (default: show all RunId )
		Sample:
		$0 --new
";
	exit (1);
}

