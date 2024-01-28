#!/usr/bin/perl
# 2015/06/16 split into 100 files for sorting

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;

if(@ARGV != 6 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [map file] -l [chromosome length] -o [file list]\n";
}

my %opt;
getopts("i:l:o:", \%opt);
my $FILE_map = $opt{i};
my $CHROMOSOME_LENGTH = $opt{l};
my $FILE_list = $opt{o};
my ($name, $dir, $ext) = &fileparse($FILE_map, '\..*');
my $TMP_PREFIX = $dir . 'tmp_register_' . $name;


# Resolution for file to create
my $RESOLUTION = $CHROMOSOME_LENGTH / 100;

# File handle
my %FH;
my %NAMES;

#---------------------------------------
# read file and split and save
#---------------------------------------
my $TOTAL_READ_NUMBER = 0;
my $fh_map = IO::File->new($FILE_map) or die "cannot open $FILE_map: $!";
while($_ = $fh_map->getline()){
	s/\r?\n//;
	my ($id, $chr1, $loc1, $direction1, $mapQ1, $resID1, $resLoc1, $uniq1, $chr2, $loc2, $direction2, $mapQ2, $resID2, $resLoc2, $uniq2) = split /\t/;
	if($resID1 eq 'NA' or $resID2 eq 'NA'){
		next;
	}

	# Compare left and right and unify as smaller on the left 
	if($chr1 eq $chr2){
		if($loc1 > $loc2){
			($loc2, $loc1) = ($loc1, $loc2);
			($direction2, $direction1) = ($direction1, $direction2);
			($mapQ2, $mapQ1) = ($mapQ1, $mapQ2);
			($resID2, $resID1) = ($resID1, $resID2);
			($resLoc2, $resLoc1) = ($resLoc1, $resLoc2);
			($uniq2, $uniq1) = ($uniq1, $uniq2);
		}
	}else{
		if(&ComparisonChr($chr1, $chr2) == 1){
			($chr2, $chr1) = ($chr1, $chr2);
			($loc2, $loc1) = ($loc1, $loc2);
			($direction2, $direction1) = ($direction1, $direction2);
			($mapQ2, $mapQ1) = ($mapQ1, $mapQ2);
			($resID2, $resID1) = ($resID1, $resID2);
			($resLoc2, $resLoc1) = ($resLoc1, $resLoc2);
			($uniq2, $uniq1) = ($uniq1, $uniq2);
		}
	}

	my $bin = int($loc1 / $RESOLUTION);

	# Create file handle if it is not generated（~100 are possible）
	unless(exists $FH{$chr1}{$bin}){
		my $file_out = $TMP_PREFIX . '_' . $chr1 . '_' . $bin;
		my $f = IO::File->new($file_out, 'w') or die "cannot write $file_out: $!";
		$FH{$chr1}{$bin} = $f;
		$NAMES{$chr1}{$bin} = $file_out;
	}

	my $LINE = join("\t", $id, $chr1, $loc1, $direction1, $mapQ1, $resID1, $resLoc1, $uniq1, $chr2, $loc2, $direction2, $mapQ2, $resID2, $resLoc2, $uniq2);
	$FH{$chr1}{$bin}->print("$LINE\n");
}
$fh_map->close();


sub Chr2Num{
	my ($chr) = @_;
	my $num = $chr;
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
	if($chr eq 'MT'){
		$num = 25;
	}
	if($chr eq 'EBV'){
		$num = 26;
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
	if($chr eq 'IV'){
		$num = 4;
	}
	if($chr eq 'V'){
		$num = 5;
	}
	if($chr eq 'VI'){
		$num = 6;
	}
	if($chr eq 'VII'){
		$num = 7;
	}
	if($chr eq 'VIII'){
		$num = 8;
	}
	if($chr eq 'IX'){
		$num = 9;
	}
	if($chr eq 'X'){
		$num = 10;
	}
	return $num;
}

sub ComparisonChr{
	my ($chr1, $chr2) = @_;
	my $num1 = &Chr2Num($chr1);
	my $num2 = &Chr2Num($chr2);
	if($num1 < $num2){
		return -1;
	}else{
		return 1;
	}
}

#---------------------------------------
# Create file list &&
#---------------------------------------
my $fh_list = IO::File->new($FILE_list, 'w') or die "cannot write $FILE_list: $!";
foreach my $chr(sort {$a cmp $b} keys %FH){
	foreach my $bin(sort {$a <=> $b} keys %{$FH{$chr}}){
		$FH{$chr}{$bin}->close();
		$fh_list->print("$NAMES{$chr}{$bin}\n");
	}
}
$fh_list->close();
