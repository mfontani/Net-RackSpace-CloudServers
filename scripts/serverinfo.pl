#!perl
use strict;
use warnings;
use Net::RackSpace::CloudServers;

my $user = $ENV{'CLOUDSERVERS_USER'} or die "Need CLOUDSERVERS_USER environment variable set";
my $key  = $ENV{'CLOUDSERVERS_KEY'}  or die "Need CLOUDSERVERS_KEY environment variable set";

$Net::RackSpace::CloudServers::DEBUG = 1;
my $CS = Net::RackSpace::CloudServers->new(
  user => $user,
  key  => $key,
);

my @flavors = $CS->get_flavor_detail;
my @images  = $CS->get_image_detail;
my @servers = $CS->get_server_detail;

print '#' x 72, "\n";

foreach my $server (@servers) {
  print "Server ID ", $server->id, " Name ", $server->name, "\n";
  print "Server status ", $server->status || 'undef', " progress ", $server->progress || 'undef',
    "\n";
  print "Public IPs: ",  join( ' ', @{ $server->public_address  || () } ), "\n";
  print "Private IPs: ", join( ' ', @{ $server->private_address || () } ), "\n";
  my $img = ( grep { $_->id == $server->imageid } @images )[0];    # find image by id
  die "Can't find image ID ", $server->imageid, " on list" if ( !defined $img );
  print "Image ID ", $server->imageid, " (", $img->name, ")",
    " status ", $img->status || 'undef', " progress ", $img->progress || 'undef', "\n";
  my $flv = ( grep { $_->id == $server->flavorid } @flavors )[0];    # find flavor by id
  die "Can't find flavor ID ", $server->flavorid, " on list" if ( !defined $flv );
  print "Flavor ID ", $server->flavorid, " (", $flv->name, ")",
    " ram ", $flv->ram || 'undef', " disk ", $flv->disk || 'undef', "\n";
}
