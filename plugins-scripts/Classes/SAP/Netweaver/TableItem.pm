package Classes::SAP::Netweaver::TableItem;
#our @ISA = qw(Monitoring::GLPlugin::TableItem Classes::SAP::Netweaver);
our @ISA = qw(Classes::SAP::Netweaver Monitoring::GLPlugin::TableItem);
use strict;

{
  no strict 'refs';
  *{'Classes::SAP::Netweaver::TableItem::new'} = \&{'Monitoring::GLPlugin::TableItem::new'};
}

sub compatibility_methods {
  my ($self) = @_;
}


