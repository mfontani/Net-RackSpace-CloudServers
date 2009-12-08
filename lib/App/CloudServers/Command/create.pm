package App::CloudServers::Command::create;
use strict;
use warnings;
use 5.010_000;
use App::CloudServers -command;
use Net::RackSpace::CloudServers;

sub abstract { 'creates servers' }

sub usage_desc { "%c create %o" }

sub opt_spec {
  return (
    [ 'name|n=s', 'specify the new server\'s name' ],
    [
      'wait|w!', '(default) wait until the server has been successfully created', { default => 1 }
    ],
    [ 'imageid|i=i',    'specify the ID of the image used to create the server' ],
    [ 'imagename|I=s',  'specify the name of the image used to create the server' ],
    [ 'flavorid|f=i',   'specify the ID of the flavor used to create the server' ],
    [ 'flavorname|F=s', 'specify the name of the flavor used to create the server' ],
    [ 'metadata|m=s%', 'specify max 5 255B string metadata keys/values', { default => {} } ],
    [ 'path|p=s%',   'specify max 5 10kB max files to be pushed to the server', { default => {} } ],
    [ 'groupid|g=s', 'specify shared ip group ID for server',                   { default => '' } ],
    [ 'user', 'specify cloudservers API user, instead of $ENV{CLOUDSERVERS_USER}' ],
    [ 'key',  'specify cloudservers API key, instead of $ENV{CLOUDSERVERS_KEY}' ],
    [ 'verbose', 'show more information', { default => 0 } ],
    [ 'help|h',  'get help for this command' ],
  );
}

sub validate_args {
  my ( $self, $opt, $args ) = @_;
  die $self->_usage_text if $opt->{help};
  use YAML;
  warn '*' x 72, "\n", "Options specified: ", Dump($opt), '*' x 72, "\n";
  $self->usage_error("use --user or defined \$ENV{CLOUDSERVERS_USER} to use this command\n")
    if ( !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER} );
  $self->usage_error("use --key or defined \$ENV{CLOUDSERVERS_KEY} to use this command\n")
    if ( !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY} );
  $self->usage_error("No args allowed\n") if @$args;
  if ( !defined $opt->{name} || !length $opt->{name} ) {
    $self->usage_error("Specify a --name for the new server\n");
  }
  say "Server name: ", $opt->{name} if ( $opt->{verbose} );
  if ( defined $opt->{imageid} && defined $opt->{imagename} ) {
    $self->usage_error("Specify either --imageid or --imagename, not both\n");
  }
  unless ( defined $opt->{imageid} || defined $opt->{imagename} ) {
    $self->usage_error("Specify either --imageid or --imagename\n");
  }
  if ( defined $opt->{flavorid} && defined $opt->{flavorname} ) {
    $self->usage_error("Specify either --flavorid or --flavorname, not both\n");
  }
  unless ( defined $opt->{flavorid} || defined $opt->{flavorname} ) {
    $self->usage_error("Specify either --flavorid or --flavorname\n");
  }
  if ( keys %{ $opt->{metadata} } > 5 ) {
    $self->usage_error("You can only specify a maximum of 5 --metadata key/value pairs\n");
  }
  foreach my $k ( keys %{ $opt->{metadata} } ) {
    $self->usage_error("$k: metadata keys can only be 255B maximum in length\n")
      if ( length $k > 255 );
    $self->usage_error("$k: metadata values can only be 255B maximum in length\n")
      if ( length $opt->{metadata}->{$k} > 255 );
  }
  say "Metadata: ", join( "\n", map { '  - ' . $_ } keys %{ $opt->{metadata} } )
    if ( $opt->{verbose} );
  if ( keys %{ $opt->{path} } > 5 ) {
    $self->usage_error("You can only specify a maximum of 5 --path key/filename pairs\n");
  }
  foreach my $f ( keys %{ $opt->{path} } ) {
    $self->usage_error("$f: path names can only be 255B maximum in length\n")
      if ( length $f > 255 );
    $self->usage_error("$f: file $opt->{path}->{$f} does not exist\n")
      unless ( -f $opt->{path}->{$f} );
    $self->usage_error("$f: file size of file $opt->{path}->{$f} > 10kB\n")
      unless ( -s $opt->{path}->{$f} <= 10_000 );
  }
  say "Paths: ", join( "\n", map { '  - ' . $_ } keys %{ $opt->{path} } ) if ( $opt->{verbose} );
  $opt->{user} //= $ENV{CLOUDSERVERS_USER};
  $opt->{key}  //= $ENV{CLOUDSERVERS_KEY};
  my $CS = Net::RackSpace::CloudServers->new(
    user => $opt->{user},
    key  => $opt->{key},
  );
  my @images = $CS->get_image();
  if ( !defined $opt->{imageid} ) {    # defined imagename
    my @_img = grep { $_->name =~ /\Q$opt->{imagename}\E/i } @images;
    $self->usage_error("image name $opt->{imagename} not found in image list\n") unless (@_img);
    unless ( @_img == 1 ) {
      $self->usage_error( "Too many matches for image name $opt->{imagename}:\n"
          . join( "\n", map { '  - ' . $_->name } @_img ) );
    }
    $opt->{imageid}   = $_img[0]->id;
    $opt->{imagename} = $_img[0]->name;
  }
  {
    my @_img = grep { $_->id eq $opt->{imageid} } @images;
    $self->usage_error("image id $opt->{imageid} not found in image list\n") unless (@_img);
    $self->usage_error("Too many matches for image id $opt->{imageid}\n") unless ( @_img == 1 );
    $opt->{imagename} = $_img[0]->name;
  }
  say "Image id ", $opt->{imageid}, " named ", $opt->{imagename} if ( $opt->{verbose} );
  my @flavors = $CS->get_flavor();
  if ( !defined $opt->{flavorid} ) {
    my @_fla = grep { $_->name =~ /\Q$opt->{flavorname}\E/i } @flavors;
    $self->usage_error("image name $opt->{flavorname} not found in flavorlist\n") unless (@_fla);
    unless ( @_fla == 1 ) {
      $self->usage_error( "Too many matches for flavor name $opt->{flavorname}:\n"
          . join( "\n", map { '  - ' . $_->name } @_fla ) );
    }
    $opt->{flavorid}   = $_fla[0]->id;
    $opt->{flavorname} = $_fla[0]->name;
  }
  {
    my @_fla = grep { $_->id eq $opt->{flavorid} } @flavors;
    $self->usage_error("flavor id $opt->{flavorid} not found in flavor list\n") unless (@_fla);
    $self->usage_error("Too many matches for flavor id $opt->{flavorid}\n") unless ( @_fla == 1 );
    $opt->{flavorname} = $_fla[0]->name;
  }
  say "Flavor id ", $opt->{flavorid}, " named ", $opt->{flavorname} if ( $opt->{verbose} );

  # TODO: groupid
  $opt->{__RACKSPACE_CLOUDSERVERS}         = $CS;
  $opt->{__RACKSPACE_CLOUDSERVERS_IMAGES}  = \@images;
  $opt->{__RACKSPACE_CLOUDSERVERS_FLAVORS} = \@flavors;
}

sub run {
  my ( $self, $opt, $args ) = @_;
  my $CS      = $opt->{__RACKSPACE_CLOUDSERVERS};
  my @images  = @{ $opt->{__RACKSPACE_CLOUDSERVERS_IMAGES} };
  my @flavors = @{ $opt->{__RACKSPACE_CLOUDSERVERS_FLAVORS} };
  say "Creating new server..." if ( $opt->{verbose} );
  my $newserver;
  {
    my $tmp = Net::RackSpace::CloudServers::Server->new(
      cloudservers    => $CS,
      name            => $opt->{name},
      flavorid        => $opt->{flavorid},
      imageid         => $opt->{imageid},
      id              => 0,
      status          => undef,
      hostid          => undef,
      progress        => undef,
      public_address  => undef,
      private_address => undef,
      metadata        => undef,
      adminpass       => undef,
    );
    $newserver = $tmp->create_server();
  }
  my $adminpass = $newserver->adminpass;    # will not be returned afterwards!
  say "Created server ID ", $newserver->id;
  say "root password: ",    $adminpass;
  say "Public IP: @{$newserver->public_address}";
  say "Private IP: @{$newserver->private_address}";
  if ( $opt->{wait} ) {
    local $| = 1;
    do {
      my @tmpservers = $CS->get_server_detail();
      $newserver = ( grep { $_->name eq $opt->{name} } @tmpservers )[0];
      print "\rServer status: ", $newserver->status // '?', " progress: ",
        $newserver->progress // '?';
      if ( ( $newserver->status // '' ) ne 'ACTIVE' ) {
        print " sleeping.." if ( $opt->{verbose} );
        sleep 2;
      }
    } while ( ( $newserver->status // '' ) ne 'ACTIVE' );
  }
  say "\nServer now available!";
}

1;
