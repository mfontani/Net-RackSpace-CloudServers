package App::CloudServers::Command::delete;
use strict;
use warnings;
use 5.010_000;
use App::CloudServers -command;
use Net::RackSpace::CloudServers;

sub abstract { 'deletes servers' }

sub usage_desc { "%c delete %o" }

sub opt_spec {
  return (
    [ 'serverid|i=i',   'specify the ID of the server to be deleted' ],
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
  $self->usage_error("use --user or defined \$ENV{CLOUDSERVERS_USER} to use this command\n")
    if ( !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER} );
  $self->usage_error("use --key or defined \$ENV{CLOUDSERVERS_KEY} to use this command\n")
    if ( !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY} );
  $self->usage_error("No args allowed\n") if @$args;
  if ( !defined $opt->{serverid} || !length $opt->{serverid} ) {
    $self->usage_error("Specify a --serverid to be deleted\n");
  }
  say "Server id: ", $opt->{serverid} if ( $opt->{verbose} );
  $opt->{user} //= $ENV{CLOUDSERVERS_USER};
  $opt->{key}  //= $ENV{CLOUDSERVERS_KEY};
  my $CS = Net::RackSpace::CloudServers->new(
    user => $opt->{user},
    key  => $opt->{key},
  );
  my $server = $CS->get_server( $opt->{serverid} );
  if ( !defined $server ) {
    $self->usage_error("Specify a --serverid which exists and is yours\n");
  }
  $opt->{__RACKSPACE_CLOUDSERVERS}        = $CS;
  $opt->{__RACKSPACE_CLOUDSERVERS_SERVER} = $server;
}

sub run {
  my ( $self, $opt, $args ) = @_;
  my $CS     = $opt->{__RACKSPACE_CLOUDSERVERS};
  my $server = $opt->{__RACKSPACE_CLOUDSERVERS_SERVER};
  say "Deleting server #", $server->id, " (", $server->name, ")..." if ( $opt->{verbose} );
  # TODO add $server->delete_server();
  say "Server deleted";
}

1;
