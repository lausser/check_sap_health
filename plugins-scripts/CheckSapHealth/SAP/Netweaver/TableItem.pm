package CheckSapHealth::SAP::Netweaver::TableItem;
#our @ISA = qw(Monitoring::GLPlugin::TableItem CheckSapHealth::SAP::Netweaver);
our @ISA = qw(CheckSapHealth::SAP::Netweaver Monitoring::GLPlugin::TableItem);
use strict;

{
  no strict 'refs';
  *{'CheckSapHealth::SAP::Netweaver::TableItem::new'} = \&{'Monitoring::GLPlugin::TableItem::new'};
}

sub compatibility_methods {
  my ($self) = @_;
}


