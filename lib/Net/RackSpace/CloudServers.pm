package Net::RackSpace::CloudServers;
use warnings;
use strict;
use Moose;
use MooseX::StrictConstructor;
use Net::RackSpace::CloudServers::Flavor;
use Net::RackSpace::CloudServers::Server;
use Net::RackSpace::CloudServers::Image;

#use Data::Stream::Bulk::Callback;
#use DateTime::Format::HTTP;
use LWP::ConnCache::MaxKeepAliveRequests;
use LWP::UserAgent::Determined;
use URI::QueryParam;
use JSON;
use YAML;

our $DEBUG = 0;

has 'user'    => ( is => 'ro', isa => 'Str',            required => 1 );
has 'key'     => ( is => 'ro', isa => 'Str',            required => 1 );
has 'timeout' => ( is => 'ro', isa => 'Num',            required => 0, default => 30 );
has 'ua'      => ( is => 'rw', isa => 'LWP::UserAgent', required => 0 );

has 'server_management_url' => (
  is       => 'rw',
  isa      => 'Str',
  required => 0,
);
has 'storage_url' => (
  is       => 'rw',
  isa      => 'Str',
  required => 0,
);
has 'cdn_management_url' => ( is => 'rw', isa => 'Str', required => 0 );
has 'token'              => ( is => 'rw', isa => 'Str', required => 0 );

no Moose;
__PACKAGE__->meta->make_immutable();

# copied from Net::Mosso::CloudFiles
sub BUILD {
  my $self = shift;
  my $ua   = LWP::UserAgent::Determined->new(
    keep_alive            => 10,
    requests_redirectable => [qw(GET HEAD DELETE PUT)],
  );
  $ua->timing('1,2,4,8,16,32');
  $ua->conn_cache(
    LWP::ConnCache::MaxKeepAliveRequests->new(
      total_capacity          => 10,
      max_keep_alive_requests => 990,
    )
  );
  my $http_codes_hr = $ua->codes_to_determinate();
  $http_codes_hr->{422} = 1;    # used by cloudfiles for upload data corruption
  $ua->timeout( $self->timeout );
  $ua->env_proxy;
  $self->ua($ua);
  $self->_authenticate;
}

sub _authenticate {
  my $self    = shift;
  my $request = HTTP::Request->new(
    'GET',
    'https://auth.api.rackspacecloud.com/v1.0',
    [
      'X-Auth-User' => $self->user,
      'X-Auth-Key'  => $self->key,
    ]
  );
  my $response = $self->_request($request);
  confess 'Unauthorized'  if $response->code == 401;
  confess 'Unknown error' if $response->code != 204;

  my $server_management_url = $response->header('X-Server-Management-Url')
    || confess 'Missing server management url';
  $self->server_management_url($server_management_url);
  my $token = $response->header('X-Auth-Token')
    || confess 'Missing auth token';
  $self->token($token);

  # From the docs:
  # The URLs specified in X-Storage-Url and X-CDN-Management-Url
  # are specific to the Cloud Files product and may be ignored
  # for purposes of interacting with Cloud Servers.

  my $storage_url = $response->header('X-Storage-Url')
    || confess 'Missing storage url';
  $self->storage_url($storage_url);
  my $cdn_management_url = $response->header('X-CDN-Management-Url')
    || confess 'Missing CDN management url';
  $self->storage_url($cdn_management_url);
}

sub _request {
  my ( $self, $request, $filename ) = @_;
  warn $request->as_string if $DEBUG;
  my $response = $self->ua->request( $request, $filename );
  warn $response->as_string if $DEBUG;

  # From the docs:
  # Authentication tokens are typically valid for 24 hours.
  # Applications should be designed to re-authenticate after
  # receiving a 401 Unauthorized response.

  if ( $response->code == 401 && $request->header('X-Auth-Token') ) {

    # http://trac.cyberduck.ch/ticket/2876
    # Be warned that the token will expire over time (possibly as short
    # as an hour). The application should trap a 401 (Unauthorized)
    # response on a given request (to either storage or cdn system)
    # and then re-authenticate to obtain an updated token.
    $self->_authenticate;
    $request->header( 'X-Auth-Token', $self->token );
    warn $request->as_string if $DEBUG;
    $response = $self->ua->request( $request, $filename );
    warn $response->as_string if $DEBUG;
  }

  # From the docs:
  # In the event you exceed the thresholds established for your account,
  # a 413 Rate Control HTTP response will be returned with a
  # Reply-After header to notify the client when they can attempt to
  # try again.
  if ( $response->code == 413 ) {
    my $when = $response->header('Reply-After');
    if ( !defined $when ) {
      $when = 'in about 10 mins';
    } else {
      $when = 'at ' . $when;
    }
    confess "Cannot execute request as rate control limit exceeded; retry ", $when;
  }

  return $response;
}

sub get_server {
  my $self   = shift;
  my $id     = shift;
  my $detail = shift;
  my $uri    = (
      ( defined $detail && $detail )
    ? ( defined $id ? '/servers/' . $id : '/servers/detail' )
    : ( defined $id ? '/servers/' . $id : '/servers' )
  );
  my $request = HTTP::Request->new(
    'GET',
    $self->server_management_url . $uri,
    [ 'X-Auth-Token' => $self->token ]
  );
  my $response = $self->_request($request);
  return if $response->code == 204;
  confess 'Unknown error' if $response->code != 200;
  my @servers;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;

  # {"servers":[{"name":"test00","id":12345}]}

  confess 'response does not contain key "servers"'
    if ( !defined $id && !defined $hash_response->{servers} );
  confess 'response does not contain key "server"'
    if ( defined $id && !defined $hash_response->{server} );
  confess 'response does not contain arrayref of "servers"'
    if ( !defined $id && ref $hash_response->{servers} ne 'ARRAY' );
  confess 'response does not contain hashref of "server"'
    if ( defined $id && ref $hash_response->{server} ne 'HASH' );

  return map {
    Net::RackSpace::CloudServers::Server->new(
      cloudservers    => $self,
      id              => $_->{id},
      name            => $_->{name},
      name            => $_->{name},
      imageid         => $_->{imageId},
      flavorid        => $_->{flavorId},
      hostid          => $_->{hostId},
      status          => $_->{status},
      progress        => $_->{progress},
      public_address  => $_->{addresses}->{public},
      private_address => $_->{addresses}->{private},
      metadata        => $_->{metadata},
      )
  } @{ $hash_response->{servers} } if ( !defined $id );

  my $hserver = $hash_response->{server};
  return Net::RackSpace::CloudServers::Server->new(
    cloudservers    => $self,
    id              => $hserver->{id},
    name            => $hserver->{name},
    imageid         => $hserver->{imageId},
    flavorid        => $hserver->{flavorId},
    hostid          => $hserver->{hostId},
    status          => $hserver->{status},
    progress        => $hserver->{progress},
    public_address  => $hserver->{addresses}->{public},
    private_address => $hserver->{addresses}->{private},
    metadata        => $hserver->{metadata},
  );
}

sub get_server_detail {
  my $self = shift;
  my $id   = shift;
  return $self->get_server( $id, 1 );
}

sub limits {
  my $self    = shift;
  my $request = HTTP::Request->new(
    'GET',
    $self->server_management_url . '/limits',
    [ 'X-Auth-Token' => $self->token ]
  );
  my $response = $self->_request($request);
  return if $response->code == 204;
  confess 'Unknown error' if $response->code != 200;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;

#{"limits":{"absolute":{"maxTotalRAMSize":51200,"maxIPGroupMembers":25,"maxNumServers":25,"maxIPGroups":25},"rate":[{"value":50,"unit":"DAY","verb":"POST","remaining":50,"URI":"\/servers*","resetTime":1247769469,"regex":"^\/servers"},{"value":10,"unit":"MINUTE","verb":"POST","remaining":10,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":600,"unit":"MINUTE","verb":"DELETE","remaining":600,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":10,"unit":"MINUTE","verb":"PUT","remaining":10,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":3,"unit":"MINUTE","verb":"GET","remaining":3,"URI":"*changes-since*","resetTime":1247769469,"regex":"changes-since"}]}}
  confess 'response does not contain key "limits"' if ( !defined $hash_response->{limits} );
  confess 'response does not contain hashref of "limits"'
    if ( ref $hash_response->{limits} ne 'HASH' );

  # return Net::RackSpace::CloudServers::Limits->new(
  #   cloudservers => $self,
  #   limits => $hash_response->{limits}
  # );
}

sub get_flavor {
  my $self   = shift;
  my $id     = shift;
  my $detail = shift;
  my $uri    = (
      ( defined $detail && $detail )
    ? ( defined $id ? '/flavors/' . $id : '/flavors/detail' )
    : ( defined $id ? '/flavors/' . $id : '/flavors' )
  );
  my $request = HTTP::Request->new(
    'GET',
    $self->server_management_url . $uri,
    [ 'X-Auth-Token' => $self->token ]
  );
  my $response = $self->_request($request);
  return if $response->code == 204;
  confess 'Unknown error' if $response->code != 200;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;

  confess 'response does not contain key "flavors"'
    if ( !defined $id && !defined $hash_response->{flavors} );
  confess 'response does not contain key "flavor"'
    if ( defined $id && !defined $hash_response->{flavor} );
  confess 'response does not contain arrayref of "flavors"'
    if ( !defined $id && ref $hash_response->{flavors} ne 'ARRAY' );
  confess 'response does not contain hashref of "flavor"'
    if ( defined $id && ref $hash_response->{flavor} ne 'HASH' );

  return map {
    Net::RackSpace::CloudServers::Flavor->new(
      cloudservers => $self,
      id           => $_->{id},
      name         => $_->{name},
      ram          => $_->{ram},
      disk         => $_->{disk},
      )
  } @{ $hash_response->{flavors} } if ( !defined $id );
  return Net::RackSpace::CloudServers::Flavor->new(
    cloudservers => $self,
    id           => $hash_response->{flavor}->{id},
    name         => $hash_response->{flavor}->{name},
    ram          => $hash_response->{flavor}->{ram},
    disk         => $hash_response->{flavor}->{disk},
  );
}

sub get_flavor_detail {
  my $self = shift;
  my $id   = shift;
  return $self->get_flavor( $id, 1 );
}

sub get_image {
  my $self   = shift;
  my $id     = shift;
  my $detail = shift;
  my $uri    = (
      ( defined $detail && $detail )
    ? ( defined $id ? '/images/' . $id : '/images/detail' )
    : ( defined $id ? '/images/' . $id : '/images' )
  );
  my $request = HTTP::Request->new(
    'GET',
    $self->server_management_url . $uri,
    [ 'X-Auth-Token' => $self->token ]
  );
  my $response = $self->_request($request);
  return if $response->code == 204;
  confess 'Unknown error' if $response->code != 200;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;

  confess 'response does not contain key "images"'
    if ( !defined $id && !defined $hash_response->{images} );
  confess 'response does not contain key "image"'
    if ( defined $id && !defined $hash_response->{image} );
  confess 'response does not contain arrayref of "images"'
    if ( !defined $id && ref $hash_response->{images} ne 'ARRAY' );
  confess 'response does not contain hashref of "image"'
    if ( defined $id && ref $hash_response->{image} ne 'HASH' );

  return map {
    Net::RackSpace::CloudServers::Image->new(
      cloudservers => $self,
      id           => $_->{id},
      name         => $_->{name},
      serverid     => $_->{serverId},
      updated      => $_->{updated},
      created      => $_->{created},
      status       => $_->{status},
      progress     => $_->{progress},
      )
  } @{ $hash_response->{images} } if ( !defined $id );
  return Net::RackSpace::CloudServers::Image->new(
    cloudservers => $self,
    id           => $hash_response->{image}->{id},
    name         => $hash_response->{image}->{name},
    serverid     => $hash_response->{image}->{serverId},
    updated      => $hash_response->{image}->{updated},
    created      => $hash_response->{image}->{created},
    status       => $hash_response->{image}->{status},
    progress     => $hash_response->{image}->{progress},
  );
}

sub get_image_detail {
  my $self = shift;
  my $id   = shift;
  return $self->get_image( $id, 1 );
}

=head1 NAME

Net::RackSpace::CloudServers - Interface to RackSpace CloudServers via API

=head1 SYNOPSIS

  use Net::RackSpace::CloudServers;
  my $cs = Net::RackSpace::CloudServers->new(
    user => 'myusername', key => 'mysecretkey'
  );
  # list my servers;
  my @servers = $cs->get_server;
  foreach my $server ( @servers ) {
    print 'Have server ', $server->name, ' id ', $server->id, "\n";
  }

=head1 METHODS

=head2 new / BUILD

The constructor logs you into CloudServers:

  my $cs = Net::RackSpace::CloudServers->new(
    user => 'myusername', key => 'mysecretkey'
  );

=head2 get_server

Lists all the servers linked to the account. If no ID is passed as parameter, returns an array of
L<Net::RackSpace::CloudServers::Server> object containing only B<id> and B<name> set.
If an ID is passed as parameter, it will return a L<Net::RackSpace::CloudServers::Server> object
containing B<id>, B<name>, B<imageid>, etc. See L<Net::RackSpace::CloudServers::Server> for details.

  my @servers     = $cs->get_server;    # all servers, id/name
  my $test_server = $cs->get_server(1); # ID 1, detailed

=head2 get_server_detail

Lists more details about all the servers and returns them as a L<Net::RackSpace::CloudServers::Server> object:

  my @servers     = $cs->get_server_detail;    # all servers, id/name
  my $test_server = $cs->get_server_detail(1); # ID 1, detailed

=head2 limits

Lists all the limits currently set for the account, and returns them as a L<Net::RackSpace::CloudServers::Limits> object:

  my $limits = $cs->limits;

=head2 get_flavor

Lists all the flavors able to be used. If no ID is passed as parameter, returns an array of
L<Net::RackSpace::CloudServers::Flavor> object containing only B<id> and B<name> set.
If an ID is passed as parameter, it will return a L<Net::RackSpace::CloudServers::Flavor> object
containing B<id>, B<name>, B<ram> and B<disk>.

  my @flavors = $cs->get_flavor;
  foreach (@flavors) { print $_->id, ' ', $_->name, "\n" }

  my $f1 = $cs->get_flavor(1);
  print join(' ', $f1->id, $f1->name, $f1->ram, $f1->disk), "\n";

=head2 get_flavor_detail

Lists details of all the flavors able to be used. If no ID is passed as parameter, returns an
array of L<Net::RackSpace::CloudServers::Flavor>. All details are returned back: B<id>, B<name>,
B<ram> and B<disk>. If an ID is passed as parameter, it will return a L<Net::RackSpace::CloudServers::Flavor>
object with all details filled in.

=head1 AUTHOR

Marco Fontani, C<< <mfontani at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-rackspace-cloudservers at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-RackSpace-CloudServers>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::RackSpace::CloudServers

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-RackSpace-CloudServers>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-RackSpace-CloudServers>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-RackSpace-CloudServers>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-RackSpace-CloudServers/>

=back

=head1 ACKNOWLEDGEMENTS

Léon Brocard for L<Net::Mosso::CloudFiles>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Marco Fontani, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Net::RackSpace::CloudServers
