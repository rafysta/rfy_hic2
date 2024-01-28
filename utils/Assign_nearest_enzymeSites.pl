#!/usr/bin/perl
# Find neareast restriction sites


use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use Carp qw(croak);
$| = 0;


#---------------------------------------
# FIX parameter
#---------------------------------------
my $unit = 20000;	# section file bin size (20000bp)

if(@ARGV != 10  or $ARGV[0] eq '--help'){
	die "Usage : $0 -a [sam file 1] -b [sam file 2] -o [output map file] -e [enzyme definition file] -d [enzyme index file]\n";
}

my %opt;
getopts("a:b:o:e:d:", \%opt);
my $FILE_sam1 = $opt{a};
my $FILE_sam2 = $opt{b};
my $FILE_map = $opt{o};
my $FILE_ENZYME_index = $opt{d};
my $FILE_ENZYME_def = $opt{e};

#---------------------------------------
# map format
#---------------------------------------
# 1. id
# 2. chr 1
# 3. position 1
# 4. direction 1
# 5. map quality 1
# 6. hindiii id 1
# 7. hindiii location 1
# 8. chr 2
# 9. position 2
# 10. direction 2
# 11. map quality 2
# 12. hindiii id 2
# 13. hindiii location 2

#---------------------------------------
# read restriction definition file
#---------------------------------------
### read def sites
my %Enzymes;
{
	my $fh_in = IO::File->new($FILE_ENZYME_def) or die "cannot open $FILE_ENZYME_def: $!";
	while($_ = $fh_in->getline()){
		if(m/^#/){
			next;
		}
		s/\r?\n//;
		my ($number, $chr, $pos, $before, $after) = split /\t/;
		my $id = $chr . ':' . $number;
		$Enzymes{$id} = $pos;
	}
	$fh_in->close();
}
### read index file
my %Hind_index;
{
	my $fh_in = IO::File->new($FILE_ENZYME_index) or die "cannot open $FILE_ENZYME_index: $!";
	while($_ = $fh_in->getline()){
		if(m/^#/){
			next;
		}
		s/\r?\n//;
		my ($chr, $loc, $ids) = split /\t/;
		if($ids ne 'NA'){
			my @lists = split /,/, $ids;
			$Hind_index{$chr}{$loc} = \@lists;
		}
	}
	$fh_in->close();
}



#---------------------------------------
# mapping two files
#---------------------------------------
my $TOTAL_read = 0;
my $Aligned_single = 0;
my $Aligned_both = 0;
my $Not_aligned = 0;

my $fh_sam1 = IO::File->new($FILE_sam1) or die "cannot open $FILE_sam1: $!";
my $fh_sam2 = IO::File->new($FILE_sam2) or die "cannot open $FILE_sam2: $!";
my $fh_map = IO::File->new($FILE_map, 'w') or die "cannot write $FILE_map: $!";
while(my $sam1 = $fh_sam1->getline()){
	my $sam2 = $fh_sam2->getline();
	$sam1 =~ s/\r?\n//;
	$sam2 =~ s/\r?\n//;
	my ($id1, $flag1, $chr1, $position1, $mapQ1, $CIAGR1, $mate_a1, $mate_b1, $mate_c1, $seq1, $quality1, @option1) = split /\t/, $sam1;
	my ($id2, $flag2, $chr2, $position2, $mapQ2, $CIAGR2, $mate_a2, $mate_b2, $mate_c2, $seq2, $quality2, @option2) = split /\t/, $sam2;

	if($id1 ne $id2){
		die ("$id1 and $id2 is different\n");
	}

	$TOTAL_read++;
	my $flag_aligned = 0;
	my ($direction1, $direction2) = ('NA','NA');

	if($flag1 == 0){
		$direction1 = '+';
		$flag_aligned++;
	}elsif($flag1 == 16){
		$direction1 = '-';
		$position1 += length($seq1) - 1;
		$flag_aligned++;
	}else{
		$chr1 = 'NA';
		$position1 = 'NA';
	}



	if($flag2 == 0){
		$direction2 = '+';
		$flag_aligned++;
	}elsif($flag2 == 16){
		$direction2 = '-';
		$position2 += length($seq2) - 1;
		$flag_aligned++;
	}else{
		$chr2 = 'NA';
		$position2 = 'NA';
	}

	my ($hinID1, $hinLoc1) = ('NA', 'NA');
	my ($hinID2, $hinLoc2) = ('NA', 'NA');
	if($chr1 ne 'NA'){
		($hinID1, $hinLoc1) = &FindHindIIIinfo($chr1, $position1, $direction1);
	}
	if($chr2 ne 'NA'){
		($hinID2, $hinLoc2) = &FindHindIIIinfo($chr2, $position2, $direction2);
	}


	my $Uniq1 = "U";
	foreach my $v(@option1){
		my $f = index $v, "XS:i";
		if($f != -1){
			$Uniq1 = "R";
			last;
		}
	}
	my $Uniq2 = "U";
	foreach my $v(@option2){
		my $f = index $v, "XS:i";
		if($f != -1){
			$Uniq2 = "R";
			last;
		}
	}


	if($flag_aligned == 0){
		$Not_aligned++;
	}elsif($flag_aligned == 1){
		$Aligned_single++;
	}elsif($flag_aligned == 2){
		$Aligned_both++;
	}

	# Assign read number as id
	$fh_map->print("$TOTAL_read\t$chr1\t$position1\t$direction1\t$mapQ1\t$hinID1\t$hinLoc1\t$Uniq1\t$chr2\t$position2\t$direction2\t$mapQ2\t$hinID2\t$hinLoc2\t$Uniq2\n");
}
$fh_sam1->close();
$fh_sam2->close();
$fh_map->close();

print "OutputFile : $FILE_map\n";
printf "Total read:\t%d\n", $TOTAL_read;
printf "Both aligned:\t%d\n", $Aligned_both;
printf "Single aligned:\t%d\n", $Aligned_single;
printf "Not aligned:\t%d\n", $Not_aligned;



sub FindHindIIIinfo{
	my ($chr, $pos, $direction) = @_;
	my $cate = int($pos / $unit) * $unit;
	if(exists $Hind_index{$chr}{$cate}){
		my @candidates = @{$Hind_index{$chr}{$cate}};

		# Get 2 enzyme site candidates, one each from left and right
		my $MIN_left = 99999999999;
		my $MIN_right = 99999999999;
		my $MIN_left_id = '';
		my $MIN_right_id = '';
		foreach my $i(@candidates){
			if($pos < $Enzymes{$i}){
				my $distance = $Enzymes{$i} - $pos;
				if($distance < $MIN_left){
					$MIN_left = $distance;
					$MIN_left_id = $i;
				}
			}else{
				my $distance = $pos - $Enzymes{$i};
				if($distance < $MIN_right){
					$MIN_right = $distance;
					$MIN_right_id = $i;
				}
			}
		}

		# If read direction is +, take the right candidate, - then take the left candidate
		my $MIN_id = '';
		if($direction eq '+'){
			$MIN_id = $MIN_right_id;
		}else{
			$MIN_id = $MIN_left_id;
		}

		if($MIN_id eq ''){
			return ('NA', 'NA');
		}

		my ($chrTmp, $hinID) = split /:/, $MIN_id;

		return ($hinID, $Enzymes{$MIN_id});
	}else{
#		warn ("Nearest restriction cites were not found for $chr : $pos \n");
		return ('NA', 'NA');
	}
}


