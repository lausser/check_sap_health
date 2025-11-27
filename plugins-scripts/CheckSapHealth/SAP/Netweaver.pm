package CheckSapHealth::SAP::Netweaver;
our @ISA = qw(CheckSapHealth::SAP);

use strict;
use File::Basename;
use Time::HiRes;
use Time::Local;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use AutoLoader;
use File::Spec;
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
    if ($self->opts->saprouter) {
      $params{SAPROUTER} = $self->opts->saprouter;
      if (rindex($params{SAPROUTER}, "/H/", 0) != 0) {
        $params{SAPROUTER} = "/H/".$params{SAPROUTER};
      }
    }
    if ($self->opts->group) {
      # Wenn man nichts angibt, dann ist beim NWRFCSDK "PUBLIC" der Default.
      # Sollte man aber nicht nehmen, da diese Group fuer SAPGUI-Benutzer
      # gedacht ist. Besser ist "INTERFACE".
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
      $params{PASSWD} = $self->opts->password;
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
    if ($self->opts->snc) {
      # The SNC flag to indicate whether the communication should use SNC protection	
      # 0 - Do not apply SNC to connections.
      # 1 - Apply SNC to connections.
      $params{'SNC_MODE'} = '1';
      # SNC_MYNAME
      # Client SNC name (DataStage Server SNC Name).\
      # It is also referred as client Personal Security Environment (PSE) Name.
      # A valid client SNC name, which is equal to
      # Distinguished Name(DN) of client PSE
      # SNC_PARTNERNAME
      # The communication partner's SNC name.
      # Therefore, this is SAP server SNC PSE name.
      # A valid SAP server SNC name, which is equal to
      # Distinguished Name(DN) of SAP server PSE
      # SNC_QOP
      # The quality of protection level.
      # Enter one of the following values:
      # 1 - Apply authentication only.
      # 2 - Apply authentication and integrity protection
      # 3 - Apply authentication, integrity, and privacy protection (encryption)
      # 8 - Apply global default protection (usually 3)
      # 9 - Apply the maximum protection.
      # SNC_LIB
      # The external security product's library
      # The path and file name for the SAP Cryptography library.

      if ($self->opts->get('secudir')) {
        $ENV{'SECUDIR'} = $self->opts->get('secudir');
      }
      if ($self->opts->get('snclib')) {
        $params{'SNC_LIB'} = $self->opts->get('snclib');
      } else {
        my $found_snc_lib = 0;
        if (exists $ENV{LD_LIBRARY_PATH} && $ENV{LD_LIBRARY_PATH} ne '') {
          foreach my $dir (split(/:/, $ENV{LD_LIBRARY_PATH})) {
            my $snc_lib_path = File::Spec->catfile($dir, 'libsapcrypto.so');
            if (-f $snc_lib_path) {
              $params{'SNC_LIB'} = $snc_lib_path;
              $self->debug("Found libsapcrypto.so in LD_LIBRARY_PATH: %s", $snc_lib_path);
              $found_snc_lib = 1;
              last; # Stop searching once found
            }
          }
        }
        if (!$found_snc_lib) {
          $self->debug("libsapcrypto.so not found in LD_LIBRARY_PATH and --snc-lib not provided.");
        }
      }
      if ($self->opts->sncmyname) {
        $params{'SNC_MYNAME'} = $self->opts->sncmyname;
      }
      if ($self->opts->sncpartnername) {
        $params{'SNC_PARTNERNAME'} = $self->opts->sncpartnername;
      }
      $params{'SNC_QOP'} = $self->opts->get('sncqop');
      $params{'SNC_SSO'} = '0';
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
      $CheckSapHealth::SAP::Netweaver::session = $session;
    }
    $self->{tac} = Time::HiRes::time();
  } else {
    $self->add_message(CRITICAL,
        'could not load perl module SAPNW');
  }
}

sub session {
  my $self = shift;
  return $CheckSapHealth::SAP::Netweaver::session;
}

sub set_failed_connection_flag {
  my($self) = @_;
  my $save_name = $self->opts->name;
  my $save_name2 = $self->opts->name2;
  my $save_name3 = $self->opts->name3;
  my $save_mode = $self->opts->mode;
  $self->override_opt("name", "");
  $self->override_opt("name2", "");
  $self->override_opt("name3", "");
  $self->override_opt("mode", "");
  $self->save_state(name => 'connection_failed');
  $self->override_opt("name", $save_name);
  $self->override_opt("name2", $save_name2);
  $self->override_opt("name3", $save_name3);
  $self->override_opt("mode", $save_mode);
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
    $self->analyze_and_check_ccms_subsystem("CheckSapHealth::SAP::Netweaver::Component::CCMS");
  } elsif ($self->mode =~ /^netweaver::snap::/) {
    $self->analyze_and_check_snap_subsystem("CheckSapHealth::SAP::Netweaver::Component::SNAP");
  } elsif ($self->mode =~ /^netweaver::updates::/) {
    $self->analyze_and_check_snap_subsystem("CheckSapHealth::SAP::Netweaver::Component::UpdateSubsystem");
  } elsif ($self->mode =~ /^netweaver::backgroundjobs::/) {
    $self->analyze_and_check_snap_subsystem("CheckSapHealth::SAP::Netweaver::Component::BackgroundjobSubsystem");
  } elsif ($self->mode =~ /^netweaver::processes::/) {
    $self->analyze_and_check_proc_subsystem("CheckSapHealth::SAP::Netweaver::Component::ProcessSubsystem");
  } elsif ($self->mode =~ /^netweaver::idocs::/) {
    $self->analyze_and_check_idoc_subsystem("CheckSapHealth::SAP::Netweaver::Component::IdocSubsystem");
    $self->reduce_messages_short(sprintf "%d idoc status checked, no problems found", $self->{components}->{idoc_subsystem}->{num_idoc_status});
  } elsif ($self->mode =~ /^netweaver::workload::/) {
    $self->analyze_and_check_proc_subsystem("CheckSapHealth::SAP::Netweaver::Component::WorkloadSubsystem");
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
  if (ref($self) ne "CheckSapHealth::SAP") {
    return;
    # Dieses DESTROY wird auch von irgendwelchen schwindligen Erbschleichern
    # aufgerufen, die mir hier die Session womoeglich zumachen.
  }
  my $plugin_exit = $?;
  if ($CheckSapHealth::SAP::Netweaver::session) {
    $CheckSapHealth::SAP::Netweaver::session->disconnect();
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

