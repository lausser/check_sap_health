package Classes::SAP::Netweaver;
our @ISA = qw(Classes::SAP);

use strict;
use File::Basename;
use Time::HiRes;
use Time::Local;
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
      'LCHECK' => '1',
    );
    if ($self->opts->ashost) {
      $params{ASHOST} = $self->opts->ashost;
    }
    if ($self->opts->sysnr) {
      $params{SYSNR} = $self->opts->sysnr;
    }
    if ($self->opts->mshost) {
      $params{MSHOST} = $self->opts->mshost;
    }
    if ($self->opts->msserv) {
      $params{MSSERV} = $self->opts->msserv;
    }
    if ($self->opts->r3name) {
      $params{R3NAME} = $self->opts->r3name;
    }
    if ($self->opts->group) {
      $params{GROUP} = $self->opts->group;
    }
    if ($self->opts->gwhost) {
      $params{GWHOST} = $self->opts->gwhost;
    }
    if ($self->opts->gwserv) {
      $params{GWSERV} = $self->opts->gwserv;
    }
    if ($self->opts->client) {
      $params{CLIENT} = $self->opts->client;
    }
    if ($self->opts->lang) {
      $params{LANG} = $self->opts->lang;
    }
    if ($self->opts->username) {
      $params{USER} = $self->opts->username;
    }
    if ($self->opts->password) {
      $params{PASSWD} = $self->decode_password($self->opts->password);
    }
    if ($self->opts->verbose) {
      $params{DEBUG} = '1';
      $params{TRACE} = '1';
    }
    if ($self->opts->mode =~ /sapinfo/) {
      $params{LCHECK} = '0';
      $params{USER} = "";
      $params{PASSWD} = "";
      $params{ABAP_DEBUG} = 0;
      $params{SAPGUI} = 0;
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
      $Classes::SAP::Netweaver::session = $session;
    }
    $self->{tac} = Time::HiRes::time();
  } else {
    $self->add_message(CRITICAL,
        'could not load perl module SAPNW');
  }
}

sub session {
  my $self = shift;
  return $Classes::SAP::Netweaver::session;
}

sub init {
  my $self = shift;
  if ($self->mode =~ /^netweaver::connectiontime/) {
    my $fc = undef;
    if ($self->mode =~ /^netweaver::connectiontime::sapinfo/) {
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
    if ($self->mode =~ /^netweaver::connectiontime::sapinfo/) {
      # extraoutput
      # $fc
    }
  } elsif ($self->mode =~ /^netweaver::ccms::/) {
    $self->analyze_and_check_ccms_subsystem("Classes::SAP::Netweaver::Component::CCMS");
  } elsif ($self->mode =~ /^netweaver::snap::/) {
    $self->analyze_and_check_snap_subsystem("Classes::SAP::Netweaver::Component::SNAP");
  } elsif ($self->mode =~ /^netweaver::updates::/) {
    $self->analyze_and_check_snap_subsystem("Classes::SAP::Netweaver::Component::UpdateSubsystem");
  } elsif ($self->mode =~ /^netweaver::backgroundjobs::/) {
    $self->analyze_and_check_snap_subsystem("Classes::SAP::Netweaver::Component::BackgroundjobSubsystem");
  } elsif ($self->mode =~ /^netweaver::processes::/) {
    $self->analyze_and_check_proc_subsystem("Classes::SAP::Netweaver::Component::ProcessSubsystem");
  } elsif ($self->mode =~ /^netweaver::idocs::/) {
    $self->analyze_and_check_proc_subsystem("Classes::SAP::Netweaver::Component::IdocSubsystem");
    $self->reduce_messages_short('no idoc problems');
  } elsif ($self->mode =~ /^netweaver::workload::/) {
    $self->analyze_and_check_proc_subsystem("Classes::SAP::Netweaver::Component::WorkloadSubsystem");
    $self->reduce_messages_short('no workload problems');
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
  $extension .= $self->opts->name ? '_'.$self->opts->name : '';
  $extension .= $self->opts->name2 ? '_'.$self->opts->name2 : '';
  $extension .= $self->opts->name3 ? '_'.$self->opts->name3 : '';
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  $extension =~ s/\//_/g;
  $extension =~ s/\|/_/g;
  my $target = "";
  $target .= $self->opts->ashost.'_'.$self->opts->sysnr if $self->opts->ashost;
  $target .= $self->opts->mshost if $self->opts->mshost;
  $target .= $self->opts->msserv if $self->opts->msserv;
  $target .= $self->opts->r3name if $self->opts->r3name;
  $target .= $self->opts->group if $self->opts->group;
  $target .= $self->opts->gwhost if $self->opts->gwhost;
  $target .= $self->opts->gwserv if $self->opts->gwserv;
  $target =~ s/\//_/g;
  return sprintf "%s/%s_%s%s", $self->statefilesdir(),
      $target, $self->opts->mode, lc $extension;
}

sub epoch_to_abap_date {
  my $self = shift;
  my $timestamp = shift || time;
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime($timestamp);
  return sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
}

sub epoch_to_abap_time {
  my $self = shift;
  my $timestamp = shift || time;
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime($timestamp);
  return sprintf "%02d%02d%02d", $hour, $min, $sec;
}

sub epoch_to_abap_date_and_time {
  my $self = shift;
  my $timestamp = shift || time;
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime($timestamp);
  my $date = sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
  my $time = sprintf "%02d%02d%02d", $hour, $min, $sec;
  return ($date, $time);
}

sub abap_date_and_time_to_epoch {
  my ($self, $date, $time) = @_;
  $date =~ /(\d\d\d\d)(\d\d)(\d\d)/;
  my ($year, $mon, $mday) = ($1, $2, $3);
  $time =~ /(\d\d)(\d\d)(\d\d)/;
  my ($hour, $min, $sec) = ($1, $2, $3);
  return timelocal($sec, $min, $hour, $mday, $mon - 1, $year);
}

sub compatibility_methods {
  my ($self) = @_;
  # there are no old-style extensions out there
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
  if (ref($message) eq "HASH") {
    foreach (keys %{$message}) {
      $self->strip($message->{$_});
    }
  } else {
    $message =~ s/^\s+//g;
    $message = $self->rstrip($message);
  }
  return $message;
}

sub DESTROY {
  my ($self) = @_;
  if (ref($self) ne "Classes::SAP") {
    return;
    # Dieses DESTROY wird auch von irgendwelchen schwindligen Erbschleichern
    # aufgerufen, die mir hier die Session womoeglich zumachen.
  }
  my $plugin_exit = $?;
  if ($Classes::SAP::Netweaver::session) {
    $Classes::SAP::Netweaver::session->disconnect();
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

