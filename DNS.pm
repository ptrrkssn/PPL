package PPL::DNS;

use strict;
use warnings;

use Net::DNS;
use Data::Dumper;

use Exporter qw(import);

our @EXPORT = qw(dns_lookup);


our $_dns_res;


sub dns_lookup {
    my ( $name, $q ) = @_;
    my @r;

    $_dns_res = Net::DNS::Resolver->new unless $_dns_res;
    return unless $_dns_res;

    my $dnsq = $_dns_res->search($name, $q);
    return unless $dnsq;

    foreach my $rr ($dnsq->answer) {
	if ($rr->type eq $q) {
	    if ($q eq 'PTR') {
		push @r, $rr->ptrdname;
	    } else {
		push @r, $rr->address;
	    }
	}
    }

    return @r;
}

1;
