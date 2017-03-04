#! /usr/bin/perl

use strict;

eval {
  if ( ! grep /AUTOLOAD/, keys %Monitoring::GLPlugin::) {
    require Monitoring::GLPlugin;
  }
};
if ($@) {
  printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
  printf "%s\n", $@;
  exit 3;
}

my $plugin = Classes::Device->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--mode <what-to-do> '.
        '--ashost <hostname> --sysnr <system number> '.
        '  ...]',
    version => '$Revision: #PACKAGE_VERSION# $',
    blurb => 'This plugin checks sap netweaver ',
    url => 'http://labs.consol.de/nagios/check_sap_health',
    timeout => 60,
);
$plugin->add_mode(
    internal => 'device::uptime',
    spec => 'uptime',
    alias => undef,
    help => 'Check the uptime of the device',
);
$plugin->add_mode(
    internal => 'netweaver::connectiontime',
    spec => 'connection-time',
    alias => undef,
    help => 'Time to connect to the server',
);
$plugin->add_mode(
    internal => 'netweaver::connectiontime::sapinfo',
    spec => 'sapinfo',
    alias => undef,
    help => 'Time to connect and show system atttributes like sapinfo',
);
$plugin->add_mode(
    internal => 'netweaver::ccms::moniset::list',
    spec => 'list-ccms-monitor-sets',
    alias => undef,
    help => 'List all available monitor sets',
);
$plugin->add_mode(
    internal => 'netweaver::ccms::monitor::list',
    spec => 'list-ccms-monitors',
    alias => undef,
    help => 'List all monitors (can be restricted to a monitor set with --name)',
);
$plugin->add_mode(
    internal => 'netweaver::ccms::mte::list',
    spec => 'list-ccms-mtes',
    alias => undef,
    help => 'List all MTEs (must be restricted to a monitor set / monitor with --name/--name2)',
);
$plugin->add_mode(
    internal => 'netweaver::ccms::mte::check',
    spec => 'ccms-mte-check',
    alias => undef,
    help => 'Check all MTEs (must be restricted to a monitor set / monitor with --name/--name2)',
);
$plugin->add_mode(
    internal => 'netweaver::snap::shortdumps::list',
    spec => 'shortdumps-list',
    alias => ['list-shortdumps'],
    help => 'Read the SNAP table and list the short dumps',
);
$plugin->add_mode(
    internal => 'netweaver::snap::shortdumps::count',
    spec => 'shortdumps-count',
    alias => undef,
    help => 'Read the SNAP table and count the short dumps (can be restricted with --name/--name2 = username/program)',
);
$plugin->add_mode(
    internal => 'netweaver::snap::shortdumps::recurrence',
    spec => 'shortdumps-recurrence',
    alias => undef,
    help => 'Like shortdumps-count, but counts the recurrence of the same errors',
);
$plugin->add_mode(
    internal => 'netweaver::updates::failed',
    spec => 'failed-updates',
    alias => undef,
    help => 'Counts new entries in the VHDR table (since last run or appeared in the interval specified by --lookback)',
);
$plugin->add_mode(
    internal => 'netweaver::backgroundjobs::failed',
    spec => 'failed-jobs',
    alias => undef,
    help => 'Looks for failed jobs in the TBTCO table (since last run or in the interval specified by --lookback)',
);
$plugin->add_mode(
    internal => 'netweaver::backgroundjobs::runtime',
    spec => 'exceeded-failed-jobs',
    alias => undef,
    help => 'Looks for jobs in the TBTCO table which failed or exceeded a certain runtime (since last run or in the interval specified by --lookback)',
);
$plugin->add_mode(
    internal => 'netweaver::processes::count',
    spec => 'count-processes',
    alias => undef,
    help => 'count the types of work processes',
);
$plugin->add_mode(
    internal => 'netweaver::workload::overview',
    spec => 'workload-overview',
    alias => undef,
    help => 'Checks response time of task types (like ST03)',
);
$plugin->add_mode(
    internal => 'netweaver::idocs::failed',
    spec => 'failed-idocs',
    alias => undef,
    help => 'Looks for failed IDoc-status-records in the EDIDS table',
);
$plugin->add_mode(
    internal => 'netweaver::processes::list',
    spec => 'list-processes',
    alias => undef,
    help => 'List the running work processes',
);
$plugin->add_mode(
    internal => 'netweaver::backgroundjobs::list',
    spec => 'list-jobs',
    alias => undef,
    help => 'Read the TBTCO table and list the jobs',
);
$plugin->add_mode(
    internal => 'netweaver::idocs::list',
    spec => 'list-idocs',
    alias => undef,
    help => 'Lists IDoc-status-records in the EDIDS table',
);
$plugin->add_arg(
    spec => 'ashost|H=s',
    help => '--ashost
   Hostname or IP-address of the application server',
    required => 0,
);
$plugin->add_arg(
    spec => 'sysnr=s',
    help => '--sysnr
   The system number',
    required => 0,
);
$plugin->add_arg(
    spec => 'mshost=s',
    help => '--mshost
   Hostname or IP-address of the message server',
    required => 0,
);
$plugin->add_arg(
    spec => 'msserv=s',
    help => '--msserv
   The port for mshost connections',
    required => 0,
);
$plugin->add_arg(
    spec => 'r3name=s',
    help => '--r3name
   The SID for mshost connections',
    required => 0,
);
$plugin->add_arg(
    spec => 'group=s',
    help => '--group
   The logon group for mshost connections',
    required => 0,
);
$plugin->add_arg(
    spec => 'gwhost=s',
    help => '--gwhost
   The gateway host',
    required => 0,
);
$plugin->add_arg(
    spec => 'gwserv=s',
    help => '--gwserv
   The gateway port',
    required => 0,
);
$plugin->add_arg(
    spec => 'username=s',
    help => '--username
   The username',
    required => 0,
);
$plugin->add_arg(
    spec => 'password=s',
    help => '--password
   The password',
    required => 0,
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
    spec => 'separator=s',
    help => "--separator
   A separator for MTE path elements",
    required => 0,
);
$plugin->add_arg(
    spec => 'mtelong',
    help => "--mtelong
   Output the full path of MTEs",
    default => 0,
    required => 0,
);
$plugin->add_arg(
    spec => 'unique',
    help => "--unique
   The parameter limits the output to unique (or only the last) items.",
    required => 0,
);
$plugin->add_default_args();

$plugin->getopts();
$plugin->classify();
$plugin->validate_args();


if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
} else {
  $plugin->add_critical('wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin);
$plugin->nagios_exit($code, $message);


