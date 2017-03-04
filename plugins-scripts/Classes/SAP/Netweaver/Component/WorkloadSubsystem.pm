package Classes::SAP::Netweaver::Component::WorkloadSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SAP::Netweaver::Item);
use strict;

sub translate_tasktype {
  my ($self, $tasktype) = @_;
  # CL_SWNC_CONSTANTS
  # https://archive.sap.com/discussions/thread/243829
  # CL_SWNC_CONSTANTS::TRANSLATE_TASKTYPE
  my $tasktypes = {
      '01' => 'DIALOG',
      '02' => 'UPDATE',
      '03' => 'SPOOL',
      '04' => 'BCKGRD',
      '05' => 'ENQUEUE',
      '06' => 'BUF.SYN',
      '07' => 'AUTOABA',
      '08' => 'UPDATE2',
      '0A' => 'EXT.PLUGIN',
      '0B' => 'AUTOTH',
      '0C' => 'RPCTH',
      '0D' => 'RFCVMC',
      '0E' => 'DDLOG',
      '0F' => 'DEL.',
      '10' => 'AUTOJAVA',
      '11' => 'LICENCESRV',
      '21' => 'ANDERE',
      '22' => 'DINOGUI',
      '23' => 'B.INPUT',
      '65' => 'HTTP',
      '66' => 'HTTPS',
      '67' => 'NNTP',
      '68' => 'SMTP',
      '69' => 'FTP',
      '6C' => 'LCOM',
      '75' => 'HTTP/JSP',
      '76' => 'HTTPS/JSP',
      'FC' => 'ESI',
      'FD' => 'ALE',
      'FE' => 'RFC',
      'FF' => 'CPIC',
  };
  return exists $tasktypes->{uc $tasktype} ? $tasktypes->{uc $tasktype} : 'UNKNOWN';
}

sub init {
  my ($self) = @_;
  if ($self->mode =~ /netweaver::workload/) {
    $self->{tasktypes} = [];
    my $now = time - 1;
    my ($todate, $totime) = $self->epoch_to_abap_date_and_time($now);
    my $from = $self->opts->lookback ? $now - $self->opts->lookback :
        $self->load_state( name => "to" ) ? $self->load_state( name => "to" )->{to} :
        $now - 3600;
    my ($fromdate, $fromtime) = $self->epoch_to_abap_date_and_time($from + 1);
    my $fl = $self->session->function_lookup("SWNC_GET_WORKLOAD_SNAPSHOT ");
    my $fc = $fl->create_function_call;
    $fc->READ_START_DATE($fromdate);
    $fc->READ_START_TIME($fromtime);
    $fc->READ_END_DATE($todate);
    $fc->READ_END_TIME($totime);
    $fc->invoke;
    my $avg_times = {};
    my @types = @{$fc->TASKTYPE};
    foreach my $row (@types) {
      my $entry_id = unpack "H*", $row->{TASKTYPE};
      foreach my $key (keys %{$row}) {
        if ($key eq "COUNT" || $key =~ /.*TI$/) {
          if (exists $avg_times->{$entry_id}->{$key}) {
            $avg_times->{$entry_id}->{$key} += $row->{$key};
          } else {
            $avg_times->{$entry_id}->{$key} = $row->{$key};
          }
        }
      }
    }
    foreach my $tasktype (keys %{$avg_times}) {
      my @times = ();
      foreach my $key (keys %{$avg_times->{$tasktype}}) {
        if ($key =~ /.*TI$/) {
          $avg_times->{$tasktype}->{$key.'AVG'} =
              $avg_times->{$tasktype}->{$key} / $avg_times->{$tasktype}->{COUNT};
        }
      }
#        printf "%s %d %.2f\n", $tasktype, $avg_times->{$tasktype}->{COUNT},
#            $avg_times->{$tasktype}->{RESPTIAVG};
      push(@{$self->{tasktypes}}, Classes::SAP::Netweaver::Component::WorkloadSubsystem::Task->new(
          name => $self->translate_tasktype($tasktype),
          count => $avg_times->{$tasktype}->{COUNT},
          avg_response_time => $avg_times->{$tasktype}->{RESPTIAVG},
      ));
      $self->save_state( name => "to", save => {to => $now} );
    };
    if ($@) {
      $self->add_unknown($@);
    }
  }
}

sub check {
  my ($self) = @_;
  foreach (@{$self->{tasktypes}}) {
    $_->check();
  }
}

package Classes::SAP::Netweaver::Component::WorkloadSubsystem::Task;
our @ISA = qw(Monitoring::GLPlugin::SAP::Netweaver::TableItem);
use strict;

sub check {
  my ($self) = @_;
  $self->valdiff({ name => $self->{name} }, qw(count));
  my $label = $self->{name}.'_avg_response_time';
  $self->add_info(sprintf "%s: %d steps (%.2f/s), avg time was %.2fms", $self->{name}, $self->{count}, $self->{count_per_sec}, $self->{avg_response_time});
  $self->set_thresholds(
      metric => $label,
      warning => 500,
      critical => 1000,
  );
  $self->add_message($self->check_thresholds(
      metric => $label,
      value => $self->{avg_response_time}));
  $self->add_perfdata(
      label => $label,
      value => $self->{avg_response_time},
      uom => 'ms',
  );
  $self->add_perfdata(
      label => $label,
      value => $self->{avg_response_time},
      uom => 'ms',
  );
  $self->add_perfdata(
      label => $self->{name}.'_steps_per_sec',
      value => $self->{count_per_sec},
      uom => 'ms',
  );
}

