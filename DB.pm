package PPL::DB;

use strict;
use warnings;

use DBI;
use Data::Dumper;

# type://user:pass@host/name
#
# mysql://user:pass/name  (host=localhost)
# mysql://user@host/name  (pass=none)
# mysql://user/name       (pass=none, host=localhost)
# mysql:name
#
sub uri2tok {
    my ($uri) = @_;
    my ($type, $user, $pass, $host, $name);

    my $r = $uri;

    # Get database type (default: mysql)
    if ($r =~ /^([^:]+):(.+)/i) {
	$type = $1;
	$r = $2;
    }

    # Handle '//user:pass@host/name'
    if ($r =~ /\/\/([^\/]+)\/(.+)/i) {
	my $uph = $1;
	$name = $2;

	# Handle '[user[:pass]][@host]'
	if ($uph =~ /([^@]+)@(.+)/i) {
	    my $up = $1;
	    $host = $2;

	    # Handle 'user[:pass]'
	    if ($up =~ /([^:]+):(.*)/i) {
		$user = $1;
		$pass = $2;
	    } else {
		$user = $up;
	    }

	} else {
	    if ($uph =~ /([^:]+):(.*)/i) {
		$user = $1;
		$pass = $2;
	    } else {
		$user = $uph;
	    }
	}
    } else { 
	if ($r =~ /([^\/]+)\/(.*)/i) {
	    my $up = $1;
	    $name = $2;

	    # Handle 'user[:pass]'
	    if ($up =~ /([^:]+):(.*)/i) {
		$user = $1;
		$pass = $2;
	    } else {
		$user = $up;
	    }
	} else {
	    $name = $r;
	}
    }

    $name =~ s/^\/+//;
    
    return ($type, $user, $pass, $host, $name);
}

sub open {
    my $class = shift;
    my $uri = shift;
    my $a = shift;

    my ($t, $u, $p, $h, $n) = uri2tok($uri);
    $t = "mysql" unless defined $t;

    $h = 'localhost' if ! defined $h;
    $a = { AutoCommit => 1, RaiseError => 0, PrintError => 1 } if ! defined $a;

    my $db = DBI->connect("DBI:$t:database=$n;host=$h", $u, $p, $a);

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


sub select_h {
    my ( $self, $t, $fields, $sel, $op) = @_;
    my @res;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return unless $rs;

    return _fetchrows_ah($rs);
}


sub select {
    my ( $self, $t, $fields, $sel, $op) = @_;
    return select_h($self, $t, $fields, $sel, $op);
}


sub select_a {
    my ( $self, $t, $fields, $sel, $op) = @_;
    my @res;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return unless $rs;

    return _fetchrows_aa($rs);
}




sub select_1h {
    my ( $self, $t, $fields, $sel, $op) = @_;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return unless $rs;

    my @res = _fetchrows_ah($rs);

    # Make sure a single row is returned
    return unless 1 == @res;

    return $res[0];
}

sub select_1a {
    my ( $self, $t, $fields, $sel, $op) = @_;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return unless $rs;

    my $res = $rs->fetchrow_arrayref();
    return unless $res;

    return if $rs->fetchrow_arrayref();
    
    return @$res;
}


# 
# Select and return a single colum from a single row, else 'undef'
#
sub select_1v {
    my ( $self, $t, $fields, $sel, $op) = @_;

    my $rs = _select($self->{_db}, $t, $fields, $sel, $op);
    return unless $rs;


    # Get result row
    my $row = $rs->fetchrow_arrayref();

    return unless $row;

    # Make sure a single row is returned
    return if $rs->fetchrow_arrayref();

    # Make sure a single column is returned
    return unless 1 == @$row;

    return @{$row}[0];
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


sub _run {
    my $db = $_[0];
    shift;

    my $statement = $_[0];
    shift;

    my $rs = $db->prepare($statement);

    $rs->execute(@_) if $rs;
    return $rs;
}


sub run {
    my $self = $_[0];
    shift;
    my $statement = $_[0];
    shift;

    my $rs = _run($self->{_db}, $statement, @_);
    return unless defined $rs;

    return _fetchrows_ah($rs);
}


sub run_1v {
    my $self = $_[0];
    shift;
    my $statement = $_[0];
    shift;

    my $rs = _run($self->{_db}, $statement, @_);

    # Get result row
    my $row = $rs->fetchrow_arrayref();

    return unless $row;

    # Make sure a single row is returned
    return if $rs->fetchrow_arrayref();

    # Make sure a single column is returned
    return unless 1 == @$row;

    return @{$row}[0];
}

# Quote table/column identifiers
sub qi {
    my ( $self, $id ) = @_;

    return $self->{_db}->quote_identifier($id);
}

1;
