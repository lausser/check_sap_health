# /usr/bin/perl -w

use strict;
use File::Basename;



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
    plugin => basename($0),
);
$plugin->add_mode(
    internal => 'device::uptime',
    spec => 'uptime',
    alias => undef,
    help => 'Check the uptime of the device',
);

$plugin->add_mode(
    internal => 'server::connectiontime',
    spec => 'connection-time',
    alias => undef,
    help => 'Time to connect to the server',
);
$plugin->add_mode(
    internal => 'server::connectiontime::sapinfo',
    spec => 'sapinfo',
    alias => undef,
    help => 'Time to connect and show system atttributes like sapinfo',
);
$plugin->add_mode(
    internal => 'server::ccms::moniset::list',
    spec => 'list-ccms-monitor-sets',
    alias => undef,
    help => 'List all available monitor sets',
);
$plugin->add_mode(
    internal => 'server::ccms::monitor::list',
    spec => 'list-ccms-monitors',
    alias => undef,
    help => 'List all monitors (can be restricted to a monitor set with --name)',
);
$plugin->add_mode(
    internal => 'server::ccms::mte::list',
    spec => 'list-ccms-mtes',
    alias => undef,
    help => 'List all MTEs (must be restricted to a monitor set / monitor with --name/--name2)',
);
$plugin->add_mode(
    internal => 'server::ccms::mte::check',
    spec => 'ccms-mte-check',
    alias => undef,
    help => 'Check all MTEs (must be restricted to a monitor set / monitor with --name/--name2)',
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
   A keyword which tells the plugin what to do",
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
    spec => 'name2=s',
    help => "--name2
   The secondary name of whatever",
    required => 0,
);
$plugin->add_arg(
    spec => 'name3=s',
    help => "--name3
   The tertiary name of whatever",
    required => 0,
);
$plugin->add_arg(
    spec => 'regexp',
    help => "--regexp
   Parameter name/name2/name3 will be interpreted as (perl) regular expression",
    required => 0,
);
$plugin->add_arg(
    spec => 'separator=s',
    help => "--separator
   A separator for MTE path elements",
    required => 0,
);
$plugin->add_arg(
    spec => 'warningx=s%',
    help => '--warningx
   The extended warning thresholds',
    required => 0,
);
$plugin->add_arg(
    spec => 'criticalx=s%',
    help => '--criticalx
   The extended critical thresholds',
    required => 0,
);
$plugin->add_arg(
    spec => 'mitigation=s',
    help => "--mitigation
   The parameter allows you to change a critical error to a warning.",
    required => 0,
);
$plugin->add_arg(
    spec => 'selectedperfdata=s',
    help => "--selectedperfdata
   The parameter allows you to limit the list of performance data. It's a perl regexp.
   Only matching perfdata show up in the output",
    required => 0,
);
$plugin->add_arg(
    spec => 'negate=s%',
    help => "--negate
   The parameter allows you to map exit levels, such as warning=critical",
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


