**Komm nach Braunschweig und triff die Leute, die sich mit genau demselben Kram beschäftigen wie du!**
<a href="https://monitors-2018.tu-braunschweig.de/dokuwiki/doku.php"><img src="https://labs.consol.de/assets/images/braunschweig-banner.gif"></a>

#Beschreibung#
Das Plugin check\_sap_health wurde entwickelt, um ein leicht erweiterbares Werkzeug zu haben, mit dem sich sowohl technische Parameter aus dem CCMS als auch betriebswirtschaftliche Fakten per RFC/BAPI überwachen lassen

<div><a href="https://www.buymeacoffee.com/bsNED0Wct" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/black_img.png" alt="Buy Me A Coffee" style="height: auto !important;width: auto !important;" ></a></div>

# Motivation #
Die bisher verfügbaren Plugins sind in C geschrieben, wodurch man nicht mal eben ein neues Feature einbauen und ausprobieren kann. Des weiteren beschränken sich die Möglichkeiten dieser Plugins auf die Abfrage von CCMS-Metriken. Als es Mitte 2013 beim bis dahin eingesetzten check\_sap zu Core-Dumps kam (irreparabel, da nach dem exit()-Aufruf) und offenbar die Kompatibilität zu neueren Netweaver-Versionen nicht mehr gewährleistet war, suchte ich nach Alternativen.

Zeitgleich hatte einer meiner Kunden die Anforderung RFC- und BAPI-Aufrufe in das Monitoring aufzunehmen. Diese Aufrufe bezogen sich hauptsächlich auf firmenspezifische Erweiterungen und sollten im Endausbau die Überwachung aller SAP-basierten Versicherungs- und Banken-Geschäftsprozesse abdecken. Mit einem starr kompilierten Plugin ist so etwas nicht machbar, jedenfalls nicht wenn man das Ergebnis als Open Source veröffentlichen will.

Daher wurde mit check\_sap\_health ein neues Plugin auf Perl-Basis entwickelt. Es bietet die von den anderen check\_*_health bekannte Erweiterbarkeit durch kleine selbstgeschriebene Perl-Schnippsel. Auf diese Weise kann das Plugin mit seinen Basisfunktionen veröffentlicht werden und gleichzeitig an spezielle Anforderungen eines Unternehmens angepasst werden.

# Aufruf #
## Kommandozeilenparameter ##
- --ashost <hostname\>  
Der Hostname bzw. die IP-Adresse des Application-Servers.
- --sysnr <nr\>  
Die System Number.    

- --mshost <hostname\>  
Der Hostname bzw. die IP-Adresse des Message-Servers.
- --r3name <sid\>  
Die Sapsid, wird benötigt, um in /etc/services den Port des Message-Servers zu finden.
- --msserv <port\>  
Alternativ kann hier der Port direkt angegeben werden.

- --username <username\>  
Der Monitoring-User.
- --password <password\>  
Dessen Passwort.
- --client <nr\>  
Die Mandantennummer. (Default ist 001).
- --lang <lang\>  
Die Sprache. (Default ist EN).

- --mode <modus\>  
Mit dem mode-Parameter teilt man dem Plugin mit, was es tun soll. Siehe Liste der möglichen Werte weiter unten.


- --name <objektname\>  
Hier kann die Prüfung auf ein einziges Objekt oder einen Oberbegriff begrenzt werden. (Siehe Beispiele, da die Bedeutung vom verwendeten Modus abhängt).
- --name2 <objektname\>  
Dito, zur genaueren Eingrenzung.
- --name3 <objektname\>  
Dito, zur genaueren Eingrenzung.
- --regexp  
Ein Flag welches angibt, ob –name[2,3] als regulärer Ausdruck zu interpretieren ist.

- --lookback <sekunden\>  
Mit diesem Parameter kann man angeben, wie weit in die Vergangenheit geblickt werden soll (um z.B. die Anzahl best. Ereignisse zu zählen).    
- --report <short|long|html\>  
Bei manchen Modi wird mehr als eine Zeile ausgegeben. Mit der html-Option erscheint dann ein farbiges Popup in der Thruk-GUI.  
- --separator <zeichen\>    
MTE-Namen in ihrer Langform werden wie ein Pfad angegeben, wobei der Backslash defaultmäßig das Trennzeichen ist. Mit –separator kann hierfür ein anderes Zeichen angegeben werden, z.B. #.
- --criticalx <label=schwellwert\>  
Mit diesem Parameter lassen sich die von SAP gelieferten Schwellwerte (bei Performance-MTEs) überschreiben.
- --warningx <label=schwellwert\>  
Dito.
- --negate <level=level\>  
Anstelle des Wrapper-Plugins negate kann dieser Parameter den Exitcode modifizieren. (--negate unknown=critical)

- --with-mymodules-dyn-dir <verzeichnis\>  
In diesem Verzeichnis wird nach selbstgeschriebenen Erweiterungen (Dateiname CheckSapHealth*.pm) gesucht.

## Modi ##
| Schlüsselwort | Bedeutung | Schwellwerte |
|-----------------|-----------------------------------------------------|-------------------------------|
| connection-time | Misst, wie lange Verbindungsaufbau und Login dauern | 0..n Sekunden (Default: 1, 5) |
|  |  |  |
|  |  |  |
| list-ccms-monitor-sets | Zeigt die im CCMS vorhandenen Monitor-Sets an |  |
| list-ccms-monitors | Zeigt die in einem Monitor-Set vorhandenen Monitore an. (–name bestimmt das Monitor-Set) |  |
| list-ccms-mtes | Zeigt die in einem Monitor vorhandenen MTEs an. (–name bestimmt das Monitor-Set, –name2 den Monitor) |  |
| ccms-mte-check | Überprüft die in einem Monitor vorhandenen MTEs. Mit –name3 und ggf. –regexp kann eine Teilmenge ausgewählt werden | (Default: vom CCMS vorgegeben) |
| shortdumps-list | Gibt alle in der SNAP-Tabelle gefundenen Short Dumps aus. Mit --lookback kann man eingrenzen, wie weit in der Vergangenheit die Events liegen dürfen. Per default ist das der Zeitpunkt des vorhergehenden Aufrufs des Plugins. |  |
| shortdumps-count | Zählt die Short Dumps. Mit –name kann nach Username, mit –name2 nach Programm gefiltert werden. Auch hier kann mit –lookback ein Alterslimit angegeben werden |  |
| shortdumps-recurrence | Zählt die Short Dumps, wobei diesmal das Aufkommen der einzelnen Events angezeigt wird |  |
| failed-updates | Zählt die Einträge in der VHDR-Tabelle, die seit dem letzten Lauf des Plugins hinzugekommen sind (oder seit einem mit --lookback bestimmten Zeitpunkt in der Vergangenheit). Damit überwacht man Updates, die es aus welchem Grund auch immer nicht in die Datenbank geschafft haben |  |




# Installation #
Wie üblich:    

    tar zxf check_sap_health...tar.gz
    cd check_sap_health...
    ./configure
    make
    cp plugins-scripts/check_sap_health sonstwohin

# Beispiele #

    $ check_sap_health --mode connection-time \
        --warning 10 --critical 20
    OK - 0.07 seconds to connect as NAGIOS@NPL | 'connection_time'=0.07;10;20;;
    
    $ check_sap_health --mode list-ccms-mtes \
        --name "SAP CCMS Monitor Templates" --name2 Enqueue
    NPL\Enqueue\Enqueue 50
    NPL\Enqueue\Enqueue Server\ 70
    NPL\Enqueue\Enqueue Server\Backup Requests 100
    NPL\Enqueue\Enqueue Server\CleanUp Requests 100
    ...
    NPL\Enqueue\Enqueue Server\Granule Arguments 111
    NPL\Enqueue\Enqueue Server\Granule Arguments Actual Utilisation 100
    NPL\Enqueue\Enqueue Server\Granule Arguments Peak Utilisation 111
    ...
    
    $ check_sap_health --mode list-ccms-mtes \
        --name "SAP CCMS Monitor Templates" --name2 Enqueue --separator '#'
    NPL#Enqueue#Enqueue 50
    NPL#Enqueue#Enqueue Server# 70
    NPL#Enqueue#Enqueue Server#Backup Requests 100
    NPL#Enqueue#Enqueue Server#CleanUp Requests 100
    ...
    NPL#Enqueue#Enqueue Server#Granule Arguments 111
    NPL#Enqueue#Enqueue Server#Granule Arguments Actual Utilisation 100
    NPL#Enqueue#Enqueue Server#Granule Arguments Peak Utilisation 111
    ...
    
    $ check_sap_health --mode ccms-mte-check \
        --name "SAP CCMS Monitor Templates" --name2 Enqueue \
        --name3 "NPL#Enqueue#Enqueue Server#Granule Arguments Actual Utilisation" \
        --separator '#'
    OK - Enqueue Server Granule Arguments Actual Utilisation = 0% | 'Enqueue Server_Granule Arguments Actual Utilisation'=0%;50;80;0;100
    
    $ check_sap_health --mode ccms-mte-check \
        --name "SAP CCMS Monitor Templates" --name2 Enqueue \
        --name3 "Granule.*Actual" --regexp
    OK - Enqueue Server Granule Arguments Actual Utilisation = 0%, Enqueue Server Granule Entries Actual Utilisation = 0% | 'Enqueue Server_Granule Arguments Actual Utilisation'=0%;50;80;0;100 'Enqueue Server_Granule Entries Actual Utilisation'=0%;50;80;0;100

    # Nochmal. Man achte auf den Parameter --warningx
    # Damit setzt man gezielt Schwellwerte für einzelne Metriken
    $ check_sap_health --mode ccms-mte-check \
        --name "SAP CCMS Monitor Templates" --name2 Enqueue \
        --name3 "Granule.*Actual" --regexp \
        --warningx 'Enqueue Server_Granule Arguments Actual Utilisation'=64
    OK - Enqueue Server Granule Arguments Actual Utilisation = 0%, Enqueue Server Granule Entries Actual Utilisation = 0% | 'Enqueue Server_Granule Arguments Actual Utilisation'=0%;64;80;0;100 'Enqueue Server_Granule Entries Actual Utilisation'=0%;50;80;0;100
    
    # Alarm wenn
    #  - mehr als 1000 Short Dumps insgesamt
    #  - mehr als 15/150 Short Dumps der gleichen Sorte
    # in den letzten zwei Tagen aufgetreten sind.
    $ check_sap_health --mode shortdumps-recurrence \
        --report html --lookback $((3600*24*2))  \
        --warningx shortdumps=1000 --criticalx shortdumps=1000 \
        --warningx max_unique_shortdumps=15 --criticalx max_unique_shortdumps=150
    WARNING - the most frequent error appeared 95 times | 'shortdumps'=108;1000;1000;; 'max_unique_shortdumps'=95;15;150;;
    ....HTML-Code für dir Thruk-GUI....
    ....und ASCII-Code für die Notification.....
    ASCII_NOTIFICATION_START
    WARNING - the most frequent error appeared 95 times
       count            ahost    uname   mandt                        error      program
          95   nplhost_NPL_42     SAP*     001     SAPSQL_INVALID_FIELDNAME     SAPLSDTX
           9   nplhost_NPL_42   NAGIOS     001             RFC_NO_AUTHORITY     SAPLSDTX
           3   nplhost_NPL_42   NAGIOS     001             RFC_NO_AUTHORITY   SAPLBUBA_5
           1   nplhost_NPL_42     SAP*     001   SAPSQL_WHERE_ILLEGAL_VALUE     SAPLSDTX
    ASCII_NOTIFICATION_END
    
    # Nochmal. Diesmal interessieren aber ausschließlich Dumps, die auf das Konto
    # des Benutzers NAGIOS gehen (--name <benutzer>)
    # Mit --name2 <program> könnte man das Ergebnis noch weiter eingrenzen.
    $ check_sap_health --mode shortdumps-recurrence \
        --report html --lookback $((3600*24*2))  \
        --warningx shortdumps=1000 --criticalx shortdumps=1000 \
        --warningx max_unique_shortdumps=15 --criticalx max_unique_shortdumps=150 \
        --name NAGIOS
    OK - 12 new shortdumps appeared between 20140306 135353 and 20140308 145352 the most frequent error appeared 9 times | 'shortdumps'=12;1000;1000;; 'max_unique_shortdumps'=9;15;150;;
    ....HTML-Code für dir Thruk-GUI....
    ....und ASCII-Code für die Notification.....
    ASCII_NOTIFICATION_START
    OK - 12 new shortdumps appeared between 20140306 135353 and 20140614 145352 the most frequent error appeared 9 times
       count            ahost    uname   mandt              error      program
           9   nplhost_NPL_42   NAGIOS     001   RFC_NO_AUTHORITY     SAPLSDTX
           3   nplhost_NPL_42   NAGIOS     001   RFC_NO_AUTHORITY   SAPLBUBA_5
    ASCII_NOTIFICATION_END

# Bildchen #
Die Option --report html ergänzt die Plugin-Ausgabe um HTML-Code, der nähere Informationen in Tabellenform liefert und die kritischen Teile farblich markiert..

# Erweiterungen #
Im Verzeichnis $HOME/etc/check_sap_health legt man Perl-Dateien ab, die den selbstgeschriebenen Code enthalten. Beispiel: CheckSapHealthTest.pm.

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


Wichtig ist der Dateiname, der mit CheckSapHealth beginnen und die Dateiendung .pm haben muss.

Die darin enthaltene Klasse muss mit My beginnen. Aufgerufen wird das Plugin dann mit --mode my-test-modus, wobei das Argument mit dem Bindestrich als Trennzeichen zerlegt und mit doppelten Doppelpunkt wieder zusammengesetzt wird. (Aus my-test-modus wird die interne Darstellung my::test::modus).

In der Methode init() kann dann zwischen den einzelnen Modi unterschieden werden. Dabei ist zu beachten, daß Teil1 my lauten muss und Teil 2 dem Klassennamen entsprechen muss..

    check_sap_health --mode my-test-rfcping \
       --with-mymodules-dyn-dir $HOME/etc/check_sap_health
    OK - pong, runtime was 0.03s | 'runtime'=0.03;5;10;;


# Download #
[check_sap_health-1.3.2.tar.gz](http://labs.consol.de/download/shinken-nagios-plugins/check_sap_health-1.3.2.tar.gz)

# Changelog #
- 2015-01-30 1.4  
add message server connections
- 2014-12-16 1.3.3.4  
update GLPlugin
- 2014-10-01 1.3.3.3  
update GLPlugin  
fix epn bug  
+epn
- 2014-08-19 1.3.3.2  
GLPlugin update, destructor bugfix
- 2014-07-28 1.3.3.1  
GLPlugin update
- 2014-07-26 1.3.3  
add a mte cache  
bugfix in st perfdata  
update GLPlugin
- 2014-06-17 1.3.2    
fix precision of float values and thresholds.
- 2014-06-16 1.3.1.1  
update GLPlugin.
- 2014-06-13 1.3.1  
bugfix in failed-updates remove duplicate mtes in BAPI_SYSTEM_MON_GETTREE.
- 2014-06-12 1.3  
bugfix in MT_CLASS_PERFORMANCE ALRELEVVAL and Thresholds. This means: throw away your rrd-files. The metrics you collected are mostly wrong. You should also throw away your old sap-plugins and use check_sap_health :-) Many thanks to Silvan Hunkirchen who provided me with the virtual clue.  
add mode failed-updates.
- 2014-06-05 1.2  
add modes shortdumps-list, shortdumps-count, shortdumps-recurrence add report html add warningx/criticalx for mtes.
- 2014-04-16 1.1.1  
add cleanup of dev_rfc-Traces.
- 2014-02-28 1.1  
fix threshold-driven perormance mtes.
- 2014-02-07 1.0.1  
bugfix in mode sapinfo single-message mtes.

# Copyright #
Gerhard Laußer  
Check_sap_health wird unter der GNU General Public License V2 zur Verfügung gestellt.
