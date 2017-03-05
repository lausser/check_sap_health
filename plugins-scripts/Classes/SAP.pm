package Classes::SAP;
our @ISA = qw(Classes::Device);
use strict;


sub init {
  my $self = shift;
  if ($self->mode =~ /^netweaver/i) {
    bless $self, 'Classes::SAP::Netweaver';
    $self->debug('using Classes::SAP::Netweaver');
  }
  if (ref($self) ne "Classes::SAP") {
    $self->init();
  } else {
    $self->no_such_mode();
  }
}

