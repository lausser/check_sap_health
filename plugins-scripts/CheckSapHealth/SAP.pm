package CheckSapHealth::SAP;
our @ISA = qw(CheckSapHealth::Device);
use strict;


sub init {
  my $self = shift;
  if ($self->mode =~ /^netweaver/i) {
    bless $self, 'CheckSapHealth::SAP::Netweaver';
    $self->debug('using CheckSapHealth::SAP::Netweaver');
  }
  if (ref($self) ne "CheckSapHealth::SAP") {
    $self->init();
  } else {
    $self->no_such_mode();
  }
}

