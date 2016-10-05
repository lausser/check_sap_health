package Monitoring::GLPlugin::SAP::TableItem;
our @ISA = qw(Monitoring::GLPlugin::TableItem Classes::SAP);
use strict;

sub session {
  my $self = shift;
  return $Classes::SAP::session;
}

sub compatibility_methods {
  my ($self) = @_;
}


