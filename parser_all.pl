#!/usr/bin/perl
# version 1.0 2016.07.12
# author s.sivalingam
##############################

# Searches new folder, parse all files ( runParameters.xml, SampleSheet.csv, RunInfo.xml, First_Base_Report.htm ) in it and inserts data into tables.

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
	print "$runId\n";

	unless( parse_runfolder ( $dbh, $runId ) ) {
			$dbh->rollback();
			next ;
	}
	
	my $filename=get_filename(  'runParameters.xml' ); 
	if( $filename ) {
		unless( parse_runParameters ( $filename , $dbh, $runId ) ) {
			$dbh->rollback();
			next ;
		}
	}
	$filename=get_filename(  'SampleSheet.csv' ); 
	if( $filename ) {
		unless( parse_SampleSheet  ( $filename , $dbh, $runId ) ) {
			$dbh->rollback();
			next ;
		}
	}
	$filename=get_filename(  'RunInfo.xml' ); 
	if( $filename ) {
		unless( parse_RunInfo ( $filename , $dbh, $runId ) ) {
			$dbh->rollback();
			next ;
		}
	}
	$filename=get_filename(  'First_Base_Report.htm' ); 
	if( $filename ) {
		unless( parse_First_Base_Report ( $filename , $dbh, $runId ) ) {
			$dbh->rollback();
			next ;
		}
	}
$dbh->commit();

}
	
	

# all ok
db_disconnect( $dbh );
exit(0);




sub show_help {
        print STDERR "	
		Search new folder, parse all files and insert data into tables.
		Show only new folders( run_id ).
		Usage: $0  [--help]
		where
";
	exit (1);
}
