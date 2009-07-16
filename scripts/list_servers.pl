#!perl
use strict;
use warnings;
use Net::Mosso::CloudServers;

my $user = $ENV{'CLOUDSERVERS_USER'} or die "Need CLOUDSERVERS_USER environment variable set";
my $key  = $ENV{'CLOUDSERVERS_KEY'}  or die "Need CLOUDSERVERS_KEY environment variable set";

$Net::Mosso::CloudServers::DEBUG = 1;
my $CS = Net::Mosso::CloudServers->new(
  user => $user,
  key  => $key,
);

$CS->servers;

$CS->serversdetails;

