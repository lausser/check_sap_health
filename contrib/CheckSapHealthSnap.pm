package MySnap;
our @ISA = qw(Classes::SAP);
use Time::HiRes;

sub init {
  my $self = shift;
  if ($self->mode =~ /my::snap::dumps/) {
    eval {
      my $now = time - 1;
      my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
          localtime($now);
      my $todate = sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
      my $totime = sprintf "%02d%02d%02d", $hour, $min, $sec;
      my $state = $self->load_state( name => "to" ) || { to => $now - 3600 };
      ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
          localtime($state->{to} + 1);
      my $fromdate = sprintf "%04d%02d%02d", $year + 1900, $mon + 1, $mday;
      my $fromtime = sprintf "%02d%02d%02d", $hour, $min, $sec;

      my $fl = $self->session->function_lookup("RFC_READ_TABLE");
      my $fc = $fl->create_function_call;
      $fc->QUERY_TABLE("SNAP");
      $fc->DELIMITER(";");
      my $condition = sprintf "SEQNO = '000' AND (DATUM > '%s' OR (DATUM = '%s' AND UZEIT > '%s')) AND (DATUM < '%s' OR (DATUM = '%s' AND UZEIT <= '%s'))",
          $fromdate, $fromdate, $fromtime, $todate, $todate, $totime;
      my @options = ();
      while ($condition ne "") {
        $condition =~ /(.{1,70}(\s|$))/ms;
        push(@options, {'TEXT' => $1});
        $condition = $';
      }
      $fc->OPTIONS(\@options);
      $fc->FIELDS([
          { 'FIELDNAME' => 'DATUM' },
          { 'FIELDNAME' => 'UZEIT' },
          { 'FIELDNAME' => 'AHOST' },
          { 'FIELDNAME' => 'UNAME' },
          { 'FIELDNAME' => 'MANDT' },
          { 'FIELDNAME' => 'FLIST' }
      ]);
      $fc->invoke;
      #printf "%s\n", Data::Dumper::Dumper($fc);
      my @rows = @{$fc->DATA};
      if (scalar(@rows) == 0) {
        $self->add_ok("no new shortdumps");
      } else {
        if ($self->mode =~ /my::snap::dumps::list/) {
          foreach my $row (@rows) {
            (my $dump = $row->{WA}) =~ s/\s+$//;
            $dump = join(";", map { s/^\s+//; s/\s+$//; $_ } split(";", $dump));
            printf "%s\n", $dump;
          }
        } elsif ($self->mode =~ /my::snap::dumps::check/) {
          $self->add_critical(sprintf "%d new shortdumps appeared between %s %s and %s %s",
              scalar(@rows), $fromdate, $fromtime, $todate, $totime);
        }
      }
      $self->save_state( name => "to", save => {to => $now} );
    };
    if ($@) {
      $self->add_message(UNKNOWN, $@);
    }
  }
}

