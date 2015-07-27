#!/usr/bin/perl
use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Pretty;
use DBI;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';

#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgi = new CGI;
my $pubmed = $cgi->param('pmd_id');


#retrieve titles and abstracts from database
my $query = q(SELECT title, pub_year, abstract FROM PM_text WHERE pmid = ?);

my $sth3 = $dbh->prepare($query); 

#execute query1
$sth3->execute($pubmed);

#format results
my @read_abs;
my $abs_title;
my $abs_year;
my $abstract;
while (my $abs_results = $sth3->fetchrow_arrayref()){
	$abs_title = $abs_results->[0];
	$abs_year = $abs_results->[1];
	$abstract = $abs_results->[2];
	
	push(@read_abs, $cgi->Tr($cgi->th(['Title']),$cgi->td([$abs_title])));
	push(@read_abs, $cgi->Tr($cgi->th(['Year']),$cgi->td([$abs_year])));
	push(@read_abs, $cgi->Tr($cgi->th(['Abstract']),$cgi->td([$abstract])));
}

print 	$cgi->header;
print	$cgi->start_html(-title=>'Abstract for '. $pubmed,
				-target=>'_blank');
print   $cgi->img ({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print	$cgi->h1('Abstract for PubMed ID '. $pubmed);
print   $cgi->hr();
	$cgi->pre(my $query);
#print results
print $cgi->table(
	{-border => '1', cellpadding => '1', cellspacing => '1'},
	#$cgi->Tr([
		#$cgi->th(['Article Details'])
		#]),

		@read_abs
	);

my $literal = 'See Complete article in Pubmed';
my $pubmedlink = $cgi->a({href=>"http://www.ncbi.nlm.nih.gov/sites/entrez?cmd=Retrieve&db=PubMed&list_uids="."$pubmed"."&dopt=Abstract#abstract"}, $literal);

print $cgi->p($pubmedlink);
print $cgi->end_html;
exit;
