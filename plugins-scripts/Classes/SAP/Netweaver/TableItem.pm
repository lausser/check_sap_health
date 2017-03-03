package Monitoring::GLPlugin::SAP::::Netweaver::TableItem;
our @ISA = qw(Monitoring::GLPlugin::TableItem Classes::SAP::Netweaver);
use strict;

sub session {
  my $self = shift;
  return $Classes::SAP::session;
}

sub compatibility_methods {
  my ($self) = @_;
}


