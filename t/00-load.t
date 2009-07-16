#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::Mosso::CloudServers' );
}

diag( "Testing Net::Mosso::CloudServers $Net::Mosso::CloudServers::VERSION, Perl $], $^X" );
