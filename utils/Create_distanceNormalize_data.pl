#!/usr/bin/perl

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);
$| = 0;

use DBI;

# Chromosome length - distance　= Possible combinations for each length
# By calculating the total for each read length, and divided by the total read length
# distance curve that shows the contact probability between 2 points is oobtained

if(@ARGV != 6 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [fragment.db] -o [output file] -l [file of chromosome length]\n";
}

my %opt;
getopts("i:o:l:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out = $opt{o};
my $FILE_LENGTH = $opt{l};

#---------------------------------------
# read chromosome length
#---------------------------------------
my %LEN;
my $fh_length = IO::File->new($FILE_LENGTH) or die "cannot open $FILE_LENGTH: $!";
while($_ = $fh_length->getline()){
	s/\r?\n//;
	my ($chr, $len) = split /\t/;
	$LEN{$chr} = $len;
}
$fh_length->close();

my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";
$fh_out->print(join("\t", "chromosome1", "chromosome2", "distance", "reads", "average", "probability") . "\n");
my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");

#---------------------------------------
# Get chromosome list
#---------------------------------------
my @chrs;
my $sth_getChr = $dbh->prepare("select distinct(chr1) from fragment");
$sth_getChr->execute();
while(my ($c) = $sth_getChr->fetchrow_array()){
	if(exists $LEN{$c}){
		push @chrs, $c;
	}
}
$sth_getChr->finish();


#---------------------------------------
# Calculate total reads
#---------------------------------------
my $TOTAL_reads = 0;
foreach my $chr(@chrs){
	my $sth_intra = $dbh->prepare("select start1, end1, fragNum1, start2, end2, fragNum2, score from fragment where chr1='$chr' and chr2='$chr';");
	$sth_intra->execute();
	while(my $ref = $sth_intra->fetchrow_arrayref()){
		my ($start1, $end1, $frag1, $start2, $end2,  $frag2, $score) = @$ref;

		# Avoid counting adjacent fragments
		if(abs($frag1 - $frag2) < 2){
			next;
		}

		# Double scoring for distance below 10kb
		if(abs($start1 + $end1 - $start2 - $end2)/2 < 10000){
			$score *= 2;
		}

		$TOTAL_reads += $score;
	}
	$sth_intra->finish();
}
for(my $i = 0; $i < @chrs; $i++){
	my $chr1 = $chrs[$i];
	for(my $j = $i + 1; $j < @chrs; $j++){
		my $chr2 = $chrs[$j];

		my $sth_total = $dbh->prepare("select sum(score) from fragment where (chr1='$chr1' and chr2='$chr2') or (chr1='$chr2' and chr2='$chr1');");
		$sth_total->execute();
		my ($SUM) = $sth_total->fetchrow_array();
		unless(defined $SUM){
			$SUM = 0;
		}
		$TOTAL_reads += $SUM;
	}
}



#---------------------------------------
# Calculate distance curve
#---------------------------------------
foreach my $chr(@chrs){
	my $sth_data = $dbh->prepare("select start1, end1, fragNum1, start2, end2, fragNum2, score from fragment where chr1='$chr' and chr2='$chr';");
	$sth_data->execute();

	my %Data;
	while(my $ref = $sth_data->fetchrow_arrayref()){
		my ($start1, $end1, $frag1, $start2, $end2,  $frag2, $score) = @$ref;

		# Avoid counting adjacent fragments
		if(abs($frag1 - $frag2) < 2){
			next;
		}

		# Double scoring for distance below 10kb
		if(abs($start1 + $end1 - $start2 - $end2)/2 < 10000){
			$score *= 2;
		}

		my $distance1 = abs($start1 - $start2);
		my $distance2 = abs($start1 - $end2);
		my $distance3 = abs($end1 - $start2);
		my $distance4 = abs($end1 - $end2);

		$distance1 = int($distance1 / 100) * 100 + 50;
		$distance2 = int($distance2 / 100) * 100 + 50;
		$distance3 = int($distance3 / 100) * 100 + 50;
		$distance4 = int($distance4 / 100) * 100 + 50;

		$Data{$distance1} += $score / 4;
		$Data{$distance2} += $score / 4;
		$Data{$distance3} += $score / 4;
		$Data{$distance4} += $score / 4;
	}
	$sth_data->finish();

	### Calculate log distance
	my %Num;
	my %Sum;
	foreach my $d(keys %Data){
		if($d < 50000){
			my $logDistance = $d;
			$Sum{$logDistance} += $Data{$d} / ($LEN{$chr} - $d) * 100;
			$Num{$logDistance}++;
		}else{
			my $logDistance = exp(sprintf("%.3f", log($d)));
			$Sum{$logDistance} += $Data{$d} / ($LEN{$chr} - $d) * 100;
			$Num{$logDistance}++;
		}
	}

	### Output results
	foreach my $d(sort {$a <=> $b} keys %Sum){
		$fh_out->printf("%s\t%s\t%d\t%.3e\t%.3e\t%.3e\n", $chr, $chr, $d, $Sum{$d}, $Sum{$d} / $Num{$d}, $Sum{$d} / $Num{$d} / $TOTAL_reads);
	}
}


for(my $i = 0; $i < @chrs; $i++){
	my $chr1 = $chrs[$i];
	for(my $j = $i + 1; $j < @chrs; $j++){
		my $chr2 = $chrs[$j];

		my $sth_total = $dbh->prepare("select sum(score) from fragment where (chr1='$chr1' and chr2='$chr2') or (chr1='$chr2' and chr2='$chr1');");
		$sth_total->execute();

		my ($SUM) = $sth_total->fetchrow_array();
		unless(defined $SUM){
			$SUM = 0;
		}
		
		my $average = $SUM / ($LEN{$chr1} * $LEN{$chr2}) * 10000;


		$fh_out->printf("%s\t%s\t%d\t%.3e\t%.3e\t%.3e\n", $chr1, $chr2, -1, $SUM, $average, $average / $TOTAL_reads);
		$fh_out->printf("%s\t%s\t%d\t%.3e\t%.3e\t%.3e\n", $chr2, $chr1, -1, $SUM, $average, $average / $TOTAL_reads);
	}
}
$dbh->disconnect();
$fh_out->close();
