package Monitoring::GLPlugin::SAP::Item;
our @ISA = qw(Monitoring::GLPlugin::Item Classes::SAP);
use strict;

sub session {
  my $self = shift;
  return $Classes::SAP::session;
}

sub compatibility_methods {
  my ($self) = @_;
}

