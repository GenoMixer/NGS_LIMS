#!/usr/bin/perl
# this script create databe tables


use PARS16;

my $dbh=db_connect( ) ;
exit ( 3 ) unless( $dbh );

my $stmt=ReadFile( "create_tables.sql" ) ;
	eval {
		my $sth = $dbh->prepare( $stmt );
		$sth->execute(  );
	};
	if( $@ ){
		w2log( "Error . Sql:$stmt . Error: $@" );
		$dbh->rollback();
	}
$dbh->commit();

# all ok
db_disconnect( $dbh );
exit(0);




