package Classes::Device;
our @ISA = qw(GLPlugin);
use strict;
use IO::File;
use File::Basename;
use Digest::MD5  qw(md5_hex);
use Errno;
use AutoLoader;
our $AUTOLOAD;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };


sub classify {
  my $self = shift;
  if (! ($self->opts->ashost && $self->opts->username && $self->opts->password)) {
    $self->add_unknown('specify at least hostname, username and password');
  } else {
    $self->check_rfc_and_model();
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      bless $self, 'Classes::SAP';
      $self->debug('using Classes::SAP');
    }
  }
}

sub check_rfc_and_model {
  my $self = shift;
  chdir("/tmp");
  if (eval "require sapnwrfc") {
    my %params = (
      'lcheck' => '1',
    );
    if ($self->opts->mode =~ /sapinfo/) {
      $params{lcheck} = 0;
    }
    if ($self->opts->ashost) {
      $params{ashost} = $self->opts->ashost;
    }
    if ($self->opts->sysnr) {
      $params{sysnr} = $self->opts->sysnr;
    }
    if ($self->opts->client) {
      $params{client} = $self->opts->client;
    }
    if ($self->opts->lang) {
      $params{lang} = $self->opts->lang;
    }
    if ($self->opts->username) {
      $params{user} = $self->opts->username;
    }
    if ($self->opts->password) {
      $params{passwd} = $self->opts->password;
    }
    if ($self->opts->verbose) {
      $params{debug} = '1';
      $params{trace} = '1';
    }
    $self->{tic} = Time::HiRes::time();
    my $session = undef;
    eval {
      $session = SAPNW::Rfc->rfc_connect(%params);
    };
    if ($@) {
      $self->add_message(CRITICAL,
          sprintf 'cannot create rfc connection: %s', $@);
      $self->debug(Data::Dumper::Dumper(\%params));
    } elsif (! defined $session) {
      $self->add_message(CRITICAL,
          sprintf 'cannot create rfc connection');
      $self->debug(Data::Dumper::Dumper(\%params));
    } else {
      $Classes::SAP::session = $session;
    }
    $self->{tac} = Time::HiRes::time();
  } else {
    $self->add_message(CRITICAL,
        'could not load perl module SAPNW');
  }
}

sub is_blacklisted {
  my $self = shift;
  return 0;
}

