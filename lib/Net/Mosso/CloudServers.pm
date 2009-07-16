package Net::Mosso::CloudServers;
use warnings;
use strict;
use Moose;
use MooseX::StrictConstructor;
use Data::Stream::Bulk::Callback;
use DateTime::Format::HTTP;
use LWP::ConnCache::MaxKeepAliveRequests;
use LWP::UserAgent::Determined;
use URI::QueryParam;
use JSON;
use YAML;

our $DEBUG = 0;

has 'user'    => ( is => 'ro', isa => 'Str', required => 1 );
has 'key'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'timeout' => ( is => 'ro', isa => 'Num', required => 0, default => 30 );
has 'ua'      => ( is => 'rw', isa => 'LWP::UserAgent', required => 0 );

has 'server_management_url' => (
  is => 'rw',
  isa => 'Str',
  required => 0,
);
has 'storage_url' => (
  is => 'rw',
  isa => 'Str',
  required => 0,
);
has 'cdn_management_url' => ( is => 'rw', isa => 'Str',            required => 0 );
has 'token'       => ( is => 'rw', isa => 'Str',            required => 0 );


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
  $http_codes_hr->{422} = 1; # used by cloudfiles for upload data corruption
  $ua->timeout( $self->timeout );
  $ua->env_proxy;
  $self->ua($ua);
  $self->_authenticate;
}

sub _authenticate {
  my $self = shift;
  my $request = HTTP::Request->new(
    'GET',
    'https://auth.api.rackspacecloud.com/v1.0',
    [
      #'Host'        => 'auth.api.rackspacecloud.com',
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
  return $response;
}

sub servers {
  my $self = shift;
  my $request = HTTP::Request->new(
    'GET', $self->server_management_url . '/servers',
    [ 'X-Auth-Token' => $self->token ]
  );
  my $response = $self->_request($request);
  return if $response->code == 204;
  confess 'Unknown error' if $response->code != 200;
  my @servers;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;
  # {"servers":[{"name":"test00","id":12345}]}
  confess 'response does not contain key "servers"' if (!defined $hash_response->{servers});
  confess 'response does not contain arrayref of "servers"' if (ref $hash_response->{servers} ne 'ARRAY');
  my @response_servers = @{ $hash_response->{servers} };
  foreach my $hserver ( @{ $hash_response->{servers} } ) {
    #push @servers,
    #  Net::Mosso::CloudServers::Server->new(
    #    id   => $hserver->{id},
    #    name => $hserver->{name}
    #  );
    warn "Name: ", $hserver->{name}, " id: ", $hserver->{id} if ($DEBUG);
  }
  return @servers;
}

=head1 NAME

Net::Mosso::CloudServers - Interface to Mosso/RackSpace CloudServers via API

=head1 SYNOPSIS

  use Net::Mosso::CloudServers;
  my $cs = Net::Mosso::CloudServers->new(
    user => 'myusername', key => 'mysecretkey'
  );
  # list my servers;
  my @servers = $cs->servers;
  foreach my $server ( @servers ) {
    print 'Have server ', $server->name, ' id ', $server->id, "\n";
  }

=head1 AUTHOR

Marco Fontani, C<< <mfontani at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-mosso-cloudservers at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Mosso-CloudServers>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Mosso::CloudServers

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Mosso-CloudServers>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Mosso-CloudServers>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Mosso-CloudServers>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Mosso-CloudServers/>

=back

=head1 ACKNOWLEDGEMENTS

Leon Brocard for L<Net::Mosso::CloudFiles>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Marco Fontani, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::Mosso::CloudServers
