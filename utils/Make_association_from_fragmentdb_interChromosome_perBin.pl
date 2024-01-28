#!/usr/bin/perl
# 2017/10/04 Calculate total reads for inter-chromosome contact at bin level

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

use DBI;

if((@ARGV != 6 and @ARGV != 8) or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files xxx_fragment.db] -o [output prefix] -r [resolution] -b [black list of fragment]\n";
}

my %opt;
getopts("i:o:r:b:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out_prefix = $opt{o};
my $Resolution = $opt{r};
my $FILE_black = $opt{b};


# Variable to contain all data
my %data;


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


my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");

#---------------------------------------
# Get chromosome list
#---------------------------------------
my @chromosomes;
my $sth_getChr = $dbh->prepare("select distinct(chr1) from fragment");
$sth_getChr->execute();
while(my ($c) = $sth_getChr->fetchrow_array()){
	push @chromosomes, $c;
}
$sth_getChr->finish();


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
# Get inter-chromosome data
my $sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment where chr1!=chr2;");
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

	my $bin1a = int($start1/$Resolution) * $Resolution;
	my $bin1b = int($end1/$Resolution) * $Resolution;
	my $bin2a = int($start2/$Resolution) * $Resolution;
	my $bin2b = int($end2/$Resolution) * $Resolution;

	my $id1a = $chr1 . ":" . $bin1a;
	my $id1b = $chr1 . ":" . $bin1b;
	my $id2a = $chr2 . ":" . $bin2a;
	my $id2b = $chr2 . ":" . $bin2b;


	# Distribute score evenly to the 4 combinations
	$score = $score / 4;

	# count data
	$data{$id1a} += $score;
	$data{$id1b} += $score;
	$data{$id2a} += $score;
	$data{$id2b} += $score;
}
$sth_data->finish();
$dbh->disconnect();



#---------------------------------------
# output
#---------------------------------------
foreach my $chr(@chromosomes){
	my $FILE_out = $FILE_out_prefix . $chr . ".txt";
	my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";

	# register bins
	for(my $i = 0; $i < $MAX_chr{$chr}; $i += $Resolution){
		my $bin = "$chr:$i";
		my $value = exists $data{$bin} ? $data{$bin} : 0;
		$fh_out->printf("$chr:$i:%d\t$value\n", $i + $Resolution - 1);
	}
	$fh_out->close();
}


