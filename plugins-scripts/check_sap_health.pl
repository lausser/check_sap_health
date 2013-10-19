#! /usr/bin/perl

use strict;
use Digest::MD5 qw(md5_hex);;

use vars qw ($PROGNAME $REVISION $CONTACT $TIMEOUT $STATEFILESDIR $needs_restart %commandline);

$PROGNAME = "check_sap_health";
$REVISION = '$Revision: #PACKAGE_VERSION# $';
$CONTACT = 'gerhard.lausser@consol.de';
$TIMEOUT = 60;
$STATEFILESDIR = '/var/tmp/check_sap_health';

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;
use constant DEPENDENT  => 4;

my @modes = (
  ['server::connectiontime',
      'connection-time', undef,
      'Time to connect to the server' ],
);
my $modestring = "";
my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
my $format = "       %-".
  (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).
  "s\t(%s)\n";
foreach (@modes) {
  $modestring .= sprintf $format, $_->[1], $_->[3];
}
$modestring .= sprintf "\n";

my $plugin = Nagios::MiniPlugin->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--mode <what-to-do> '.
        '--hostname <network-component> --community <snmp-community>'.
        '  ...]',
    version => $REVISION,
    blurb => 'This plugin checks various parameters of network components ',
    url => 'http://labs.consol.de/nagios/check_sap_health',
    timeout => 60,
    shortname => '',
);
$plugin->add_arg(
    spec => 'ashost|H=s',
    help => '--ashost
   Hostname or IP-address of the application server',
    required => 1,
);
$plugin->add_arg(
    spec => 'sysnr=s',
    help => '--sysnr
   The system number',
    required => 1,
);
$plugin->add_arg(
    spec => 'username=s',
    help => '--username
   The username',
    required => 1,
);
$plugin->add_arg(
    spec => 'password=s',
    help => '--password
   The password',
    required => 1,
);
$plugin->add_arg(
    spec => 'client=s',
    help => '--client
   The client',
    default => '001',
    required => 0,
);
$plugin->add_arg(
    spec => 'lang=s',
    help => '--lang
   The language',
    default => 'EN',
    required => 0,
);
$plugin->add_arg(
    spec => 'mode=s',
    help => "--mode
   A keyword which tells the plugin what to do
$modestring",
    required => 1,
);
$plugin->add_arg(
    spec => 'warning=s',
    help => '--warning
   The warning threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'critical=s',
    help => '--critical
   The critical threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'name=s',
    help => "--name
   The name of whatever",
    required => 0,
);
$plugin->add_arg(
    spec => 'with-mymodules-dyn-dir=s',
    help => '--with-mymodules-dyn-dir
   A directory where own extensions can be found',
    required => 0,
);
$plugin->add_arg(
    spec => 'statefilesdir=s',
    help => '--statefilesdir
   An alternate directory where the plugin can save files',
    required => 0,
);
$plugin->add_arg(
    spec => 'multiline',
    help => '--multiline
   Multiline output',
    required => 0,
);


$plugin->getopts();
if ($plugin->opts->multiline) {
  $ENV{NRPE_MULTILINESUPPORT} = 1;
} else {
  $ENV{NRPE_MULTILINESUPPORT} = 0;
}
if (! $plugin->opts->statefilesdir) {
  if (exists $ENV{OMD_ROOT}) {
    $plugin->override_opt('statefilesdir', $ENV{OMD_ROOT}."/var/tmp/check_nwc_health");
  } else {
    $plugin->override_opt('statefilesdir', $STATEFILESDIR);
  }
}
if (exists $plugin->opts->{opts}->{'with-mymodules-dyn-dir'}) {
  $SAP::Server::my_modules_dyn_dir = $plugin->opts->{opts}->{'with-mymodules-dyn-dir'};
} else {
  $SAP::Server::my_modules_dyn_dir = '#MYMODULES_DYN_DIR#';
}


$plugin->{messages}->{unknown} = []; # wg. add_message(UNKNOWN,...)

$plugin->{info} = []; # gefrickel

if ($plugin->opts->mode =~ /^my-([^\-.]+)/) {
  my $param = $plugin->opts->mode;
  $param =~ s/\-/::/g;
  push(@modes, [$param, $plugin->opts->mode, undef, 'my extension']);
} elsif ($plugin->opts->mode eq 'encode') {
  my $input = <>;
  chomp $input;
  $input =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  printf "%s\n", $input;
  exit 0;
} elsif ((! grep { $plugin->opts->mode eq $_ } map { $_->[1] } @modes) &&
    (! grep { $plugin->opts->mode eq $_ } map { defined $_->[2] ? @{$_->[2]} : () } @modes)) {
  printf "UNKNOWN - mode %s\n", $plugin->opts->mode;
  $plugin->opts->print_help();
  exit 3;
}
if ($plugin->opts->name && $plugin->opts->name =~ /(%22)|(%27)/) {
  my $name = $plugin->opts->name;
  $name =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
  $plugin->override_opt('name', $name);
}

$SIG{'ALRM'} = sub {
  printf "UNKNOWN - check_sap_health timed out after %d seconds\n",
      $plugin->opts->timeout;
  exit $ERRORS{UNKNOWN};
};
alarm($plugin->opts->timeout);

$SAP::Server::plugin = $plugin;
$SAP::Server::mode = (
    map { $_->[0] }
    grep {
       ($plugin->opts->mode eq $_->[1]) ||
       ( defined $_->[2] && grep { $plugin->opts->mode eq $_ } @{$_->[2]})
    } @modes
)[0];

my $server = SAP::Server->new( runtime => {
    plugin => $plugin,
    options => {
        verbose => $plugin->opts->verbose,
    },
},);
#$server->dumper();
if (! $plugin->check_messages()) {
  $server->init();
  if (! $plugin->check_messages()) {
    $plugin->add_message(OK, $server->get_summary())
        if $server->get_summary();
    $plugin->add_message(OK, $server->get_extendedinfo())
        if $server->get_extendedinfo();
  }
} else {
  $plugin->add_message(CRITICAL, 'wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", join("\n", @{$SAP::Server::info})
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin->{info});
$plugin->nagios_exit($code, $message);

