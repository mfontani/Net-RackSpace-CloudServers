package Net::RackSpace::CloudServers::Server;
use warnings;
use strict;
our $DEBUG = 0;
use Moose;
use MooseX::StrictConstructor;
use HTTP::Request;
use JSON;
use YAML;

has 'cloudservers'    => ( is => 'rw', isa => 'Net::RackSpace::CloudServers', required => 1 );
has 'id'              => ( is => 'ro', isa => 'Int',                          required => 1 );
has 'name'            => ( is => 'ro', isa => 'Str',                          required => 1 );
has 'imageid'         => ( is => 'ro', isa => 'Maybe[Int]',                   required => 1 );
has 'flavorid'        => ( is => 'ro', isa => 'Maybe[Int]',                   required => 1 );
has 'hostid'          => ( is => 'ro', isa => 'Maybe[Str]',                   required => 1 );
has 'status'          => ( is => 'ro', isa => 'Maybe[Str]',                   required => 1 );
has 'adminpass'       => ( is => 'ro', isa => 'Maybe[Str]',                   required => 1 );
has 'progress'        => ( is => 'ro', isa => 'Maybe[Str]',                   required => 1 );
has 'public_address'  => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]',         required => 1 );
has 'private_address' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]',         required => 1 );
has 'metadata'        => ( is => 'ro', isa => 'Maybe[HashRef]',               required => 1 );

no Moose;
__PACKAGE__->meta->make_immutable();

sub change_root_password {
  my $self     = shift;
  my $password = shift;
  my $uri      = '/servers/' . $self->id;
  my $request  = HTTP::Request->new(
    'PUT',
    $self->cloudservers->server_management_url . $uri,
    [
      'X-Auth-Token' => $self->cloudservers->token,
      'Content-Type' => 'application/json',
    ],
    to_json( { server => { adminPass => $password, } } )
  );
  my $response = $self->cloudservers->_request($request);
  confess 'Unknown error' if $response->code != 202;
  return $response;
}

sub change_name {
  my $self    = shift;
  my $name    = shift;
  my $uri     = '/servers/' . $self->id;
  my $request = HTTP::Request->new(
    'PUT',
    $self->cloudservers->server_management_url . $uri,
    [
      'X-Auth-Token' => $self->cloudservers->token,
      'Content-Type' => 'application/json',
    ],
    to_json( { server => { name => $name, } } )
  );
  my $response = $self->cloudservers->_request($request);
  confess 'Unknown error' if $response->code != 202;
  return $response;
}

sub create_server {
  my $self = shift;
  my $request = HTTP::Request->new(
    'POST',
    $self->cloudservers->server_management_url . '/servers',
    [
      'X-Auth-Token' => $self->cloudservers->token,
      'Content-Type' => 'application/json',
    ],
    to_json({
      server => {
        name     => $self->name,
        imageId  => int $self->imageid,
        flavorId => int $self->flavorid,
      }
    })
  );
  my $response = $self->cloudservers->_request($request);
  confess 'Unknown error' if $response->code != 202;
  my $hash_response = from_json( $response->content );
  warn Dump($hash_response) if $DEBUG;
  confess 'response does not contain key "server"'
    if ( !defined $hash_response->{server} );
  confess 'response does not contain hashref of "server"'
    if ( ref $hash_response->{server} ne 'HASH' );
  my $hserver = $hash_response->{server};
  return __PACKAGE__->new(
    cloudservers    => $self->cloudservers,
    adminpass       => $hserver->{adminPass},
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

=head1 NAME

Net::RackSpace::CloudServers::Server - a RackSpace CloudServers Server instance

=head1 SYNOPSIS

  use Net::RackSpace::CloudServers;
  use Net::RackSpace::CloudServers::Server;
  my $cs = Net::RackSpace::CloudServers->new( user => 'myusername', key => 'mysecretkey' );
  my $server = Net::RackSpace::CloudServers::Server->new(
    cloudservers => $cs,
    id => '1', name => 'test',
  );
  # get list: 
  my @servers = $cs->get_server;
  foreach my $server ( @servers ) {
    print 'Have server ', $server->name, ' id ', $server->id, "\n";
  }
  # get detailed list
  my @servers = $cs->get_server_detail();
  foreach my $server ( @servers) {
    print 'Have server ', $server->name, ' id ', $server->id,
      # ...
      "\n";
  }

  ## Create server from template
  my $tmp = Net::Rackspace::CloudServer::Server->new(
    cloudservers => $cs, name => 'myserver',
    flavor => 2, image => 8,
    # others
  );
  my $srv = $tmp->create_server;
  print "root pass: ", $srv->adminpass, " IP: @{$srv->public_address}\n";

=head1 METHODS

=head2 new / BUILD

The constructor creates a Server object, see L<create_server> to create a server instance from a template:

  my $server = Net::RackSpace::CloudServers::Server->new(
    cloudserver => $cs
    id => 'id', name => 'name',
  );
  
This normally gets created for you by L<Net::RackSpace::Cloudserver>'s L<get_server> or L<get_server_detail> methods.
Needs a Net::RackSpace::CloudServers object as B<cloudserver> parameter.

=head2 create_server

This creates a real server based on a Server template object (TODO: will accept all the other build parameters).

=head2 change_name

Changes the server's name to the new value given. Dies on error, or returns the response

  $srv->change_name('newname');

=head2 change_root_password

Changes the server's root password to the new value given. Dies on error, or returns the response

  $srv->change_root_password('toor');

=head1 ATTRIBUTES

=head2 id

The id is used for the creation of new cloudservers

=head2 name

The name which identifies the server

=head2 adminpass

When newly built ONLY, the automatically generated password for root

=head2 imageid

The ID of the L<Net::RackSpace::CloudServer::Image> from which the server has been created

=head2 flavorid

The ID of the L<Net::RackSpace::CloudServer::Flavor> the server is currently running as

=head2 hostid

An ID which univocally identifies a server on your account. May not be unique across accounts.

=head2 status

The status of the server: building, etc

=head2 progress

The progress of the current B<status> operation: 60%, etc.

=head2 public_address

Arrayref containing the list of public addresses the server is configured to use

=head2 private_address

Arrayref containing the list of private addresses the server is configured to use

=head2 metadata

Hashref containing any metadata that has been set for the server

=head1 AUTHOR

Marco Fontani, C<< <mfontani at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-rackspace-cloudservers at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-RackSpace-CloudServers>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::RackSpace::CloudServers::Server

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

=head1 COPYRIGHT & LICENSE

Copyright 2009 Marco Fontani, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Net::RackSpace::CloudServers::Server
