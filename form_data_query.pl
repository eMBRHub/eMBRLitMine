#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Pretty;
use DBI;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';
use GraphViz;
use IO::String;
use File::Copy;
use Fcntl; 

#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgi = new CGI;

#prepare query
my $query = q(SELECT bactname, COUNT(bactname) FROM PM_bacteria WHERE assoc_cont LIKE ? GROUP BY bactname);

my $sth = $dbh->prepare($query); 


#new web page


my $output = $cgi->param('output');
my $docs = $cgi->param('doc_no');

###if textual output is required
if($output eq "Textual"){

my $cont = $cgi->param('contaminant');


#run and report query

$sth->execute( $cgi->param('contaminant'));

my @query_results;
while (my $results = $sth->fetchrow_arrayref()){
	next if $results->[1]<$docs;
	my $bacteria_search_name = $results->[0];
	my $link = $cgi->a({href=>"../cgi-bin/bac_search.pl?bac_name=$bacteria_search_name;art_count=$results->[1];contam=$cont"}, $bacteria_search_name);

	push(@query_results, $cgi->Tr( $cgi->td([ $link, $results->[1]])));
}


#print results

if(!@query_results){
	print $cgi->header;
	print $cgi->start_html('Database query for contaminant');
	print $cgi->img({-scr=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
	print $cgi->h1('Results for contaminant: '. $cont);
	print $cgi->hr();
	$cgi->pre($query);
	print $cgi->p("SORRY! Your query resulted in NO matches from our current database!");
}else{

	print	$cgi->header;
	print	$cgi->start_html('Database query for contaminant');
	print   $cgi->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
	#print   $cgi->br();
	print	$cgi->h1('Results for contaminant: '. $cont);
	print   $cgi->hr();
	print	$cgi->p("The table below shows results of co-occurence of ".$cgi->b($cont)." and relevant bacteria, in PubMed");
	$cgi->pre($query);
	print	$cgi->p('Find the results below: ');
print $cgi->table(
	{-border => '1', cellpadding => '1', cellspacing => '1'},
	$cgi->Tr([
		$cgi->th(['Bacteria name', 'Article Count'])
		]),

		@query_results
	);
}

#possible other searches
print $cgi->p('Do you want to do another search?');
print $cgi->p('Click', a({href => '/cont_query.html'}, 'HERE'));

#clean up
$sth->finish;
$dbh->disconnect;
print $cgi->end_html;

}elsif($output eq "Graphical"){ #if graphical output is rather required

	my $contaminant = $cgi->param('contaminant');
	#prepare query
	my $query = q(SELECT bactname, COUNT(bactname) FROM PM_bacteria WHERE assoc_cont LIKE ? GROUP BY bactname);
	my $query2 = q(SELECT COUNT(*) FROM PM_bacteria2 WHERE bact1 = ? AND bact2 = ? AND assoc_contamin = ?);

	my $sth = $dbh->prepare($query); 
	my $sth2 = $dbh->prepare($query2);

	#run and report query
	my $graph = GraphViz->new(layout =>'twopi', directed => 0, overlap =>'scale');
	$graph->add_node($contaminant, shape => 'octagon', fontsize => '20', style => 'filled', color => '#00ff00');


	$sth->execute($contaminant);

	my @query_results;my $results; my @mics1; my @mics2;
	while (my @results = $sth->fetchrow_array()){
	my $name = $results[0];
	my $numb = $results[1];
	next if $numb <$docs;
	$graph->add_node($results[0]);
	$graph->add_edge($contaminant => $name, label => $numb, URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/search_lit.pl?bacteria=$name;counta=$numb;comp=$contaminant", color => 'green', fontsize =>'18', minilen => '10');
	#push(@query_results, $cgi->Tr( $cgi->td([ $link, $results->[1]])));
	push(@mics1, $name);
	push(@mics2, $name);
	}

for($a=0; $a<scalar(@mics1); $a++){
		for ($b = $a + 1;$b <scalar(@mics2); $b++){
		$sth2->execute($mics1[$a],$mics2[$b],$contaminant);
		my @res = $sth2->fetchrow_array();
		my $count = $res[0];
		next if $count == 0;
		$graph->add_edge($mics1[$a]=>$mics2[$b], style =>'dotted', label => $count , fontsize=> '10',URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/search2_lit.pl?bac1=$mics1[$a];bac2=$mics2[$b];cont=$contaminant;nu=$count");
		}
	}
	
	my $imagedot = $graph->as_canon;
	my $dot_fh = IO::String->new($imagedot);
	my $time = time;
	my $filename = "biodeg1$time";
	my $outfile = "/var/www/html/$filename.dot";
	sysopen (OUTF,$outfile, O_RDWR| O_CREAT | O_TRUNC, 0755) or die "Can't open $outfile for writing: $!\n";
	
	while (my $line = <$dot_fh>){
		print OUTF "$line";
	}
	
	#clean up
	$sth->finish;
	$sth2->finish;
	$dbh->disconnect;
	close OUTF;


#and now display in new window:
print	$cgi->header;
print	$cgi->start_html('Graphic View of Database query for'.$contaminant.'!');
print   $cgi->img ({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print	$cgi->h1("Graph showing results of co-occurence of ".$cgi->b($contaminant)." and relevant bacteria, in PubMed");
print   $cgi->hr();
print   $cgi->a({-href=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.twopi.svg'}, 'Click Here For Interactive Image');
my $bt = $ENV{HTTP_USER_AGENT};
if (index($bt, "MSIE") > -1){print $cgi->br();print $cgi->small("You appear to be using Internet Explorer. Please be adviced that these are SVG images and early versions of Internet Explorer may not support them!");}
print   $cgi->img({-src=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.twopi.svg'});

print   $cgi->end_html;
}



exit;
