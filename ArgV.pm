package PPL::ArgV;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $s = shift;
    my $a = shift;

    $s =~ s/^\s+|\s+$//g;

    my $self = { 
	_av_input => $s,
	_av_attrs => $a,
    };

    bless $self, $class;
    return $self;
}


# TODO: Handle \ 

sub token {
    my ( $self ) = @_;

    $self->{_av_input} =~ s/^\s+//g;
    return unless $self->{_av_input};

    my $q = ($self->{_av_input} =~ /^(["']).*/);

    my $s = '';
    while ($self->{_av_input} =~ /^\S/) {
	if ($self->{_av_input} =~ /^(["']).*/) {
	    if ($self->{_av_input} =~ m/^$1([^$1]*)$1(.*)/) {
		$s .= $1;
		$self->{_av_input} = $2;
	    } else {
		$self->{_av_input} =~ s/^["']//;
		$s .= $self->{_av_input};
		$self->{_av_input} = '';
	    }
	} else {
	    if ($self->{_av_input} =~ m/^([^\s"']*)(["'\s].*)$/) {
		$s .= $1;
		$self->{_av_input} = $2;
	    } else {
		$s .= $self->{_av_input};
		$self->{_av_input} = '';
	    }
	}
    }

    $self->{_av_input} =~ s/^\s+//g;
    return ( $s, $q );
}


sub parse {
    my ( $self ) = @_;
    my @argv;

    while (my ( $s, $q ) = $self->token()) {
	if ($self->{_av_attrs}{QuoteMagic} && $q) {
	    push @argv, '=';
	}
	push @argv, $s;
    }

    return @argv;
}


1;
