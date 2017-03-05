package Classes::SAP::Netweaver::Component::IdocSubsystem;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->{idocs} = [];
  my %languages = ();
  my %messages = ();
  if ($self->mode =~ /netweaver::idocs/) {
    my $now = time - 1;
    my ($todate, $totime) = $self->epoch_to_abap_date_and_time($now);
    my $from = $self->opts->lookback ? $now - $self->opts->lookback :
        $self->load_state( name => "to" ) ? $self->load_state( name => "to" )->{to} :
        $now - 3600;
    my ($fromdate, $fromtime) = $self->epoch_to_abap_date_and_time($from + 1);

    my $t002fl = $self->session->function_lookup("RFC_READ_TABLE");
    my $t002fc = $t002fl->create_function_call;
    $t002fc->QUERY_TABLE("T002");
    $t002fc->DELIMITER(";");
    my @t002fcfields = qw(SPRAS LAISO);
    $t002fc->FIELDS([map { { 'FIELDNAME' => $_ } } @t002fcfields]);
    $t002fc->invoke;
    map {
        $languages{$_->[0]} = $_->[1];
    } map {
        my($a, $b) = ($_->[0], $_->[1]); $b =~ s/\s*$//; [$a, $b];
    } map {
        [split(';', $_->{WA})];
    } @{$t002fc->DATA};
    %languages = reverse %languages;
    my $shortlang = $languages{uc $self->opts->lang};

    my $teds2fl = $self->session->function_lookup("RFC_READ_TABLE");
    my $teds2fc = $teds2fl->create_function_call;
    $teds2fc->QUERY_TABLE("TEDS2");
    $teds2fc->DELIMITER(";");
    my @teds2fcfields = qw(STATUS LANGUA DESCRP);
    $teds2fc->FIELDS([map { { 'FIELDNAME' => $_ } } @teds2fcfields]);
    $teds2fc->invoke;
    map {
        $messages{$_->[0]}{$_->[1]} = $_->[2];
    } map {
        my($a, $b, $c) = ($_->[0], $_->[1], $_->[2]); $c =~ s/\s*$//; [$a, $b, $c];
    } map {
        [split(';', $_->{WA})];
    } @{$teds2fc->DATA};

    my $fl = $self->session->function_lookup("RFC_READ_TABLE");
    my $fc = $fl->create_function_call;
    $fc->QUERY_TABLE("EDIDS");
    $fc->DELIMITER(";");
    my $condition = sprintf "LOGDAT >= '%s' AND LOGTIM > '%s'", $fromdate, $fromtime;
    my @options = ();
    while ($condition ne "") {
      $condition =~ /(.{1,70}(\s|$))/ms;
      push(@options, {'TEXT' => $1});
      $condition = $';
    }
    $fc->OPTIONS(\@options);
    my @fields = qw(MANDT DOCNUM LOGDAT LOGTIM STATUS UNAME REPID STATXT STATYP);
    $fc->FIELDS([map { { 'FIELDNAME' => $_ } } @fields]);
    $fc->invoke;
    @{$self->{idocs}} = grep {
      $self->filter_name($_->{MANDT}) && $self->filter_name2($_->{REPID});
    } map {
      my %hash = ();
      my @values = split(";", $_->{WA});
      @hash{@fields} = @values;
      eval {
        $hash{STATUSDESCRP} = $messages{$hash{STATUS}}{$shortlang};
      };
      $hash{STATUSDESCRP} = '-unknown-' if $@;
      IdocStatus->new(%hash);
    } @{$fc->DATA};
  }
}

package IdocStatus;
our @ISA = qw(Classes::SAP::Netweaver::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  my @fields = qw(MANDT DOCNUM LOGDAT LOGTIM STATUS UNAME REPID STATXT STATYP);
  foreach (@fields) {
    if (! defined $self->{$_}) {
      $self->{$_} = '-undef-';
    }
    $self->{$_} =~ s/^\s+//g;
    $self->{$_} =~ s/\s+$//g;
  }
  $self->{STATYP} ||= 'I';
  $self->{STATYPLONG} = {
    'A' => 'Cancel',
    'W' => 'Warning',
    'E' => 'Error',
    'S' => 'Success',
    'I' => 'Information',
  }->{$self->{STATYP}};
  $self->{TIMESTAMP} = $self->abap_date_and_time_to_epoch(
    $self->{LOGDAT}, $self->{LOGTIM}
  );
}

sub check {
  my ($self) = @_;
  if ($self->mode =~ /netweaver::idocs::list/) {
    printf "%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n",
        $self->{MANDT}, $self->{DOCNUM}, $self->{LOGDAT},
        $self->{LOGTIM}, $self->{STATUS}, $self->{STATUSDESCRP},
        $self->{UNAME}, $self->{REPID}, $self->{STATXT}, $self->{STATYP};
  } elsif ($self->mode =~ /netweaver::idocs::failed/) {
    $self->add_info(sprintf "idoc %s has status \"%s\" (%s) at %s",
        $self->{DOCNUM}, $self->{STATUSDESCRP}, $self->{STATYPLONG}, 
        scalar localtime $self->{TIMESTAMP});
    if ($self->{STATYP} eq "A") {
      $self->add_ok();
    } elsif ($self->{STATYP} eq "W") {
      $self->add_warning();
    } elsif ($self->{STATYP} eq "E") {
      $self->add_critical();
    } elsif ($self->{STATYP} eq "S") {
      $self->add_ok();
    } elsif ($self->{STATYP} eq "I") {
      $self->add_ok();
    }
  }
}

