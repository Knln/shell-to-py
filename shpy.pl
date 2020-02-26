#!/usr/bin/perl

use warnings;

my @content = ();
my @words = ();
my $indent = 0;
my $nestedif = 0;
my %declaredvariables = ();

if(@ARGV gt 0){
    foreach my $arg (@ARGV){
	readArgs($arg);
    }
} else {
    stdin();
}

sub readArgs {
   my $filename = $_[0];
   open(FILE, "<$_[0]") or die "./shpy.pl: $_[0] can't open\n";
   foreach my $line ( <FILE> ){
	transform($line);
	#then we need to print the transformed line somewhere...
   }
   my $line = "#!/usr/bin/python2.7 -u\n";
   push @content, $line;
   open(OUT, ">$filename.output") or die "Can't open $filename.\n";
   print OUT @content;
   close(OUT);
   close(FILE);
}

sub stdin {
    foreach my $line ( <STDIN> ){
	transform($line);
    }
    my $line = "#!/usr/bin/python2.7 -u\n";
    unshift @content, $line;
    print @content;
}

sub transform {
    my $line = $_[0];
    $line =~ s/^\s*//;
    $line = substitutiontable($line);

    if ($line =~ /#!\/bin/) {
    } elsif ($line =~ /^\s*$/){
    } elsif ($line =~ /^\#/){
	push @content, $line;
    } elsif ($line =~ /echo/){
	printfunction($line);
    } elsif ($line =~ /^\s*\w+\s*\=\s*.+\s*$/){
	declarationfunction($line);
    } elsif ($line =~ /^\s*cd.*$/){
	cdfunction($line);
    } elsif ($line =~ /for.*$/){
	forfunction($line);
    } elsif ($line =~ /do\s*$/){
	dofunction($line);
    } elsif ($line =~ /done\s*$/){
	donefunction($line);
    } elsif ($line =~ /exit/){
	my $sys = "import sys\n";
	if (!grep(/^import sys$/, @content)){ 
	    unshift @content, $sys;
	}
	exitfunction($line);
    } elsif ($line =~ /read/){
	my $sys = "import sys\n";
	if (!grep(/^import sys$/, @content)){ 
	    unshift @content, $sys;
	}
	readfunction($line);
    } elsif ($line =~ /^\s*[^a-z]*if\s+/){
	iffunction($line);
	dofunction();
    } elsif ($line =~ /^\s*while/){
	iffunction($line);
    } elsif ($line =~ /^\s*elif/){
	donefunction();
	iffunction($line);
	dofunction();
    } elsif ($line =~ /^\s*else\s*$/){
	donefunction();
	for (1..$indent){
	    $line = indentfunctionline($line);
	}
	$line =~ s/else/else:/;
	push @content, $line;
	dofunction();
    } elsif ($line =~ /^\s*then\s*$/){
    } elsif ($line =~ /^\s*fi\s*$/){
	donefunction();
    } elsif ($line =~ /subprocess/){
	push @content, $line;
    } else {
	my $subprocess = "import subprocess\n";
	if (!grep(/^import subprocess$/, @content)){ 
	    unshift @content, $subprocess;
	}
	my @words = split(' ', $line);
	foreach my $word (@words){
	    if ($word eq $words[$#words]){
		$word = "\'$word\'";
	    } else {
		$word = "\'$word\',";
	    }
	}
	$line = "subprocess.call([@words])\n";
        for (1..$indent){
	    $line = indentfunctionline($line);
        }
	push @content, $line;
    }
}

sub dofunction {
    $indent += 1;
}

sub donefunction {
    $indent = $indent - 1;
}

sub indentfunctionlist {
    my @words = @_;
    s/^/    / for (@words);
    return @words;
}

sub indentfunctionline {
    my $line = $_[0];
    $line =~ s/^/    /;
    return $line;
}

sub iffunction {
    my $line = $_[0];
    my @words = split(' ', $line);
    my $iforelif = shift(@words);
    foreach my $word (@words){
	if (($word eq "\[") || ($word eq "test")){
	    $word =~ s/.*//;
	} elsif ($word =~ /^\=$/){
	    $word =~ s/\=/\=\=/g;
	} elsif ($word eq "\]"){
	    pop(@words);
	} elsif ($word =~ /\./) {
	} elsif ($word =~ /\(.*\)/){
	} elsif ($word =~ /\!|<|>/){
	} elsif ($word =~ /[0-9]/){ 
	} else {
	    $word = "\'$word\'";
	}
    }
    unshift @words, $iforelif;
    $words[$#words] =~ s/$/:/;
    @words = join(" ", @words);    
    for (1..$indent){
	@words = indentfunctionlist(@words);
    }
    push @words, "\n";
    push @content, @words;
}

sub printfunction {
    my $line = $_[0];
    my $chomp = 0;
#    while (my ($find, $replace) =  each %declaredvariables){
#	eval "\$line =~ s{$find}{$replace}";
#    }
    if ($line =~ /echo\s+\-n/){
	$chomp = 1;
	$line =~ s/\-n//;
    }
    if ($line =~ /\'.*\s{2,}.*\'/){
	$line =~ s/echo/print/;
	for (1..$indent){
	    $line = indentfunctionline($line);
        }
	push @content, $line;
	return;
    }
    my @words = split(' ', $line);
    my $singlequote = 2;
    my $echoonce = 0;
    foreach my $word (@words) {
	if ($word =~ /\'/ || $word =~ /\"/){
	    $singlequote += 1;
	    next;
	}
	if (!($singlequote % 2 == 0)){
	    next;
	}
	if ($word =~ /echo/ && $echoonce == 0){ #HANDLES THE ECHO
	    $word = "print";
	    $echoonce = 1;
	} elsif ($word eq $words[$#words]) {
	    if (($word =~ /^\$/) || ($word =~ /^sys/)){
		$word = "$word";
		$word =~ s/\$//;
	    } elsif (($word =~ /\".*/) || ($word =~ /.*\"/)){
		#do nothing
	    } else {
		$word = "\'$word\'";
	    }
	} else {
	    if (($word =~ /^\$/) || ($word =~ /^sys/)){
		$word = "$word,";
		$word =~ s/\$//;
	    } elsif (($word =~ /\".*/) || ($word =~ /.*\"/)){
		#do nothing
	    } else {
		$word = "\'$word\',";
	    }
	}
    }
    @words = join(" ", @words);
    for (1..$indent){
	@words = indentfunctionlist(@words);
    }
    if ($chomp eq 0){
	push @words, "\n";
    }
    push @content, @words;
}

sub declarationfunction {
    my $line = $_[0];
    $line =~ /\s*(.*)\s*=\s*(.*)\s*/;
    my ($variable, $variablevalue) = ($1,$2);
    $declaredvariables{$variable} = $variablevalue;
    if ($line =~ /subprocess/){
	push @content, $line;
	return;
    }

    if (!($line =~ /[0-9]+/)){ 
	$line =~ s/\s*(.*)\s*=\s*(\w+)\s*$/$1 \= \'$2\'\n/;
    }
    if ($line =~ /sys\.arg/){
	$line =~ s/\'//g;
    }
    if ($line =~ /\$/){
	if ($line =~ /\$\(\(.*\)\)/){
	    $line =~ s/\(//g;
	    $line =~ s/\)//g;
	}
	$line =~ s/\$//g;
	$line =~ s/\'//g;
    }
    for (1..$indent){
	$line = indentfunctionline($line);
    }
    push @content, $line;
}

sub cdfunction {
    my $os = "import os\n";
    if (!grep(/^import os$/, @content)){ 
	unshift @content, $os;
    }
    my $line = $_[0];
    my @words = split(' ', $line);
    foreach my $word (@words){
	if($word =~ /cd/){
	    shift(@words);
	}
    }
    @words = join(" ", @words);
    $line = "os.chdir(\'@words\')\n";
    for (1..$indent){
	$line = indentfunctionlist($line);
    }
    push @content, $line;
}

sub forfunction {
    my $line = $_[0];
    my @words = split(' ', $line);
    foreach my $word (@words){
	if(($word eq $words[0]) || ($word eq $words[1]) || ($word eq $words[2])){
	} elsif ($word eq $words[$#words]) {
	    if ($word =~ /^\d+/){
		$word = "$word:";
	    } else {
		$word = "\'$word\':";
	    }
	} else {
	    if ($word =~ /^\d+/){
		$word = "$word,";
	    } else {
		$word = "\'$word\',";
	    }
        }
    }
    @words = join(" ", @words);
    for (1..$indent){
	@words = indentfunctionlist(@words);
    }
    push @words, "\n";
    push @content, @words;
}

sub exitfunction {
    my $line = $_[0];
    my @words = split(' ', $line);
    my $number = $words[1];
    $line = "sys.exit($number)\n";
    for (1..$indent){
	$line = indentfunctionline($line);
    }
    push @content, $line;
}

sub readfunction {
    my $line = $_[0];
    my @words = split(' ', $line);
    my $word = $words[1];
    $line = "$word = sys.stdin.readline().rstrip()\n";
    for (1..$indent){
	$line = indentfunctionline($line);
    }
    push @content, $line;
}

sub substitutiontable {
    my $line = $_[0];
    $line =~ s/\-le/<\=/g;
    $line =~ s/\-gt/>/g;
    $line =~ s/\-eq/\=\=/g;
    $line =~ s/\-lt/</g;
    $line =~ s/\-ge/\=>/g;
    $line =~ s/\-ne/!\=/g;
    $line =~ s/\-o/or/g;
    if ($line ne $_[0]) {
	$line =~ s/\$(\w+)/int($1)/g;
    }

    if ($line =~ /\$\d+/){
	my $sys = "import sys\n";
	if (!grep(/^import sys$/, @content)){ 
	    unshift @content, $sys;
	}
	$line =~ s/\$(\d+)/sys\.argv\[$1\]/g;
    }
    if ($line =~ /`expr.*`/){
	$line =~ s/`expr.*(\$\w+)/int($1)/;
	$line =~ s/`//g;
    } elsif ($line =~ /`(.*)`/) {
	my $temp = $&;
	$temp =~ s/`//g;
	my @temparray = split(' ', $temp);
	foreach $temp (@temparray){
	    if ($temparray[$#temparray] eq $temp){
		$temp = "\'$temp\'";
	    } else {
		$temp = "\'$temp\',";
	    }
	}
	@temparray = join(' ', @temparray);
	$line =~ s/`.*`/subprocess.call([@temparray])/g;
    } 
    if ($line =~ /\"?(\$\@)\"?/){
	$line =~ s/\$\@/sys.argv[1:]/g;
    } 
    if ($line =~ /\"?(\$\#)\"?/){
	$line =~ s/\$\#/len(sys.argv[1:])/g;
    } 
    if ($line =~ /\"?(\$\*)\"?/){
	$line =~ s/\$\*/len(sys.argv[1:])/g;
    }

    my $bracket = 0;
    if ($line =~ /^\s*[^a-z]*if\s+\[/){
	$bracket = 1;
    }
    if ($line =~ /(\*\.)/){
	my $glob = "import glob\n";
	if (!grep(/^import glob$/, @content)){ 
	    unshift @content, $glob;
	}
	if ($bracket eq 0){
	    $line =~ s/(\*\.\d+)/sorted(glob.glob(\"$1\"))/;
	} else {
	    $line =~ s/(\*\.\d+)\s+]/sorted(glob.glob(\"$1\")) ]/;
	}
    }
    if ($line =~ /(\-r)/){
	my $os = "import os\n";
	if (!grep(/^import os$/, @content)){ 
	    unshift @content, $os;
	}
	if ($bracket eq 0){
	    $line =~ s/\-r\s+(.*)/os.access('$1', os.R_OK)/;
	} else {
	    $line =~ s/\-r\s+(.*)\s+]/os.access('$1', os.R_OK) ]/;
	}
    } 

    if ($line =~ /(\-d)/){
	my $ospath = "import os.path\n";
	if (!grep(/^import os\.path$/, @content)){ 
	    unshift @content, $ospath;
	}
	if ($bracket eq 0){
	    $line =~ s/\-d\s+(.*)/os.path.isdir('$1')/;
	} else {
	    $line =~ s/\-d\s+(.*)\s+]/os.path.isdir('$1') ]/;
	}
    } 

    return ($line);
}
