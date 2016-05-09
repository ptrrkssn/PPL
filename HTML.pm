package PPL::HTML;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(h_str h_print h_h_print h_t_start h_t_end h_th_print h_tr_print h_t_print);




sub h_str {
    my $first = 1;

    my $res = '';

    foreach (@_) {
	$res .= '<br>' unless $first;
	$first = 0;
	next unless defined $_;

	my $s = $_;
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;
	$res .= $s;
    }

    return $res;
}

sub h_print {
    print h_str(@_);
}

# Print HTML <Hn> header
sub h_h_print {
    my $n = $_[0];
    shift;

    print '<h'.$n.'>';
    h_print @_;
    print '</h'.$n.'>'."\n";
}




my $tr_state;

sub h_t_start {
    print '<table class="'.$_[0].'">'."\n";
    undef $tr_state;
}

sub h_t_end {
    print '</table>'."\n";
}


sub null_formatter {
    my ($row, $val) = @_;

    return '' unless defined $val;
    return h_str($val);
}


sub h_tr_print {
    my $type = ref($_[0]);
    my $tcn = 'td';;

    if (!defined $tr_state || length($tr_state) > 1) {
	print '<tr class="header">';
	$tr_state = 0;
	$tcn = 'th';
    } elsif ($tr_state == 1) {
	print '<tr class="odd">';
	$tr_state = 0;
    } else {
	print '<tr class="even">';
	$tr_state = 1;
    }


    if ($type eq 'HASH') {
	my $row   = $_[0];
	my $attrs = $_[1];

	foreach my $k (@{$attrs->{order}}) {
	    my $v = $row->{$k};
	    print '<'.$tcn.' class="'.$k.'">';

	    my $fmt = \&null_formatter;
	    my $afh = $attrs->{format};
	    $fmt = $afh->{$k} if defined $afh && defined $afh->{$k} && $tcn eq 'td';
	    print $fmt->($row, $v);
	    print '</'.$tcn.'>';
	}
	print '</tr>'."\n";
	return;
    } elsif ($type eq 'ARRAY') {
	my @row = $_[0];
	foreach my $v (@row) {
	    print '<'.$tcn.'>';
	    h_print $v;
	    print '</'.$tcn.'>';
	}
	print '</tr>'."\n";

    } else {
	foreach (@_) {
	    print '<'.$tcn.'>';
	    h_print $_;
	    print '</'.$tcn.'>';
	}
    }

    print '</tr>'."\n";
}

sub h_th_print {
    $tr_state = $_[0];
    shift;
    return h_tr_print(@_);
}


sub h_t_print {
    my ( $table, $attrs) = @_;

    h_t_start($attrs->{name});

    h_th_print($attrs->{name}, $attrs->{header}, $attrs) if defined $attrs->{header};

    foreach (@$table) {
	h_tr_print($_, $attrs);
    }

    h_t_end();
}

1;
