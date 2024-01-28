#!/usr/bin/perl
# 2017/08/22 Calculate and output information for each fragment
# 2017/02/13 Create black list for suspicious fragments with extreme read counts

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use Carp qw(croak);
$| = 0;

use DBI;

if((@ARGV < 2) or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [detabase files]\n";
}


my %opt;
getopts("i:", \%opt);
my $FILE_database = $opt{i};


my %Score;


#---------------------------------------
# collect information
#---------------------------------------
my $dbh = DBI->connect("dbi:SQLite:dbname=$FILE_database");
my $sth_data = $dbh->prepare("select chr1, start1, end1, fragNum1, chr2, start2, end2, fragNum2, score from fragment;");
$sth_data->execute();
while(my $ref = $sth_data->fetchrow_arrayref()){
	my ($chr1, $start1, $end1, $frag1, $chr2, $start2, $end2, $frag2, $score) = @$ref;
	my $len1 = $end1 - $start1;
	my $len2 = $end2 - $start2;
	my $key1 = "$chr1\t$frag1\t$len1";
	my $key2 = "$chr2\t$frag2\t$len2";
	$Score{$key1} +=$score;
	$Score{$key2} +=$score;
}
$sth_data->finish();
$dbh->disconnect();



#---------------------------------------
# output
#---------------------------------------
print "chr\tfragNum\tlength\tcount\n";
foreach my $key (sort {$Score{$b} <=> $Score{$a}} keys %Score){
	my $value = $Score{$key};
	print "$key\t$value\n";
}

