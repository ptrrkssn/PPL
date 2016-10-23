package PPL::LiUPF;

use Exporter qw(import);

our @EXPORT = qw(dirname propagate);


# Propagate role inheritance down the group tree (nodes or users)

sub propagate {
    my ($table, $obj) = @_;

    my $type = $table;
    $type =~ s/_group//;

    print STDERR "PROPAGATE ${table} (starting at group name=$obj->{name}, role=$obj->{role})\n";

    return unless defined $obj;

    my $r = $obj->{role};
    $r = $obj->{i_role} unless defined $r;

    print STDERR "  PROPAGATE FROM $obj->{name}, ROLE=$r\n";

    # Get list of sub-groups one level down
    my @sglist = $db->run("SELECT * FROM `${table}` WHERE `name` LIKE ? AND `name` NOT LIKE ?", 
			  "$obj->{name}/%", "$obj->{name}/%/%");
    return unless 0 < @sglist;

    foreach my $sg (@sglist) {
	print STDERR "    PROPAGATE role=$r TO ${table} $sg->{name} AND ${type} in group\n";
	$db->run("UPDATE `${table}` SET `i_role`=? WHERE `id`=?", $r, $sg->{id});
	$db->run("UPDATE `${type}` SET `i_role`=? WHERE `group`=?", $r, $sg->{id});
	
	# Stop at node_groups with set role, unless force flag is set.
	propagate($table, $sg) unless defined $sg->{role} && !$f_force;
    }
}

# ----------------------------------------------------------------------

sub dirname {
    my $n = $_[0];
    
    return $1 if $n =~ /^(.*)\//;
    return;
}

# ----------------------------------------------------------------------
