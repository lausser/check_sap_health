package Classes::SAP::Netweaver::Component::CCMS;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;


sub init {
  my $self = shift;
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);
  my $bapi_tic = Time::HiRes::time();
  if ($self->mode =~ /netweaver::ccms::/) {
    eval {
      my $rcb = $self->session->function_lookup("SXMI_VERSIONS_GET");
      my $tsl = $rcb->create_function_call;
      #$tsl->INTERFACE("XMB"); # weglassen fuer alle interfaces
      $tsl->invoke;
      my $xmbversion = "0.1";
      my $xalversion = "0.1";
      foreach my $row (@{$tsl->VERSIONS}) {
        $xmbversion = $row->{'VERSION'} if $row->{'INTERFACE'} eq "XMB";
        $xalversion = $row->{'VERSION'} if $row->{'INTERFACE'} eq "XAL";
      }
      my $fl = $self->session->function_lookup("BAPI_XMI_LOGON");
      my $fc = $fl->create_function_call;
      $fc->EXTCOMPANY('LAUSSER');
      $fc->EXTPRODUCT('CHECK_SAP_HEALTH');
      $fc->INTERFACE('XAL');
      $fc->parameter('VERSION')->value($xalversion);
      $fc->invoke;
      if ($fc->RETURN->{TYPE} !~ /^E/) {
        if ($self->mode =~ /netweaver::ccms::moniset::list/) {
          $fl = $self->session->function_lookup("BAPI_SYSTEM_MS_GETLIST");
          $fc = $fl->create_function_call;
          $fc->EXTERNAL_USER_NAME("Agent");
          $fc->invoke;
          my @sets = @{$fc->MONITOR_SETS};
          foreach (@sets) {
            printf "%s\n", $_->{NAME};
          }
          $self->add_ok("have fun");

        } elsif ($self->mode =~ /netweaver::ccms::monitor::list/) {
          $fl = $self->session->function_lookup("BAPI_SYSTEM_MON_GETLIST");
          # details with BAPI_SYSTEM_MS_GETDETAILS
          $fc = $fl->create_function_call;
          $fc->EXTERNAL_USER_NAME("Agent");
          if ($self->opts->name) {
            $fc->MONI_SET_NAME({
                NAME => $self->opts->name,
            });
          }
          $fc->invoke;
          my @names = @{$fc->MONITOR_NAMES};
          foreach my $ms (sort keys %{{ map {$_ => 1} map { $_->{MS_NAME} } @names }}) {
            printf "%s\n", $ms;
            foreach my $moni (sort keys %{{ map {$_ => 1} map { $_->{MONI_NAME} }
                grep { $_->{MS_NAME} eq $ms } @names }}) {
              printf " %s\n", $moni;
            }
          }
          $self->add_ok("have fun");
        } elsif ($self->mode =~ /netweaver::ccms::mte::/) {
          if (! $self->opts->name || ! $self->opts->name2) {
            die "__no_internals__you need to specify --name moniset --name2 monitor";
          }
          if ($self->mode =~ /netweaver::ccms::mte::list/) {
            $self->update_tree_cache(1);
          }
          my @tree_nodes = $self->update_tree_cache(0);
          my %seen;
          my @mtes = sort {
              $a->{MTNAMELONG} cmp $b->{MTNAMELONG}
          } grep {
            $self->filter_name3($_->{MTNAMELONG})
          } grep {
            ! $seen{$_->tid_flat()}++;
          } map { 
              MTE->new(%{$_});
          } @tree_nodes;
          if ($self->mode =~ /netweaver::ccms::mte::list/) {
            foreach my $mte (@mtes) {
              printf "%s %d\n", $mte->{MTNAMELONG}, $mte->{MTCLASS};
            }
          } elsif ($self->mode =~ /netweaver::ccms::mte::check/) {
            $self->set_thresholds();
            foreach my $mte (@mtes) {
              next if grep { $mte->{MTCLASS} == $_ } (50, 70, 199);
              $self->debug(sprintf "collect_details for %s", $mte->{MTNAMELONG});
              $mte->collect_details($self->session);
              $mte->check();
            }
            if (! @mtes) {
              if (defined $self->opts->mitigation()) {
                $self->add_message($self->opts->mitigation(), 'no mtes');
              } else {
                $self->add_unknown("no mtes");
              }
            }
          }
        }
        $self->debug("logoff");
        $fl = $self->session->function_lookup("BAPI_XMI_LOGOFF");
        $fc = $fl->create_function_call;
        $fc->INTERFACE('XAL');
        $fc->invoke;
      } else {
        $self->add_critical($fc->RETURN->{MESSAGE});
      }
    };
    if ($@) {
      my $message = $@;
      $message =~ s/[^[:ascii:]]//g;
      $message =~ s/\s+$//g;
      chomp($message);
      if ($message =~ /__no_internals__/) {
        $message =~ s/at $Monitoring::GLPlugin::pluginname line.*//g;
        $message =~ s/__no_internals__//g;
      }
      $self->add_unknown($message);
    }
  }
  my $bapi_tac = Time::HiRes::time();
  $self->set_thresholds(warning => 5, critical => 10);
  #$self->add_message($self->check_thresholds($bapi_tac - $bapi_tic),
  #     sprintf "runtime was %.2fs", $bapi_tac - $bapi_tic);
  #$self->add_perfdata(
  #    label => 'runtime',
  #    value => $bapi_tac - $bapi_tic,
  #    warning => $self->{warning},
  #    critical => $self->{critical},
  #);
}

sub update_tree_cache {
  my $self = shift;
  my $force = shift;
  my @tree_nodes = ();
  my $statefile = $self->create_statefile(name => 'tree_'.$self->opts->name.'_'.$self->opts->name2);
  my $update = time - 24 * 3600;
  if ($force || ! -f $statefile || ((stat $statefile)[9]) < ($update)) {
    $self->debug(sprintf "updating the tree cache for %s %s",
        $self->opts->name, $self->opts->name2);
    my $fl = $self->session->function_lookup("BAPI_SYSTEM_MON_GETTREE");
    my  $fc = $fl->create_function_call;
    $fc->EXTERNAL_USER_NAME("Agent");
    $fc->MONITOR_NAME({
      MS_NAME => $self->opts->name,
      MONI_NAME => $self->opts->name2,
    });
    $fc->invoke;
    # TREE_NODES
    if ($fc->RETURN->{TYPE} =~ /^E/) {
      $self->add_critical($fc->RETURN->{MESSAGE});
    } else {
      map { push(@tree_nodes, $_) } @{$fc->TREE_NODES};
    }
    $self->debug(sprintf "updated the tree cache for %s %s",
        $self->opts->name, $self->opts->name2);
    $self->save_state(name => 'tree_'.$self->opts->name.'_'.$self->opts->name2, save => \@tree_nodes);
  }
  my $content = do { local (@ARGV, $/) = $statefile; my $x = <>; close ARGV; $x };
  my $VAR1;
  $VAR1 = eval "$content";
  my $cache = $VAR1;;
  @tree_nodes = @{$cache};
  $self->debug(sprintf "return cached tree nodes for %s %s",
      $self->opts->name, $self->opts->name2);
  return @tree_nodes;
}

sub map_alvalue {
  my $self = shift;
  my $value = shift;
  if ($value && 1 <= $value && $value <= 3) {
    return {
      1 => 0,
      2 => 1,
      3 => 2,
    }->{$value};
  } else {
    return 3;
  }
}



package MTE;
our @ISA = qw(Classes::SAP::Netweaver::TableItem);
use strict;

#our @ISA = qw(SAP::CCMS);
# can't inherit, because this undefines the session handle. hurnmatz, greisliche

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;

use constant { GREEN => 1, YELLOW => 2, RED => 3, GRAY => 4 };

# http://www.benx.de/en/sap/program/RSALBAPI---code.htm
use constant MT_CLASS_NO_CLASS    => 0;
use constant MT_CLASS_SUMMARY     => 50;
use constant MT_CLASS_MONIOBJECT  => 70;
use constant MT_CLASS_FIRST_MA    => 99;
use constant MT_CLASS_PERFORMANCE => 100;
use constant MT_CLASS_MSG_CONT    => 101;
use constant MT_CLASS_SINGLE_MSG  => 102;
use constant MT_CLASS_HEARTBEAT   => 103;
use constant MT_CLASS_LONGTEXT    => 110;
use constant MT_CLASS_SHORTTEXT   => 111;
use constant MT_CLASS_VIRTUAL     => 199;
# skip 50, 70, 199

use constant AL_VAL_INAKTIV => 0;
use constant AL_VAL_GREEN => 1;
use constant AL_VAL_YELLOW => 2;
use constant AL_VAL_RED => 3;

# Attribute Type
#  Description
#  
# This graphic is explained in the accompanying text Performance Attribute
#  Collects reported performance values and calculates the average
#  
# This graphic is explained in the accompanying text Status Attribute
#  Reports error message texts and alert status
#  
# This graphic is explained in the accompanying text Heartbeat Attribute
#  Checks whether components of the SAP system are active; if no values are reported for a monitoring attribute for a long time, it triggers an alert
#  
# This graphic is explained in the accompanying text Log Attribute
#  Checks log and trace files (these attributes can use an existing log mechanism, such as the SAP system log, or they can be used by an application for the implementation of a separate log)
#  
# This graphic is explained in the accompanying text Text Attribute
#  Allows a data supplier to report information that is not evaluated for alerts; the text can be updated as required
#  


our $separator = "\\";

{
  sub sap2nagios {
    my $sap = shift;
    my $nagios = 0;
    if ($sap == 1) {
      return OK;
    } elsif ($sap == 2) {
      return WARNING;
    } elsif ($sap == 3) {
      return CRITICAL;
    } elsif ($sap == 4) {
      return UNKNOWN;
    } else {
      return UNKNOWN;
    }
  }
}


sub new {
  my $class = shift;
  my %params = @_;
  my $self = {};
  bless $self, $class;
  foreach (qw(MTSYSID MTCLASS MTMCNAME MTNUMRANGE MTUID MTINDEX EXTINDEX
      OBJECTNAME MTNAMESHRT PRNTMTNAMESHRT)) {
    $self->{$_} = $self->rstrip($params{$_}) if defined $params{$_};
  }
  foreach (qw(ALTREENUM ALIDXINTRE ALLEVINTRE ALPARINTRE VALINDEX)) {
    $self->{$_} = $self->rstrip($params{$_}) if defined $params{$_};
  }
  # CUSGRPNAME = Eigenschaften: ..der MTE-Klasse
  $self->{MTNAMELONG} = $self->mkMTNAMELONG;
  $self->{MTNAGIOSNAME} = $self->opts->mtelong ?
      $self->{MTNAMELONG} : $self->{MTNAMESHRT};
  $self->{TID} = $self->tid();
  if ($self->{MTCLASS} == MT_CLASS_PERFORMANCE) {
    bless $self, "MTE::Performance";
  } elsif ($self->{MTCLASS} == MT_CLASS_MSG_CONT) {
    bless $self, "MTE::ML";
  } elsif ($self->{MTCLASS} == MT_CLASS_SINGLE_MSG) {
    bless $self, "MTE::SM";
  } elsif ($self->{MTCLASS} == MT_CLASS_SHORTTEXT) {
    bless $self, "MTE::ST";
  } else {
  }
  return $self;
                my $bapi = {
                    MT_CLASS_PERFORMANCE() => "BAPI_SYSTEM_MTE_GETPERFCURVAL",
                    MT_CLASS_SINGLE_MSG() => "BAPI_SYSTEM_MTE_GETSMVALUE",
                    #MT_CLASS_MSGCONT() => "BAPI_SYSTEM_MTE_?",
                    MT_CLASS_LONGTEXT() => "BAPI_SYSTEM_MTE_GETMLCURVAL",
                    MT_CLASS_SHORTTEXT() => "BAPI_SYSTEM_MTE_GETTXTPROP",
                }->{$self->{MTCLASS}};

}

sub mkMTNAMELONG {
  my $self = shift;
  my $myname = "";
  if ($self->{MTSYSID}) {
    $myname = $myname.$self->{MTSYSID}.$MTE::separator;
  } else {
    #return undef;
  }
  $myname = $myname.$self->{MTMCNAME}.$MTE::separator;
  if ($self->{PRNTMTNAMESHRT} && $self->{PRNTMTNAMESHRT} ne $self->{MTSYSID}.$MTE::separator.$self->{MTMCNAME}) {
    $myname = $myname.$self->{PRNTMTNAMESHRT}.$MTE::separator;
  }
  if ($self->{OBJECTNAME}) {
    $myname = $myname.$self->{OBJECTNAME}.$MTE::separator;
  } else {
    #return undef;
  }
  if ($self->{OBJECTNAME} ne $self->{MTNAMESHRT}) {
    $myname = $myname.$self->{MTNAMESHRT};
  }
  return $myname;
}

sub collect_details {
  my $self = shift;
  my $session = shift;
  my $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETGENPROP");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  #next if $fc->ACTUAL_ALERT_DATA->{VALUE} == 0;
  $self->{ACTUAL_ALERT_DATA_VALUE} = $fc->ACTUAL_ALERT_DATA->{VALUE};
  $self->{ACTUAL_ALERT_DATA_LEVEL} = $fc->ACTUAL_ALERT_DATA->{LEVEL};
}

sub check {
  my $self = shift;
  $self->debug(sprintf "mte %s has alert %s",
      $self->mkMTNAMELONG(), MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
  $self->add_info("");
  $self->add_message(MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
}

sub tid {
  my $self = shift;
  if (! exists $self->{tid}) {
    $self->{tid} = {
      MTSYSID => $self->{MTSYSID},
      MTMCNAME => $self->{MTMCNAME},
      MTNUMRANGE => $self->{MTNUMRANGE},
      MTUID => $self->{MTUID},
      MTCLASS => $self->{MTCLASS},
      MTINDEX => $self->{MTINDEX},
      EXTINDEX => $self->{EXTINDEX},
    };
  }
  return $self->{tid};
}

sub tid_flat {
  my $self = shift;
  return sprintf "%s_%s_%s_%s_%s_%s_%s_",
      $_->{MTSYSID},
      $_->{MTMCNAME},
      $_->{MTNUMRANGE},
      $_->{MTUID},
      $_->{MTCLASS},
      $_->{MTINDEX},
      $_->{EXTINDEX};
}

sub extra_props {
  my $self = shift;
  my %params = @_;
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


package MTE::Performance;
use strict;
our @ISA = qw(MTE);
use constant { GREEN => 1, YELLOW => 2, RED => 3, GRAY => 4 };

sub collect_details {
  my $self = shift;
  my $session = shift;
  $self->SUPER::collect_details($session);
  my $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETPERFCURVAL");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(ALRELEVVAL AVG15PVAL ALRELVALTI AVG05PVAL MAXPFDATE ALRELVALDT MINPFDATE
      LASTPERVAL MAXPFTIME AVG15SVAL AVG15CVAL MAXPFVALUE AVG01PVAL AVG01SVAL MINPFVALUE
      LASTALSTAT AVG01CVAL AVG05CVAL MINPFTIME AVG05SVAL)) {
    $self->{$_} = $self->strip($fc->CURRENT_VALUE->{$_});
  }
  $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETPERFPROP");
  $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(DECIMALS MSGID RELVALTYPE VALUNIT ATTRGROUP
      TRESHR2Y THRESHDIR TRESHG2Y TRESHY2G THRESHSTAT MSGCLASS TRESHY2R)) {
    $self->{$_} = $self->strip($fc->PROPERTIES->{$_});
  }
  if ($self->{DECIMALS} != 0) {
    # aus SAP_BASIS Modul BC-CCM-MON-OS
    my $exp = 10 ** $self->{DECIMALS};
    $self->{ALRELEVVAL} = sprintf("%.*f", $self->{DECIMALS}, $self->{ALRELEVVAL} / $exp);
    foreach (qw(TRESHR2Y TRESHG2Y TRESHY2G TRESHY2R)) {
      $self->{$_} = sprintf("%.*f", $self->{DECIMALS}, $self->{$_} / $exp) if $self->{$_};
    }
  }
}

sub check {
  my $self = shift;
  my $perfdata = {
    label => $self->{OBJECTNAME}."_".$self->{MTNAGIOSNAME},
    value => $self->{ALRELEVVAL},
  };
  if ($self->{VALUNIT}) {
    my $unit = lc $self->{VALUNIT};
    $unit = "ms" if $unit eq "msec";
    if ($unit =~ /^([u,m]{0,1}s|%|[kmgt]{0,1}b)$/) {
      $perfdata->{uom} = $unit;
    }
  }
  if ($self->{THRESHDIR} == 1 || $self->{THRESHDIR} == 2) {
    if ($self->{THRESHDIR} == 1) {
      $perfdata->{warning} = $self->{TRESHG2Y};
      $perfdata->{critical} = $self->{TRESHY2R};
    } else {
      $perfdata->{warning} = $self->{TRESHG2Y}.":";
      $perfdata->{critical} = $self->{TRESHY2R}.":";
    }
  }
  $self->set_thresholds(warning => $perfdata->{warning}, critical => $perfdata->{critical}, metric => $perfdata->{label});
  delete $perfdata->{warning};
  delete $perfdata->{critical};
  $self->add_perfdata(%{$perfdata});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{ALRELEVVAL}, metric => $perfdata->{label}),
      sprintf "%s %s = %s%s", $self->{OBJECTNAME}, $self->{MTNAGIOSNAME}, $self->{ALRELEVVAL}, $self->{VALUNIT}
  );
}

sub nagios_level { #deprecated
  my $self = shift;
  if ($self->{ACTUAL_ALERT_DATA_VALUE} == 0) {
    if ($self->{THRESHDIR} == 1 || $self->{THRESHDIR} == 2) {
      # this mte is threshold driven
      if ($self->{THRESHDIR} == 1) {
        if ($self->{ALRELEVVAL} > $self->{TRESHY2R}) {
          $self->{ACTUAL_ALERT_DATA_VALUE} = RED;
        } elsif ($self->{ALRELEVVAL} > $self->{TRESHG2Y}) {
          $self->{ACTUAL_ALERT_DATA_VALUE} = YELLOW;
        } else {
          $self->{ACTUAL_ALERT_DATA_VALUE} = GREEN;
        }
      } else {
        if ($self->{ALRELEVVAL} < $self->{TRESHY2R}) {
          $self->{ACTUAL_ALERT_DATA_VALUE} = RED;
        } elsif ($self->{ALRELEVVAL} < $self->{TRESHG2Y}) {
          $self->{ACTUAL_ALERT_DATA_VALUE} = YELLOW;
        } else {
          $self->{ACTUAL_ALERT_DATA_VALUE} = GREEN;
        }
      }
    }
  }
  return MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE});
}



package MTE::ML;
our @ISA = qw(MTE);
use strict;

sub collect_details {
  my $self = shift;
  my $session = shift;
  $self->SUPER::collect_details($session);
  my $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETMLCURVAL");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(MSG)) {
    $self->{$_} = $self->strip($fc->XMI_MSG_EXT->{$_});
  }
}

sub check {
  my $self = shift;
  $self->debug(sprintf "mte %s has alert %s",
      $self->mkMTNAMELONG(), MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
  $self->add_info($self->{MTNAGIOSNAME}." = ".$self->{MSG});
  $self->add_message(MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
}


package MTE::SM;
our @ISA = qw(MTE);
use strict;

sub collect_details {
  my $self = shift;
  my $session = shift;
  $self->SUPER::collect_details($session);
  my $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETSMVALUE");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(MSG SMSGDATE SMSGDATE SMSGVALUE)) {
    $self->{$_} = $self->strip($fc->VALUE->{$_});
  }
}

sub check {
  my $self = shift;
  $self->debug(sprintf "mte %s has alert %s",
      $self->mkMTNAMELONG(), MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
  $self->{MSG} ||= "<empty>";
  $self->add_info($self->{MTNAGIOSNAME}." = ".$self->{MSG});
  $self->add_message(MTE::sap2nagios($self->{ACTUAL_ALERT_DATA_VALUE}));
}


package MTE::ST;
our @ISA = qw(MTE);
use strict;

sub collect_details {
  my $self = shift;
  my $session = shift;
  $self->SUPER::collect_details($session);
  my $fl = $session->function_lookup("BAPI_SYSTEM_MTE_GETTXTPROP");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(TEXT)) {
    $self->{$_} = $self->strip($fc->PROPERTIES->{$_});
  }
}

sub check {
  my $self = shift;
  $self->debug(sprintf "mte %s has alert 0",
      $self->mkMTNAMELONG());
  $self->{TEXT} ||= "<empty>";
  $self->add_info($self->{MTNAGIOSNAME}." = ".$self->{TEXT});
  $self->add_ok();
  if ($self->{TEXT} =~ /([\d\.]+)\s*(s|%|[kmgt]{0,1}b|ms|msec)/) {
    my $value = $1;
    my $unit = $2;
    $self->add_perfdata(
        label => $self->{OBJECTNAME}."_".$self->{MTNAGIOSNAME},
        value => $value,
        uom => $unit eq "msec" ? "ms" : $unit,
    );
  }
}

__END__
CALL FUNCTION 'BAPI_SYSTEM_MTE_GETGENPROP' "Read General Properties of a Monitor Tree Element
  EXPORTING
    tid =                       " bapitid       Monitor Tree Element ID
    external_user_name =        " bapixmlogr-extuser  Name of the SAP-External User
  IMPORTING
    general_info =              " bapimtegen    General Data (Name, MTE Class and so on)
    general_properties =        " bapimteprp    General Customizing data
    general_values =            " bapimteval    Current General Values
    last_value_time =           " bapialdate    Time of Last Value Change
    highest_alert =             " bapiaid       ID of "Highest Alert"
    highest_alert_data =        " bapialdata    Alert Value of "Highest Alert"
    actual_alert =              " bapiaid       ID of "Actual Alert"
    actual_alert_data =         " bapialdata    Alert Value of Actual Alert
    collection_tool_def =       " bapitldef     Effectively Assigned Data Collection Method
    onalert_tool_def =          " bapitldef     Effectively Assigned Auto-Reaction Method
    analyze_tool_def =          " bapitldef     Effectively Assigned Analysis Method
    collection_tool_run =       " bapitlrun     Runtime Information for Data Collection Method
    onalert_tool_run =          " bapitlrun     Runtime Information for Auto-Reaction Method
    parent_tid =                " bapitid       Parent Node ID
    parent_data =               " bapiparent    Information About the Parent Node
    return =                    " bapiret2      Return Messages
    .  "  BAPI_SYSTEM_MTE_GETGENPROP

actual_alert_data =
VALUE ALVALUE INT4 000010  Alert value 
SEVERITY ALSEVERITY INT4 000010  severity 

VALUE = 
AL_VAL_INAKTIV: White MTE, no data is being reported. Integer value 0.
AL_VAL_GREEN: Green MTE, no alert is generated. Integer value 1.
AL_VAL_YELLOW: Yellow MTE, yellow alert is generated. Integer value 2.
AL_VAL_RED: Red MTE, highest possible alert, red alert is generated. Integer value 3.

SEVERITY =
Severity is measured with a scale from 0 (not important) to 255 (very important). 

