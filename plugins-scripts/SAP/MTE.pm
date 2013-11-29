package MTE;

our @ISA = qw(SAP::CCMS);

use strict;

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




our $separator = "\\";

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
  $self->{TID} = $self->tid();
  if ($self->{MTCLASS} == MT_CLASS_PERFORMANCE) {
    bless $self, "MTE::Performance";
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

sub nagios {
  my $self = shift;
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
  $message =~ s/^\s+//g;
  $message = $self->rstrip($message);
  return $message;
}


package MTE::Performance;

our @ISA = qw(MTE);

sub collect_details {
  my $self = shift;
  my $session = shift;
  $self->SUPER::collect_details($session);
  my $fl = $self->session->function_lookup("BAPI_SYSTEM_MTE_GETPERFCURVAL");
  my $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(ALRELEVVAL AVG15PVAL ALRELVALTI AVG05PVAL MAXPFDATE ALRELVALDT MINPFDATE
      LASTPERVAL MAXPFTIME AVG15SVAL AVG15CVAL MAXPFVALUE AVG01PVAL AVG01SVAL MINPFVALUE
      LASTALSTAT AVG01CVAL AVG05CVAL MINPFTIME AVG05SVAL)) {
    $self->{$_} = $self->strip($fc->CURRENT_VALUE->{$_});
  }
  $fl = $self->session->function_lookup("BAPI_SYSTEM_MTE_GETPERFPROP");
  $fc = $fl->create_function_call;
  $fc->TID($self->tid);
  $fc->EXTERNAL_USER_NAME("CHECK_SAP_HEALTH");
  $fc->invoke;
  foreach (qw(DECIMALS MSGID RELVALTYPE VALUNIT ATTRGROUP
      TRESHR2Y THRESHDIR TRESHG2Y TRESHY2G THRESHSTAT MSGCLASS TRESHY2R)) {
    $self->{$_} = $self->strip($fc->PROPERTIES->{$_});
  }

}

sub perfdata {
  my $self = shift;
  my $perfdata = {
    label => $self->{OBJECTNAME}."_".$self->{MTNAMESHRT},
    value => $self->{ALRELEVVAL},
  };
  if ($self->{VALUNIT}) {
    my $unit = lc $self->{VALUNIT};
    $unit = "ms" if $unit eq "msec";
    if ($unit =~ /^([u,m]{0,1}s|%|[kmgt]{0,1}b)$/) {
      $perfdata->{uom} = $unit;
    }
  }
  return $perfdata;
  #warning
  #critical
}

sub nagios {
  my $self = shift;
  return {};
}

