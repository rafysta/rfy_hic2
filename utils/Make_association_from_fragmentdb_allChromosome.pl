#!/usr/bin/perl
# 2015/07/02 Edits at reading filtered db
# 2015/03/28 Read data from db file and create interaction file

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

use DBI;

if((@ARGV != 10 and @ARGV != 12) or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files] -o [output file prefix] -r [resolution] -b [black list of fragment] -c [chromosome list] -t [threshod of different direction read cut-off]\n";
}

my %opt;
getopts("i:o:r:b:c:t:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out_prefix = $opt{o};
my $Resolution = $opt{r};
my $FILE_black = $opt{b};
my $THRESHOLD_SELF = $opt{t};
my @chromosomes = split /,/, $opt{c};

# Variable to contain all data
my %data;


#---------------------------------------
# Read fragment blacklist
#---------------------------------------
my %Black;
if(defined $FILE_black){
	my $fh_in = IO::File->new($FILE_black ) or die "cannot open $FILE_black: $!";
	while($_ = $fh_in->getline()){
		s/\r?\n//;
		my ($chr, $fragID) = split /\t/;
		$Black{"$chr\t$fragID"} = 1;
	}
	$fh_in->close();
}


my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");


#---------------------------------------
# check max length
#---------------------------------------
my %MAX_chr;
my $sth_maxCheck1 = $dbh->prepare("select max(end1) from fragment where chr1=?");
my $sth_maxCheck2 = $dbh->prepare("select max(end2) from fragment where chr2=?");
foreach my $chr(@chromosomes){
	$sth_maxCheck1->execute($chr);
	my ($m1) = $sth_maxCheck1->fetchrow_array();
	$sth_maxCheck2->execute($chr);
	my ($m2) = $sth_maxCheck2->fetchrow_array();
	$MAX_chr{$chr} = $m1 < $m2 ? $m2 : $m1;
}
$sth_maxCheck1->finish();
$sth_maxCheck2->finish();


#---------------------------------------
# collect information
#---------------------------------------
my $sth_data;

$sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment;");
$sth_data->execute();
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;

	# Avoid counting adjacent fragment
	# if($chr1 eq $chr2 and abs($frag1 - $frag2) < 2){
	# 	next;
	# }

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

	# Double scoring if within the distance of self-ligation (10kb by default)
	# Since there are only same direction data
	if($chr1 eq $chr2 and $distance < $THRESHOLD_SELF){
		$score = $score * 2;
	}

	my $bin1a = int($start1/$Resolution) * $Resolution;
	my $bin1b = int($end1/$Resolution) * $Resolution;
	my $bin2a = int($start2/$Resolution) * $Resolution;
	my $bin2b = int($end2/$Resolution) * $Resolution;

	my $id1a = $chr1 . ":" . $bin1a;
	my $id1b = $chr1 . ":" . $bin1b;
	my $id2a = $chr2 . ":" . $bin2a;
	my $id2b = $chr2 . ":" . $bin2b;


	# Evenly distribute score to the 4 combinations
	$score = $score / 4;

	# count data (confirmed that left is smaller)
	$data{$id1a}{$id2a} += $score;
	$data{$id1a}{$id2b} += $score;
	$data{$id1b}{$id2a} += $score;
	$data{$id1b}{$id2b} += $score;

}
$sth_data->finish();
$dbh->disconnect();



#---------------------------------------
# output
#---------------------------------------
my $FILE_out = $FILE_out_prefix . "ALL.matrix";
my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";

# register bins
my @bins;
foreach my $chr(@chromosomes){
	for(my $i = 0; $i < $MAX_chr{$chr}; $i += $Resolution){
		push @bins, "$chr:$i";
		$fh_out->printf("\t$chr:$i:%d", $i + $Resolution - 1);
	}
}
$fh_out->print("\n");


for(my $i = 0; $i < @bins; $i++){
	my @values;
	for(my $j = 0; $j < @bins; $j++){
		if($i < $j){
			my $value = exists $data{$bins[$i]}{$bins[$j]} ? $data{$bins[$i]}{$bins[$j]} : 0;
			push @values, $value;
		}else{
			my $value = exists $data{$bins[$j]}{$bins[$i]} ? $data{$bins[$j]}{$bins[$i]} : 0;
			push @values, $value;
		}
	}
	my ($c, $m) = split /:/, $bins[$i];
	$fh_out->printf("%s:%d\t", $bins[$i], $m + $Resolution - 1);
	$fh_out->print(join("\t", @values) . "\n");
}
$fh_out->close();


