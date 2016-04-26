package PPL::DB;

use strict;
use warnings;

use DBI;

sub open {
    my $class = shift;
    my $n = shift;
    my $u = shift;
    my $p = shift;
    my $h = shift;
    my $a = shift;

    $h = 'localhost' if ! defined $h;
    $a = { RaiseError => 0, PrintError => 1 } if ! defined $a;

    my $db = DBI->connect("DBI:mysql:database=$n;host=$h", $u, $p, $a);

    return undef if ! defined $db;

    my $self = {
	_db_name => $n,
	_db_user => $u,
	_db_pass => $p,
	_db_host => $h,
	_db_attr => $a,
	_db      => $db,
    };

    bless $self, $class;
    return $self;
}

sub hash_prepare {
    my $a = $_[0];
    my @fn;
    my @fv;
    
    foreach my $key (keys %$a) {
	if (defined($a->{$key})) {
	    push @fn, "`$key`=?";
	    push @fv, $a->{$key};
	}
    }
    my $q=join(' AND ', @fn);

    return ( $q, \@fv );
}

sub select {
    my ( $self, $t, $m ) = @_;
    my @res;
    
    my ( $mq, $mf ) = hash_prepare($m);
    return undef unless $mq;
    return undef unless $mf;
    
    my $st = "SELECT * FROM `$t` WHERE ".$mq;
    my $rs = $self->{_db}->prepare($st);

    my $rc = $rs->execute(@$mf);
    return undef if !$rc;
    
    while (my $row = $rs->fetchrow_hashref()) {
	push @res, $row;
    }

    return @res;
}

sub insert {
    my ( $self, $t, $s ) = @_;

    my $st = "INSERT INTO `$t` ( ".join(',', keys %$s)." ) VALUES ( ".join(',', ('?') x keys %$s)." )";
    my $rs = $self->{_db}->prepare($st);
    
    return $rs->execute(values %$s);
}

sub delete {
    my ( $self, $t, $s ) = @_;
    
    my ( $sq, $sf ) = hash_prepare($s);
    
    my $st = "DELETE FROM `$t` WHERE ".$sq;
    my $rs = $self->{_db}->prepare($st);
    return $rs->execute(@$sf);
}

sub update {
    my ( $self, $t, $s, $m ) = @_;
    my @res;
    my @sq;

    foreach my $key (keys %$s) {
	push @sq, "`$key`=?";
    }
    
    my ( $mq, $mf ) = db_hash_prepare($m);
    return undef unless $mq;
    return undef unless $mf;

    my $st = "UPDATE `$t` SET ".join(',', @sq)." WHERE ".$mq;
    my $rs = $self->{_db}->prepare($st);
    
    return $rs->execute(values %$s, values %$m);
}


sub errstr {
    my ( $self ) = $_;

    return DBI::errstr if (!$self);
    return $self->{_db}->errstr;
}

sub close {
    my ( $self ) = @_;
    return $self->{_db}->disconnect();
}

1;
