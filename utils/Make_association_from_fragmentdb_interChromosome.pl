#!/usr/bin/perl
# 2017/08/02 Finding inter-chromsoome interaction count

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

use DBI;

if($ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files] -o [output file] -b [black list of fragment]\n";
}

my %opt;
getopts("i:o:b:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out = $opt{o};
my $FILE_black = $opt{b};

# Variable to contain all data
my %data;

my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");


#---------------------------------------
# Get chromosome list
#---------------------------------------
my @chromosomes_list;
my $sth_getChr = $dbh->prepare("select distinct(chr1) from fragment");
$sth_getChr->execute();
while(my ($c) = $sth_getChr->fetchrow_array()){
	push @chromosomes_list, $c;
}
$sth_getChr->finish();
my @chromosomes = sort { &ChromosomeNum($a) <=> &ChromosomeNum($b) } @chromosomes_list;

sub ChromosomeNum{
	my ($chr) = @_;
	my $num = 0;
	if($chr =~ m/chr(\w+)/){
		$num = $1;
	}
	if($num eq 'X'){
		$num = 23;
	}
	if($num eq 'Y'){
		$num = 24;
	}
	if($num eq 'M'){
		$num = 25;
	}
	if($chr eq 'I'){
		$num = 1;
	}
	if($chr eq 'II'){
		$num = 2;
	}
	if($chr eq 'III'){
		$num = 3;
	}
	return $num;
}


#---------------------------------------
# Read fragment blacklist
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

#---------------------------------------
# collect information
#---------------------------------------
# Get data
my $sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment;");
$sth_data->execute();
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;

	# Skip fragments in blacklist
	if(exists $Black{"$chr1\t$frag1"}){
		next;
	}
	if(exists $Black{"$chr2\t$frag2"}){
		next;
	}
	
	if($chr1 eq $chr2){
		# Avoid counting adjacent fragments
		if(abs($frag1 - $frag2) < 2){
			next;
		}
		my $middle1 = ($start1 + $end1) / 2;
		my $middle2 = ($start2 + $end2) / 2;
		my $distance = abs($middle1 - $middle2);
	
		# Double scoring if within 10kb
		# since only same-direction reads are present within this distance
		if($distance < 10000){
			$score = $score * 2;
		}
		$data{"$chr1\t$chr2"} += $score;
	}else{
		$data{"$chr1\t$chr2"} += $score;
		$data{"$chr2\t$chr1"} += $score;
	}
}
$sth_data->finish();
$dbh->disconnect();


#---------------------------------------
# output
#---------------------------------------
my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";


foreach my $chr(@chromosomes){
	$fh_out->printf("\t$chr");
}
$fh_out->print("\n");


for(my $i = 0; $i < @chromosomes; $i++){
	my @values;
	my $chr1 = $chromosomes[$i];
	for(my $j = 0; $j < @chromosomes; $j++){
		my $chr2 = $chromosomes[$j];
		my $val = 0;
		if($i < $j){
			$val = exists $data{"$chr1\t$chr2"} ? $data{"$chr1\t$chr2"} : 0;
		}else{
			$val = exists $data{"$chr2\t$chr1"} ? $data{"$chr2\t$chr1"} : 0;
		}
		push @values, $val;
	}
	$fh_out->printf("$chr1\t");
	$fh_out->print(join("\t", @values) . "\n");
}
$fh_out->close();


