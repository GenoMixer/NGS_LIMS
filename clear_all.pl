#!/usr/bin/perl

# this script clear all data in tables !!!!
# clear all tables


use PARS16;

my @tables=qw( runinfo first_base_report runparameter  selecttable readtable runfolder samplesheet surface) ;

my @ql=(
'DELETE FROM runinfo;', 
);

my $dbh=db_connect( ) ;
exit ( 3 ) unless( $dbh );

foreach $table ( @tables ) {
	$stmt="DELETE FROM $table; "; # sql
	eval {
		my $sth = $dbh->prepare( $stmt );
		$sth->execute(  );
	};
	if( $@ ){
		w2log( "Error Sql:$stmt . Error: $@" );
		$dbh->rollback();
	}
	$dbh->commit();
}


# all ok
db_disconnect( $dbh );
exit(0);




