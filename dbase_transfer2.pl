#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use IO::String;
use DBD::mysql;
#use lib'/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';


my $newname = "Pmtextfile.txt";

my @recordsfile = get_data($newname);

#Define details for mySQL database:
my $ds = "DBI:mysql:Pmeddata:localhost";
my $user = "root";
my $passwd = "S952pa74lkp";

#connect to database, prepare and execute SQL
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#prepare the insert statement
my $sth = $dbh->prepare("INSERT INTO PM_text (pmid, title, publ, pub_year, pub_vol, pub_pages, abstract) VALUES (?,?,?,?,?,?,?)");

foreach my $line (@recordsfile){
		my @records = split("\t", $line); 
		chomp $records[0]; #to maintain array lengths
		chomp $records[1];
		chomp $records[2];
		chomp $records[3];
		chomp $records[4];
		chomp $records[5];
		chomp $records[6];
		#print "$records[0]\t$records[1]\t$records[2]\t$records[3]\t$records[4]\t$records[5]\t$records[6]\n\n";
		
		$sth->execute($records[0],$records[1],$records[2],$records[3],$records[4],$records[5],$records[6]);

	}

$sth->finish;


sub get_data{
	my ($filename) = @_;
	unless (open(DATAFILE, $filename)){
		print "Could not open file $filename!!\n";
		exit;
	}
	my (@filedata) = <DATAFILE>;
	close(DATAFILE);
	return @filedata;
}

