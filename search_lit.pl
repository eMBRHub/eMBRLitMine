#!/usr/bin/perl
use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Pretty;
use DBI;
#use DBD::mysql;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';

#connect to the database
my $ds = "DBI:mysql:xxxx:localhost"; #replace xxxx with database name
my $user = "root";
my $passwd = "xxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgi = new CGI;

#prepare query
#use two queries for now. join later

my $bacteria = $cgi->param('bacteria');
my $contaminant_name = $cgi->param('comp');
my $count_of_articles = $cgi->param('counta');

my $sth1;
#my $results1;

#retrieve pmids from relevant databases
my $query1 = q(SELECT pmid,pub_year,title,publ,pub_vol,pub_pages FROM PM_text INNER JOIN PM_bacteria ON PM_bacteria.pm_id = PM_text.pmid WHERE PM_bacteria.bactname LIKE ? AND PM_bacteria.assoc_cont LIKE ?);

$sth1 = $dbh->prepare($query1); 
#execute query1

$sth1->execute($bacteria, $contaminant_name);

#push all results into an array for further processing for printing

my @final_results;
my $pmedID;
my $pmlink;
my $results1;
while ($results1 = $sth1->fetchrow_arrayref()){
	$pmedID = $results1->[0];
	$pmlink = $cgi->a({href=>"../cgi-bin/get_article.pl?pmd_id=$pmedID"}, $pmedID);
#$pmlink = $cgi->a({href=>"http://www.ncbi.nlm.nih.gov/sites/entrez?cmd=Retrieve&db=PubMed&list_uids=".$pmedID."&dopt=Abstract#abstract"}, $pmedID);
	push(@final_results, $cgi->Tr( $cgi->td([$pmlink, $results1->[1], $results1->[2], $results1->[3], $results1->[4], $results1->[5]])));
}

#create new web page

print	$cgi->header;
print	$cgi->start_html(-title=>'Results of search for bacteria',
				-target=>'_blank');
print   $cgi->img ({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print	$cgi->h1('Results of bacteria literature search');
print	$cgi->p("The table below shows details of articles in which contaminant ".$cgi->b($contaminant_name). "and bacteria ".$cgi->b($bacteria)."co-occur");
#print	$cgi->pre($query1);
print	$cgi->p('Contaminant: '. $contaminant_name);
print	$cgi->p('Bacteria: '. $bacteria);
print	$cgi->p('Article Count: '. $count_of_articles);

#print results
print $cgi->table(
	{-border => '1', cellpadding => '1', cellspacing => '1'},
	$cgi->Tr([
		$cgi->th(['Pubmed ID', 'Year', 'Title', 'Journal', 'Volume', 'Pages'])
		]),

		@final_results
	);


#clean up
$sth1->finish;
$dbh->disconnect;

print $cgi->end_html;
exit;
