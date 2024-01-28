#!/usr/bin/perl

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);
$| = 0;

if(@ARGV != 4 or $ARGV[0] eq '--help'){
	die "Usage : $0 -s [sam file] -o [command file]\n";
}

my %opt;
getopts("s:o:", \%opt);
my $FILE_sam = $opt{s};
my $FILE_out = $opt{o};

my %FH;
my $fh_in = IO::File->new($FILE_sam) or die "cannot open $FILE_sam: $!";
my $fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";
while($_ = $fh_in->getline()){
	if(m/^@/){
		print "$_";
		next;
	}

	my ($id, $flag, $chr, $position, $mapQ, $CIGAR, $mate_a, $mate_b, $mate_c, $seq, $quality, @option) = split /\t/;

	if($mapQ > 10){
		print "$_";
	}else{
		my @N;
		while($CIGAR =~ m/(\d+)[MID]/g){
			push @N, $1;
		}

		if(@N < 2){
			print "$_";
		}else{
			if($flag == 16){
				my @sorted = reverse @N;
				@N = @sorted;
			}

			# Compare values between left and right
			my $SIDE;
			my $TRIM_length;
			my $READ_length = length($seq);
			if($N[0] < $N[-1]){
				if($N[-1] < 20){
					print "$_";
					next;
				}
				$SIDE = '-5';
				$TRIM_length = $READ_length - $N[-1];
			}else{
				if($N[0] < 20){
					print "$_";
					next;
				}
				$SIDE = '-3';
				$TRIM_length = $READ_length - $N[0];
			}

			my $OPTION = $SIDE . ' ' . $TRIM_length;

			unless(exists $FH{$OPTION}){
				my $FILE_name = $FILE_sam . '_tempFastq_' . $SIDE . '_' . $TRIM_length . 'bp.fastq';
				my $fh_fastq = IO::File->new($FILE_name, 'w') or die "cannot write $FILE_name: $!";
				$FH{$OPTION} = $fh_fastq;
				$fh_out->print("$OPTION\t$FILE_name\n");
			}

			if($flag == 16){
				my $complement = reverse $seq;
				$complement =~ tr/ATGC/TACG/;
				$seq = $complement;
				my $comp_q = reverse $quality;
				$quality = $comp_q;
			}
			$FH{$OPTION}->print('@' . "$id\n$seq\n+\n$quality\n");
		}
	}
}
$fh_in->close();
$fh_out->close();

foreach my $f(keys %FH){
	$FH{$f}->close();
}

