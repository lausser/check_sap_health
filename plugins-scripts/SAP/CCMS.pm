package SAP::CCMS;

our @ISA = qw(SAP::Server);

use strict;
use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;

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
# skip 50, 70, 110, 111, 199

use constant AL_VAL_INAKTIV => 0;
use constant AL_VAL_GREEN => 1;
use constant AL_VAL_YELLOW => 2;
use constant AL_VAL_RED => 3;


sub init {
  my $self = shift;
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);
  my $bapi_tic = Time::HiRes::time();
  if ($self->mode =~ /server::ccms::/) {
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
        if ($self->mode =~ /server::ccms::moniset::list/) {
          $fl = $self->session->function_lookup("BAPI_SYSTEM_MS_GETLIST");
          $fc = $fl->create_function_call;
          $fc->EXTERNAL_USER_NAME("Agent");
          $fc->invoke;
          my @sets = @{$fc->MONITOR_SETS};
          foreach (@sets) {
            printf "%s\n", $_->{NAME};
          }
          $self->add_message(OK, "have fun");

        } elsif ($self->mode =~ /server::ccms::monitor::list/) {
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
          $self->add_message(OK, "have fun");
        } elsif ($self->mode =~ /server::ccms::mte::/) {
          if (! $self->opts->name || ! $self->opts->name2) {
            die "__no_internals__you need to specify --name moniset --name2 monitor";
          }
          $fl = $self->session->function_lookup("BAPI_SYSTEM_MON_GETTREE");
          $fc = $fl->create_function_call;
          $fc->EXTERNAL_USER_NAME("Agent");
          $fc->MONITOR_NAME({
            MS_NAME => $self->opts->name,
            MONI_NAME => $self->opts->name2,
          });
          $fc->invoke;
          # TREE_NODES
          if ($fc->RETURN->{TYPE} =~ /^E/) {
            $self->add_message(CRITICAL, $fc->RETURN->{MESSAGE});
          } else {
            my @mtes = sort {
                $a->{MTNAMELONG} cmp $b->{MTNAMELONG}
            } grep {
              $self->filter_name3($_->{MTNAMELONG})
            } map { 
                MTE->new(%{$_});
            } @{$fc->TREE_NODES};
            if ($self->mode =~ /server::ccms::mte::list/) {
              foreach my $mte (@mtes) {
                printf "%s %d\n", $mte->{MTNAMELONG}, $mte->{MTCLASS};
              }
            } elsif ($self->mode =~ /server::ccms::mte::check/) {
              foreach my $mte (@mtes) {
                next if ! grep $mte->{MTCLASS}, (100, 101);
                #next if $mte->{ACTUAL_ALERT_DATA_VALUE} == 0;
                $mte->collect_details($self->session);
                if (keys %{$mte->perfdata()}) {
                  $self->add_perfdata(%{$mte->perfdata()});
                }
                $self->add_message($mte->nagios_level(), $mte->nagios_message());
              }
              if (! @mtes) {
                $self->add_message(UNKNOWN, "no mtes");
              }
            }
          }
        }
        $fl = $self->session->function_lookup("BAPI_XMI_LOGOFF");
        $fc = $fl->create_function_call;
        $fc->INTERFACE('XAL');
        $fc->invoke;
      } else {
        $self->add_message(CRITICAL, $fc->RETURN->{MESSAGE});
      }
    };
    if ($@) {
      my $message = $@;
      $message =~ s/[^[:ascii:]]//g;
      $message =~ s/\s+$//g;
      chomp($message);
      if ($message =~ /__no_internals__/) {
        $message =~ s/at $0 line.*//g;
        $message =~ s/__no_internals__//g;
      }
      $self->add_message(UNKNOWN, $message);
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

sub map_alvalue {
  my $self = shift;
  my $value = shift;
  if ($value && 1 <= $value && $value <= 3) {
    return {
      1 => OK,
      2 => WARNING,
      3 => CRITICAL,
    }->{$value};
  } else {
    return UNKNOWN;
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

