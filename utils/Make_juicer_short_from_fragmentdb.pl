#!/usr/bin/perl
# Convert fragment database to Juicer "short with score" format
#
# The output reproduces exactly the bin assignment used by
# Make_association_from_fragmentdb_allChromosome.pl / _onlyIntraChr.pl:
#   - fragment pairs listed in the blacklist are skipped
#   - score is doubled for intra-chromosomal pairs closer than THRESHOLD_SELF
#     (only same-direction reads are kept within this distance)
#   - each fragment pair is distributed to the 4 combinations of
#     (start1|end1) x (start2|end2) with score/4 each
# Because the 4 positions are written before binning, "juicer_tools pre"
# assigns them to bins with int(pos / resolution), which is identical to the
# rfy_hic2 matrices at every resolution.
#
# Output columns (space separated, no header):
#   str1 chr1 pos1 frag1 str2 chr2 pos2 frag2 score
# str is always 0, frag1=0 and frag2=1 (dummy values required by juicer).
# Pairs are written with (chr1,pos1) <= (chr2,pos2) according to the order of
# the chromosome list given by -c, and grouped by chromosome pair (juicer pre
# requires that each chromosome pair appears in one contiguous block).

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Temp qw(tempdir);

if(@ARGV < 6 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [fragment database] -o [output file (.gz allowed)] -c [comma separated chromosome list] -t [threshold of self ligation distance] [-b black list of fragment]\n";
}

my %opt;
getopts("i:o:c:t:b:", \%opt);
my $FILE_database = $opt{i};
my $FILE_out = $opt{o};
my $FILE_black = $opt{b};
my $THRESHOLD_SELF = defined $opt{t} ? $opt{t} : 10000;
my @chromosomes = split /,/, $opt{c};

use DBI;

#---------------------------------------
# chromosome order (for sorting pairs)
#---------------------------------------
my %chrOrder;
for(my $i = 0; $i < @chromosomes; $i++){
	$chrOrder{$chromosomes[$i]} = $i;
}

#---------------------------------------
# Read fragment blacklist
#---------------------------------------
my %Black;
if(defined $FILE_black and -e $FILE_black){
	my $fh_in = IO::File->new($FILE_black) or die "cannot open $FILE_black: $!";
	while($_ = $fh_in->getline()){
		s/\r?\n//;
		my ($chr, $fragID) = split /\t/;
		next unless(defined $fragID and $fragID =~ /^\d+$/);   # skip header line
		$Black{"$chr\t$fragID"} = 1;
	}
	$fh_in->close();
}

#---------------------------------------
# temporary files per chromosome pair
#---------------------------------------
my $DIR_tmp = tempdir("short_XXXXXX", DIR => ($ENV{TMPDIR} || "/tmp"), CLEANUP => 1);
my %fh_pair;
sub get_fh{
	my ($c1, $c2) = @_;
	my $key = "$c1\t$c2";
	unless(exists $fh_pair{$key}){
		$fh_pair{$key} = IO::File->new("$DIR_tmp/$chrOrder{$c1}_$chrOrder{$c2}.txt", 'w') or die "cannot write temporary file: $!";
	}
	return $fh_pair{$key};
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database", "", "", {RaiseError => 1, AutoCommit => 1});
my $sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment;");
$sth_data->execute();

my $count_pair = 0;
my $count_out = 0;
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;

	# only chromosomes in the list
	next unless(exists $chrOrder{$chr1} and exists $chrOrder{$chr2});

	# Skip fragments in blacklist
	next if(exists $Black{"$chr1\t$frag1"});
	next if(exists $Black{"$chr2\t$frag2"});

	$count_pair++;

	my $middle1 = ($start1 + $end1) / 2;
	my $middle2 = ($start2 + $end2) / 2;
	my $distance = abs($middle1 - $middle2);

	# Double scoring if within the distance of self-ligation
	if($chr1 eq $chr2 and $distance < $THRESHOLD_SELF){
		$score = $score * 2;
	}

	# Evenly distribute score to the 4 combinations
	$score = $score / 4;

	foreach my $p1 ($start1, $end1){
		foreach my $p2 ($start2, $end2){
			my ($c1, $q1, $c2, $q2) = ($chr1, $p1, $chr2, $p2);
			# keep (chr1,pos1) <= (chr2,pos2)
			if($chrOrder{$c1} > $chrOrder{$c2} or ($c1 eq $c2 and $q1 > $q2)){
				($c1, $q1, $c2, $q2) = ($chr2, $p2, $chr1, $p1);
			}
			get_fh($c1, $c2)->print("0 $c1 $q1 0 0 $c2 $q2 1 $score\n");
			$count_out++;
		}
	}
}
$sth_data->finish();
$dbh->disconnect();
foreach my $fh(values %fh_pair){ $fh->close(); }

#---------------------------------------
# concatenate in chromosome pair order
#---------------------------------------
my $fh_out;
if($FILE_out =~ /\.gz$/){
	$fh_out = IO::File->new("| gzip -c > $FILE_out") or die "cannot write $FILE_out: $!";
}else{
	$fh_out = IO::File->new($FILE_out, 'w') or die "cannot write $FILE_out: $!";
}
for(my $i = 0; $i < @chromosomes; $i++){
	for(my $j = $i; $j < @chromosomes; $j++){
		my $f = "$DIR_tmp/${i}_${j}.txt";
		next unless -e $f;
		my $fh_in = IO::File->new($f) or die "cannot open $f: $!";
		while($_ = $fh_in->getline()){ $fh_out->print($_); }
		$fh_in->close();
		unlink $f;
	}
}
$fh_out->close();

print STDERR "fragment pairs used: $count_pair\nrecords written: $count_out\n";
