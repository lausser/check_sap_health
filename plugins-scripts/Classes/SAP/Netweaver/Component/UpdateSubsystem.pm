package Classes::SAP::Netweaver::Component::UpdateSubsystem;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;


sub init {
  my $self = shift;
  if ($self->mode =~ /netweaver::updates::failed/) {
    eval {
      my $now = time - 1;
      my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
          localtime($now);
      my $todate = sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
      my $totime = sprintf "%02d%02d%02d", $hour, $min, $sec;
      my $from = $self->opts->lookback ? $now - $self->opts->lookback :
          $self->load_state( name => "to" ) ? $self->load_state( name => "to" )->{to} :
          $now - 3600;
      ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
          localtime($from + 1);
      my $fromdate = sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
      my $fromtime = sprintf "%02d%02d%02d", $hour, $min, $sec;
      my $fl = $self->session->function_lookup("RFC_READ_TABLE");
      my $fc = $fl->create_function_call;
      $fc->QUERY_TABLE("VBHDR");
      $fc->DELIMITER(";");
      my $condition = sprintf "VBDATE > '%s%s'", $fromdate, $fromtime;
      my @options = ();
      while ($condition ne "") {
        $condition =~ /(.{1,70}(\s|$))/ms;
        push(@options, {'TEXT' => $1});
        $condition = $';
      }
      $fc->OPTIONS(\@options);
      $fc->FIELDS([
          { 'FIELDNAME' => 'VBKEY' },
          { 'FIELDNAME' => 'VBREPORT' },
          { 'FIELDNAME' => 'VBENQKEY' },
          { 'FIELDNAME' => 'VBDATE' }
      ]);
      $fc->invoke;
      my @rows = @{$fc->DATA};
      my $failed_updates = scalar(@rows);
      $self->set_thresholds(warning => 10, critical => 20);
      if ($failed_updates == 0) {
        $self->add_info("no failed updates in system");
      } else {
        $self->add_info(
            sprintf "%d new failed update records appeared between %s %s and %s %s", 
            $failed_updates, $fromdate, $fromtime, $todate, $totime);
      }
      $self->add_message($self->check_thresholds($failed_updates));
      $self->add_perfdata(
          label => 'failed_updates',
          value => $failed_updates,
      );
      $self->save_state( name => "to", save => {to => $now} );
    };
    if ($@) {
      $self->add_unknown($@);
    }
  }
}

