package App::CloudServers::Command::list;
use strict;
use warnings;
use 5.010_000;
use App::CloudServers -command;

sub abstract { 'lists images, flavors, servers, requests remaining' }

sub usage_desc { "%c list %o" }

sub opt_spec {
  return (
    ['flavors','list possible flavors and their IDs'],
    ['images','list possible images and their IDs'],
    ['servers','list all your servers and their IDs'],
    ['limits','lists how many requests can still be done'],
    ['user','specify cloudservers API user, instead of $ENV{CLOUDSERVERS_USER}'],
    ['key','specify cloudservers API key, instead of $ENV{CLOUDSERVERS_KEY}'],
    ['help','get help for this command'],
  );
}

sub validate_args {
  my ( $self, $opt, $args ) = @_;
  die $self->_usage_text if $opt->{help};
  $self->usage_error('choose what you want to list') if (
    !defined $opt->{flavors}
    && !defined $opt->{images}
    && !defined $opt->{servers}
    && !defined $opt->{limits}
  );
  $self->usage_error('use --user or defined $ENV{CLOUDSERVERS_USER} to use this command') if (
    !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER}
  );
  $self->usage_error('use --key or defined $ENV{CLOUDSERVERS_KEY} to use this command') if (
    !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY}
  );
  $opt->{user} //= $ENV{CLOUDSERVERS_USER};
  $opt->{key} //= $ENV{CLOUDSERVERS_KEY};
  $self->usage_error("No args allowed") if @$args;
}

sub run {
  my ($self, $opt, $args) = @_;
  _list_flavors() if ( $opt->{flavors} );
  _list_images() if ( $opt->{images} );
  _list_servers() if ( $opt->{servers} );
  _list_limits() if ( $opt->{limits} );
}

sub _list_flavors() { say "Listing flavors"; }
sub _list_images() { say "Listing images"; }
sub _list_servers() { say "Listing servers"; }
sub _list_limits() { say "Listing limits"; }

1;
