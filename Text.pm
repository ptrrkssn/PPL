package PPL::Text;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(t_t_print);


sub null_formatter {
    my ($row, $val) = @_;
    return '' unless defined $val;
    return $val;
}


#
# print array of data in a nice way
#
sub t_t_print {
    my ( $table, $attrs) = @_;

    my $f_limit  = $attrs->{limit};
    my $f_border = $attrs->{border};

    my @columns  = @{$attrs->{order}};

    my $width;


# Check size of header column names
    foreach (@columns) {
	my $n = $attrs->{header}{$_};
	$n = $_ unless $n;
	$width->{$_} = length($n);
    }

    my $n = 0;
    foreach (@{$table}) {
	my $row = $_;
	
	last if ($f_limit && $n++ >= $f_limit);

# Check size of each cell value
	foreach (@columns) {
	    my $v = $row->{$_};

	    my $fmt = \&null_formatter;
	    my $afh = $attrs->{format};
	    $fmt = $afh->{$_} if defined $afh && defined $afh->{$_};

	    my $len = length($fmt->($row, $v));
	    $width->{$_} = $len if $len > $width->{$_};
	}
    }

# Calculate the total width of the list with all columns
    my $maxlen = -3;

    foreach (@columns) {
	my $len = $width->{$_};
	$maxlen += (5+$len);
    }


# Print header
    if ($f_border) {
	print "+-";
	my $first_col = 1;
	foreach (@columns) {
	    my $len = $width->{$_};
	    print "-+-" unless $first_col;
	    print "-" x $len;
	    $first_col = 0;
	}
	print "-+";
	print "\n";
    }

    print "|" if $f_border;
    print " ";
    my $first_col = 1;
    foreach (@columns) {
	my $len = $width->{$_};
	print " | " unless $first_col;
	my $n = $attrs->{header}{$_};
	$n = $_ unless $n;
	printf "%-${len}s", $n;
	$first_col = 0;
    }
    print " ";
    print "|" if $f_border;
    print "\n";
    
    
    print "+" if $f_border;
    print "-";
    $first_col = 1;
    foreach (@columns) {
	my $len = $width->{$_};
	print "-+-" unless $first_col;
	print "-" x $len;
	$first_col = 0;
    }
    print "-";
    print "+" if $f_border;
    print "\n";


# Loop through array of objects
    $n = 0;
    foreach (@{$table}) {
	my $row = $_;
	my $i;

	last if ($f_limit && $n++ >= $f_limit);

	print "|" if $f_border;
	print " ";
	my $first_col = 1;

# Print data columns
	foreach (@columns) {
	    print " | " unless $first_col;

	    my $v = $row->{$_};
	    my $len = $width->{$_};

	    my $fmt = \&null_formatter;
	    my $afh = $attrs->{format};
	    $fmt = $afh->{$_} if defined $afh && defined $afh->{$_};

	    printf "%-${len}s", $fmt->($row, $v);
	    $first_col = 0;
	}
	print " ";
	print "|" if $f_border;
	print "\n";
    }

    if ($f_border) {
	print "+-";
	$first_col = 1;
	foreach (@columns) {
	    my $len = $width->{$_};
	    print "-+-" unless $first_col;
	    print "-" x $len;
	    $first_col = 0;
	}
	print "-+";
	print "\n";
    }

    return 0;
}



1;
