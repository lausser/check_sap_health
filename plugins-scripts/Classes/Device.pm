package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin);
use strict;


sub classify {
  my $self = shift;
  #if (! (($self->opts->ashost || $self->opts->mshost) && $self->opts->username && $self->opts->password)) {
  if (! ($self->opts->ashost || $self->opts->mshost)) {
    $self->add_unknown('specify at least hostname, username and password');
  } else {
    bless $self, 'Classes::SAP::Netweaver';
    $self->debug('using Classes::SAP::Netweaver');
    $self->check_rfc_and_model();
  }
  if ($self->opts->mode =~ /^my-/) {
    $self->load_my_extension();
  }
}

