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
    [ 'name|n', 'specify the new server\'s name' ],
    [ 'wait|w', '(default) wait until the server has been successfully created', { default => 1 } ],
    [ 'imageid|i',    'specify the ID of the image used to create the server' ],
    [ 'imagename|I',  'specify the name of the image used to create the server' ],
    [ 'flavorid|f',   'specify the ID of the flavor used to create the server' ],
    [ 'flavorname|F', 'specify the name of the flavor used to create the server' ],
    [ 'metadata|m=s%', 'specify max 5 255B string metadata keys/values', { default => {} } ],
    [ 'path|p=s%',   'specify max 5 10kB max files to be pushed to the server', { default => {} } ],
    [ 'groupid|g=s', 'specify shared ip group ID for server',                   { default => '' } ],
    [ 'user',   'specify cloudservers API user, instead of $ENV{CLOUDSERVERS_USER}' ],
    [ 'key',    'specify cloudservers API key, instead of $ENV{CLOUDSERVERS_KEY}' ],
    [ 'help|h', 'get help for this command' ],
  );
}

sub validate_args {
  my ( $self, $opt, $args ) = @_;
  die $self->_usage_text if $opt->{help};
  use YAML;
  warn "Options specified: ", Dump($opt);
  if ( !defined $opt->{name} || !length $opt->{name} ) {
    $self->usage_error("Specify a --name for the new server\n");
  }
  if ( defined $opt->{imageid} && defined $opt->{imagename} ) {
    $self->usage_error("Specify either --imageid or --imagename, not both\n");
  }
  if ( defined $opt->{flavorid} && defined $opt->{flavorname} ) {
    $self->usage_error("Specify either --flavorid or --flavorname, not both\n");
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
  die "NOT IMPLEMENTED\n";
  $self->usage_error("use --user or defined \$ENV{CLOUDSERVERS_USER} to use this command\n")
    if ( !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER} );
  $self->usage_error("use --key or defined \$ENV{CLOUDSERVERS_KEY} to use this command\n")
    if ( !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY} );

  # TODO: groupid
  # TODO: check image id or name exist
  # TODO: check flavor id or name exist
  $opt->{user}  //= $ENV{CLOUDSERVERS_USER};
  $opt->{key}   //= $ENV{CLOUDSERVERS_KEY};
  $opt->{table} //= 0;
  $self->usage_error("No args allowed\n") if @$args;
}

sub run {
  my ( $self, $opt, $args ) = @_;
  my $CS = Net::RackSpace::CloudServers->new(
    user => $opt->{user},
    key  => $opt->{key},
  );
}

1;
