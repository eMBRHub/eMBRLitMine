#!/usr/bin/perl
#====================================================================
#Software used during the pre-processing stage of eMBRLitMine to scan titles and abstracts of citation data, 
#establish co-occurence of contaminant and bacteria names, and
#store the relationship data in a mySQL database. 
#Chijoke Elekwachi, MyCIB, Univ of Nottingham. UK, 2009
#====================================================================
use strict;
use warnings;
use DBI;
#use library in place of DBD::MySQL (if driver doesn't load)
use lib'/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';
use DBI;
#use DBD::mysql;


#retrieve names of bacteria and contaminants (from relevant lexicon), store in arrays
my $bactfilename = "processed_unique_bactnames.txt"; #file containing bacteria names
my $contaminantname = "processed_cont23.txt"; #file containing contaminants
my $keywords = "biorem_keywords.txt"; #file containing keywords
my @bact_names = get_data($bactfilename);
my @bact2_names = get_data($bactfilename); #bacteria names array created twice for subsequent use
my @cont_names = get_data($contaminantname);
my @keywords = get_data($keywords);

#Data clean up; for check, never happens, as list is continuous 
my $element; my $element2; my $cont; my $ke;
foreach $element (@bact_names){
		#print "item is NULL\n" unless $element; 
		if ($element){chomp $element; }
		#print "$element\n";
	}
#print "@bact_names\n";
foreach $element2 (@bact2_names){
		#print "item is NULL\n" unless $element;
		if ($element2){chomp $element2;}
		#print "$element2\n";
	}

foreach $cont (@cont_names){
		if ($cont){chomp $cont;}
		#print "$cont\n";
	}

foreach $ke (@keywords){
		if ($ke){chomp $ke;}
		#print "$ke\n";
	}


#Define details for mySQL database:
my $ds = "DBI:mysql:xxxxx:localhost"; #replace xxxxx with actual database name
my $user = "root";
my $passwd = "xxxxx"; #use actual password for your database

#connect to database, prepare and execute SQL
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#prepare query to obtain
my $sth = $dbh->prepare("SELECT pmid, title, abstract FROM PM_text"); 
$sth->execute;

#arrays to hold pmid, title and abstract
my @abst_listing;
my @abst_PMID;

my $checkw; my $word;
while (my @abstracts = $sth->fetchrow_array()){
		chomp $abstracts[0]; #to maintain array lengths
		chomp $abstracts[1];
		chomp $abstracts[2];
		$abstracts[2] =~ s/\n//;
		my $comp_abstracts = "$abstracts[1] $abstracts[2]"; #combining 'title' and 'abstracts'
		($checkw, $word) = check_words($comp_abstracts);#check keywords file
		if ($checkw eq "matched"){  # print "$checkw\tword: $word\n";
		push(@abst_PMID,$abstracts[0]);
		push(@abst_listing,$comp_abstracts);
		}
	}
 
$sth->finish;


my $sizep = scalar@abst_PMID;
my $sizea = scalar@abst_listing;

#sql queries for database inserts
my $sth2 = $dbh->prepare("INSERT INTO PM_bacteria (bactname, assoc_cont, pm_id) VALUES (?,?,?)");
my $sth3 = $dbh->prepare("INSERT INTO PM_cont (cont_name, pmed_id) VALUES (?,?)");
my $sth4 = $dbh->prepare("INSERT INTO PM_bacteria2 (bact1, bact2, assoc_contamin, pmd_id)VALUES (?,?,?,?)");

#
#use nested 'for' loops
my $a; my $b1; my $c; my $b2; 

for ($a=0; $a<= scalar(@abst_listing); $a++){
	print "Abstract no: ".$a."\n";
	for ($c=0; $c<= scalar(@cont_names); $c++){
		if($abst_listing[$a] =~ m/\Q$cont_names[$c]\E/i){
			#print "match found (compound): ".$cont_names[$c]."\n";
			for($b1=0; $b1<= scalar(@bact_names); $b1++){
				if($abst_listing[$a] =~ m/$bact_names[$b1]/i){
					#insert into database(PM_bacteria);
				#	print "Full match found: comp: ".$cont_names[$c]."\tBacteria: ".$bact_names[$b1]."\n";
					$sth2->execute($bact_names[$b1],$cont_names[$c],$abst_PMID[$a]);
					for($b2=0; $b2<=scalar(@bact2_names); $b2++){
						if($abst_listing[$a] =~ m/$bact2_names[$b2]/i){
							#print "2nd match: ".$cont_names[$c]."\t1st bact: ".$bact_names[$b1]."2nd bact2: ".$bact_names[$b2]."\n";
							next if $bact_names[$b1] eq $bact2_names[$b2]; #not an interaction
							#insert in database (PM_bacteria2)
							$sth4->execute($bact_names[$b1],$bact2_names[$b2],$cont_names[$c],$abst_PMID[$a]);
							}
						}										
					}
				}
			}
		}
	}

$sth2->finish;
$sth3->finish;
$sth4->finish;
$dbh->disconnect;


#######################################################
#subs here
#######################################################


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

sub check_words{
	my ($listing) = @_;
	my $code; my $kw;my $place;

	foreach my $kw(@keywords){
		chomp $kw;
		if($listing =~ /$kw/i){
			$code = "matched";
			$place = $kw;
			#print "$kw\n";
			last;	
			}else{$code = "unmatched"; $place = "unmatched keyword";}
	}
return ($code, $place);
}
