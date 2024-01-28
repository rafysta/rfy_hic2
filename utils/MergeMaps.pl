#!/usr/bin/perl
# Merge multiple map files from technical replicates (Remove duplicated reads)

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use File::Basename;
use File::Copy;;
use Carp qw(croak);
$| = 0;

if(@ARGV < 6 or $ARGV[0] eq '--help'){
	die "Usage : $0 -i [list of map file (it can be gziped) separated by cammma] -o [merged map file] -t [tmporary directory]\n";
}

my %opt;
getopts("i:o:t:", \%opt);
my @FILE_maps = split /,/, $opt{i};
my $FILE_out = $opt{o};
my $DIR_tmp = $opt{t};
my $TMP_master =  $DIR_tmp . '/tmp_master.txt';
my $TMP_working =  $DIR_tmp . '/tmp_working.txt';

if(scalar @FILE_maps < 2){
	die "input file has less than 2 files";
}


#--------------------------------------------------------------
# merge files
#--------------------------------------------------------------
my $FILE_master = shift @FILE_maps;
my $fh_master;
if($FILE_master =~ /\.gz/){
	$fh_master = IO::File->new("gzip -dc $FILE_master |") or die "cannot open $FILE_master: $!";
}else{
	$fh_master = IO::File->new($FILE_master) or die "cannot open $FILE_master: $!";
}
my $Title = $fh_master->getline();
my $READ_master = $fh_master->getline();
$READ_master =~ s/\r?\n//; my @data_master = split /\t/, $READ_master;

for my $file(@FILE_maps){
	my @data_new;

	my $fh_out = IO::File->new($TMP_working, 'w') or die "cannot write $TMP_working: $!";
	$fh_out->print("$Title");

	my $fh_new;
	if($file =~ /\.gz/){
		$fh_new = IO::File->new("gzip -dc $file |") or die "cannot open $file: $!";
	}else{
		$fh_new = IO::File->new($file) or die "cannot open $file: $!";
	}
	$fh_new->getline();
	my $READ_new = $fh_new->getline();
	$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;
	while(1){
		if($READ_new and $READ_master){
			my $chr1_cmp = $data_new[1] cmp $data_master[1];
			if($chr1_cmp == 0){
				if($data_new[2] == $data_master[2]){
					my $chr2_cmp = $data_new[8] cmp $data_master[8];
					if($chr1_cmp == 0){
						if($data_new[9] == $data_master[9]){
							$fh_out->print("$READ_master\n");
							$READ_master = $fh_master->getline();
							$READ_new = $fh_new->getline();
							if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
							if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
						}elsif($data_new[9] < $data_master[9]){
							$fh_out->print("$READ_new\n");
							$READ_new = $fh_new->getline();
							if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
						}elsif($data_new[9] > $data_master[9]){
							$fh_out->print("$READ_master\n");
							$READ_master = $fh_master->getline();
							if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
						}
					}elsif($chr2_cmp == -1){
						$fh_out->print("$READ_new\n");
						$READ_new = $fh_new->getline();
						if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
					}elsif($chr2_cmp == 1){
						$fh_out->print("$READ_master\n");
						$READ_master = $fh_master->getline();
						if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
					}
				}elsif($data_new[2] < $data_master[2]){
					$fh_out->print("$READ_new\n");
					$READ_new = $fh_new->getline();
					if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
				}elsif($data_new[2] > $data_master[2]){
					$fh_out->print("$READ_master\n");
					$READ_master = $fh_master->getline();
					if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
				}
			}elsif($chr1_cmp == -1){
				$fh_out->print("$READ_new\n");
				$READ_new = $fh_new->getline();
				if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
			}elsif($chr1_cmp == 1){
				$fh_out->print("$READ_master\n");
				$READ_master = $fh_master->getline();
				if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
			}
		}elsif(!$READ_new and $READ_master){
			$fh_out->print("$READ_master\n");
			$READ_master = $fh_master->getline();
			if($READ_master){$READ_master =~ s/\r?\n//; @data_master = split /\t/, $READ_master;}
		}elsif($READ_new and !$READ_master){
			$fh_out->print("$READ_new\n");
			$READ_new = $fh_new->getline();
			if($READ_new){$READ_new =~ s/\r?\n//; @data_new = split /\t/, $READ_new;}
		}elsif(!$READ_new and !$READ_master){
			last;
		}
	}
	$fh_master->close();
	$fh_new->close();
	$fh_out->close();

	# Change file name
	system("mv $TMP_working $TMP_master");
	$FILE_master = $TMP_master;
}


#--------------------------------------------------------------
# Combine files
#--------------------------------------------------------------
system("mv $TMP_master $FILE_out");
