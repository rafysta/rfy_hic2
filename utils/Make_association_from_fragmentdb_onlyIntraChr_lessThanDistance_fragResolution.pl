#!/usr/bin/perl
# 2015/07/02 Edits at reading filtered db
# 2015/03/28 Read data from db file and create interaction file
# 2020-03-03 Results within a certain distance is output as data.frame instead of matrix
# 2021-04-14 Total for above a certain distance is output in 1-dimension. Introduced cut-off for different direction reads. Also handles single fragment resolution
# 2021-07-25 Handle multiple fragment resolution

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

use DBI;

if((@ARGV != 12 and @ARGV != 14 and @ARGV != 16) or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files] -o [output file name] -r [resolution. fragment number] -c [target single chromosome] -b [black list of fragment] -m [maximum distance] -t [different direction reads cut-off threshold]\n";
}

my %opt;
getopts("i:o:r:c:b:m:t:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out = $opt{o};
my $CHROMOSOME = $opt{c};
my $Resolution = $opt{r};
my $FILE_black = $opt{b};
my $MAX_DISTANCE = $opt{m};
my $THRESHOLD_SELF = $opt{t};
unless(defined $THRESHOLD_SELF){
	$THRESHOLD_SELF = 10000;
}

# Variable to contain all data
my %data;

#---------------------------------------
# Read fragement blacklist
#---------------------------------------
my %Black;
if(defined $FILE_black){
	my $fh_in = IO::File->new($FILE_black ) or die "cannot open $FILE_black: $!";
	$fh_in->getline();
	while($_ = $fh_in->getline()){
		s/\r?\n//;
		my ($chr, $fragID) = split /\t/;
		$Black{"$chr\t$fragID"} = 1;
	}
	$fh_in->close();
}


my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");


#---------------------------------------
# collect information
#---------------------------------------
my $sth_data;
my %id_info;

$sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment where chr1=='$CHROMOSOME' or chr2=='$CHROMOSOME';");
$sth_data->execute();
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;

	if($chr1 eq $chr2 and $start1 > $start2){
		($start1, $end1, $frag1, $start2, $end2, $frag2) = ($start2, $end2, $frag2, $start1, $end1, $frag1);
	}

	# Skip fragments in blacklist
	if(exists $Black{"$chr1\t$frag1"}){
		next;
	}
	if(exists $Black{"$chr2\t$frag2"}){
		next;
	}

	my $middle1 = ($start1 + $end1) / 2;
	my $middle2 = ($start2 + $end2) / 2;
	my $distance = abs($middle1 - $middle2);

	# Combinations farther away than max distance
	my $FLAG_longDistance = 0;
	if($distance > $MAX_DISTANCE or $chr1 ne $chr2){
		$FLAG_longDistance = 1;
	}

	# Double score if within THRESHOLD_SELF distance
	# Since only same-direction reads are present within this distance
	if($chr1 eq $chr2 and $distance < $THRESHOLD_SELF){
		$score = $score * 2;
	}

	my $bin1 = int($frag1/$Resolution) * $Resolution;
	my $bin2 = int($frag2/$Resolution) * $Resolution;
	my $id1 = $chr1 . ":" . $bin1;
	my $id2 = $chr2 . ":" . $bin2;

	# count data（confirmed that left is smaller)
	if($FLAG_longDistance == 0){
		$data{"$id1\t$id2"} += $score;
	}else{
		if($chr1 eq $CHROMOSOME){
			$data{"$id1\tlong_distance"} += $score;
		}
		if($chr2 eq $CHROMOSOME){
			$data{"$id2\tlong_distance"} += $score;
		}
	}

	# id information
	if(exists $id_info{$id1}{'start'}){
		if($start1 < $id_info{$id1}{'start'}){
			$id_info{$id1}{'start'} = $start1;
		}
	}else{
		$id_info{$id1}{'start'} = $start1;
	}
	if(exists $id_info{$id2}{'start'}){
		if($start2 < $id_info{$id2}{'start'}){
			$id_info{$id2}{'start'} = $start2;
		}
	}else{
		$id_info{$id2}{'start'} = $start2;
	}
	
	if(exists $id_info{$id1}{'end'}){
		if($end1 > $id_info{$id1}{'end'}){
			$id_info{$id1}{'end'} = $end1;
		}
	}else{
		$id_info{$id1}{'end'} = $end1;
	}
	if(exists $id_info{$id2}{'end'}){
		if($end2 > $id_info{$id2}{'end'}){
			$id_info{$id2}{'end'} = $end2;
		}
	}else{
		$id_info{$id2}{'end'} = $end2;
	}
}
$sth_data->finish();
$dbh->disconnect();



#---------------------------------------
# output
#---------------------------------------
my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";
$fh_out->print("loc1\tloc2\tscore\n");
foreach my $key(keys %data){
	my ($id1, $id2) = split /\t/, $key;
	my ($chr1, $bin1) = split /:/, $id1;
	my $start1 = $id_info{$id1}{'start'};
	my $end1 = $id_info{$id1}{'end'};
	my $loc1 = $chr1 . ":" . $start1 . ":" . $end1;

	my $loc2;
	if($id2 eq 'long_distance'){
		$loc2 = 'long_distance';
	}else{
		my ($chr2, $bin2) = split /:/, $id2;
		my $start2 = $id_info{$id2}{'start'};
		my $end2 = $id_info{$id2}{'end'};
		$loc2 = $chr2 . ":" . $start2 . ":" . $end2;
	}

	$fh_out->printf("%s\t%s\t%.2f\n", $loc1, $loc2, $data{$key});
}

$fh_out->close();



