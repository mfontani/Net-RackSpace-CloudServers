package App::CloudServers::Command::list;
use strict;
use warnings;
use 5.010_000;
use App::CloudServers -command;
use Net::RackSpace::CloudServers;

sub abstract { 'lists images, flavors, servers, requests remaining' }

sub usage_desc { "%c list %o" }

sub opt_spec {
  return (
    ['flavors','list possible flavors and their IDs'],
    ['images','list possible images and their IDs'],
    ['servers','list all your servers and their IDs'],
    ['details','list detailed info for servers, flavors, or images'],
    ['limits','lists how many requests can still be done'],
    ['user','specify cloudservers API user, instead of $ENV{CLOUDSERVERS_USER}'],
    ['key','specify cloudservers API key, instead of $ENV{CLOUDSERVERS_KEY}'],
    ['help','get help for this command'],
  );
}

sub validate_args {
  my ( $self, $opt, $args ) = @_;
  die $self->_usage_text if $opt->{help};
  $self->usage_error("choose what you want to list\n") if (
    !defined $opt->{flavors}
    && !defined $opt->{images}
    && !defined $opt->{servers}
    && !defined $opt->{limits}
  );
  $self->usage_error("--details cannot be used for --limits\n") if (
    defined $opt->{details} && defined $opt->{limits}
  );
  $opt->{details} //= 0;
  $self->usage_error("use --user or defined \$ENV{CLOUDSERVERS_USER} to use this command\n") if (
    !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER}
  );
  $self->usage_error("use --key or defined \$ENV{CLOUDSERVERS_KEY} to use this command\n") if (
    !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY}
  );
  $opt->{user} //= $ENV{CLOUDSERVERS_USER};
  $opt->{key} //= $ENV{CLOUDSERVERS_KEY};
  $self->usage_error("No args allowed\n") if @$args;
}

sub run {
  my ($self, $opt, $args) = @_;
  my $CS = Net::RackSpace::CloudServers->new(
    user => $opt->{user},
    key  => $opt->{key},
  );
  _list_flavors($CS,$opt->{details}) if ( $opt->{flavors} );
  _list_images($CS,$opt->{details}) if ( $opt->{images} );
  _list_servers($CS,$opt->{details}) if ( $opt->{servers} );
  _list_limits($CS) if ( $opt->{limits} );
}

sub _list_flavors { say "Listing flavors"; }
sub _list_images { say "Listing images"; }

sub _list_servers {
  my ($CS,$details) = @_;
  my @servers = $details ? $CS->get_server_detail() : $CS->get_server();
  say "Listing servers", $details ? ' details' : '';
  my $fmt;
  if ( $details ) {
    $fmt = '  %-8s %-12s %-32s %-8s %-7s %-8s %s';
    say sprintf($fmt,qw/id name hostid flavorid imageid progress status/);
    say '  --------+------------+--------------------------------+--------+-------+--------+--------------';
  } else {
    $fmt = '  %-8s %s';
    say sprintf($fmt,qw/id name/);
    say '  --------+------------';
  }
  foreach my $srv ( @servers ) {
    say sprintf($fmt,
      map { $srv->$_ } (qw/id name/, ($details ? (qw/hostid flavorid imageid progress status/) : ())),
    );
  }
}

sub _list_limits {
  my ($CS) = @_;
  my $cs = $CS->limits;
  if (defined $cs->rate && ref $cs->rate eq 'ARRAY') {
    say "Rate limits:";
    my $fmt = '  %-8s %-16s %-16s %-6s %-10s %-7s (%s) %s';
    say sprintf($fmt,qw/verb URI regex value remaining units reset-time local-time/);
    say '  --------+----------------+----------------+------+----------+',
      '-------+------------+------------------------';
    foreach my $rl (@{$cs->rate}) {
      say sprintf($fmt,
        $rl->{verb} // 'n/a',
        $rl->{URI} // 'n/a',
        $rl->{regex} // 'n/a',
        $rl->{value} // 'n/a',
        $rl->{remaining} // 'n/a',
        $rl->{unit} // 'n/a',
        $rl->{resetTime} // 'n/a',
        defined $rl->{resetTime} ? scalar localtime($rl->{resetTime}) : 'n/a',
      );
    }
  } else {
    say "No rate info found or not an array: ", ref $cs->rate;
  }
  say "Absolute limits:";
  foreach my $k (qw/totalramsize maxipgroups maxipgroupmembers/) {
    say sprintf('  %-20s %s',$k,$cs->$k // 'n/a');
  }
}

1;
