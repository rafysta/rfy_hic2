#!/usr/bin/perl
# 2014/03/05 changed for human
# 2012/10/17 Output location of target sequence

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);

if(@ARGV != 4 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [fasta file] -t [recognition sequences separated by ,]\n";
}

my %opt;
getopts("i:t:", \%opt);
my $FastaFile = $opt{i};
my @recognitionSeq = map uc, split /,/, $opt{t};

print "#number\tchr\tposition\tlength_before\tlength_after\n";
my $fh = IO::File->new($FastaFile) or die "cannot open $FastaFile: $!";
my $id = '';
my $seq = '';
while($_ = $fh->getline()){
	s/\r?\n//;
	if(m/^>(\S+)/){
		if($seq ne ''){
			$seq = uc($seq);
			&parseSeq($id, $seq);
		}
		$id = $1;
		$seq = '';
	}else{
		$seq .= $_;
	}
}
$seq = uc($seq);
&parseSeq($id, $seq);
$fh->close();


sub parseSeq{
	my ($chr, $seq) = @_;
	my $frag_number = 0;

	my $pos = 0;
	my $previous = 0;
	my @locationList = (0);
	while($pos != 9999999999){
		$pos = 9999999999;
		foreach my $rr (@recognitionSeq){
			my $pp = index $seq, $rr, $previous;
			if($pp != -1 and $pp < $pos){
				$pos = $pp;
			}
		}
		if($pos != 9999999999){
			push @locationList, $pos;
		}
		$previous = $pos + 1;
	}
	my $totalLength = length $seq;
	push @locationList, $totalLength;

	for(my $i = 1; $i < @locationList - 1; $i++){
		$frag_number++;
		my $length_before = $locationList[$i] - $locationList[$i-1];
		my $length_after = $locationList[$i+1] - $locationList[$i];
		print "$frag_number\t$chr\t$locationList[$i]\t$length_before\t$length_after\n";
	}
}

