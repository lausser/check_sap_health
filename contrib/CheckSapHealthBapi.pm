package MyBapi;
our @ISA = qw(Classes::SAP);
use Time::HiRes;

sub init {
  my $self = shift;
  my $bapi_tic = Time::HiRes::time();
  if ($self->mode =~ /my::bapi::bpgetlist/) {
    eval {
      my $fl = $self->session->function_lookup("BAPI_BUPA_CENTRAL_GETLIST");
      my $fc = $fl->create_function_call;
      $fc->BUSINESSPARTNER($self->opts->name); # A000000001
      $fc->VALIDFROM("01010001");
      $fc->VALIDTO("31129999");
      $fc->invoke;
      my @rows = @{$fc->RETURN};
      if (scalar(@rows) == 0) {
        # in der SAPGUI getestet: leere Tabelle RETURN ist OK
        $self->add_ok("BAPI_BUPA_CENTRAL_GETDETAIL is OK");
        $fc->CENTRALDATAORGANIZATION->[0]->{NAME1} =~ s/\s+$//;
        $self->add_ok(sprintf "found partner %s",
            $fc->CENTRALDATAORGANIZATION->[0]->{NAME1});
      } elsif (scalar(@rows) == 1) {
        if ($rows[0]->{TYPE} =~ /^(E|A)/) {
          $self->add_unknown($rows[0]->{MESSAGE});
        } else {
          $self->add_ok("BAPI_BUPA_CENTRAL_GETDETAIL is OK");
        }
      } else {
        foreach my $row (@rows) {
          $errors++ if $row->{TYPE} =~ /^(E|A)/ && $rownum > 0;
          $rownum++;
        }
        $self->add_message($errors ? 2 : 0,
            sprintf "BAPI_BUPA_CENTRAL_GETDETAIL returned %d errors (in %d rows)",
                $errors, $rownum);
      }
    };
    if ($@) {
      $self->add_unknown($@);
    }
  } else {
    $self->add_unknown("unknown mode");
  }
  my $bapi_tac = Time::HiRes::time();
  my $bapi_duration = $bapi_tac - $bapi_tic;
  $self->set_thresholds(warning => 5, critical => 10);
  $self->add_message($self->check_thresholds($bapi_duration),
       sprintf "runtime was %.2fs", $bapi_duration);
  $self->add_perfdata(
      label => 'runtime',
      value => $bapi_duration,
  );
}

