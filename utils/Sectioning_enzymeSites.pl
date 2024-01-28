#!/usr/bin/perl
# making section for enzyme sites


use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);
$| = 0;

if(@ARGV != 2 or $ARGV[0] eq '--help'){
	die "Usage : $0  -i [enzyme sites file]\n";
}


my %opt;
getopts("i:", \%opt);
my $FILE_ENZYME = $opt{i};


### 20000bp bin size
my $unit = 20000;



### read enzyme sites
my %Sections;
my %MAX_chr;
{
	my $fh_in = IO::File->new($FILE_ENZYME) or die "cannot open $FILE_ENZYME: $!";
	while($_ = $fh_in->getline()){
		if(m/^#/){
			next;
		}
		s/\r?\n//;
		my ($number, $chr, $pos, $before, $after) = split /\t/;
		my $cate = int($pos / $unit) * $unit;
		my $id = $chr . ':' . $number;
		push @{$Sections{"$chr\t$cate"}}, $id;
		unless(exists $MAX_chr{$chr}){
			$MAX_chr{$chr} = 0;
		}
		if($MAX_chr{$chr} < $cate){
			$MAX_chr{$chr} = $cate;
		}
	}
	$fh_in->close();
}



### output enzyme site number lists
### check the nearest Hind III for empty location
foreach my $chr(keys %MAX_chr){
	for(my $i = 0; $i <= $MAX_chr{$chr} + 5 * $unit; $i += $unit){
		my @lists;
		if(exists $Sections{"$chr\t$i"}){
			push @lists, @{$Sections{"$chr\t$i"}};
		}
		my $before = $i - $unit;
		if(exists $Sections{"$chr\t$before"}){
			push @lists, @{$Sections{"$chr\t$before"}};
		}
		my $after = $i + $unit;
		if(exists $Sections{"$chr\t$after"}){
			push @lists, @{$Sections{"$chr\t$after"}};
		}

		if(@lists > 0){
			print "$chr\t$i\t" . join(",", @lists) . "\n";
		}else{
			print "$chr\t$i\tNA\n";
		}
	}
}
