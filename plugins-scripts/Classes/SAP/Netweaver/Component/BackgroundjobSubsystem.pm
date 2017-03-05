package Classes::SAP::Netweaver::Component::BackgroundjobSubsystem;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;


sub init {
  my $self = shift;
  $self->{jobs} = [];
  eval {
    my $now = time - 1;
    my ($todate, $totime) = $self->epoch_to_abap_date_and_time($now);
    my $from = $self->opts->lookback ? $now - $self->opts->lookback :
        $self->load_state( name => "to" ) ? $self->load_state( name => "to" )->{to} :
        $now - 3600;
    my ($fromdate, $fromtime) = $self->epoch_to_abap_date_and_time($from + 1);
    my $fl = $self->session->function_lookup("RFC_READ_TABLE");
    my $fc = $fl->create_function_call;
    $fc->QUERY_TABLE("TBTCO");
    $fc->DELIMITER(";");
    my $condition = sprintf "ENDDATE >= '%s' AND ENDTIME > '%s'", $fromdate, $fromtime;
    my @options = ();
    while ($condition ne "") {
      $condition =~ /(.{1,70}(\s|$))/ms;
      push(@options, {'TEXT' => $1});
      $condition = $';
    }
    $fc->OPTIONS(\@options);
    my @fields = qw(JOBNAME SDLUNAME STRTDATE STRTTIME ENDDATE ENDTIME STATUS SDLSTRTDT SDLSTRTTM);
    $fc->FIELDS([map { { 'FIELDNAME' => $_ } } @fields]);
    $fc->invoke;
    @{$self->{jobs}} = sort {
      $a->{stop} <=> $b->{stop}
    } grep {
      $self->filter_name($_->{JOBNAME}) && $self->filter_name2($_->{SDLUNAME});
    } map {
      my %hash = ();
      my @values = split(";", $_->{WA});
      @hash{@fields} = @values;
      Job->new(%hash);
    } @{$fc->DATA};
    $self->save_state( name => "to", save => {to => $now} );
  };
  if ($@) {
    $self->add_unknown($@);
  }
}

sub check {
  my $self = shift;
  if (! $self->check_messages()) {
    if (! @{$self->{jobs}}) {
      $self->add_unknown("no finished jobs were found");
    } else {
      if ($self->mode =~ /netweaver::backgroundjobs::list/) {
        foreach (@{$self->{jobs}}) {
          printf "%-12s %-32s %s %4d %4d %s\n", $_->{SDLUNAME}, $_->{JOBNAME},
              $_->{output_start}, $_->{runtime}, $_->{delay}, $_->{STATUS};
        }
      } else {
        my $jobs = {};
        map { $jobs->{$_->{JOBNAME}.$_->{SDLUNAME}}++ } @{$self->{jobs}};
        if ($self->mode =~ /netweaver::backgroundjobs::(failed|runtime)/) {
          foreach (@{$self->{jobs}}) {
            $_->check() if (! $self->opts->unique || ($self->opts->unique && ! --$jobs->{$_->{JOBNAME}.$_->{SDLUNAME}}));
          }
        }
        if (! $self->check_messages()) {
          $self->add_ok("all jobs finished in time with status ok");
        }
      }
    }
  }
}

package Job;
our @ISA = qw(Classes::SAP::Netweaver::TableItem);
use strict;
use Date::Manip::Date;

sub finish {
  my $self = shift;
  # man kann eigentlich davon ausgehen, dass jeder Job STRT* und END* hat,
  # da die Tabelle TBTCO nur beendete (mit welchem Status auch immer) Eintraege
  # enthaelt.
  foreach (keys %{$self}) {
    $self->{$_} =~ s/^\s+//;
    $self->{$_} =~ s/\s+$//;
  }
  my $date = new Date::Manip::Date;
  if ($self->{ENDDATE} && $self->{ENDTIME}) {
    $date->parse_format("%Y%m%d%H%M%S", $self->{ENDDATE}.$self->{ENDTIME});
    $self->{stop} = $date->printf("%s");
    $self->{output_stop} = $date->printf("%d.%m.%Y %H:%M:%S");
  }
  if ($self->{STRTDATE} && $self->{STRTTIME}) {
    $date->parse_format("%Y%m%d%H%M%S", $self->{STRTDATE}.$self->{STRTTIME});
    $self->{start} = $date->printf("%s");
    $self->{output_start} = $date->printf("%d.%m.%Y %H:%M:%S");
  }
  if ($self->{start} && $self->{stop}) {
    $self->{runtime} = $self->{stop} - $self->{start};
  }
  if ($self->{SDLSTRTDT} && $self->{SDLSTRTTM}) {
    $date->parse_format("%Y%m%d%H%M%S", $self->{SDLSTRTDT}.$self->{SDLSTRTTM});
    $self->{planned_start} = $date->printf("%s");
  }
  if ($self->{start} && $self->{planned_start}) {
    $self->{delay} = $self->{start} - $self->{planned_start};
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /netweaver::backgroundjobs::(failed|runtime)/) {
    if ($self->{STATUS} eq "A") {
      $self->add_critical(sprintf "job %s failed at %s", $self->{JOBNAME}, $self->{output_stop});
    }
  }
  if ($self->mode =~ /netweaver::backgroundjobs::runtime/) {
    $self->set_thresholds(metric => $self->{SDLUNAME}.'_'.$self->{JOBNAME}.'_runtime',
       warning => 60, critical => 300);
    $self->add_info(sprintf "job %s of user %s ran for %ds",
        $self->{JOBNAME}, $self->{SDLUNAME}, $self->{runtime});
    if ($self->check_thresholds(metric => $self->{SDLUNAME}.'_'.$self->{JOBNAME}.'_runtime',
        value => $self->{runtime},)) {
      my ($warning, $critical) = $self->get_thresholds(
          metric => $self->{SDLUNAME}.'_'.$self->{JOBNAME}.'_runtime');
      $self->annotate_info(sprintf "limit: %ds", $self->{runtime} > $critical ?
          $critical : $warning);
      $self->add_message($self->check_thresholds(
          metric => $self->{SDLUNAME}.'_'.$self->{JOBNAME}.'_runtime',
          value => $self->{runtime},
      ));
    }
    $self->add_perfdata(
        label => $self->{SDLUNAME}.'_'.$self->{JOBNAME}.'_runtime',
        value => $self->{runtime},
        uom => 's',
    );
  }
}

__END__

Tabelle auslesen.
- es gibt etliche Jobs, Vorhaltezeit ist mind. ein paar Tage
- mit --lookback schraenkt man die Reichweite in die Vergangenheit ein
- es koennen mehrere Laeufe des gleichen Jobs vorhanden sein, mit untersch.
  Status und Laufzeiten
- Default: 
  alle Jobs auf Abbruch pruefen 
  den letzten Job jeder JOBNAME/USERNAME-Kombi auf Laufzeitueberschreitung pruefen
  
  btc_running       LIKE tbtco-status VALUE 'R',
  btc_ready         LIKE tbtco-status VALUE 'Y',
  btc_scheduled     LIKE tbtco-status VALUE 'P',
  btc_released      LIKE tbtco-status VALUE 'S',
  btc_aborted       LIKE tbtco-status VALUE 'A',
  btc_finished      LIKE tbtco-status VALUE 'F',
  btc_put_active    LIKE tbtco-status VALUE 'Z',
  btc_unknown_state LIKE tbtco-status VALUE 'X'.

 
The 'help' on the field description gives the following explanation of the statuses,
The following statuses are possible:                                                                                
o   Scheduled:  Job defined, but not yet eligible to run even if the start condition has been fulfilled.
o   Released:  Job eligible to be started as soon as the start condition with which it was scheduled is fulfilled.
o   Ready:  Job waiting to start.  The job has been released and the job's start condition has been fulfilled.
o   Active:  Job is currently running and can no longer be deleted or reset to scheduled.
o   Finished:  Job has been successfully completed. All job steps completed successfully.  Note:  the background processing system cannot always determine whether an external job step was successfully completed. In this case, the system assumes successful completion.                                                                                
o   Terminated:  Job was ended abnormally either through user action or through an error in running a job step. Check in the table FAVSELS for the following fields 


