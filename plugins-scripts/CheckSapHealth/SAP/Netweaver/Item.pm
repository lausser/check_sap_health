package CheckSapHealth::SAP::Netweaver::Item;
#our @ISA = qw(Monitoring::GLPlugin::Item CheckSapHealth::SAP::Netweaver);
our @ISA = qw(CheckSapHealth::SAP::Netweaver Monitoring::GLPlugin::Item);
use strict;

{
  no strict 'refs';
  *{'CheckSapHealth::SAP::Netweaver::Item::new'} = \&{'Monitoring::GLPlugin::Item::new'};
}

sub compatibility_methods {
  my ($self) = @_;
}

