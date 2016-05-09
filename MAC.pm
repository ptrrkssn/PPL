package PPL::MAC;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT = qw(mac_get mac_equal);

sub mac_get {
    my $mac = $_[0];

# 0:01:2:03:04:5 -> 00:01:02:03:04:05
# 0-01-2-03-04-5 -> 00:01:02:03:04:05
    if ($mac =~ /^([0-9a-f]{1,2})[:-]([0-9a-f]{1,2})[:-]([0-9a-f]{1,2})[:-]([0-9a-f]{1,2})[:-]([0-9a-f]{1,2})[:-]([0-9a-f]{1,2})$/i) {
	return sprintf "%02x:%02x:%02x:%02x:%02x:%02x", hex $1, hex $2, hex $3, hex $4, hex $5, hex $6;
    }

# 000102-030405 -> 00:01:02:03:04:05
    if ($mac =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})-([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i) {
	return sprintf "%02x:%02x:%02x:%02x:%02x:%02x", hex $1, hex $2, hex $3, hex $4, hex $5, hex $6;
    }

# 0001.0203.0405 -> 00:01:02:03:04:05
    if ($mac =~ /^([0-9a-f]{2})([0-9a-f]{2})\.([0-9a-f]{2})([0-9a-f]{2})\.([0-9a-f]{2})([0-9a-f]{2})$/i) {
	return sprintf "%02x:%02x:%02x:%02x:%02x:%02x", hex $1, hex $2, hex $3, hex $4, hex $5, hex $6;
    }

# 0102030405 -> 00:01:02:03:04:05
    if ($mac =~ /^([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$/i) {
	return sprintf "%02x:%02x:%02x:%02x:%02x:%02x", hex $1, hex $2, hex $3, hex $4, hex $5, hex $6;
    }

    return;
}


sub mac_equal {
    my ($a, $b) = @_;

    return mac_get($a) eq mac_get($b);
}
