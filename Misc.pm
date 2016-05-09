package PPL::Misc;

use Exporter qw(import);

our @EXPORT = qw(abbrev_compare range2str str2range print_array purge_array clean_array in_array);



# 
# ---------- ABBREVIATED COMMANDS COMPARE FUNCTION ----------------------------------------
#
# area
# area-group
#
# a vs area         1
# a vs area-group   0
# a-g vs area       0
# a-g vs area-group 1
#

sub abbrev_compare {
    my ($a, $b) = @_;

    my @av = split('-', $a);
    my @bv = split('-', $b);
    
    my $alen = @av;
    my $blen = @bv;

    return 0 unless $alen == $blen;

    my $nm;
    for (my $i = 0; $i < $alen; $i++) {
	my $len = length($av[$i]);
	$nm++ if ( $av[$i] eq substr($bv[$i], 0, $len) );
    }

    return 1 if $nm == $alen;
    return 0;
}



#
# ---------- RANGE SUPPORT FUNCTIONS ----------------------------------------
#

# XXX Move to PPL

sub range2str {
    my $len = @_;
    my $str;
    for (my $i=0; $i < $len; $i++) {
	my $val = $_[$i];
	my $j;

	for ($j = $i; $j < $len && $_[$j] == $val; $j++) {
	    $val++;
	}
	$j--;

	$str .= ',' if $str;
	if ($_[$i] == $_[$j]) {
	    $str .= $_[$i];
	} else {
	    $str .= "$_[$i]-$_[$j]";
	}
	$i = $j;
    }

    return $str;
}

sub str2range {
    my @range;

    return unless @_;

    foreach (@_) {
	foreach (split(',', $_)) {
	    my $arg = $_;
	    
	    if ($arg =~ /^([0-9]+)-([0-9]+)$/) {
		if ($1 < $2) {
		    for ($1 .. $2) {
			push @range, $_;
		    } 
		} else {
		    for ($2 .. $1) {
			push @range, $_;
		    } 
		}
	    } elsif ($arg =~ /^([0-9]+)$/) {
		push @range, $1;
	    } else {
		return;
	    }
	}
    }
    return sort { $a <=> $b } @range;
}


#
# ---------- ARRAY SUPPORT FUNCTIONS ----------------------------------------
#

# XXX Move to PPL

sub print_array {
    my ($sep, @arr) = @_;
    my $first = 1;
    foreach (@arr) {
	print "$sep" unless $first;
	print $_ if defined $_;
	$first = 0;
    }
    print "\n";
}


# Remove undef'd cells from array
sub purge_array {
    my @out;

    foreach (@_) {
	push @out, $_ if defined $_;
    }

    return @out;
}


# Replace undef' cells with ''
sub clean_array {
    my @out;

    foreach (@_) {
	if (defined $_) {
	    push @out, $_;
	} else {
	    push @out, '';
	}
    }

    return @out;
}

sub in_array {
    my ($val, $arr) = @_;

    foreach (@{$arr}) {
	return 1 if (!defined $val && !defined $_);
	return 1 if (defined $val && defined $_ && $val eq $_);
    }

    return 0;
}

