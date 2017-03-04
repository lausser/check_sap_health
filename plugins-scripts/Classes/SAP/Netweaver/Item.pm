package Monitoring::GLPlugin::SAP::Netweaver::Item;
our @ISA = qw(Monitoring::GLPlugin::Item Classes::SAP::Netweaver);
use strict;

sub session {
  my $self = shift;
  return $Classes::SAP::Netweaver::session;
}

sub compatibility_methods {
  my ($self) = @_;
}

