package PPL::HTML;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(h_str h_print h_h_print h_t_start h_t_end h_th_print h_tr_start h_tr_end h_tr_print h_th_start h_th_end h_td_start h_td_end h_t_print h_a h_a_href h_h h_i h_form_start h_form_end h_input);



sub h_str {
    my ($str, $cgi) = @_;

    return '' unless $str;

    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/"/&quot;/g;

    if ($cgi) {
	$str =~ s/\ /&#32;/g;
	$str =~ s/\+/&#43;/g;
	$str =~ s/\;/&#59;/g;
	$str =~ s/\'/&#39;/g;
    }
    return $str;
}

sub h_print {
    foreach (@_) {
	print h_str($_);
    }
}




my $tr_state;

sub h_t_start {
    my ($class) = @_;

    my $str = "<table";
    $str .= " class=\"".h_str($class)."\"" if $class;
    $str .= ">";

    undef $tr_state;
    
    return $str;
}

sub h_t_end {
    my $str = '';

    if (defined $tr_state) {
	if ($tr_state == 1) {
	    $str .= "</thead>";
	} else {
	    $str .= "</tbody>";
	}
    }

    $str .= "</table>";
    undef $tr_state;
    return $str;
}


sub h_tr_start {
    my ($class) = @_;

    my $str = '';
    if (! defined $tr_state || (defined $class && $class eq 'header')) {
	$str .= "<thead>";
	$class = 'header';
	$tr_state = 1;
    } elsif ($tr_state == 1) {
	$str .= "<tbody>";
	$tr_state = 2;
    }
    $str .= "<tr";
    if (defined $class) {
	$str .= " class=\"".h_str($class)."\"" if $class ne '';
    } else {
	if ($tr_state == 2) {
	    $str .= " class=\"odd\"";
	    $tr_state = 3;
	} else {
	    $str .= " class=\"even\"";
	    $tr_state = 2;
	}
    }
    $str .= ">";

    return $str;
}

sub h_tr_end {
    my $str = '</tr>';

    $str .= "</thead>" if defined $tr_state && $tr_state == 1;

    return $str;
}

sub h_th_start {
    my ($class) = @_;

    my $str = "<th";
    $str .= " class=\"".h_str($class)."\"" if $class;
    $str .= ">";

    return $str;
}

sub h_th_end {
    return "</th>";
}

sub h_td_start {
    my ($class) = @_;

    my $str = "<td";
    $str .= " class=\"".h_str($class)."\"" if $class;
    $str .= ">";

    return $str;
}

sub h_td_end {
    return "</td>";
}


sub null_formatter {
    my ($row, $val, $html) = @_;

    return '' unless defined $val;
    return h_str($val) if $html;
    return $val;
}


sub h_tr_print {
    my $type = ref($_[0]);
    my $tcn = 'td';

    print h_tr_start()."\n";
    $tcn = 'th' if $tr_state == 1;

    if ($type eq 'HASH') {
	my $row   = $_[0];
	my $attrs = $_[1];

	foreach my $k (@{$attrs->{order}}) {
	    my $v = $row->{$k};
	    print "<".$tcn." class=\"".$k."\">";

	    if ($tcn eq 'th') {
		my $fmt = \&null_formatter;
		my $afh = $attrs->{format};
		$fmt = $afh->{TH} if defined $afh && defined $afh->{TH};
		print $fmt->($row, $k, 1, 'table');
	    } else {
		my $fmt = \&null_formatter;
		my $afh = $attrs->{format};
		$fmt = $afh->{$k} if defined $afh && defined $afh->{$k};
		print $fmt->($row, $v, 1, 'table');
	    }

	    print "</".$tcn.">\n";
	}
    } elsif ($type eq 'ARRAY') {
	my @row = $_[0];
	foreach my $v (@row) {
	    print "<".$tcn.">";
	    h_print $v;
	    print "</".$tcn.">\n";
	}
    } else {
	foreach (@_) {
	    print "<".$tcn.">";
	    h_print $_;
	    print "</".$tcn.">\n";
	}
    }

    print h_tr_end()."\n";
}

sub h_th_print {
    undef $tr_state;
    return h_tr_print(@_);
}


sub h_t_print {
    my ( $table, $attrs) = @_;

    print h_t_start($attrs->{name})."\n";

    h_th_print($attrs->{header}, $attrs) if defined $attrs->{header};

    my $start = $attrs->{start};
    $start = 0 unless defined $start;

    my $limit = $attrs->{limit};

    my $n = 0;
    my @t = @$table;
    my $i; 

    foreach $i ($start .. $#t) {
	my $row = $t[$i];

	last if defined $limit && $n >= $limit;
	
	my $f_print = 1;
	
	if (defined $attrs->{filter}) {
	    my $f = $attrs->{filter};
	    foreach (keys %$f) {
		
		my $fmt = \&null_formatter;
		my $afh = $attrs->{format};
		$fmt = $afh->{$_} if defined $afh && defined $afh->{$_};
		my $val = $fmt->($row, $row->{$_}, 0, 'table');
		
		if (defined $f->{$_} && $f->{$_} ne '') {
		    $f_print = 0 if ! defined $val || $val ne $f->{$_};
		} else {
		    $f_print = 0 if defined $val && $val ne '';
		}
	    }
	}
	
	if ($f_print) {
	    h_tr_print($row, $attrs);
	    $n++;
	}
    }
    
    print h_t_end()."\n";
    return $n;
}

sub h_a {
    my ($text, $attrs) = @_;
    my $str = "<a";
    
    foreach (keys %$attrs) {
	my $v = h_str($attrs->{$_});
	$str .= " $_=\"$v\"";
    }
    
    $str .= ">".h_str($text)."</a>";
    return $str;

}

sub h_a_href {
    my ($text, $href, $title) = @_;

    
    return h_a($text, { href => $href, title => $title }) if defined $title;
    return h_a($text, { href => $href });
}

sub h_h {
    my ($n, $title) = @_;

    return "<h$n>".h_str($title)."</h$n>";
}

# Print HTML <Hn> header
sub h_h_print {
    print h_h(@_);
}


sub h_i {
    my ($text) = @_;
    
    return "<i>".h_str($text)."</i>";
}


sub h_form_start {
    my ($action, $method) = @_;

    my $str = "<form";

    $str .= " action=\"".h_str($action)."\"" if $action;
    $str .= " method=\"".h_str($method)."\"" if $method;

    $str .= ">";

    return $str;
}

sub h_input {
    my ($attrs) = @_;

    my $str = "<input";

    foreach my $k (keys %$attrs) {
	if (defined $attrs->{$k}) {
	    $str .= " $k=\"".h_str($attrs->{$k})."\"";
	} else {
	    $str .= " $k";
	}
    }

    $str .= ">";
    return $str;
}

sub h_form_end {
    return "</form>";
}

1;
