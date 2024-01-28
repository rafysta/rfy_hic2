#!/usr/bin/perl
# count fragments with less than 1kb (=probably correspond to undigested ragments)

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);
$| = 0;

use DBI;

if(@ARGV != 4 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [database] -o [output bed file]\n";
}

my %opt;
getopts("i:o:", \%opt);
my $FILE_database = $opt{i};
my $FILE_output = $opt{o};



my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");



#---------------------------------------
# Get chromosome list
#---------------------------------------
my @Chromosomes ;
my $sth_getChr = $dbh->prepare("select distinct(chr1) from map");
$sth_getChr->execute();
while(my ($c) = $sth_getChr->fetchrow_array()){
	push @Chromosomes, $c;
}
$sth_getChr->finish();


my $fh_out = IO::File->new($FILE_output, 'w') or die "cannot write $FILE_output: $!";

foreach my $chr(@Chromosomes){
	my $sth_data = $dbh->prepare("select position1, position2, direction1, direction2 from map
			where chr1=chr2 and abs(position1 - position2) < 1000 and chr1='$chr'");
	$dbh->do('BEGIN');
	$sth_data->execute();

	# Count overlaps per 1kb
	# Different direction read pairs - same direction read pairs(Correct HiC products)
	my %Same;
	my %Different;
	my %Diff;
	while(my $ref = $sth_data->fetchrow_arrayref()){
		my ($position1, $position2, $direction1, $direction2) = @$ref;
		for(my $i = $position1; $i < $position2; $i += 1000){
			my $bin = int($i / 1000) * 1000;
			if($direction1 eq $direction2){
				$Same{$bin}++;
				$Diff{$bin}--;
			}else{
				$Different{$bin}++;
				$Diff{$bin}++;
			}
		}
	}
	$dbh->do('COMMIT');

	$sth_data->finish();

	# Output
	foreach my $p(sort {$a <=> $b} keys %Diff){
		$fh_out->printf("%s\t%d\t%d\t.\t%d\t+\t%d\t%d\n", $chr, $p, $p+999, $Diff{$p}, $Same{$p}, $Different{$p});
	}
}
$fh_out->close();
$dbh->disconnect();










