#!/usr/bin/perl
use strict;
use warnings;

use LWP::Simple;
use XML::Simple;
use Data::Dumper;
use IO::String;
use lib'/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm'; #use in place of DBD::mysql if unavailable
use DBI;
#use DBD::MySQL;

my $searchterms = "Bacteria_names4.txt";
my @bacteria_names = get_data($searchterms);

#an outfile for testing
my $postout = "testprint.txt";
open (POSTOUT, ">$postout") || die "Error opening postout file $postout!!\n";

#connection details of mysql server
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxxx with database name
my $user = "root";
my $passwd = "xxxxx";#replace with appropriate password

#connect to database
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to mysql database!!";

#prepare the insert statement
my $sth = $dbh->prepare("INSERT INTO PM_text (pmid, title, publ, pub_year, pub_vol, pub_pages, abstract) VALUES (?,?,?,?,?,?,?)");

#get details from table of bacteria names
foreach my $line(@bacteria_names){
	chomp $line;
	my $bact_name = $line;

#pubmed matters; connect search and retrieve entries
my $utils = "http://www.ncbi.nlm.nih.gov/entrez/eutils";

my $db     = "Pubmed";
my $query  = $bact_name;
my $report = "abstract";

my $esearch = "$utils/esearch.fcgi?" .
              "db=$db&retmax=1&usehistory=y&term=";

my $esearch_result = get($esearch . $query);


my ($Count, $QueryKey, $WebEnv);
$esearch_result =~ m#<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>#s;
$Count    = $1;
$QueryKey = $2;
$WebEnv   = $3;

print "Count = $Count; QueryKey = $QueryKey; WebEnv = $WebEnv\n";

my $retstart;
my $retmax=1;

for($retstart = 0; $retstart < $Count; $retstart += $retmax) {
    my $efetch = "$utils/efetch.fcgi?" .
               "rettype=$report&retmode=xml&retstart=$retstart&retmax=$retmax&" .
               "db=$db&query_key=$QueryKey&WebEnv=$WebEnv";
    my $efetch_result = get($efetch);
    my $trythefectch = $efetch_result;
    
    # either use a file handle (via IO::String)
    #
    #my $string_fh = IO::String->new($trythefectch);
    #&parse_xml_fh($string_fh);
    #
    #  or just parse the string
    &parse_and_write_xml_string($trythefectch);
}

}
$sth->finish;
$dbh->disconnect;


################################################################################
# subs here
################################################################################

sub ask_user {
  print "$_[0] [$_[1]]: ";
  my $rc = <>;
  chomp $rc;
  if($rc eq "") { $rc = $_[1]; }
  return $rc;
}


sub parse_xml_fh {
    my $string_fh = shift @_;
    #  die with an error if no string fh was passed, the calling routing should check a result was found!
    die "No string fh passed to parse_xml_fh!\n" unless $string_fh;

    my $xml = XML::Simple->new(KeyAttr=>[]);

    my $data = $xml->XMLin($string_fh);

    print "PMID: ". $data->{PubmedArticle}->{MedlineCitation}->{PMID}, "\n";
    print "Title: ". $data->{PubmedArticle}->{MedlineCitation}->{Article}->{ArticleTitle}, "\n";
    print "Abstract: ".$data->{PubmedArticle}->{MedlineCitation}->{Article}->{Abstract}->{AbstractText},"\n";
    my $authors;
    foreach my $e (@{$data->{PubmedArticle}->{MedlineCitation}->{Article}->{AuthorList}->{Author}}){
	$authors.= $e->{LastName}." ".$e->{Initials}.', ';
    }

    print $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{ISOAbbreviation}, " ";
    print $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year}, ";", ;
    print $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{JournalIssue}->{Volume}, ":";
    print $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Pagination}->{MedlinePgn}, "." ;
    print "\n";

}

sub parse_and_write_xml_string{
    my $xml_string = shift @_;
    # die with an error if no string was passed, the calling routing should check a result was found!
    die "No string passed to parse_xml_string!\n" unless $xml_string;
    
    my $xml = XML::Simple->new(KeyAttr=>[]);
    my $data = $xml->parse_string($xml_string);
    
    # process  the data
    my $PMID = $data->{PubmedArticle}->{MedlineCitation}->{PMID};
    my $Title = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{ArticleTitle};
    my $Abstract = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Abstract}->{AbstractText};
    my $Publication = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{ISOAbbreviation};
    my $Pub_year = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year};
    my $Pub_vol = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Journal}->{JournalIssue}->{Volume};
    my $Pub_pages = $data->{PubmedArticle}->{MedlineCitation}->{Article}->{Pagination}->{MedlinePgn};
    
    print "PMID: ". $data->{PubmedArticle}->{MedlineCitation}->{PMID}, "\n";
    print "Title: ". $data->{PubmedArticle}->{MedlineCitation}->{Article}->{ArticleTitle}, "\n";
    print "Abstract: ".$data->{PubmedArticle}->{MedlineCitation}->{Article}->{Abstract}->{AbstractText},"\n";
    print "\n";

    $sth->execute($PMID,$Title,$Publication,$Pub_year,$Pub_vol,$Pub_pages,$Abstract);
}

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


