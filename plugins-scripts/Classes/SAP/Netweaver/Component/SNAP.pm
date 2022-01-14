package Classes::SAP::Netweaver::Component::SNAP;
our @ISA = qw(Classes::SAP::Netweaver::Item);
use strict;


sub init {
  my $self = shift;
  if ($self->mode =~ /netweaver::snap::shortdumps/) {
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
      $fc->QUERY_TABLE("SNAP");
      $fc->DELIMITER(";");
      my $condition = sprintf "SEQNO = '000' AND ( DATUM > '%s' OR ( DATUM = '%s' AND UZEIT > '%s' ) ) AND ( DATUM < '%s' OR ( DATUM = '%s' AND UZEIT <= '%s' ) )",
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
      my @shortdumps = ();
      foreach (@rows) {
        my $shortdump = {};
        (my $dump = $_->{WA}) =~ s/\s+$//;
        ($shortdump->{datum}, $shortdump->{uzeit},
            $shortdump->{ahost}, $shortdump->{uname},
            $shortdump->{mandt}, $shortdump->{flist}) = 
            map { s/^\s+//; s/\s+$//; $_ } split(";", $dump);
        $shortdump->{error} = substr($shortdump->{flist}, 5,
            (index($shortdump->{flist}, 'AP0') - 5));
        $shortdump->{program} = substr($shortdump->{flist},
            (index($shortdump->{flist}, 'AP0') + 5),
            (index($shortdump->{flist}, 'AI0') -
            (index($shortdump->{flist}, 'AP0') + 5)));
        $shortdump->{bgcolor} = "#f83838";
        next if ! $self->filter_name($shortdump->{uname});
        next if ! $self->filter_name2($shortdump->{program});
        push(@shortdumps, $shortdump);
      }
      if (scalar(@shortdumps) == 0) {
        $self->add_ok(sprintf "no new shortdumps between %s %s and %s %s",
            $fromdate, $fromtime, $todate, $totime);
      } else {
        if ($self->mode =~ /netweaver::snap::shortdumps::list/) {
          foreach my $row (@rows) {
            (my $dump = $row->{WA}) =~ s/\s+$//;
            $dump = join(";", map { s/^\s+//; s/\s+$//; $_ } split(";", $dump));
            printf "%s\n", $dump;
          }
        } elsif ($self->mode =~ /netweaver::snap::shortdumps::/) {
          my $num_shortdumps = scalar(@shortdumps);
          $self->add_info(sprintf "%d new shortdumps appeared between %s %s and %s %s",
              $num_shortdumps, $fromdate, $fromtime, $todate, $totime);
          $self->set_thresholds(warning => 50, critical => 100, metric => 'shortdumps');
          $self->add_message($self->check_thresholds(value => $num_shortdumps, metric => 'shortdumps'));
          $self->add_perfdata(
              label => 'shortdumps',
              value => $num_shortdumps
          );
          my $table = [];
          my @titles = ();
          my $unique_dumps = {};
          if ($self->mode =~ /netweaver::snap::shortdumps::recurrence/) {
            my $max_unique_shortdumps = 0;
            my $max_unique_overflows = 0;
            foreach my $shortdump (@shortdumps) {
              my $signature = join("_", map { $shortdump->{$_} } qw(ahost uname mandt error program));
              if (! exists $unique_dumps->{$signature}) {
                $unique_dumps->{$signature} = {
                  count => 1,
                  dump => $shortdump,
                };
              } else {
                $unique_dumps->{$signature}->{count}++;
              }
            }
            $self->set_thresholds(warning => 50, critical => 100, metric => 'max_unique_shortdumps');
            foreach my $unique_dump (map { $unique_dumps->{$_} } keys %{$unique_dumps}) {
              $max_unique_shortdumps = $unique_dump->{count} if ($unique_dump->{count} > $max_unique_shortdumps);
              $max_unique_overflows++ if $self->check_thresholds(value => $unique_dump->{count}, metric => 'max_unique_shortdumps');
            }
            $self->add_info(sprintf "the most frequent error appeared %d times", $max_unique_shortdumps);
            $self->add_message($self->check_thresholds(value => $max_unique_shortdumps, metric => 'max_unique_shortdumps'));
            $self->add_perfdata(
                label => 'max_unique_shortdumps',
                value => $max_unique_shortdumps
            );
          }
          if ($self->opts->report eq "html") {
            if ($self->mode =~ /netweaver::snap::shortdumps::count/) {
              @titles = qw(datum uzeit ahost uname mandt error program);
              foreach my $shortdump (@shortdumps) {
                push(@{$table}, [map { [$shortdump->{$_}, 2] } @titles]);
              }
            } elsif ($self->mode =~ /netweaver::snap::shortdumps::recurrence/) {
              @titles = qw(count ahost uname mandt error program);
              foreach my $unique_dump (map { 
                  $unique_dumps->{$_}
              } reverse sort {
                  $unique_dumps->{$a}->{count} <=> $unique_dumps->{$b}->{count} 
              } keys %{$unique_dumps}) {
                my $level = $self->check_thresholds(value => $num_shortdumps, metric => 'shortdumps') ?
                    $self->check_thresholds(value => $num_shortdumps, metric => 'shortdumps') :
                    $self->check_thresholds(value => $unique_dump->{count}, metric => 'max_unique_shortdumps');
                my @line = ([$unique_dump->{count}, $level]);
                push(@line, map {
                    [$unique_dump->{dump}->{$_}, $level]
                } qw(ahost uname mandt error program));
                push(@{$table}, \@line);
              }
            }
            $self->add_html($self->table_html($table, \@titles));
            my ($code, $message) = $self->check_messages();
            printf "%s - %s%s\n", $self->status_code($code), $message, $self->perfdata_string() ? " | ".$self->perfdata_string() : "";
            $self->suppress_messages();
            print $self->html_string();
            printf "\n <!--\nASCII_NOTIFICATION_START\n";
            printf "%s - %s%s\n", $self->status_code($code), $message, $self->perfdata_string() ? " | ".$self->perfdata_string() : "";
            printf "%s", $self->table_ascii($table, \@titles);
            printf "ASCII_NOTIFICATION_END\n-->\n";
          }
        }
      }
      $self->save_state( name => "to", save => {to => $now} );
    };
    if ($@) {
      $self->add_unknown($@);
    }
  }
}

