# common variables and functions


use DBI;
use Data::Dumper;
use Getopt::Long;
use HTML::TokeParser;
use XML::Simple qw(:strict);
use Text::CSV;


# mask for run_id in runfolder directory
$globmask='^\d{6}_\w\d{5}_\d{4}_\w{10}$' ;

$Paths->{HOME}='/home/sugi/Desktop/160818_NGS_LIMS';
if( -d 'c:\git\tmp\csv-xml' ) { 
	$Paths->{HOME}='c:\git\tmp\csv-xml';
}

$Paths->{RUNFOLDER}="$Paths->{HOME}/Runfolder";
$Paths->{LOG}="$Paths->{HOME}/log/pars16.log";

$DB->{dsn}="DBI:mysql:database=NGS_LIMS;host=localhost;port=3306";
$DB->{user}="root";
$DB->{password}="suggi05";



sub db_connect {
my $dsn      = $DB->{dsn};
my $user     = $DB->{user};
my $password = $DB->{password};

my $dbh = DBI->connect($dsn, $user, $password, {
   PrintError       => 0,
   RaiseError       => 1,
   AutoCommit       => 0,
   FetchHashKeyName => 'NAME_lc',
}) or w2log( "Cannot connect to database : $DBI::errstr" );
return $dbh;
}



sub get_date {
	my $time=shift() || time();
	my $format=shift || "%s-%.2i-%.2i %.2i:%.2i:%.2i";
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time);
	$year+=1900;$mon++;
    return sprintf( $format,$year,$mon,$mday,$hour,$min,$sec);
}	


sub w2log {
	my $msg=shift;
	open (LOG,">>$Paths->{LOG}") || print ("Can't open file $Paths->{LOG}. $msg") ;
	print LOG get_date()."\t$msg\n";
	print STDERR $msg;
	close (LOG);
}



sub get_filename {
	my $fn=shift; 
	my $filename="$Paths->{RUNFOLDER}/$runId/$fn" ;
	unless( -f $filename ) {
		w2log( "File $filename not exist\n" ) ;
		return undef;
	}
	return $filename;
}


sub db_disconnect {
	my $dbh=shift;
	$dbh->disconnect;
}

sub GetRecord {
	my $dbh=shift;
	my $id=shift;
	my $table=shift;
	#my $fields=shift || '*';
	my $stmt ="SELECT * from $table where id = ? ;";
	my $sth = $dbh->prepare( $stmt );
	my $rv;
	unless ( $rv = $sth->execute( $id ) || $rv < 0 ) {
		message2 ( "Someting wrong with database  : $DBI::errstr" );
		w2log ( "Sql( $stmt ) Someting wrong with database  : $DBI::errstr" );
		return 0;
	}
	return ( $sth->fetchrow_hashref );	
}

sub GetNextSequence {
	my $dbh=shift;
	my $row;
	my $table='sequ';
	my $stmt ="update $table set id=id+1; ";
	my $sth;
	my $rv ;
eval {
	$sth = $dbh->prepare( $stmt );
	$rv = $sth->execute( );
};
	if( $@ ){
		w2log( "Error update. Sql:$stmt . Error: $@" );
		$dbh->rollback();
		return 0;
	}
eval {
	$stmt ="select id from $table";
	$sth = $dbh->prepare( $stmt );
	$rv = $sth->execute( );
	$row=$sth->fetchrow_hashref;
};
	if( $@ ){
		w2log( "Error select. Sql:$stmt . Error: $@" );
		$dbh->rollback();
		return 0;
	}
$dbh->commit();
return ( $row->{id} );	
}


sub InsertRecord {
	my $dbh=shift;
	my $stmt=shift; # sql
	my $row=shift; # data
	#print Dumper( $row );
	#print Dumper( $stmt );
	#print Dumper( $Columns	);
eval {
	my $sth = $dbh->prepare( $stmt );
	$sth->execute( @{$row} );
};
	if( $@ ){
		w2log( "Error insert. Sql:$stmt . Error: $@" );
		$dbh->rollback();
		return 0;
	}
$dbh->commit();
return ( 1 );	
}



sub ReadFile {
	my $filename=shift;
	my $ret="";
	open (IN,"$filename") || w2log("Can't open file $filename") ;
		while (<IN>) { $ret.=$_; }
	close (IN);
	return $ret;
}	

sub WriteFile {
	my $filename=shift;
	my $body=shift;
	unless( open (OUT,">$filename")) { w2log("Can't open file $filename for write" ) ;return 0; }
	print OUT $body;
	close (OUT);
	return 1;
}	

sub AppendFile {
	my $filename=shift;
	my $body=shift;
	unless( open (OUT,">>$filename")) { w2log("Can't open file $filename for append" ) ;return 0; }
	print OUT $body;
	close (OUT);
	return 1;
}


sub ReadXml{
        my $filename=shift;
        my $xml;
        eval {  $xml=XMLin( $filename,  ForceArray=>0 , ForceContent =>0 , KeyAttr => 1, KeepRoot => 1, SuppressEmpty => '' ) } ;
                if($@) {
                        w2log ( "XML file $filename error: $@" );
                        return( undef );
                }
        return $xml;
}



sub parse_runParameters {
	my $filename=shift;
	my $dbh=shift;
	my $runId=shift;	
	my $xml=ReadXml( $filename );
	#print Dumper( $xml );
	my $tmp_root=$xml->{'RunParameters'}->{'Setup'};
	my %hrow;
	my @rows;

$hrow{run_id}=$runId ;
$hrow{run_id}=substr( $tmp_root->{'RunID'}, 0, 45 ) unless(ref( $tmp_root->{'RunID'} ));
$hrow{recipefragmentversion}=substr( $tmp_root->{'RecipeFragmentVersion'}, 0, 45 ) unless(ref( $tmp_root->{'RecipeFragmentVersion'} ));
$hrow{flowcell}=substr( $tmp_root->{'Flowcell'}, 0, 45 ) unless(ref( $tmp_root->{'Flowcell'} ));
$hrow{remapqscores}=substr( $tmp_root->{'RemapQScores'}, 0, 45 ) unless(ref( $tmp_root->{'RemapQScores'} ));
$hrow{computername}=substr( $tmp_root->{'ComputerName'}, 0, 45 ) unless(ref( $tmp_root->{'ComputerName'} ));
$hrow{sbs0}=substr( $tmp_root->{'Sbs'}, 0, 45 ) unless(ref( $tmp_root->{'Sbs'} ));
$hrow{performprerunfluidicscheck}=1 if($tmp_root->{'PerformPreRunFluidicsCheck'}=~/^true$/ );
$hrow{performprerunfluidicscheck}=0 if($tmp_root->{'PerformPreRunFluidicsCheck'}=~/^false$/ );
$hrow{experimentname}=substr( $tmp_root->{'ExperimentName'}, 0, 45 ) unless(ref( $tmp_root->{'ExperimentName'} ));
$hrow{numtilesperswath}=$tmp_root->{'NumTilesPerSwath'} if($tmp_root->{'NumTilesPerSwath'}=~/^\d+$/ );
$hrow{cpldversion}=substr( $tmp_root->{'CPLDVersion'}, 0, 45 ) unless(ref( $tmp_root->{'CPLDVersion'} ));
$hrow{clusteringchoice}=substr( $tmp_root->{'ClusteringChoice'}, 0, 45 ) unless(ref( $tmp_root->{'ClusteringChoice'} ));
$hrow{resumecycle}=$tmp_root->{'ResumeCycle'} if($tmp_root->{'ResumeCycle'}=~/^\d+$/ );
$hrow{mockrun}=1 if($tmp_root->{'MockRun'}=~/^true$/ );
$hrow{mockrun}=0 if($tmp_root->{'MockRun'}=~/^false$/ );
$hrow{periodicsave}=substr( $tmp_root->{'PeriodicSave'}, 0, 45 ) unless(ref( $tmp_root->{'PeriodicSave'} ));
$hrow{areaperpixelmm2}=substr( $tmp_root->{'AreaPerPixelmm2'}, 0, 45 ) unless(ref( $tmp_root->{'AreaPerPixelmm2'} ));
$hrow{swathscanmode}=substr( $tmp_root->{'SwathScanMode'}, 0, 45 ) unless(ref( $tmp_root->{'SwathScanMode'} ));
$hrow{username0}=substr( $tmp_root->{'Username'}, 0, 45 ) unless(ref( $tmp_root->{'Username'} ));
$hrow{scannedbarcode}=substr( $tmp_root->{'ScannedBarcode'}, 0, 45 ) unless(ref( $tmp_root->{'ScannedBarcode'} ));
$hrow{tempfolder1}=substr( $tmp_root->{'TempFolder'}, 0, 254 ) unless(ref( $tmp_root->{'TempFolder'} ));
$hrow{read1}=$tmp_root->{'Read1'} if($tmp_root->{'Read1'}=~/^\d+$/ );
$hrow{firstbaseconfirmation}=1 if($tmp_root->{'FirstBaseConfirmation'}=~/^true$/ );
$hrow{firstbaseconfirmation}=0 if($tmp_root->{'FirstBaseConfirmation'}=~/^false$/ );
$hrow{enableanalysis}=1 if($tmp_root->{'EnableAnalysis'}=~/^true$/ );
$hrow{enableanalysis}=0 if($tmp_root->{'EnableAnalysis'}=~/^false$/ );
$hrow{compressbcls}=1 if($tmp_root->{'CompressBcls'}=~/^true$/ );
$hrow{compressbcls}=0 if($tmp_root->{'CompressBcls'}=~/^false$/ );
$hrow{indexread2}=$tmp_root->{'IndexRead2'} if($tmp_root->{'IndexRead2'}=~/^\d+$/ );
$hrow{promptforpereagents}=1 if($tmp_root->{'PromptForPeReagents'}=~/^true$/ );
$hrow{promptforpereagents}=0 if($tmp_root->{'PromptForPeReagents'}=~/^false$/ );
$hrow{samplesheet}=substr( $tmp_root->{'SampleSheet'}, 0, 254 ) unless(ref( $tmp_root->{'SampleSheet'} ));
$hrow{outputfolder}=substr( $tmp_root->{'OutputFolder'}, 0, 254 ) unless(ref( $tmp_root->{'OutputFolder'} ));
$hrow{motordelayframes}=$tmp_root->{'FPGADynamicFocusSettings'}->{'MotorDelayFrames'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'MotorDelayFrames'}=~/^\d+$/ );
$hrow{maxsubsequentzjumphalfum}=$tmp_root->{'FPGADynamicFocusSettings'}->{'MaxSubsequentZJumpHalfUm'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'MaxSubsequentZJumpHalfUm'}=~/^\d+$/ );
$hrow{maxinitialzjumphalfum}=$tmp_root->{'FPGADynamicFocusSettings'}->{'MaxInitialZJumpHalfUm'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'MaxInitialZJumpHalfUm'}=~/^\d+$/ );
$hrow{numberofinitialzjumps}=$tmp_root->{'FPGADynamicFocusSettings'}->{'NumberOfInitialZJumps'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'NumberOfInitialZJumps'}=~/^\d+$/ );
$hrow{groupsize}=$tmp_root->{'FPGADynamicFocusSettings'}->{'GroupSize'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'GroupSize'}=~/^\d+$/ );
$hrow{cvgainstart}=$tmp_root->{'FPGADynamicFocusSettings'}->{'CVGainStart'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'CVGainStart'}=~/^\d+$/ );
$hrow{igain}=$tmp_root->{'FPGADynamicFocusSettings'}->{'IGain'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'IGain'}=~/^\d+$/ );
$hrow{hotpixel}=$tmp_root->{'FPGADynamicFocusSettings'}->{'HotPixel'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'HotPixel'}=~/^\d+$/ );
$hrow{offset}=$tmp_root->{'FPGADynamicFocusSettings'}->{'Offset'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'Offset'}=~/^\d+$/ );
$hrow{dithersize}=$tmp_root->{'FPGADynamicFocusSettings'}->{'DitherSize'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'DitherSize'}=~/^\d+$/ );
$hrow{ihistory}=$tmp_root->{'FPGADynamicFocusSettings'}->{'IHistory'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'IHistory'}=~/^\d+$/ );
$hrow{cvgainposlocked}=$tmp_root->{'FPGADynamicFocusSettings'}->{'CVGainPosLocked'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'CVGainPosLocked'}=~/^\d+$/ );
$hrow{dithershift}=$tmp_root->{'FPGADynamicFocusSettings'}->{'DitherShift'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'DitherShift'}=~/^\d+$/ );
$hrow{softwarelaserlag}=$tmp_root->{'FPGADynamicFocusSettings'}->{'SoftwareLaserLag'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'SoftwareLaserLag'}=~/^\d+$/ );
$hrow{intensityceiling}=$tmp_root->{'FPGADynamicFocusSettings'}->{'IntensityCeiling'} if($tmp_root->{'FPGADynamicFocusSettings'}->{'IntensityCeiling'}=~/^\d+$/ );
$hrow{index0}=substr( $tmp_root->{'Index'}, 0, 45 ) unless(ref( $tmp_root->{'Index'} ));
$hrow{applicationversion}=substr( $tmp_root->{'ApplicationVersion'}, 0, 45 ) unless(ref( $tmp_root->{'ApplicationVersion'} ));
$hrow{indexread1}=$tmp_root->{'IndexRead1'} if($tmp_root->{'IndexRead1'}=~/^\d+$/ );
$hrow{templatecyclecount}=$tmp_root->{'TemplateCycleCount'} if($tmp_root->{'TemplateCycleCount'}=~/^\d+$/ );
$hrow{enablenotifications}=1 if($tmp_root->{'EnableNotifications'}=~/^true$/ );
$hrow{enablenotifications}=0 if($tmp_root->{'EnableNotifications'}=~/^false$/ );
$hrow{numanalysisthreads}=$tmp_root->{'NumAnalysisThreads'} if($tmp_root->{'NumAnalysisThreads'}=~/^\d+$/ );
$hrow{resume}=1 if($tmp_root->{'Resume'}=~/^true$/ );
$hrow{resume}=0 if($tmp_root->{'Resume'}=~/^false$/ );
$hrow{slideholder}=substr( $tmp_root->{'SlideHolder'}, 0, 45 ) unless(ref( $tmp_root->{'SlideHolder'} ));
$hrow{pairendfc}=1 if($tmp_root->{'PairEndFC'}=~/^true$/ );
$hrow{pairendfc}=0 if($tmp_root->{'PairEndFC'}=~/^false$/ );
$hrow{runmode}=substr( $tmp_root->{'RunMode'}, 0, 45 ) unless(ref( $tmp_root->{'RunMode'} ));
$hrow{focuscamerafirmware}=substr( $tmp_root->{'FocusCameraFirmware'}, 0, 45 ) unless(ref( $tmp_root->{'FocusCameraFirmware'} ));
$hrow{integrationmode}=substr( $tmp_root->{'IntegrationMode'}, 0, 45 ) unless(ref( $tmp_root->{'IntegrationMode'} ));
$hrow{cameradriver}=substr( $tmp_root->{'CameraDriver'}, 0, 45 ) unless(ref( $tmp_root->{'CameraDriver'} ));
$hrow{fcposition}=substr( $tmp_root->{'FCPosition'}, 0, 45 ) unless(ref( $tmp_root->{'FCPosition'} ));
$hrow{selectedsurface}=substr( $tmp_root->{'SelectedSurface'}, 0, 45 ) unless(ref( $tmp_root->{'SelectedSurface'} ));
$hrow{enablecameralogging}=1 if($tmp_root->{'EnableCameraLogging'}=~/^true$/ );
$hrow{enablecameralogging}=0 if($tmp_root->{'EnableCameraLogging'}=~/^false$/ );
$hrow{camerafirmware}=substr( $tmp_root->{'CameraFirmware'}, 0, 45 ) unless(ref( $tmp_root->{'CameraFirmware'} ));
$hrow{rehyb0}=substr( $tmp_root->{'Rehyb'}, 0, 45 ) unless(ref( $tmp_root->{'Rehyb'} ));
$hrow{autotiltonce}=1 if($tmp_root->{'AutoTiltOnce'}=~/^true$/ );
$hrow{autotiltonce}=0 if($tmp_root->{'AutoTiltOnce'}=~/^false$/ );
$hrow{rapidrunchemistry}=substr( $tmp_root->{'RapidRunChemistry'}, 0, 45 ) unless(ref( $tmp_root->{'RapidRunChemistry'} ));
$hrow{imageheight}=$tmp_root->{'ImageHeight'} if($tmp_root->{'ImageHeight'}=~/^\d+$/ );
$hrow{chemistryversion}=substr( $tmp_root->{'ChemistryVersion'}, 0, 45 ) unless(ref( $tmp_root->{'ChemistryVersion'} ));
$hrow{enableautocenter}=1 if($tmp_root->{'EnableAutoCenter'}=~/^true$/ );
$hrow{enableautocenter}=0 if($tmp_root->{'EnableAutoCenter'}=~/^false$/ );
$hrow{applicationname}=substr( $tmp_root->{'ApplicationName'}, 0, 45 ) unless(ref( $tmp_root->{'ApplicationName'} ));
$hrow{focusmethod}=substr( $tmp_root->{'FocusMethod'}, 0, 45 ) unless(ref( $tmp_root->{'FocusMethod'} ));
$hrow{rtaversion}=substr( $tmp_root->{'RTAVersion'}, 0, 45 ) unless(ref( $tmp_root->{'RTAVersion'} ));
$hrow{scannumber}=$tmp_root->{'ScanNumber'} if($tmp_root->{'ScanNumber'}=~/^\d+$/ );
$hrow{imagewidth}=$tmp_root->{'ImageWidth'} if($tmp_root->{'ImageWidth'}=~/^\d+$/ );
$hrow{enablebasecalling}=1 if($tmp_root->{'EnableBasecalling'}=~/^true$/ );
$hrow{enablebasecalling}=0 if($tmp_root->{'EnableBasecalling'}=~/^false$/ );
$hrow{supportmultiplesurfacesinui}=1 if($tmp_root->{'SupportMultipleSurfacesInUI'}=~/^true$/ );
$hrow{supportmultiplesurfacesinui}=0 if($tmp_root->{'SupportMultipleSurfacesInUI'}=~/^false$/ );
$hrow{enablelft}=1 if($tmp_root->{'EnableLft'}=~/^true$/ );
$hrow{enablelft}=0 if($tmp_root->{'EnableLft'}=~/^false$/ );
$hrow{runid1}=$tmp_root->{'BaseSpaceSettings'}->{'RunId'} if($tmp_root->{'BaseSpaceSettings'}->{'RunId'}=~/^\d+$/ );
$hrow{username1}=substr( $tmp_root->{'BaseSpaceSettings'}->{'Username'}, 0, 45 ) unless(ref( $tmp_root->{'BaseSpaceSettings'}->{'Username'} ));
$hrow{runmonitoringonly}=1 if($tmp_root->{'BaseSpaceSettings'}->{'RunMonitoringOnly'}=~/^true$/ );
$hrow{runmonitoringonly}=0 if($tmp_root->{'BaseSpaceSettings'}->{'RunMonitoringOnly'}=~/^false$/ );
$hrow{sendinstrumenthealthtoilmn}=1 if($tmp_root->{'BaseSpaceSettings'}->{'SendInstrumentHealthToILMN'}=~/^true$/ );
$hrow{sendinstrumenthealthtoilmn}=0 if($tmp_root->{'BaseSpaceSettings'}->{'SendInstrumentHealthToILMN'}=~/^false$/ );
$hrow{tempfolder0}=substr( $tmp_root->{'BaseSpaceSettings'}->{'TempFolder'}, 0, 254 ) unless(ref( $tmp_root->{'BaseSpaceSettings'}->{'TempFolder'} ));
$hrow{plannedrun}=1 if($tmp_root->{'BaseSpaceSettings'}->{'PlannedRun'}=~/^true$/ );
$hrow{plannedrun}=0 if($tmp_root->{'BaseSpaceSettings'}->{'PlannedRun'}=~/^false$/ );
$hrow{workflowtype}=substr( $tmp_root->{'WorkFlowType'}, 0, 45 ) unless(ref( $tmp_root->{'WorkFlowType'} ));
$hrow{barcode}=substr( $tmp_root->{'Barcode'}, 0, 45 ) unless(ref( $tmp_root->{'Barcode'} ));
$hrow{tileheight}=$tmp_root->{'TileHeight'} if($tmp_root->{'TileHeight'}=~/^\d+$/ );
$hrow{fpgaversion}=substr( $tmp_root->{'FPGAVersion'}, 0, 45 ) unless(ref( $tmp_root->{'FPGAVersion'} ));
$hrow{adapterplate}=substr( $tmp_root->{'AdapterPlate'}, 0, 45 ) unless(ref( $tmp_root->{'AdapterPlate'} ));
$hrow{pe0}=substr( $tmp_root->{'Pe'}, 0, 45 ) unless(ref( $tmp_root->{'Pe'} ));
$hrow{numswaths}=$tmp_root->{'NumSwaths'} if($tmp_root->{'NumSwaths'}=~/^\d+$/ );
$hrow{scannerid}=substr( $tmp_root->{'ScannerID'}, 0, 45 ) unless(ref( $tmp_root->{'ScannerID'} ));
$hrow{aligntophix}=substr( $tmp_root->{'AlignToPhiX'}, 0, 45 ) unless(ref( $tmp_root->{'AlignToPhiX'} ));
$hrow{scanid}=substr( $tmp_root->{'ScanID'}, 0, 45 ) unless(ref( $tmp_root->{'ScanID'} ));
$hrow{washbarcode}=substr( $tmp_root->{'WashBarcode'}, 0, 45 ) unless(ref( $tmp_root->{'WashBarcode'} ));
#
# simple fix. sorry, use only first array element
if( ref($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}) eq 'ARRAY' ) {
$hrow{isnew200cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew200Cycle'}=~/^true$/ );
$hrow{isnew200cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew200Cycle'}=~/^false$/ );
$hrow{id0}=substr( $tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'ID'}, 0, 45 ) unless(ref( $tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'ID'} ));
$hrow{isnew50cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew50Cycle'}=~/^true$/ );
$hrow{isnew50cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew50Cycle'}=~/^false$/ );
$hrow{numbercyclesremaining}=$tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'NumberCyclesRemaining'} if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'NumberCyclesRemaining'}=~/^\d+$/ );
$hrow{prime}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'Prime'}=~/^true$/ );
$hrow{prime}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'Prime'}=~/^false$/ );
$hrow{isnew500cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew500Cycle'}=~/^true$/ );
$hrow{isnew500cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->[0]->{'IsNew500Cycle'}=~/^false$/ );
} else {
$hrow{isnew200cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew200Cycle'}=~/^true$/ );
$hrow{isnew200cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew200Cycle'}=~/^false$/ );
$hrow{id0}=substr( $tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'ID'}, 0, 45 ) unless(ref( $tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'ID'} ));
$hrow{isnew50cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew50Cycle'}=~/^true$/ );
$hrow{isnew50cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew50Cycle'}=~/^false$/ );
$hrow{numbercyclesremaining}=$tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'NumberCyclesRemaining'} if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'NumberCyclesRemaining'}=~/^\d+$/ );
$hrow{prime}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'Prime'}=~/^true$/ );
$hrow{prime}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'Prime'}=~/^false$/ );
$hrow{isnew500cycle}=1 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew500Cycle'}=~/^true$/ );
$hrow{isnew500cycle}=0 if($tmp_root->{'ReagentKits'}->{'Sbs'}->{'SbsReagentKit'}->{'IsNew500Cycle'}=~/^false$/ );
}

$hrow{rehyb1}=substr( $tmp_root->{'Rehyb'}, 0, 45 ) unless(ref( $tmp_root->{'Rehyb'} ));
$hrow{pe1}=substr( $tmp_root->{'ReagentKits'}->{'Pe'}, 0, 45 ) unless(ref( $tmp_root->{'ReagentKits'}->{'Pe'} ));
$hrow{id1}=substr( $tmp_root->{'ReagentKits'}->{'ReagentKits'}->{'Index'}->{'ReagentKit'}->{'ID'}, 0, 45 ) unless(ref( $tmp_root->{'ReagentKits'}->{'ReagentKits'}->{'Index'}->{'ReagentKit'}->{'ID'} ));
$hrow{keepintensityfiles}=1 if($tmp_root->{'KeepIntensityFiles'}=~/^true$/ );
$hrow{keepintensityfiles}=0 if($tmp_root->{'KeepIntensityFiles'}=~/^false$/ );
$hrow{tilewidth}=$tmp_root->{'TileWidth'} if($tmp_root->{'TileWidth'}=~/^\d+$/ );
$hrow{sbs1}=substr( $tmp_root->{'ReagentBottles'}->{'Sbs'}, 0, 45 ) unless(ref( $tmp_root->{'ReagentBottles'}->{'Sbs'} ));
$hrow{useexistingrecipe}=1 if($tmp_root->{'UseExistingRecipe'}=~/^true$/ );
$hrow{useexistingrecipe}=0 if($tmp_root->{'UseExistingRecipe'}=~/^false$/ );
$hrow{runstartdate}=$tmp_root->{'RunStartDate'} if($tmp_root->{'RunStartDate'}=~/^\d+$/ );
$hrow{servicerun}=1 if($tmp_root->{'ServiceRun'}=~/^true$/ );
$hrow{servicerun}=0 if($tmp_root->{'ServiceRun'}=~/^false$/ );
$hrow{lanelength}=$tmp_root->{'LaneLength'} if($tmp_root->{'LaneLength'}=~/^\d+$/ );
$hrow{read2}=$tmp_root->{'Read2'} if($tmp_root->{'Read2'}=~/^\d+$/ );
$hrow{read_id}=GetNextSequence( $dbh ) ;
$hrow{select_id}=GetNextSequence( $dbh ) ;


my $read_id=$hrow{read_id};
my $select_id=$hrow{select_id};
	
my $table='runparameter';
my @Columns=qw(
adapterplate
aligntophix
applicationname
applicationversion
areaperpixelmm2
autotiltonce
barcode
cameradriver
camerafirmware
chemistryversion
clusteringchoice
compressbcls
computername
cpldversion
cvgainposlocked
cvgainstart
dithershift
dithersize
enableanalysis
enableautocenter
enablebasecalling
enablecameralogging
enablelft
enablenotifications
experimentname
fcposition
firstbaseconfirmation
flowcell
focuscamerafirmware
focusmethod
fpgaversion
groupsize
hotpixel
id0
id1
igain
ihistory
imageheight
imagewidth
index0
indexread1
indexread2
integrationmode
intensityceiling
isnew200cycle
isnew500cycle
isnew50cycle
keepintensityfiles
lanelength
maxinitialzjumphalfum
maxsubsequentzjumphalfum
mockrun
motordelayframes
numanalysisthreads
numbercyclesremaining
numberofinitialzjumps
numswaths
numtilesperswath
offset
outputfolder
pairendfc
pe0
pe1
performprerunfluidicscheck
periodicsave
plannedrun
prime
promptforpereagents
rapidrunchemistry
read1
read2
read_id
recipefragmentversion
rehyb0
rehyb1
remapqscores
resume
resumecycle
rtaversion
run_id
runid1
runmode
runmonitoringonly
runstartdate
samplesheet
sbs0
sbs1
scanid
scannedbarcode
scannerid
scannumber
selectedsurface
select_id
sendinstrumenthealthtoilmn
servicerun
slideholder
softwarelaserlag
supportmultiplesurfacesinui
swathscanmode
tempfolder0
tempfolder1
templatecyclecount
tileheight
tilewidth
useexistingrecipe
username0
username1
washbarcode
workflowtype

);


	foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
	}
	
	my $sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
	unless( InsertRecord( $dbh, $sql, \@rows ) ) {
		return 0;
	}


	# insert read records
	undef( $hrow);
	$table='readtable';
	@Columns=qw( number0 numcycles isindexedread read_id ) ;
	$sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
					
	# usualy field 'read' - is array, but in case one value, we make array from it
	$tmp_root->{'Reads'}->{'Read'}=( $tmp_root->{'Reads'}->{'Read'} ) if( ref( $tmp_root->{'Reads'}->{'Read'} ) ne 'ARRAY' ); 
	foreach $read ( @{ $tmp_root->{'Reads'}->{'Read'} } ) {
		my %hrow;
		my @rows;
		#print Dumper( $read );
		$hrow{isindexedread}=$read->{'IsIndexedRead'} if( $read->{'IsIndexedRead'} =~ /^(Y|N)$/i ) ;	
		$hrow{numcycles}=$read->{'NumCycles'}  if( $read->{'NumCycles'}=~/^\d+$/ );	
		$hrow{number0}=$read->{'Number'} if($read->{'Number'}=~/^\d+$/ );	
		$hrow{read_id}=$read_id ;
		foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
		}		
		unless( InsertRecord( $dbh, $sql, \@rows ) ) {
			return 0;
		}				
	}	

	# insert SelectedSections records
	undef( $hrow);
	$table='selecttable';
	@Columns=qw( name select_id ) ;
	$sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
					
	# usualy field 'select' - is array, but in case one value, we make array from it
	my $tmp_root2=$tmp_root->{'SelectedSections'}->{'Section'};
	$tmp_root2=( $tmp_root2 ) if( ref( $tmp_root2 ) ne 'ARRAY' ); 
	foreach $select ( @{ $tmp_root2 } ) {
		my %hrow;
		my @rows;
		#print Dumper( $tmp_root2 );
		$hrow{name}=substr( $select->{'Name'}, 0, 45 ) ;
		$hrow{select_id}=$select_id ;
		foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
		}		
		unless( InsertRecord( $dbh, $sql, \@rows ) ) {
			return 0;
		}				
	}
	return 1;

}



sub parse_SampleSheet {
	my $filename=shift;
	my $dbh=shift;
	my $runId=shift;
	my @Rows;
	my $csv = Text::CSV->new ( { binary => 1 } ) ;  # should set binary attribute.
	unless( $csv ) {
		w2log "Cannot use CSV: ".Text::CSV->error_diag ();
		return 0;
	}


	my $fh;
#	unless( open(  $fh, "<:encoding(utf8)", $filename ) ) {
	unless( open(  $fh, "<", $filename ) ) {
		w2log( "$filename: $!" );
		return 0;
	}
	
	my $found_data_section=0;
	while ( my $row = $csv->getline( $fh ) ) {
		if( $row->[0]=~/^\[Data\]$/ )  {
			$found_data_section=1 ;
			next;
		}
		next unless( $found_data_section );		
		push @Rows, $row;
	}
	$csv->eof or $csv->error_diag();
	close $fh;


	my $sql;
	my $table='samplesheet';
	my @Columns=qw( run_id lane sample_id sample_name sample_plate sample_well i7_index_id index0 sample_project description  ) ;
	
	shift @Rows; # remove columns names 
	$sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";						
	foreach $row ( @Rows ) {
		my %hrow;
$hrow{run_id}=$runId;
$hrow{lane}=$row->[0] if( $row->[0] =~/^\d+$/ );
$hrow{sample_id}=substr( $row->[1], 0, 45 ) ;
$hrow{sample_name}=substr( $row->[2], 0, 45 ) ;
$hrow{sample_plate}=substr( $row->[3], 0, 45 ) ;
$hrow{sample_well}=substr( $row->[4], 0, 45 ) ;
$hrow{i7_index_id}=substr( $row->[5], 0, 45 ) ;
$hrow{index0}=substr( $row->[6], 0, 45 ) ;
$hrow{sample_project}=substr( $row->[7], 0, 45 ) ;
$hrow{description}=substr( $row->[8], 0, 45 ) ;

	my @irow=();
	foreach my $key( @Columns ) {
			push( @irow, $hrow{$key} );
	}
		unless( InsertRecord( $dbh, $sql, \@irow ) ) {
			return 0;
		}
	}
	return 1;
}



sub parse_RunInfo {
	my $filename=shift;
	my $dbh=shift;
	my $runId=shift;
	my $xml=ReadXml( $filename );
	#return 1;
	my $tmp_root=$xml->{'RunInfo'}->{'Run'};
	my %hrow;

	#print Dumper( $tmp_root );


$hrow{run_id}=$runId ;
$hrow{flowcell}=substr( $tmp_root->{'Flowcell'}, 0, 45 ) ;
$hrow{instrument}=substr( $tmp_root->{'Instrument'}, 0, 45 ) ;
$hrow{lanecount}=$tmp_root->{'FlowcellLayout'}->{'LaneCount'} if($tmp_root->{'FlowcellLayout'}->{'LaneCount'}=~/^\d+$/ );
$hrow{swathcount}=$tmp_root->{'FlowcellLayout'}->{'SwathCount'} if($tmp_root->{'FlowcellLayout'}->{'SwathCount'}=~/^\d+$/ );
$hrow{surfacecount}=$tmp_root->{'FlowcellLayout'}->{'SurfaceCount'} if($tmp_root->{'FlowcellLayout'}->{'SurfaceCount'}=~/^\d+$/ );
$hrow{tilecount}=$tmp_root->{'FlowcellLayout'}->{'TileCount'} if($tmp_root->{'FlowcellLayout'}->{'TileCount'}=~/^\d+$/ );
$hrow{date0}=$tmp_root->{'Date'} if($tmp_root->{'Date'}=~/^\d{6}$/ );
$hrow{number0}=$tmp_root->{'Number'} if($tmp_root->{'Number'}=~/^\d+$/ );
$hrow{read_id}=GetNextSequence( $dbh ) ;	

	#print Dumper( %hrow,  );
	#return 1;	

	#print Dumper( $tmp_root->{'FlowcellLayout'}->{'SwathCount'} );
	
	#print Dumper( $hrow );
	my $read_id=$hrow{read_id};

	my @rows=();
	my $table='runinfo';
	my @Columns=qw( swathcount number0 flowcell instrument run_id date0 read_id lanecount tilecount surfacecount  ) ;
	foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
	}
	
	my $sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
	unless( InsertRecord( $dbh, $sql, \@rows ) ) {
		return 0;
	}

	undef( %hrow);
	$table='readtable';
	@Columns=qw( number0 numcycles isindexedread read_id ) ;
	$sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
					
	# usualy field 'read' - is array, but in case one value, we make array from it
	$tmp_root->{'Reads'}->{'Read'}=( $tmp_root->{'Reads'}->{'Read'} ) if( ref( $tmp_root->{'Reads'}->{'Read'} ) ne 'ARRAY' ); 
	foreach $read ( @{ $tmp_root->{'Reads'}->{'Read'} } ) {
		my %hrow;
		my @rows;
		$hrow{isindexedread}=$read->{'IsIndexedRead'} if( $read->{'IsIndexedRead'} =~ /^(Y|N)$/i ) ;	
		$hrow{numcycles}=$read->{'NumCycles'}  if($read->{'NumCycles'}=~/^\d+$/ );;	
		$hrow{number0}=$read->{'Number'} if($read->{'Number'}=~/^\d+$/ );;	
		$hrow{read_id}=$read_id ;
		foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
		}		
		unless( InsertRecord( $dbh, $sql, \@rows ) ) {
			return 0;
		}				
	}	
	return 1;

}


sub parse_First_Base_Report {
	my $filename=shift;
	my $dbh=shift;
	my $runId=shift;

	my $html=ReadFile( $filename );
	my $parser = HTML::TokeParser->new(\$html);

my $result='';
while (my $token = $parser->get_token) {
	#print Dumper( $token );
	$result .="$token->[1]#" if( $token->[0] =~'T');
}  
  	
#print $result;
#$result=~/#Top Surface#\s+#\s+(.+\w#\s+)#\s+.+
#$result=~/#Bottom Surface#\s+#\s+(.+\w#\s+)#\s+/sg;
$result=~/#Top Surface#\s+#\s+(.+\w#\s+)#\s+.+#Bottom Surface#\s+#\s+(.+\w#\s+)#\s+/sg;
#print "!\n\n$1\n\n$2";
my @top=split( /\n/, $1 );
my @bottom=split( /\n/, $2 );


my %hrow;
$hrow{top_id}=GetNextSequence( $dbh ) ;
$hrow{bottom_id}=GetNextSequence( $dbh ) ;
$hrow{run_id}=$runId ;

my $top_id=$hrow{top_id};
my $bottom_id=$hrow{bottom_id};

	my @rows=();
	my $table='first_base_report';
	my @Columns=qw( top_id bottom_id run_id ) ;
	foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
	}
	
	my $sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
	unless( InsertRecord( $dbh, $sql, \@rows ) ) {
		return 0;
	}

	undef( %hrow);
unless( parse_surface ( $dbh, \@top, $top_id ) ) {
	return 0;
}

unless( parse_surface ( $dbh, \@bottom, $bottom_id )) {
	return 0;
}

	return 1;
}


sub parse_surface {
	my $dbh=shift;
	my $surface_array=shift;
	my $surface_id=shift;
	shift @{ $surface_array };
	foreach my $line ( @{ $surface_array } ){
		$line=~s/^#//;
		$line=~s/#$//;
		my @Fields=split( /#/, $line );
		my @Columns=qw( metric lane1 lane2 lane3 lane4 lane5 lane6 lane7 lane8 surface_id id ) ;
		my %hrow;
$hrow{metric}=substr( @Fields[0] , 0, 45 ) ;
$hrow{lane1}=@Fields[1] if( @Fields[1]=~/^\d*\.?\d*$/ ) ;
$hrow{lane2}=@Fields[2] if( @Fields[2]=~/^\d*\.?\d*$/ ) ;
$hrow{lane3}=@Fields[3] if( @Fields[3]=~/^\d*\.?\d*$/ ) ;
$hrow{lane4}=@Fields[4] if( @Fields[4]=~/^\d*\.?\d*$/ ) ;
$hrow{lane5}=@Fields[5] if( @Fields[5]=~/^\d*\.?\d*$/ ) ;
$hrow{lane6}=@Fields[6] if( @Fields[6]=~/^\d*\.?\d*$/ ) ;
$hrow{lane7}=@Fields[7] if( @Fields[7]=~/^\d*\.?\d*$/ ) ;
$hrow{lane8}=@Fields[8] if( @Fields[8]=~/^\d*\.?\d*$/ ) ;
$hrow{lane1}=@Fields[1] if( @Fields[1]=~/^\d*\.?\d*$/ ) ;
$hrow{surface_id}=$surface_id;
$hrow{id}=GetNextSequence( $dbh ) ;

		my @rows=();
		my $table='surface';
		foreach $key( @Columns ) {
			push( @rows, $hrow{$key} );
		}
	
		my $sql="INSERT into $table
					( ". join(',', @Columns  ) ." )
					values 
					( ".join( ',', map{ '?' } @Columns )." ) ;";	
		unless( InsertRecord( $dbh, $sql, \@rows ) ) {
			return 0;
		}	
	}
return 1;	
}



sub parse_runfolder {
	my $dbh=shift;
	my $id=shift;

# inser new folder name(run_id) into table 

	my $table='runfolder';
	my @Columns=qw( dt run_id );

	$sql="INSERT into $table
				( ". join(',', @Columns  ) ." )
				values 
				( ".join( ',', map{ '?' } @Columns )." ) ;" ;	
	my $row;
	push( @{$row}, get_date( ) );
	push( @{$row}, $id );
	
	return ( InsertRecord( $dbh, $sql, $row ) );
return 1;	
}



1;


