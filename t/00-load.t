#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::RackSpace::CloudServers' );
}

diag( "Testing Net::RackSpace::CloudServers $Net::RackSpace::CloudServers::VERSION, Perl $], $^X" );
