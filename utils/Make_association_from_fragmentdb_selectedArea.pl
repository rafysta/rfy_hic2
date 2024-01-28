#!/usr/bin/perl
# Create matrix from selected area from fragmentdb

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

use DBI;

if($ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files] -o [output matrix] -r [resolution] -b [black list of fragment] -c [chr] -s [start] -e [end]\n";
}

my %opt;
getopts("i:o:r:b:c:s:e:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out = $opt{o};
my $Resolution = $opt{r};
my $FILE_black = $opt{b};
my $CHR = $opt{c};
my $START = $opt{s};
my $END = $opt{e};



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

# Read intra-chromosome data
$sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment where chr1==chr2 and chr1==\"${CHR}\" and start1 < $END and end2 > $START;");
$sth_data->execute();
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;

	# Avoid counting adjacent fragments
	if(abs($frag1 - $frag2) < 2){
		next;
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

	# Double score if within 10kb distance
	# Since only same-direction reads are present within this distance
	if($distance < 10000){
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


	# Evenly distribute the score to the 4 combinations
	$score = $score / 4;


	# count data（confirmed that left is smaller)
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
my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";

# register bins
my @bins;
for(my $i = int($START/$Resolution) * $Resolution; $i < int($END/$Resolution) * $Resolution; $i += $Resolution){
	push @bins, "$CHR:$i";
	$fh_out->printf("\t$CHR:$i:%d", $i + $Resolution - 1);
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



