#!/usr/bin/perl -w

# This is a perl front end to run dot as a web service.
# To install, set the perl path above, and configuration paths below:
# $Tdir, $SigCommand, $GraphvizBinDir

# This script takes as an argument the URL of a dot (graph) file with
# the name of a graphviz layout server and an output type as suffixes.
# The argument can be passed in the PATH_INFO environment variable as
# in a typical Apache setup, or as a command line argument for manual
# testing. 
# 
# The server must be: dot, neato, or twopi.(or fdp or circo as introduced 
# in a patch(Ryan Schmidt, 2009)
# The output type must be one of dot's output types.  The server
# returns a layout of the requested type as an HTTP stream.  The dot
# output # type is mapped to an appropriate MIME type.
# For example, if yourhost.company.com/unix.dot is a dot graph file, try
# webdot.cgi http://yourhost.company.com/unix.dot.dot.ps
# webdot.cgi http://yourhost.company.com/unix.dot.neato.gif
# webdot.cgi http://yourhost.company.com/unix.dot.twopi.pdf
#
# More details:
# PDF and EPSI files are made by postprocessors.
#
# The server maintains a cache directory of dot files and layouts.
# The server always pulls the dot file, but doesn't bother with layout
# if its cache is valid.  This is checked using $SigCommand on the dot source
# (typically md5 or at least cksum).
#
# The cache should be cleaned externally, for example by a cron job.
# When testing, remember to clobber cache entries manually as needed.
#
# If we thought users were going to request many layouts of the same
# graph but in different layout formats, we might just cache the layout
# in canonical dot format, and run neato -nop for code generation.
#
# The first version of this script was written in tclsh by John Ellson
# and had some additional features for tclet integration, background
# images, and a "Graph by Webdot" logo in each image; they are not
# included here. 
#
# Thanks to John Linderman for perl hacking. --Stephen North
# 
#

use strict;
use FileHandle;
use Fcntl ':flock';
use File::Path qw( mkpath );
use LWP;

# bugs:
# need to test imap, ismap, svg
# vrml requires its own subdir?

# set $Tdir to the webdot cache directory.  note that this script must have
# write permission on the directory when it is run by your web server.
# for example apache's default httpd.conf specifies that CGI programs such
# as this one run as user 'nobody'.  in that case the cache directory must
# be writable by 'nobody' - either mode 0777 or chown to nobody.
#my $Tdir = '/home/north/public_html/tmp/'; ## the original one
my $Tdir = 'http://psbmsc03.nottingham.ac.uk/cgi-bin';

# set $GraphvizBinDir to the dot/neato/twopi standalone command directory.
# DotFontPath shouldn't be necessary, but our graphviz installation is broken.
#my $DotFontPath = '/home/north/lib/fonts/dos/windows/fonts';
my $DotFontPath = '/usr/share/X11/fonts/TTF';


#my $GraphvizBinDir = '/home/north/arch/linux.i386/bin'; ## Originally
#my $GraphvizBinDir = '/usr/lib/perl5/vendor_perl/5.8.8/'; #or
my $GraphvizBinDir = '/usr/bin/';

# set $EPSIfilter to the script that maps Postscript into epsi.
my $EPSIfilter = '/usr/bin/ps2epsi';

# set $GS to Ghostscript - must be compiled with -sDEVICE=pdfwrite enabled!
my $GS = '/usr/bin/gs';

# set $SigCommand to the path of your signature utility.  if you don't have md5,
# you could likely use GNU cksum or just /usr/bin/sum in a pinch.
# my $SigCommand = '/usr/local/SSLeay-0.9.0b/bin/md5';  for www.research.att.com
my $SigCommand = '/usr/bin/cksum';
# or '/usr/bin/md5sum'

# set 

my %KnownTypes = (
	dot =>    'application/x-dot',
	gif =>    'image/gif',
	png =>    'image/png',
	mif =>    'application/x-mif',
	hpgl =>   'application/x-hpgl',
	pcl =>    'application/x-pcl',
	vrml =>   'x-world/x-vrml',
	vtx =>    'application/x-vtx',
	ps =>     'application/postscript',
	epsi =>   'application/postscript',
	pdf =>    'application/pdf',
	map =>    'text/plain',
	cmapx =>  'text/plain',
	txt =>    'text/plain',
	src =>    'text/plain',
	svg =>	  'image/svg+xml', ##included following (Ryan Schmidt, 2009)
);

my %KnownServers = ( 'dot' => 1, 'neato' => 1, 'twopi' => 1, 'circo' => 1, 'fdp' => 1 );

# What content type is returned.  Usually $KnownTypes{$tag},
# but not always.
#my $ContentType = 'text/plain'; #changed this for test. REMEMBER.
#my $ContentType = 'image/svg+xml';  ##also changed REMEMBER.
my $tag;
my $ContentType = $KnownTypes{$tag};

# What is returned.  In good times, the results of running dot,
# (and maybe a postprocessor), in bad times, an apologetic message.
my $TheGoods = 'Server Error, profound apologies';

# Arrange to return an error message
sub trouble {
    $TheGoods = shift;
    $ContentType = 'text/plain';
}


sub run_under_lock {
    my ($fh, $cmd) = @_;
    my $rc;

    flock($fh, LOCK_EX);	# Upgrade to exclusive lock
    truncate($fh, 0);		# Make sure file is empty
    $rc = system($cmd);		# Run command to load file
    unless ($rc == 0) {
	trouble("Server error: Non-zero exit $rc from $cmd\n");
	return;
    }
    flock($fh, LOCK_SH);	# Downgrade to shared lock
    return 1;
}

sub up_doc {
    my ($base, $url, $layouter, $tag) = @_;
    my $dotdir = "$Tdir/$layouter/$base";
    my $dotfile = "$dotdir/source";
    my $tagfile = "$dotdir/$tag";
    my $dotfh = new FileHandle;
    my $tagfh = new FileHandle;
    my $fh = new FileHandle;
    my ($size, $mtime, $cmd, $webdoc, $content);
    my ($ttime, $rc);
    my $now = time();
    my ($oldsig, $newsig);

    unless (-d $dotdir) {
	unless (mkpath( [ $dotdir ], 0, 02775)) {
	    trouble("Server error: Unable to make directory $dotdir: $!");
	    return;
	}
    }
    unless (open($dotfh, "+>> $dotfile")) {
	trouble("Server error: Open failed on $dotfile: $!");
	return;
    }
    flock($dotfh, LOCK_SH);
    ($size, $mtime) = (stat($dotfh))[7,9];
    # if($size > 0) { $oldsig = `$SigCommand $dotfile`; }
    $oldsig = ($size > 0? `$SigCommand $dotfile` : 0);

		# Can anyone tell me why http://blabla was changed to http:/blabla
		# and why I have to fix it this way? SCN  3/22/2006
		$url =~ s%(http[s]?:/)([^/])%$1/$2%;
    my $browser = LWP::UserAgent->new();   ## Create a virtual browser
    $browser->agent("Kipper Browser");     ## Name it
    ## Do a GET request on the URL with the fake browser
    $webdoc = $browser->request(HTTP::Request->new(GET => $url));
    if($webdoc->is_success){ ## found it 
	$content = $webdoc->content();
	flock($dotfh, LOCK_EX);
	truncate($dotfh, 0);
	print $dotfh $content;
	$dotfh->autoflush();
	flock($dotfh, LOCK_SH);
	($size, $mtime) = (stat($dotfh))[7,9];
    } else {                 ## did not find it
	trouble("Server error: Could not find $url\n");
	return;
    }

    ($size, $mtime) = (stat($dotfh))[7,9];
    # if (($size == 0) || ((($now - $mtime)/(60*60)) > $SourceHours)) { }
    unless ($size) {
	trouble("Empty dot source\n");
	return;
    }
    unless (open($tagfh, "+>> $tagfile")) {
	trouble("Server error: Open failed on $tagfile: $!");
	return;
    }
    flock($tagfh, LOCK_SH);
    ($size, $ttime) = (stat($tagfh))[7,9];
    $newsig = `$SigCommand $dotfile`;
    if (($size == 0) || ($oldsig ne $newsig)) {
	my $dottag = $tag;
	my $tmpfile;
	my $tmpfh;
	if (($tag eq 'epsi') || ($tag eq 'pdf')) {
	    $dottag = 'ps';
	    $tmpfile = "$dotdir/ps";
	    $tmpfh = new FileHandle;
	    unless (open($tmpfh, "+>> $tmpfile")) {
		trouble("Server error: Open failed on $tmpfile: $!");
		return;
	    }
	} else {
	    $tmpfile = $tagfile;
	    $tmpfh = $tagfh;
	}
	$cmd = "DOTFONTPATH=\"$DotFontPath\" $GraphvizBinDir/$layouter -T$dottag < $dotfile > $tmpfile";
	return unless (run_under_lock($tmpfh, $cmd));
	## might have to postprocess ps into epsi or pdf
	if ($tag eq 'epsi') {
		$cmd = "$EPSIfilter < $tmpfile > $tagfile";
		return unless (run_under_lock($tagfh, $cmd));
	} elsif ($tag eq 'pdf') {
		# need BoundingBox
		my @box;
		open(EPS, "<$tmpfile") or
			trouble "webdot: Cannot open $tmpfile for reading", return;
		while(<EPS>) {
			if(/^%%BoundingBox:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$/) {
				@box = ($1, $2, $3, $4);
				last;
			}
		}
		unless( @box ) {
			trouble "webdot: I didn't find a valid boundingbox in $tmpfile";
			return;
		}
		$cmd = "$GS -dDEVICEWIDTHPOINTS=$box[2] -dDEVICEHEIGHTPOINTS=$box[3] -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$tagfile $tmpfile";
		return unless (run_under_lock($tagfh, $cmd));
	}
    }
    seek($tagfh,0,0);
    {
	local($/);	# slurp mode
	$TheGoods = <$tagfh>;
    }
    1;
}


sub get_dot {
    my $urltag = shift;
    my ($url, $base, $layouter, $tag);

    # if ($urltag =~ /^(.+)[.]([^.]+)$/) 
    if ($urltag =~ /^(.+)[.]([^.]+)[.]([^.]+)$/) {
	($url, $layouter, $tag) = ($1, $2, $3);
	unless ($KnownServers{$layouter}) {
	    trouble("Unknown layout service $layouter from $url\n");
	    return;
	}
	unless ($ContentType = $KnownTypes{$tag}) {
	    trouble("Unknown tag type $tag from $url\n");
	    return;
	}
	# ($base = $url) =~ s:/:-:g;
	($base = $url) =~ s%[/:]%-%g;	# remember to make safe for PC's. ##Added this from patch if nt good cleave
	$base = $url;
	$base =~ s%[/:]%-%g;  ##remember to make safe for PC's
	# trouble("I see: '$base' '$url' '$layouter' '$tag' \n"); return;
	up_doc($base, $url, $layouter, $tag);
    } else {
	trouble("Unknown url format: $url\n");
    }
}


sub show_results {
    my $size = length($TheGoods);

    print <<EOF ;
Content-type: $ContentType;
Content-length: $size
Pragma: no-cache

EOF
    print($TheGoods);
}


sub main {
    my $arg;
    if ($arg = ($ENV{'PATH_INFO'})) {
	    $arg =~ s:/::;
	    $arg =~ s%^/%%;			# strip initial
	    $arg =~ s%(^[^:]+:/)([^/])%$1/$2%;	# reinstate double slash before hostname if web server removed it
	}
	else  {
		$arg = $ARGV[0];
	}
    get_dot($arg);
    show_results();
}
main();