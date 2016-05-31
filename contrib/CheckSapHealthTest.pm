package MyTest;
our @ISA = qw(Classes::SAP);
use Time::HiRes;

sub init {
  my $self = shift;
  my $bapi_tic = Time::HiRes::time();
  if ($self->mode =~ /my::test::rfcping/) {
    my $ping = $self->session->function_lookup("RFC_PING");
    my $fc = $ping->create_function_call;
    my $frc = $fc->invoke();
    $self->add_ok("pong");
    # $fc kann jetzt ausgewertet werden
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

