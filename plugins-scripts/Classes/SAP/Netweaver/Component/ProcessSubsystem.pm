package Classes::SAP::Netweaver::Component::ProcessSubsystem;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;


sub init {
  my $self = shift;
  my $fl = $self->session->function_lookup("TH_WPINFO");
  my $fc = $fl->create_function_call;
  my @fields = qw(WP_TYP WP_STATUS WP_PID);
  $fc->invoke;
  @{$self->{workprocs}} = map {
    WorkProc->new(
        WP_TYP => $_->{WP_TYP},
        WP_PID => $_->{WP_PID},
        WP_STATUS => $_->{WP_STATUS},
    );
  } @{$fc->WPLIST};
  if ($self->mode =~ /netweaver::processes::count/) {
    # Note 39412
    $self->{types} = [qw(DIA UPD UP2 BGD ENQ SPO)];
    $self->{types} = [map {
        s/^\s*//g; $_;
    } map {
        s/\s*$//g; $_;
    } map {
        uc $_;
    } split(/,/, $self->opts->name)] if $self->opts->name;
    $self->{num_types} = {};
    foreach my $type (@{$self->{types}}) {
      $self->{num_types}->{$type} = 0;
      map { $self->{num_types}->{$_->{WP_TYP}}++ if $_->{WP_TYP} eq $type; } @{$self->{workprocs}};
    }
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /netweaver::processes::list/) {
    $self->SUPER::check();
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /netweaver::processes::count/) {
    foreach my $type (@{$self->{types}}) {
      $self->{num_types}->{$type} = 0 if ! exists $self->{num_types}->{$type};
      my $metric = lc 'num_'.$type;
      $self->set_thresholds(metric => $metric,
          warning => '1:', critical => '1:',
      );
      $self->add_message(
          $self->check_thresholds(metric => $metric, value => $self->{num_types}->{$type}),
          sprintf "%d %s process%s", $self->{num_types}->{$type}, $type, $self->{num_types}->{$type} == 1 ? "" : "es");
      $self->add_perfdata(
          label => $metric, value => $self->{num_types}->{$type},
      );
    }
  } else {
    if (! @{$self->{workprocs}}) {
      $self->add_unknown("no workprocs were found");
    }
  }
}


package WorkProc;
our @ISA = qw(Classes::SAP::Netweaver::TableItem);
use strict;

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

sub finish {
  my $self = shift;
  foreach (qw(WP_TYP WP_PID WP_STATUS)) {
    $self->{$_} = $self->strip($self->{$_});
  }
  # BTC and BGD are technically the same, it is only a different translation
  # from German (BTC) to English (BGD).
  # Depending on the logon language the WP type is either BTC or BGD,
  # but never both.
  if ($self->{WP_TYP} eq 'BTC') {
    $self->{WP_TYP} = 'BGD';
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /netweaver::processes::list/) {
    printf "%s %s %s\n", $self->{WP_TYP}, $self->{WP_PID}, $self->{WP_STATUS};
  }
}


