package Classes::SAP::Netweaver::Item;
#our @ISA = qw(Monitoring::GLPlugin::Item Classes::SAP::Netweaver);
our @ISA = qw(Classes::SAP::Netweaver Monitoring::GLPlugin::Item);
use strict;

{
  no strict 'refs';
  *{'Classes::SAP::Netweaver::Item::new'} = \&{'Monitoring::GLPlugin::Item::new'};
}

sub compatibility_methods {
  my ($self) = @_;
}

