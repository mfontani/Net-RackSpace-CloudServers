package Net::Mosso::CloudServers::Server;
use warnings;
use strict;
use Moose;
use MooseX::StrictConstructor;

has 'cloudservers'    => ( is => 'rw', isa => 'Net::Mosso::CloudServers', required => 1 );
has 'id'              => ( is => 'ro', isa => 'Int',                      required => 1 );
has 'name'            => ( is => 'ro', isa => 'Str',                      required => 1 );
has 'imageid'         => ( is => 'ro', isa => 'Maybe[Int]',               required => 1 );
has 'flavorid'        => ( is => 'ro', isa => 'Maybe[Int]',               required => 1 );
has 'hostid'          => ( is => 'ro', isa => 'Maybe[Str]',               required => 1 );
has 'status'          => ( is => 'ro', isa => 'Maybe[Str]',               required => 1 );
has 'progress'        => ( is => 'ro', isa => 'Maybe[Str]',               required => 1 );
has 'public_address'  => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]',     required => 1 );
has 'private_address' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]',     required => 1 );
has 'metadata'        => ( is => 'ro', isa => 'Maybe[HashRef]',           required => 1 );

no Moose;
__PACKAGE__->meta->make_immutable();

=head1 NAME

Net::Mosso::CloudServers::Server - a Mosso/RackSpace CloudServers Server instance

=head1 SYNOPSIS

  use Net::Mosso::CloudServers;
  use Net::Mosso::CloudServers::Server;
  my $cs = Net::Mosso::CloudServers->new( user => 'myusername', key => 'mysecretkey' );
  my $server = Net::Mosso::CloudServers::Server->new(
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

=head1 METHODS

=head2 new / BUILD

The constructor creates a Server:

  my $server = Net::Mosso::CloudServers::Server->new(
    cloudserver => $cs
    id => 'id', name => 'name',
  );
  
This normally gets created for you by L<Net::Mosso::Cloudserver>'s L<get_server> or L<get_server_detail> methods.
Needs a Net::Mosso::CloudServers object as B<cloudserver> parameter.

=head2 id

The id is used for the creation of new cloudservers

=head2 name

The name which identifies the server

=head2 imageid

The ID of the L<Net::Mosso::CloudServer::Image> from which the server has been created

=head2 flavorid

The ID of the L<Net::Mosso::CloudServer::Flavor> the server is currently running as

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

Please report any bugs or feature requests to C<bug-net-mosso-cloudservers at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Mosso-CloudServers>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Mosso::CloudServers::Server

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

1;    # End of Net::Mosso::CloudServers::Server
