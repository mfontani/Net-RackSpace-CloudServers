package Net::Mosso::CloudServers::Flavor;
use warnings;
use strict;
use Moose;
use MooseX::StrictConstructor;

has 'cloudservers' => ( is => 'rw', isa => 'Net::Mosso::CloudServers', required => 1 );
has 'id' => ( is => 'ro', isa => 'Int', required => 1 );
has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'ram' => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'disk' => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );

no Moose;
__PACKAGE__->meta->make_immutable();

=head1 NAME

Net::Mosso::CloudServers::Flavor - a Mosso/RackSpace CloudServers Flavor

=head1 SYNOPSIS

  use Net::Mosso::CloudServers;
  use Net::Mosso::CloudServers::Flavor;
  my $cs = Net::Mosso::CloudServers->new( user => 'myusername', key => 'mysecretkey' );
  my $flavor = Net::Mosso::CloudServers::Flavor->new(
    cloudservers => $cs,
    id => '1', name => 'test', ram => 5, disk => 10,
  );
  # get list: 
  my @flavors = $cs->flavors;
  foreach my $flavor ( @flavors ) {
    print 'Have flavor ', $flavor->name, ' id ', $flavor->id, "\n";
  }
  # get detailed list
  my @flavors = $cs->flavors(1);
  foreach my $flavor ( @flavors ) {
    print 'Have flavor ', $flavor->name, ' id ', $flavor->id,
      ' ram ', $flavor->ram, ' disk ', $flavor->disk,
      "\n";
  }

=head1 METHODS

=head2 new / BUILD

The constructor creates a Flavor:

  my $flavor = Net::Mosso::CloudServers::Flavor->new(
    cloudserver => $cs
    id => 'id', name => 'name',
  );
  
This normally gets created for you by L<Net::Mosso::Cloudserver>'s L<flavors> or L<flavorsdetails> methods.
Needs a Net::Mosso::CloudServers::Flavor object.

=head2 id

The id is used for the creation of new cloudservers

=head2 name

The name which identifies the flavor

=head2 ram

How much RAM does this flavor have

=head2 disk

How much disk space does this flavor have

=head1 AUTHOR

Marco Fontani, C<< <mfontani at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-mosso-cloudservers at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Mosso-CloudServers>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Mosso::CloudServers::Flavor

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

1;    # End of Net::Mosso::CloudServers::Flavor
