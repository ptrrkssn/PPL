package PPL::DB;

use strict;
use warnings;

use DBI;
use Data::Dumper;

sub open {
    my $class = shift;
    my $n = shift;
    my $u = shift;
    my $p = shift;
    my $h = shift;
    my $a = shift;

    $h = 'localhost' if ! defined $h;
    $a = { AutoCommit => 1, RaiseError => 0, PrintError => 1 } if ! defined $a;

    my $db = DBI->connect("DBI:mysql:database=$n;host=$h", $u, $p, $a);

    my $self = {
	_db_name  => $n,
	_db_user  => $u,
	_db_pass  => $p,
	_db_host  => $h,
	_db_attr  => $a,
	_db       => $db,
	_db_debug => 0,
    };

    bless $self, $class;

    return undef if ! defined $db;
    return $self;
}

sub build_update_from_hash {
    my ( $a, $op ) = @_;
    my @fn;
    my @fv;


    $op = "AND" unless defined $op;

    foreach my $key (keys %$a) {
	if ( defined $a->{$key} ) {
	    my $val = $a->{$key};
	    push @fn, "`$key`=?";
	    push @fv, $val;
	}
    }

    my $q=join(" $op ", @fn);
    return ( $q, \@fv );
}


#
# Build strings and arrays with variables & values suitable for DBI select usage
#
# Example usage:
#
# my $s1 = [ 'TRUE' ];
# my $s2 = [ 'DEFINED', 'size' ];
# my $s3 = [ 'EQ', 'date', '2018-10-10' ];
# my $s4 = [ 'AND', 
# 	   [ 'OR', 
# 	     [ 'GT', 'larts', '200' ],
# 	     [ 'UNDEFINED', 'bread' ],
# 	   ],
# 	   [ 'GT', 'size', '100' ],
# 	   [ 'EQ', 'date', '2018-10-10' ],
# 	   [ 'OR', 
# 	     [ 'NE', 'vlans', '150' ],
# 	     [ 'DEFINED', 'size' ],
# 	   ],
# 	   [ 'TRUE' ],
#     ];
#
# Generates:
#   ( ( `larts` GT ? ) OR ( UNDEFINED `bread` ) ) AND ( `size` GT ? ) AND ( `date` EQ ? ) AND ( ( `vlans` NE ? ) OR ( DEFINED `size` ) ) AND ( TRUE )
#
# Usage:
#   my ($s, $vals) = build_search($s4);
#   my $rs  = $DB->prepare("SELECT * FROM `table` WHERE $s\n\n";
#   my @res = $DB->execute(@$vals);
#
sub build_select_from_array {
    my ( $op, @a ) = @{$_[0]};
    my @s;
    my @vars;
    my @vals;
    my $n=0;

    foreach (@a) {
	my $t = ref($_);
	if ($t eq 'ARRAY') {
	    my ($rs, $rvars, $rvals) = build_search($_);
	    push @vars, @{$rvars};
	    push @vals, @{$rvals};
	    push @s, "( ".$rs." )";
	} else {
	    if ($n == 0) {
		push @s, "`".$_."`";
		push @vars, "`".$_."`";
	    } else {
		push @s, "?";
		push @vals, $_;
	    }
	    $n++;
	}
    }

    if (@s >= 2) {
	return (join(" $op ", @s), \@vars, \@vals);
    } 

    if (@s == 1) {
	return ("$op $s[0]", \@vars, \@vals);
    } 

    return ("$op", \@vars, \@vals);
}



sub str2fields {
    return '*' unless @_;
    return '*' if $_[0] eq '*';

    my @fv;

    if (ref($_[0]) eq 'ARRAY') {
	@fv = @{$_[0]};
    } else {
	@fv = split(',', $_[0]);
    }

    my @res;
    foreach (@fv) {
	if ($_ =~ /`/) {
# Preformatted - push as is
	    push @res, "$_";
	} elsif ($_ =~ /^(.+)\((.+)\)$/) {
# Handle COUNT(id)
	    push @res, "$1(`$2`)";
	} else {
# Plain columns
	    push @res, "`$_`";
	}
    }

    return join(',', @res);
}




#
# Select from database
#
# Inputs:
#   1: table name (string)
#   2: fields of interest (array, comma-separated string or undef (= *)
#   3: 'where'-structure (array of arrays, or hash (default: AND)
#   4: operator (string, change default AND to OR in case of hash)
# 
sub _select {
    my ( $db, $t, $fields, $sel, $op) = @_;
    my @res;
    my ( $rs, $where, $vars, $values );

    my $fs = '*';
    $fs = str2fields($fields) if defined $fields;

    if (defined $sel) {
	if (ref($sel) eq 'HASH') {
	    ( $where, $values ) = build_update_from_hash($sel, $op);
	} elsif (ref($sel) eq 'ARRAY') {
	    ( $where, $vars, $values ) = build_select_from_array($sel);
	} else {
	    return;
	}
    
	return unless $where;
	return unless $values;


	my $st = "SELECT $fs FROM `$t` WHERE ".$where;
	$rs = $db->prepare($st);

	$rs->execute(@$values);
    } else {
	my $st = "SELECT $fs FROM `$t`";
	$rs = $db->prepare($st);

	return unless $rs->execute();
    }

    return $rs;
}


sub _fetchrows_ah {
    my ( $rs ) = @_;
    my @res;

    while (my $row = $rs->fetchrow_hashref()) {
	push @res, $row;
    }

    return @res;
}


sub _fetchrows_aa {
    my ( $rs ) = @_;
    my @res;

    while (my $row = $rs->fetchrow_arrayref()) {
	push @res, $row;
    }

    return @res;
}


sub select {
    my ( $self, $t, $fields, $sel, $op) = @_;
    my @res;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return _fetchrows_ah(rs);
}

sub select_1h {
    my ( $self, $t, $fields, $sel, $op) = @_;
    my @res;


    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    my @res _fetchrows_ah(rs);
    
    return $res[0] if 1 == @res;
    return;
}

sub select_1a {
    my ( $self, $t, $fields, $sel, $op) = @_;
    my @res;


    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    my @res _fetchrows_aa(rs);
    
    return $res[0] if 1 == @res;
    return;
}



sub delete {
    my ( $self, $t, $sel, $op ) = @_;
    my ( $where, $vars, $values );

    
    if (ref($sel) eq 'HASH') {
	( $where, $values ) = build_update_from_hash($sel, $op);
    } elsif (ref($sel) eq 'ARRAY') {
	( $where, $vars, $values ) = build_select_from_array($sel);
    } else {
	return;
    }
    
    my $st = "DELETE FROM `$t` WHERE ".$where;
    my $rs = $self->{_db}->prepare($st);

    print "PPL:DB: SQL: $st (Values: @$values)\n" if $self->{_db_debug};
    return $rs->execute(@$values);
}


#
# Input:
# 
#  1: Table (string)
#  2: Variable assignments (hash)
#  3: 'Where' conditions (array or hash)
#  4: Optional 'op' for hash where condition
#
sub update {
    my ( $self, $t, $set, $sel, $op ) = @_;
    my @res;
    my @sq;
    
    foreach my $key (keys %$set) {
	push @sq, "`$key`=?";
    }
    
    my ( $where, $vars, $values );
    
    if (ref($sel) eq 'HASH') {
	( $where, $values ) = build_update_from_hash($sel, $op);
    } elsif (ref($sel) eq 'ARRAY') {
	( $where, $vars, $values ) = build_select_from_array($sel);
    } else {
	return;
    }

    return unless $where;
    return unless $values;
    
    my $st = "UPDATE `$t` SET ".join(',', @sq)." WHERE ".$where;
    my $rs = $self->{_db}->prepare($st);
    
    print "PPL:DB: SQL: $st\n" if $self->{_db_debug};
    return $rs->execute(values %$set, @{$values});
}


#
# Input:
# 1. Table name (string)
# 2. Field assignments (hash)
# 
sub insert {
    my ( $self, $t, $set ) = @_;

    my @cols;
    foreach (keys %$set) {
	push @cols, "`$_`";
    }

    my $st = "INSERT INTO `$t` ( ".join(',', @cols)." ) VALUES ( ".join(',', ('?') x keys %$set)." )";
    my $rs = $self->{_db}->prepare($st);
    
    print "PPL:DB: SQL: $st\n" if $self->{_db_debug};
    return $rs->execute(values %$set);
}



sub errstr {
    my ( $self ) = @_;
    
    return $self->{_db}->errstr;
}

sub close {
    my ( $self ) = @_;
    return $self->{_db}->disconnect();
}

sub debug {
    my ( $self, $n ) = @_;
    $self->{_db_debug} = $n;
}


#
# Set the DATETIME column to NOW()
#
sub touch_datetime {
    my ( $self, $t, $column, $sel, $op ) = @_;

    my ( @res, @sq );
    my ( $st, $rs, $where, $vars, $values );


    if (defined $sel) {
	if (ref($sel) eq 'HASH') {
	    ( $where, $values ) = build_update_from_hash($sel, $op);
	} elsif (ref($sel) eq 'ARRAY') {
	    ( $where, $vars, $values ) = build_select_from_array($sel);
	} else {
	    return;
	}
    
	return unless $where;
	return unless $values;

	$st = "UPDATE `$t` SET `$column`=NOW() WHERE ".$where;
	$rs = $self->{_db}->prepare($st);

	print "PPL:DB: SQL: $st\n" if $self->{_db_debug};
	return $rs->execute(@$values);
    } else {
	$st = "UPDATE `$t` SET `$column`=NOW()";
	$rs = $self->{_db}->prepare($st);

	print "PPL:DB: SQL: $st\n" if $self->{_db_debug};
	return $rs->execute();
    }
    
}



1;
