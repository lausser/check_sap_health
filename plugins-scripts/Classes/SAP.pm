package Classes::SAP;
our @ISA = qw(Classes::Device);

use strict;
use File::Basename;
use Time::HiRes;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use AutoLoader;
our $AUTOLOAD;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $blacklist = undef;
  our $session = undef;
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $oidtrace = [];
  our $uptime = 0;
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

sub session {
  my $self = shift;
  return $Classes::SAP::session;
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
      if ($@) {
        printf "crash %s\n", $@;
      }
      $self->{tac} = Time::HiRes::time();
    }
    $self->{connection_time} = $self->{tac} - $self->{tic};
    $self->set_thresholds(warning => 1, critical => 5);
    $self->add_message($self->check_thresholds($self->{connection_time}),
         sprintf "%.2f seconds to connect as %s@%s",
              $self->{connection_time}, $self->opts->username,
              $self->session->connection_attributes->{sysId});
    $self->add_perfdata(
        label => 'connection_time',
        value => $self->{connection_time},
    );
    if ($self->mode =~ /^server::connectiontime::sapinfo/) {
      # extraoutput
      # $fc
    }
  } elsif ($self->mode =~ /^server::ccms::/) {
    $self->analyze_and_check_ccms_subsystem("Classes::SAP::Component::CCMS");
  } elsif ($self->mode =~ /^server::snap::/) {
    $self->analyze_and_check_snap_subsystem("Classes::SAP::Component::SNAP");
  } elsif ($self->mode =~ /^my::([^:.]+)/) {
    my $class = $1;
    my $loaderror = undef;
    substr($class, 0, 1) = uc substr($class, 0, 1);
    if (! $self->opts->get("with-mymodules-dyn-dir")) {
      $self->override_opt("with-mymodules-dyn-dir", "");
    }
    foreach my $libpath (split(":", $self->opts->get("with-mymodules-dyn-dir"))) {
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
        session => $self->session,
        warning => $self->opts->warning,
        critical => $self->opts->critical,
    };
    bless $obj, "My$class";
    $self->{my} = $obj;
    if ($self->{my}->isa("Classes::SAP")) {
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
          sprintf "Class %s is not a subclass of Classes::SAP%s",
              ref($self->{my}),
              $loaderror ? sprintf " (syntax error in %s?)", $loaderror : "" );
    }
  }
}

sub validate_args {
  my $self = shift;
  $self->SUPER::validate_args();
  $MTE::separator = $self->opts->separator if $self->opts->separator;
  if ($self->opts->get("with-my-modules-dyn-dir")) {
  }
}

sub create_statefile {
  my $self = shift;
  my %params = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s_%s_%s%s", $self->statefilesdir(),
      $self->opts->ashost, $self->opts->sysnr, $self->opts->mode, lc $extension;
}

sub DESTROY {
  my $self = shift;
  my $plugin_exit = $?;
  if ($Classes::SAP::session) {
    $Classes::SAP::session->disconnect();
  }
  #$self->debug("disconnected");
  my $now = time;
  eval {
    my $ramschdir = $ENV{RFC_TRACE_DIR} ? $ENV{RFC_TRACE_DIR} : "/tmp";
    unlink $ramschdir."/dev_rfc.trc" if -f $ramschdir."/dev_rfc.trc";
    no warnings "all";
    foreach (glob $ramschdir."/rfc*.trc") {
      eval {
        if (($now - (stat $_)[9]) > 300) {
          unlink $_;
        }
      };
    }
  };
  $? = $plugin_exit;
}

