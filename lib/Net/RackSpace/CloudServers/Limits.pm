package Net::RackSpace::CloudServers::Limits;
use warnings;
use strict;
our $DEBUG = 0;
use Moose;
use MooseX::StrictConstructor;
use HTTP::Request;
use JSON;
use YAML;

has 'cloudservers'      => ( is => 'rw', isa => 'Net::RackSpace::CloudServers', required => 1 );
has 'totalramsize'      => ( is => 'rw', isa => 'Int',                          );
has 'maxipgroups'       => ( is => 'rw', isa => 'Int',                          );
has 'maxipgroupmembers' => ( is => 'rw', isa => 'Int',                          );
has 'rate'              => ( is => 'rw', isa => 'Maybe[ArrayRef]',              );

no Moose;
__PACKAGE__->meta->make_immutable();

sub BUILD {
  my $self = shift;
  $self->refresh();
}

sub refresh {
  my $self    = shift;
  my $request = HTTP::Request->new(
    'GET',
    $self->cloudservers->server_management_url . '/limits',
    [ 'X-Auth-Token' => $self->cloudservers->token ]
  );
  my $response = $self->cloudservers->_request($request);
  return if $response->code == 204;
  confess 'Unknown error ' . $response->code unless ( $response->code ~~ [ 200, 203 ] );
  my $hr = from_json( $response->content );
  warn Dump($hr) if $DEBUG;

  #{"limits":{"absolute":{"maxTotalRAMSize":51200,"maxIPGroupMembers":25,"maxNumServers":25,"maxIPGroups":25},"rate":[{"value":50,"unit":"DAY","verb":"POST","remaining":50,"URI":"\/servers*","resetTime":1247769469,"regex":"^\/servers"},{"value":10,"unit":"MINUTE","verb":"POST","remaining":10,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":600,"unit":"MINUTE","verb":"DELETE","remaining":600,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":10,"unit":"MINUTE","verb":"PUT","remaining":10,"URI":"*","resetTime":1247769469,"regex":".*"},{"value":3,"unit":"MINUTE","verb":"GET","remaining":3,"URI":"*changes-since*","resetTime":1247769469,"regex":"changes-since"}]}}
  confess 'response does not contain key "limits"' unless defined $hr->{limits};
  confess 'response does not contain hashref of "limits"'
    unless ( ref $hr->{limits} eq 'HASH' );

  confess 'response "limits" does not contain key "rate"' unless defined $hr->{limits}->{rate};
  confess 'response "limits", key "rate" is not an arrayref' unless ( ref $hr->{limits}->{rate} eq 'ARRAY' );
  $self->rate( $hr->{limits}->{rate} );

  confess 'response "limits" does not contain key "absolute"' unless defined $hr->{limits}->{absolute};
  confess 'response "limits", key "absolute" is not an hashref' unless ( ref $hr->{limits}->{absolute} eq 'HASH' );
  confess 'response "limits", key "absolute" does not contain key "maxTotalRAMSize"' unless (
    defined $hr->{limits}->{absolute}->{"maxTotalRAMSize"}
  );
  $self->totalramsize( $hr->{limits}->{absolute}->{"maxTotalRAMSize"} );
  confess 'response "limits", key "absolute" does not contain key "maxIPGroups"' unless (
    defined $hr->{limits}->{absolute}->{"maxIPGroups"}
  );
  $self->maxipgroups( $hr->{limits}->{absolute}->{"maxIPGroups"} );
  confess 'response "limits", key "absolute" does not contain key "maxIPGroupMembers"' unless (
    defined $hr->{limits}->{absolute}->{"maxIPGroupMembers"}
  );
  $self->maxipgroupmembers( $hr->{limits}->{absolute}->{"maxIPGroupMembers"} );
  return $self;
}

1;
