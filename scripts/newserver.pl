#!perl
use strict;
use warnings;
use Net::RackSpace::CloudServers;
use Net::RackSpace::CloudServers::Server;


my $user = $ENV{'CLOUDSERVERS_USER'} or die "Need CLOUDSERVERS_USER environment variable set";
my $key  = $ENV{'CLOUDSERVERS_KEY'}  or die "Need CLOUDSERVERS_KEY environment variable set";

my $CS = Net::RackSpace::CloudServers->new(
  user => $user,
  key  => $key,
);
$Net::RackSpace::CloudServers::DEBUG = 0;
my @flavors = $CS->get_flavor_detail;
my @images  = $CS->get_image_detail;
my @servers = $CS->get_server_detail;

if (grep {$_->name eq 'perlmfapitest'} @servers) {
  die "you already have a server named perlmfapitest, quitting\n";
}

## Provision a new server
$Net::RackSpace::CloudServers::DEBUG = 1;
my $srv;
{
  my $tmp = Net::RackSpace::CloudServers::Server->new(
    cloudservers => $CS,
    name         => 'perlmfapitest',
    flavorid     => ( grep { $_->name eq '256 slice' } @flavors )[0]->id,
    imageid      => ( grep { $_->name =~ /jaunty/ } @images )[0]->id,
    status       => undef,
    hostid       => undef,
    progress     => undef,
    public_address => undef,
    private_address => undef,
    metadata => undef,
    adminpass => undef,
    id => 0 ,
  );
  $srv = $tmp->create_server();
}

$Net::RackSpace::CloudServers::DEBUG = 0;
print "Created server ID ", $srv->id, ", root password is: ", $srv->adminpass, "\n";
print "Available at public IP: @{$srv->public_address}\n";

## unusable until ->status will be ACTIVE, from BUILD
do {
  print "Status: ", $srv->status, " progress: ", $srv->progress, "\n";
  my @tmpservers = $CS->get_server_detail();
  $srv = ( grep { $_->name eq 'perlmfapitest' } @tmpservers )[0];
  sleep 5 if ( $srv->status ne 'ACTIVE' );
} while ( $srv->status ne 'ACTIVE' );

print "Server is now built and available!\n";
