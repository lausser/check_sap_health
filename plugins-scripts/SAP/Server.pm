package SAP::Server;

use strict;
use IO::File;
use File::Basename;
use Digest::MD5  qw(md5_hex);
use Time::HiRes;
use Errno;
use AutoLoader;
our $AUTOLOAD;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $session = undef;
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $statefilesdir = '/var/tmp/check_sap_health';
  our $uptime = 0;
}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    productname => 'unknown',
  };
  bless $self, $class;
  $SAP::Server::statefilesdir = $self->opts->statefilesdir;
  if ($self->opts->separator) {
    $MTE::separator = $self->opts->separator;
  }
  $self->connect();
  return $self;
}

sub connect {
  my $self = shift;
  chdir("/tmp");
  if (eval "require sapnwrfc") {
    my %params = (
      'lcheck' => '1',
    );
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
    if ($self->opts->mode =~ /sapinfo/) { 
die;
    }
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
      $SAP::Server::session = $session;
    }
  } else {
      $self->add_message(CRITICAL,
          'could not find SAPNW');
  }
  $self->{tac} = Time::HiRes::time();
}

sub init {
  my $self = shift;
  if ($self->mode =~ /^server::connectiontime/) {
    my $fc = undef;
    if ($self->mode =~ /^server::connectiontime::sapinfo/) {
      eval {
        my $fl = $self->session->function_lookup("RFC_SYSTEM_INFO");
        $fc = $fl->create_function_call;
        $fc->invoke();
        printf "rrc %s\n", Data::Dumper::Dumper($fc->RFCSI_EXPORT);
      };
      $self->{tac} = Time::HiRes::time();
    }
    $self->{connection_time} = $self->{tac} - $self->{tic};
    $self->set_thresholds(warning => 1, critical => 5);
    $self->add_message($self->check_thresholds($self->{connection_time}), 
         sprintf "%.2f seconds to connect as %s@%s",
              $self->{connection_time}, $self->opts->username,
              $SAP::Server::session->connection_attributes->{sysId});
    $self->add_perfdata(
        label => 'connection_time',
        value => $self->{connection_time},
        warning => $self->{warning},
        critical => $self->{critical},
    );
    if ($self->mode =~ /^server::connectiontime::sapinfo/) {
      # extraoutput
      # $fc
    }
  } elsif ($self->mode =~ /^server::ccms::/) {
    bless $self, 'SAP::CCMS';
    $self->init();
  } elsif ($self->mode =~ /^my::([^:.]+)/) {
    my $class = $1;
    my $loaderror = undef;
    substr($class, 0, 1) = uc substr($class, 0, 1);
    foreach my $libpath (split(":", $SAP::Server::my_modules_dyn_dir)) {
      foreach my $extmod (glob $libpath."/CheckSapHealth*.pm") {
        eval {
          $self->debug(sprintf "loading module %s", $extmod);
          require $extmod;
        };
        if ($@) {
          $loaderror = $extmod;
          $self->debug(sprintf "failed loading module %s: %s", $extmod, $@);
        }
      }
    }
    my $obj = {
        session => $SAP::Server::session,
        warning => $self->opts->warning,
        critical => $self->opts->critical,
    };
    bless $obj, "My$class";
    $self->{my} = $obj;
    if ($self->{my}->isa("SAP::Server")) {
      my $dos_init = $self->can("init");
      my $dos_nagios = $self->can("nagios");
      my $my_init = $self->{my}->can("init");
      my $my_nagios = $self->{my}->can("nagios");
      if ($my_init == $dos_init) {
          $self->add_message(UNKNOWN,
              sprintf "Class %s needs an init() method", ref($self->{my}));
      } else {
        $self->{my}->init();
      }
    } else {
      $self->add_message(UNKNOWN,
          sprintf "Class %s is not a subclass of SAP::Server%s",
              ref($self->{my}),
              $loaderror ? sprintf " (syntax error in %s?)", $loaderror : "" );
    }
  }
}

sub nagios {
  my $self = shift;
  if ($self->mode =~ /dummy/) {
  } elsif ($self->mode =~ /^my::([^:.]+)/) {
    $self->{my}->init();
  }
}

sub debug {
  my $self = shift;
  my $format = shift;
  $self->{trace} = -f "/tmp/check_sap_health.trace" ? 1 : 0;
  if ($self->opts->verbose && $self->opts->verbose > 10) {
    printf("%s: ", scalar localtime);
    printf($format, @_);
    printf "\n";
  }
  if ($self->{trace}) {
    my $logfh = new IO::File;
    $logfh->autoflush(1);
    if ($logfh->open("/tmp/check_sap_health.trace", "a")) {
      $logfh->printf("%s: ", scalar localtime);
      $logfh->printf($format, @_);
      $logfh->printf("\n");
      $logfh->close();
    }
  }
}

sub rstrip {
  my $self = shift;
  my $message = shift;
  $message =~ s/\s+$//g;
  chomp $message;
  return $message;
}

sub strip {
  my $self = shift;
  my $message = shift;
  $message =~ s/^\s+//g;
  $message = $self->rstrip($message);
  return $message;
}

sub session {
  my $self = shift;
  return $SAP::Server::session;
}

sub mode {
  my $self = shift;
  return $SAP::Server::mode;
}

sub add_message {
  my $self = shift;
  my $level = shift;
  my $message = $self->strip(shift);
  $message =~ s/[^[:ascii:]]//g;
  $SAP::Server::plugin->add_message($level, $message)
      unless $self->{blacklisted};
  if (exists $self->{failed}) {
    if ($level == UNKNOWN && $self->{failed} == OK) {
      $self->{failed} = $level;
    } elsif ($level > $self->{failed}) {
      $self->{failed} = $level;
    }
  }
}

sub status_code {
  my $self = shift;
  return $SAP::Server::plugin->status_code(@_);
}

sub check_messages {
  my $self = shift;
  return $SAP::Server::plugin->check_messages(@_);
}

sub clear_messages {
  my $self = shift;
  return $SAP::Server::plugin->clear_messages(@_);
}

sub suppress_messages {
  my $self = shift;
  return $SAP::Server::plugin->suppress_messages(@_);
}

sub add_perfdata {
  my $self = shift;
  $SAP::Server::plugin->add_perfdata(@_);
}

sub set_thresholds {
  my $self = shift;
  $SAP::Server::plugin->set_thresholds(@_);
}

sub force_thresholds {
  my $self = shift;
  $SAP::Server::plugin->force_thresholds(@_);
}

sub check_thresholds {
  my $self = shift;
  my @params = @_;
  ($self->{warning}, $self->{critical}) =
      $SAP::Server::plugin->get_thresholds(@params);
  return $SAP::Server::plugin->check_thresholds(@params);
}

sub get_thresholds {
  my $self = shift;
  my @params = @_;
  my @thresholds = $SAP::Server::plugin->get_thresholds(@params);
  my($warning, $critical) = $SAP::Server::plugin->get_thresholds(@params);
  $self->{warning} = $thresholds[0];
  $self->{critical} = $thresholds[1];
  return @thresholds;
}

sub has_failed {
  my $self = shift;
  return $self->{failed};
}

sub add_info {
  my $self = shift;
  my $info = shift;
  $info = $self->{blacklisted} ? $info.' (blacklisted)' : $info;
  $self->{info} = $info;
  push(@{$SAP::Server::info}, $info);
}

sub annotate_info {
  my $self = shift;
  my $annotation = shift;
  my $lastinfo = pop(@{$SAP::Server::info});
  $lastinfo .= sprintf ' (%s)', $annotation;
  push(@{$SAP::Server::info}, $lastinfo);
}

sub add_extendedinfo {
  my $self = shift;
  my $info = shift;
  $self->{extendedinfo} = $info;
  return if ! $self->opts->extendedinfo;
  push(@{$SAP::Server::extendedinfo}, $info);
}

sub get_extendedinfo {
  my $self = shift;
  return join(' ', @{$SAP::Server::extendedinfo});
}

sub add_summary {
  my $self = shift;
  my $summary = shift;
  push(@{$SAP::Server::summary}, $summary);
}

sub get_summary {
  my $self = shift;
  return join(', ', @{$SAP::Server::summary});
}

sub opts {
  my $self = shift;
  return $SAP::Server::plugin->opts();
}

sub DESTROY {
  my $self = shift;
  if ($SAP::Server::session) {
    $SAP::Server::session->disconnect();
  }
  $self->debug("disconnected");
}


