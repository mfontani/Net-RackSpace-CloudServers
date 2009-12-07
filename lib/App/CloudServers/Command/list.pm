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
    [ 'flavors|f', 'list possible flavors and their IDs' ],
    [ 'images|i',  'list possible images and their IDs' ],
    [ 'servers|s', 'list all your servers and their IDs' ],
    [ 'details|d', 'list detailed info for servers, flavors, or images' ],
    [ 'ips|p',     'enables --details, and also list servers IP addresses info' ],
    [ 'limits|l',  'lists how many requests can still be done' ],
    [ 'table|t',   'uses Text::SimpleTable to draw the report' ],
    [ 'quiet|q',   'only output data (useful for piping)' ],
    [ 'user',      'specify cloudservers API user, instead of $ENV{CLOUDSERVERS_USER}' ],
    [ 'key',       'specify cloudservers API key, instead of $ENV{CLOUDSERVERS_KEY}' ],
    [ 'help|h',    'get help for this command' ],
  );
}

sub validate_args {
  my ( $self, $opt, $args ) = @_;
  die $self->_usage_text if $opt->{help};
  $self->usage_error("choose what you want to list\n")
    if ( !defined $opt->{flavors}
    && !defined $opt->{images}
    && !defined $opt->{servers}
    && !defined $opt->{limits} );
  $self->usage_error("--details cannot be used for --limits\n")
    if ( defined $opt->{details} && defined $opt->{limits} );
  $opt->{details} //= 0;
  $opt->{quiet}   //= 0;
  $self->usage_error("--ips can be used for --servers only\n")
    if ( defined $opt->{ips} && !defined $opt->{servers} );
  $opt->{ips} //= 0;
  $opt->{details} = 1 if ( $opt->{ips} );
  $self->usage_error("use --user or defined \$ENV{CLOUDSERVERS_USER} to use this command\n")
    if ( !defined $opt->{user} && !defined $ENV{CLOUDSERVERS_USER} );
  $self->usage_error("use --key or defined \$ENV{CLOUDSERVERS_KEY} to use this command\n")
    if ( !defined $opt->{key} && !defined $ENV{CLOUDSERVERS_KEY} );
  $opt->{user}  //= $ENV{CLOUDSERVERS_USER};
  $opt->{key}   //= $ENV{CLOUDSERVERS_KEY};
  $opt->{table} //= 0;
  $self->usage_error("--quiet cannot be used with --table\n")
    if ( $opt->{table} && $opt->{quiet} );
  $self->usage_error("No args allowed\n") if @$args;
}

sub run {
  my ( $self, $opt, $args ) = @_;
  my $CS = Net::RackSpace::CloudServers->new(
    user => $opt->{user},
    key  => $opt->{key},
  );
  _list_flavors( $CS, $opt ) if ( $opt->{flavors} );
  _list_images( $CS, $opt ) if ( $opt->{images} );
  _list_servers( $CS, $opt ) if ( $opt->{servers} );
  _list_limits( $CS, $opt ) if ( $opt->{limits} );
}

sub _list_flavors {
  my ( $CS, $opt ) = @_;
  my @flavors = $opt->{details} ? $CS->get_flavor_detail() : $CS->get_flavor();
  say "Listing flavors", $opt->{details} ? ' details' : '' unless $opt->{quiet};
  my $table;
  my $fmt;
  my $details = $opt->{details};
  if ( $opt->{table} ) {
    use Text::SimpleTable;
    $table = Text::SimpleTable->new(
      [ 4,  'id' ],
      [ 14, 'name' ],
      (
        $details
        ? ( [ 8, 'disk' ], [ 8, 'ram' ], )
        : ()
      )
    );
  } elsif ( !$opt->{quiet} ) {
    $fmt = '  %-4s %-14s' . ( $details ? ' %-8s %-8s' : '' );
    say sprintf( $fmt, qw/id name/, $details ? qw/disk ram/ : undef );
    say '  ----+--------------', $details ? '+--------+--------+' : '';
  } else {    # quiet
    $fmt = '%s "%s"' . ( $details ? ' %s %s' : '' );
  }

  foreach my $fla (@flavors) {
    my @det =
      map { $fla->$_ // '' } ( qw/id name/, ( $details ? (qw/disk ram/) : () ) );
    if ( $opt->{table} ) {
      $table->row(@det);
    } else {
      say sprintf( $fmt, @det );
    }
  }
  say $table->draw if $opt->{table};
}

sub _list_images {
  my ( $CS, $opt ) = @_;
  my @images = $opt->{details} ? $CS->get_image_detail() : $CS->get_image();
  say "Listing images", $opt->{details} ? ' details' : '' unless $opt->{quiet};
  my $table;
  my $fmt;
  my $details = $opt->{details};
  if ( $opt->{table} ) {
    use Text::SimpleTable;
    $table = Text::SimpleTable->new(
      [ 6,  'id' ],
      [ 26, 'name' ],
      (
        $details
        ? ( [ 7, 'status' ], [ 25, 'created' ], [ 25, 'updated' ], )
        : ()
      )
    );
  } elsif ( !$opt->{quiet} ) {
    $fmt = '  %-6s %-26s' . ( $details ? ' %-7s %-25s %-25s' : '' );
    say sprintf( $fmt, qw/id name/, $details ? qw/status created updated/ : undef );
    say '  ------+--------------------------',
      $details ? '+-------+-------------------------+-------------------------' : '';
  } else {
    $fmt = '%s "%s"' . ( $details ? ' %s %s %s' : '' );
  }

  foreach my $img (@images) {
    my @det =
      map { $img->$_ // '' } ( qw/id name/, ( $details ? (qw/status created updated/) : () ) );
    if ( $opt->{table} ) {
      $table->row(@det);
    } else {
      say sprintf( $fmt, @det );
    }
  }
  say $table->draw if $opt->{table};
}

sub _list_servers {
  my ( $CS, $opt ) = @_;
  my @servers = $opt->{details} ? $CS->get_server_detail() : $CS->get_server();
  say "Listing servers", $opt->{details} ? ' details' : '', $opt->{ips} ? ' and IP addresses' : '';
  my $table;
  my $fmt;
  my $details = $opt->{details};
  if ( $opt->{table} ) {
    use Text::SimpleTable;
    $table = Text::SimpleTable->new(
      [ 8,  'id' ],
      [ 12, 'name' ],
      (
        $details
        ? (
          [ 32, $opt->{ips} ? 'hostid and IPs' : 'hostid' ],
          [ 18, 'flavor' ],
          [ 28, 'image' ],
          [ 8,  'progress' ],
          [ 10, 'status' ]
          )
        : ()
      )
    );
  } elsif ( !$opt->{quiet} ) {
    $fmt = '  %-8s %-12s' . ( $details ? ' %-32s %-18s %-28s %-8s %s' : '' );
    say sprintf( $fmt,
      qw/id name/,
      $details
      ? ( $opt->{ips} ? 'hostid and IPs' : 'hostid', qw/flavor image progress status/ )
      : undef );
    say '  --------+------------',
      $details
      ? '+--------------------------------+------------------'
      . '+----------------------------+--------+--------------'
      : '';
  } else {
    $fmt = '%s %s' . ( $details ? ' %s %s %s %s %s' : '' );
  }

  foreach my $srv (@servers) {
    my $flavor;
    my $image;
    if ($details) {
      $flavor = $srv->flavorid . ' ';
      $flavor .= '"' if ( $opt->{quiet} );
      $flavor .= $CS->get_flavor( $srv->flavorid )->name;
      $flavor .= '"' if ( $opt->{quiet} );
      $image = $srv->imageid . ' ';
      $image .= '"' if ( $opt->{quiet} );
      $image .= $CS->get_image( $srv->imageid )->name;
      $image .= '"' if ( $opt->{quiet} );
    }
    my $hostip;
    if ( $opt->{ips} ) {
      if ( $opt->{quiet} ) {
        $hostip = [
          'Public ' . join( ' ', map { $_ } @{ $srv->public_address } ),
          'Private ' . join( ' ', map { $_ } @{ $srv->private_address } )
        ];
      } else {
        $hostip = [
          'Public:  ' . join( ' ', map { $_ } @{ $srv->public_address } ),
          'Private: ' . join( ' ', map { $_ } @{ $srv->private_address } )
        ];
      }
    }
    my @det = (
      ( map { $srv->$_ // '' } (qw/id name/) ),
      $details
      ? (
          $opt->{table}
        ? $srv->hostid . "\n" . join( "\n", @$hostip )
        : $srv->hostid,
        $flavor, $image, $srv->progress, $srv->status
        )
      : ()
    );
    if ( $opt->{table} ) {
      $table->row(@det);
    } else {
      say sprintf( $fmt, @det );
      if ( $opt->{ips} ) {
        foreach (@$hostip) {
          if ( $opt->{quiet} ) {
            say sprintf( '%s "%s"', $srv->id, $_ );
          } else {
            say sprintf( $fmt, '', '', $_, '', '', '', '', '' );
          }
        }
      }
    }
  }
  say $table->draw if $opt->{table};
}

sub _list_limits {
  my ( $CS, $opt ) = @_;
  my $cs = $CS->limits;
  if ( defined $cs->rate && ref $cs->rate eq 'ARRAY' ) {
    say "Rate limits:" unless $opt->{quiet};
    my $table;
    my $fmt;
    if ( $opt->{table} ) {
      use Text::SimpleTable;
      $table = Text::SimpleTable->new(
        [ 6,  'verb' ],
        [ 16, 'URI' ],
        [ 16, 'regex' ],
        [ 5,  'value' ],
        [ 4,  'left' ],
        [ 7,  'progress' ],
        [ 35, 'reset-time (local time)' ]
      );
    } elsif ( !$opt->{quiet} ) {
      $fmt = '  %-8s %-16s %-16s %-6s %-6s %-6s (%s) %s';
      say sprintf( $fmt, qw/verb URI regex value left units reset-time local-time/ );
      say '  --------+----------------+----------------+------+------+',
        '------+------------+------------------------';
    } else {
      $fmt = '%s "%s" "%s" %s %s %s %s "%s"';
    }
    foreach my $rl ( @{ $cs->rate } ) {
      my @reset_time = (
        $rl->{resetTime} // 'n/a',
        defined $rl->{resetTime} ? scalar localtime( $rl->{resetTime} ) : 'n/a'
      );
      my @det = (
        $rl->{verb}      // 'n/a',
        $rl->{URI}       // 'n/a',
        $rl->{regex}     // 'n/a',
        $rl->{value}     // 'n/a',
        $rl->{remaining} // 'n/a',
        $rl->{unit}      // 'n/a',
        $opt->{table} ? join( ' ', @reset_time ) : @reset_time
      );
      if ( $opt->{table} ) {
        $table->row(@det);
      } else {
        say sprintf( $fmt, @det );
      }
    }
    say $table->draw if $opt->{table};
  } else {
    warn "No rate info found or not an array: ", ref $cs->rate;
  }
  say "Absolute limits:" unless $opt->{quiet};
  foreach my $k (qw/totalramsize maxipgroups maxipgroupmembers/) {
    if ( $opt->{quiet} ) {
      say sprintf( '%s %s', $k, $cs->$k // 'n/a' );
    } else {
      say sprintf( '  %-20s %s', $k, $cs->$k // 'n/a' );
    }
  }
}

1;
