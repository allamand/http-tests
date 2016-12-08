#!/usr/bin/perl
###################################################
# Author : Sebastien Allamand / Frederic Corne
# Skill Center Identity
# Date: 09/2010
#
# version v2.0.5
#
# v2.0.5 (25/01/2016)
# test_datas : si le nom se termine par _ENCODE alors on url encode
# methodes DELETE et PATCH 
#
# v2.0.4 (27/11/2015)
# * bug : $resp etait globale => problemes avec repeate 
#
# v2.0.3 (09/01/2015)
# * reset des headers entre 2 steps, deplacement du log de la requete, et correction du print du contenu du post
#
# v2.0.2
# * reset des var $s et $resp entre chaque step pour le log
#
# v2.0.1
# * correction headers non-canonicalized field names
#
###################################################

use strict;
require LWP::UserAgent;
require LWP::Protocol::http;
require LWP::Protocol::http10;
require HTTP::Headers;
require HTTP::Request;
use XML::LibXML;
use URI::Escape;


use Data::Dumper;
use Getopt::Std;
#use Time::HiRes qw(  gettimeofday tv_interval );
use POSIX qw(strftime);

# User-definable variables
my $donotsend =0 ;  	 # if 1, do not send the requests
my $print_request=1;     # 1: prints the request
my $print_conf=0;     # 1: prints the request
my $print_response=1;    # 1: prints the entire response from server affiche header HTTP de reponse
my $print_extra_fields=1; # 1: prints fields not expected, but present in the response
my $show_only_failed=0;	 # 1: only print failed tests
my $debug=0;	 # 1: only print failed tests
my $debug2=0;
my $reecriture=1;  # permet de reecrire la reponse pour remplacer les car non ascii par des ?
my %tags;
my %headers;

my $http_vers = '1.1'; # par defaut HTTP/1.1 sinon HTTP/1.0
my $is_https = 1 ; #par defaut c'est http
my $sign_req = 0 ; #par defaut c'est non
my $method ='';
my $is_post =0; # post/patch ou delete
my $post_data_on=0; # debut zone post
my $proxy='';
my $parse_xml_response=0;




my $step_number;
my $test_datas;	#store cookies or different values (key is the number of the step value can be a hash of keyvalue
#my %step_datas; #store datas for one step and will be store in test_datas[step_number]

my $req; 	#
my $Test_Description; # description du test (#DN# dans fichier de conf)
my $Test_Expected; # resultat du test (#ED# dans fichier de conf)
my $post;	#contenu du POST
my $exp=""; 	# expected headers
my $s;		# string that will be printed
my $l;
my %h;
my $start_line_number=1; #line where the test starts
my $line_number=0;
my $test_disabled;	 # will be set to 1 if the test has to be skipped ie (disabled) in the comments
my $repeat_step=1;       # par defaut on joue la requete qu'1 fois!

my $ROUGE="\033[31m";
my $VERT="\033[32m";
my $NORMAL="\033[m";
my $BLEU="\033[36m";
my $BOLD="\033[1m";
my $NO_BOLD="\033[22m";

#HiRes
#my $t0 = [gettimeofday];
my $t0 = time;

$| = 1;

# Parameters 
my ( $server_ip, $server_port, $server_infile, $server_tagfile, $run_distant, $pas_a_pas ) = &options ;

#actuellement on passe pas le pas a pas au script donc on l'initialise ici
my $pas_a_pas = 0;
#print "pas apa $pas_a_pas\n";
sub STEP 
{
    my $msg = shift;
    if ($pas_a_pas )
    {
        print "Validation: $msg <return> to continue\n";
        my $dd = <STDIN>;
    }
}

if ($run_distant eq "true")  {
    $ROUGE="";
    $VERT="";
    $NORMAL="";
    $BLEU="";
    $BOLD="";
    $NO_BOLD="";
}

if ($print_conf) { print("##################################### Sending requests to $server_ip:$server_port, reading from $server_infile\n"); }

#Lecture du fichier de TAG
if($server_tagfile ne "")
{
    open( FILE, "< $server_tagfile" ) or die "Can't open tag file $server_tagfile : $!\n";
    if ($print_conf) {print("##################################### Using tags from file $server_tagfile\n\n"); }
    while( <FILE> ) 
    {
	chomp;
	#print "$_\n";
	my $pos = index($_,"=");
	my $tag=substr($_, 0, $pos);
	my $val=substr($_, $pos+1);
	
	if($tag)
	{
	    #print "mon tag = $tag\n";
	    #le format du tag est <TAG>=valeur
	    if(substr($tag,0,1) eq "<" && substr($tag,-1,1) eq ">")
	    {
		#si la valeur du Tag comprend un $, alors, on cherche a le remplacer par sa variable d'environnement! (docker)
		if ( $val =~ /^\$(.*)(:.*)/){
		    #print "Validation seeeeb $tag='$1' = $ENV{$1}\n" if ($debug);
		    $tags{trim($tag)}=trim($ENV{$1}.$2);
		}
		else{ # cas normal
		    $tags{trim($tag)}=trim($val);
		    #print "trim($tag)=trim($val)\n";
		}
	    }
	}
    }
    close FILE;
}
print "Reading TAG file <--\n" if ($debug);
print ( Data::Dumper->Dump([\%tags],['*tags'])) if ($debug>= 1) ;

#Lecture du fichier de CONF (request & checks file)
print "Reading CONF file -->\n" if ($debug);
open (IN, "< ".$server_infile) or warn "\nFichier $server_infile absent !!!\n";

#init global
$step_number=1;

#Parcours du fichier de CONF
while  ($l = <IN>) 
{
#		print $l;
    
    $line_number++;
    chomp $l;
    
    
    #First we apply specific TAGS on each CONF Line (tags can be in request or in checks)
    #Rejeu d'informations sauvegardes dans les steps precedents
    $l =~ s/<STEP([0-9]*)_([^>]*)>/$test_datas->{$1}->{$2}/g;
    if ($debug && $1) {
	print "Dynamic TAG updated :  Step:'$1' elem:'$2' value:'$test_datas->{$1}->{$2}'\n";
    }
    
#		print "line before $l\n";
    # Then We apply classics tags
    foreach(keys(%tags))
    {
	$l =~ s/$_/$tags{$_}/g;
	$l =~ s/\\r\\n/\n/g;
	$l =~ s/\\n/\n/g;
    }
#		print "line after  $l\n";
    
    
    #skip empty lines (except in req mode pour les POST)
    if(! $l) 
    {
	if(!$exp && $req) 
	{	
	    #		print $req;
	    if ($is_post) {
		print "Empty line going in POST/DELETE/PATCH mode\n" if ($debug);
		$post_data_on = 1;
	    }
	}
	next;
    } 
    
    
    #We can disabled test using NONE flag
    if ( $l =~ /NONE/) 
    {
	$test_disabled = 1;
    }
    #We can put a Temporisation using #SLEEPXX# Keyword
    elsif ( $l =~ /\#SLEEP\(([0-9]*)\)\#/) 
    {
	$s.= $l." (line ".$line_number.") => sleep $1\n";
	print "sleep $1\n" if ($debug);
	sleep $1;
    }
    
    #We can put a Temporisation using #SLEEPXX# Keyword
    elsif ( $l =~ /\#REPEAT\(([0-9]*)\)\#/) 
    {
	$s.= $l." (line ".$line_number.") => repeat $1\n";
	print "repeat $1\n" if ($debug);
	$repeat_step=$1;
    }
    
    #Update/Change of Host and Port server destination for the requests
    elsif ( $l =~ /\#\#URLTEST\=(.*)/)
    {
	print $VERT."Validation ==> New HostPort : $1".$NORMAL."\n";
	if ($1 =~ /https:\/\/(.*)/){
	    $1 =~ /(.*):(.*)/;
	    $server_ip=$1;
	    $server_port=$2;
	    if (!$server_port) { $server_port=443; }
	    $is_https=1;
	}
	elsif ($1 =~ /http:\/\/(.*)/){
	    $1 =~ /(.*):(.*)/;
	    $server_ip=$1;
	    $server_port=$2;
	    if (!$server_port) { $server_port=80; }
	}
	else {
	    $1 =~ /(.*):(.*)/;
	    $server_ip=$1;
	    $server_port=$2;
	    if (!$server_port) { $server_port=80; }
	}
	print $VERT."Validation ==> New Host Port $l ==> is_htps=$is_https server=ip=$server_ip server_port=$server_port".$NORMAL."\n";
    }
    elsif ( $l =~ /\#\#PROXY\=(.*)/)
    {
	print $VERT."Validation ==> New Proxy : $1".$NORMAL."\n";
	$proxy=$1;
	$s .= $l."\r\n";
    } 
    #Test Description
    elsif ( $l =~ /\#DN\#(.*)/ )
    {
	print $VERT."Validation ==> Description : $1".$NORMAL."\n" if ($debug);
	$Test_Description=$1;
	$s .= $l."\r\n";
    } 
    #Expected Resultss
    elsif ( $l =~ /\#ED\#(.*)/ )
    {
	print $VERT."Validation ==> Expected : $1".$NORMAL."\n" if ($debug);
	$Test_Expected=$1;
	$s .= $l."\r\n";
    } 
#    # http ou https 
#    elsif ( $l =~ /\#\#HTTPS\=(.*)/ )
#    {
#	print $VERT."Validation ==> HTTPS=$1".$NORMAL."\n" if ($debug);
#	$is_https=$1;
#	$s .= $l."\r\n";
#    } 
    # sign request
    elsif ( $l =~ /\#\#SIGN_REQUEST\=(.*)\#/ )
    {
	print $VERT."Validation ==> SIGN_REQUEST=$1".$NORMAL."\n" if ($debug);
	$sign_req=$1;
	$s .= $l."\r\n";
    } 
    # parse de la reponse xml 
    elsif ( $l =~ /\#\#PARSE_XML_RESPONSE\=(.*)\#/ )
    {
	print $VERT."Validation ==> PARSE_XML_RESPONSE=$1".$NORMAL."\n";# if ($debug);
	$parse_xml_response=$1;
	$s .= $l."\r\n";
    } 
    
    # If there is # then we check for disabling falg (disabled)
#    elsif ( $l =~ m/\#/) //06/07/2015 on check que la ligne commence par #
    elsif ( $l =~ m/^\#/) 
    {
	if ( $l =~ m/\#.*\(disabled\)/)
	{
	    $test_disabled = 1;
	} 
	
	$s.= $l." (line ".$line_number.")\n";
    }
    
    #If match, then reading the test is over we can proceed with the request 
    elsif ( $l =~ m/--------------------/) 
    {
	print "Step $step_number  We Found a request try to send it\n" if ($debug);
	my $success;	
	
	#first check that test is not disabled
	if(! $test_disabled)
	{
	    
	    for (my $x=1 ; $x<=$repeat_step ; $x++) # repeat x time the step
	    {
		
		$test_datas->{$step_number}->{"request"} = $req; 
		
		#If not specified, the defaut expected is X_SERVER_STATUS=OK
		if($exp eq "")
		{
		    # No expected header found. We use the default.
		    $exp="X_SERVER_STATUS=OK";
		}
		else
		{
		    #We remove the '\n\r' that we have put before at the beginning
		    if (substr($exp, 0, 2) eq "\r\n")
		    {
			substr($exp, 0, 2) = "";
		    }
		}
		
		my $t1 = time;
		my $response = &SendRecvNetHttp ($server_ip, $server_port, $proxy,  $req, \%headers, $post , $http_vers, $is_https, $sign_req, $is_post, $method, $parse_xml_response, "$step_number:$x");

		$s.= "\n########### Step ($step_number) Response:\n$response\n" if $print_response;
		
		&BackupRresults ($response, $step_number);
		
		#######################################################
		#parsing de la reponse et verification des resultats...
		$success = &check_reply_WT($response, $exp);
		
		#HiRes
		#my $elapsed = tv_interval ( $t9 );
		my $elapsed = $t1 - time;
		
		if ($success) {
		    $s .=$VERT."\tResult Step $step_number:$x  Validation : $Test_Expected [".$BOLD."OK".$NO_BOLD."] ($elapsed ms)".$NORMAL."\n";  }
		else {
		    $s .=$ROUGE."\tResult Step $step_number:$x  Validation : $Test_Expected [".$BOLD."KO".$NO_BOLD."] ($elapsed ms)".$NORMAL."\n";  }
		
		#passage au step suivant
		$step_number++;
	    }#for
	}#test enabled
	
	$s.= "----------------------------------------\n"; 
	if(($show_only_failed && !$success) || !$show_only_failed)
	{		
	    #print $VERT."print actuellement on a \$s :".$NORMAL."\n"; 
	    #print $s;
	}
	#On affiche l'état du step
	print $VERT."On affiche l'état du test :".$NORMAL."\n"; 
	print $s;

	&STEP ('next test');
	#Reseting test datas
	$Test_Description="Not Specified";
	$Test_Expected="Not Specified";
	$req = "";
	$post = "";
	$method ="";
	$is_post =0;
	$exp = "";
	$s="";
	$test_disabled = 0;
	$repeat_step=1;
	$start_line_number=$line_number+1;
	$http_vers = '1.1'; 
	$is_https=0;
	$sign_req=0;
	$post_data_on = 0;
	#seb ajout
	$s="";
	%headers=();
    }
    

    #Starting reading expected results
    elsif ( $l =~ m/---/)
    {
	#On initialise exp pour differentier la lecture des req et des exp
	$exp="\r\n";
	$post_data_on = 0;
    } 
    
    #C'est soit la requete soit les expected
    else 
    {
	if($exp) {
	    $exp .= $l."\r\n";
	} else {
	    if ($post_data_on ) {
		print "post_data_on: addind $l\n" if ($debug);
		$post .= $l;#."\r\n";
	    } else {
		if ($req ne '') { # GET ou Post deja lu, ce sont les headers
		    #seb
		    #my ($name , $value ) = split (':', $l);
		    #WT_Hack_Client-IP:80.13.211.95
		    $l =~ /([^:]*):(.*)/;
		    my $name=$1;
		    my $value=$2;
		    print "reading_headers: $l ==> '$name' = '$value'\n" if ($debug);
		    $headers {&trim($name)} = &trim($value);
		} else {
		    $req .= trim ($l);
		    if (substr($req, 0, 3) eq "GET") {
			$method = 'GET';
			$req = substr($req, 4) ;
		    } elsif (substr($req, 0, 4) eq "POST") {
			$method = 'POST';
			$req = substr($req, 5) ;
			$is_post =1;
		    } elsif (substr($req, 0, 6) eq "DELETE") {
			$method = 'DELETE';
			$req = substr($req, 7) ;
			$is_post =1;
		    } elsif (substr($req, 0, 5) eq "PATCH") {
			$method = 'PATCH';
			$req = substr($req, 6) ;
			$is_post =1;
		    }
		    # faut virer HTTP/1.1
		    my $rr = rindex($req, " HTTP/");
		    if ($rr > 0)  {
			if (substr($req, $rr+1 ) eq "HTTP/1.0") {
			    $http_vers = '1.0';
			} 
			$req= substr($req, 0, $rr);
		    }
		    #	print "req finale \"$req\"\n";
		    #	print "HTTP/$http_vers\n" ;
		}
	    }
	}
    }
}
close (IN);

#Final print all the store datas for each Steps
#if ($debug) {
my $nbstep = scalar keys(%$test_datas);
print "Nombre step : $nbstep\n";
my @step = keys(%$test_datas);


#if ($debug) {
foreach my $j ( sort keys %$test_datas ) {
    print "\tStep $j:\n";
    
    foreach my $i ( sort keys %{$test_datas->{$j}} ) {	
	print "\t\t$j:$i = '$test_datas->{$j}->{$i}'\n";
    }    
}
#}


#temps d'execution globale
#HiRes
#my $elapsed = tv_interval ( $t0 );
my $elapsed = $t0 - time;
print $BLEU."Validation ==> Total $elapsed ms".$NORMAL."\n\n";

print "END ;-)\n";
exit (1);


sub options {
# Recuperation des arguments
    my %opts;
    getopt('HPITdp',\%opts) ;
    &usage unless (exists($opts{"H"}) && exists($opts{"P"}) && exists($opts{"I"})) ;
    return ( $opts{"H"}, $opts{"P"}, $opts{"I"}, $opts{"T"}, $opts{"d"}, (exists($opts{"p"}) ? 1 : 0) ) ;
}

sub usage {
    print "Parametres incorrects :\n$0 -H host -P port -I inputfile [-T tagfile] [-d rundistant] [-p]\n" ;
    exit(-1);
}

sub BackupRresults
{
    my ($response , $step_number) = @_;


#######################################################################################
#Backup results in step_datas
#Section historique preferer l'utilisation des _$_ REGEXP || var1 var2 pour sauvegarder des datas
#######################################################################################


    if ($debug) {print ("Backup results\n");}
#add custom var backups
#    if ($response =~ /ulo=([0-9A-Za-z@.]*)/i) {
#	$test_datas->{$step_number}->{"ulo"} = $1; } else {
#	    $test_datas->{$step_number}->{"ulo"} = ""; }

}

sub SendRecvNetHttp {
    
    my ($ip, $port, $proxy, $url, $r_headers, $content , $http_vers, $is_https, $sign_req, $is_post, $method, $parse_xml, $step_msg) = @_;
    print "Connection to server $ip $port, proxy=\"$proxy\", url=$url, https=$is_https, post=$is_post method=$method \n" if ($debug >= 1 );
    
    #CONNEXION
    my $ua = LWP::UserAgent->new;
    if ($http_vers eq '1.0') {
	LWP::Protocol::implementor('http', 'LWP::Protocol::http10');
    } else {
	LWP::Protocol::implementor('http', 'LWP::Protocol::http');
    }
    $ua->timeout(5);
    #seb : permet de ne pas suivre les 302 :
    $ua->max_redirect(0);
    if ($proxy ne '') {
	$ua->proxy(['http', 'https'], "$proxy");
    }
    
    my $full;
    if ($is_https) {
	if ($port = 443){
	    $full = "https://".$ip.$url;
	}else{
	    $full = "https://".$ip.':'.$port.$url;
	}
    } else {
	$full = "http://".$ip.':'.$port.$url;
    }
    print "call : $full\n"if ($debug >= 1 );
    
    my $ss = undef;

    $s .=$VERT."Validation in [$server_infile]".$NORMAL."\n"; 
    $s .=$BLEU."Step $step_msg  Validation : $Test_Description (method=\"$method\")-->".$NORMAL."\n"; 
    #seb : Afficher la requête ici
    my $t9 = time;
    
    my $request = HTTP::Request->new;
    if ($is_post) {
	$request -> content( $content);
    } 
    $request -> method($method);
    $s .= "$method $url HTTP/$http_vers\n" if ($print_request );
    $request -> uri ( "$full");
    
    #http://search.cpan.org/~gaas/HTTP-Message-6.06/lib/HTTP/Headers.pm#NON-CANONICALIZED_FIELD_NAMES
    #si on veux garder les headers avec des "_" et non pas transformé en "-", il faut mettre : devant le nom du header
    foreach my $elt (keys  %{$r_headers}) {
	if ($elt =~ /_/) {
	    $request->header( ":$elt" => $r_headers ->{$elt});
	    $s .= "$elt: ".$r_headers ->{$elt}."\n" if ($print_request );
	} else {
	    $request->header( "$elt" => $r_headers ->{$elt}); 
	    $s .= "$elt: ".$r_headers ->{$elt}."\n" if ($print_request );
	}
    }

    #seb: si on rajoute la signature on modifie la requete ici
    #on exclue X_SERVER_COOKIE
    if ($sign_req){
	print "seb url=$url\n" if ($debug);
	my $to_sign="";
	my %tmp;

	#on prend que la QS
	my $pos = index($url, "?");
	my $val = substr($url, $pos+1);

	print "sval url=$val\n" if ($debug);
	for my $char (split '&', $val){
	    $char =~ /([^=]*)=(.*)/;
	    $tmp {lc($1)} = $2;
	}

	foreach my $elt (sort {lc $a cmp lc $b} keys %tmp) {
	    $to_sign.="$elt=$tmp{$elt}&";
	}
	#je coupe le dernier &
	my $rpos = rindex($to_sign, "&");
	$to_sign=substr($to_sign, 0, $rpos);

	#on calcul le timestamp pour la signature et on l'ajoute a la requete
	my $datestring = strftime("%Y%m%dT%H%M%S%z", localtime);
	#$to_sign.=",x_server_timestamp=$datestring";
	$request->header( ":X_SERVER_TIMESTAMP" => $datestring); 
	$s .= "X_SERVER_TIMESTAMP: ".$datestring."\n" if ($print_request );
	$r_headers->{"X_SERVER_TIMESTAMP"} = $datestring;
	
	#on passe aux headers, on met la "," en premier
	foreach my $elt (sort {lc $a cmp lc $b} keys  %{$r_headers}) {
	    #on exclue COOKIE
	    if ($elt eq "X_SERVER_COOKIE" || $elt eq "X_SERVER_USER_COOKIE"){
		next;
	    }
	    $to_sign.=",".lc($elt)."=".$r_headers->{$elt};
	}
	print "to_sign = $to_sign\n" if ($debug);
	print "Validation to_sign = $to_sign\n";

	#recherche de la bonne clef dans le fichier de tag sous la forme : <service>_KEY_SIGN
	my $serv = $tmp{'serv'};
	print "serv = $tmp{'serv'}\n";
	print $serv."_KEY_SIGN\n" if ($debug);
	my $key = $tags{"<".$serv."_KEY_SIGN".">"};
	my $type = $tags{"<".$serv."_TYPE_KEY_SIGN".">"};
	print "key = $key\n";


	system "pwd";
	print "./tags/create_tags_files/tools/hash_it -s -h $type -k \"$key\" -i \"$to_sign\"\n";
	my $hash=`./tags/create_tags_files/tools/hash_it -s -h $type -k "$key" -i "$to_sign"`;

	print "hash $hash\n" if ($debug);
	$request->header( ":X_SERVER_SIGNATURE" => $hash); 
	$s .= "X_SERVER_SIGNATURE: ".$hash."\n" if ($print_request );
    }

    $s .= "\n$content" if ($is_post && $print_request );
    $s .= "\n" if ($print_request ) ;

    print "foreach : $request->as_string" if ($debug);

    $ss = $ua->request($request );

    my $elapsed = time - $t9 ;
    print $BLEU."  Validation : Sending/Receiving Request ($elapsed ms)<--".$NORMAL."\n" if ($debug2);

#    if ($ss->is_success) {
    # A VOIR : meme en cas d'echec , il y a du xml a analyser
    # on a besoin de decomposer la reponse pour les xml
    my $resp ='';
    
    # $ss->status_line ne donne pas le proto, seulement "200 OK" ou "40X KO"
    # donc trick : la premiere ligne de $ss->as_string
    $ss->as_string =~ /(.*?)\n/;
    $resp .= "$1\n";
    # les headers
    $resp .= $ss->headers->as_string;
    if ($parse_xml) {
	print "parse_xml activated :\n";
	$resp .= &ParseXmlResponse( $ss-> content);
    } else {
	$resp .= $ss-> content;
    }
#		} else {
#				$resp .= $ss->as_string . "\n";
#		}


    my $response ='';

    #on supprime le code binaire (images..) # 10=\n et 13=\r on les garde pour avoir les retour chariot
    if ($reecriture == 1)
    { 
	for my $char (split '', $resp) {
	    my $ord = ord($char); 
	    if ($ord == 10 || $ord == 13 || ($ord > 31 && $ord < 128)){
		$response .= $char;
	    } else {
		$response .= '?';
	    }
	}
    }	   
    else
    {
	$response = $resp;
    }
    return $response;
    
}

sub ParseXmlResponse {
    my $content = shift;
    
    if ($content =~ /<WTResponse/ ){ # reponse WT
	my $dom =  eval {XML::LibXML->new->parse_string($content); };
	#print $dom->toString;
	die $@ if $@;
	
	my $str='';
	my $found = 0;
	for my $node ($dom->findnodes('/WTResponse/identifiers/ident')) {
	    #		print $node->toString."\n";
	    my $name =$node->getAttribute ('name');
	    my $value = $node->getAttribute ('value');
	    $str.="$name=\"$value\"\n";
	    $found = 1;
	}
	if (!$found) {
	    for my $node ($dom->findnodes('/WTResponse/error')) {
		$str.= $node->nodeName."\n";
		$str.=	&ReadNode($node);
		$found = 1;
	    }
	}
	if ($found){
	    return $str;
	}

    } elsif ($content =~ /<SOAP-ENV:Envelope/ ){ # reponse northapi
	my $dom =  eval {XML::LibXML->new->parse_string($content); };
	print "### DOM STRING ".$dom->toString;
	die $@ if $@;	
	my $str;
	for my $node ($dom->findnodes('SOAP-ENV:Envelope/SOAP-ENV:Body')){
	    
	    foreach my $subnode  ($node->childNodes()) {
		#		print "#".$subnode->nodeType."#".$subnode->nodeName."\n";
		if ($subnode->nodeType == 1) {
		    $str.= $subnode->nodeName."\n";
		    $str.=	&ReadNode($subnode);
		}
	    }
	} 
	return $str;	
    }

    #		on ne sait rien faire -> retour a l'identique
    return $content;
}
sub ReadNode
{
    my $node = shift;
    my $str='';
    foreach my $node1  ($node->childNodes()) {
	if ($node1->nodeType == 1) {
	    my $name  = $node1->nodeName;
	    if ($name eq 'additionalData') {
		$str.=	&ReadNodeAdditionalData($node1);
	    } else {
		my $value = $node1->textContent;
		$str .= "$name=\"$value\"\n";
	    }
	}
    }
    return $str;
}
sub ReadNodeAdditionalData
{
    my $node = shift;
    my $name;
    my $desc;
    my $value;
    foreach my $node1  ($node->childNodes()) {
	if ($node1->nodeType == 1) {
	    if ($node1->nodeName eq 'name') {
		$name= $node1->textContent;
	    } elsif ($node1->nodeName eq 'description') {
		$desc= $node1->textContent;
	    } elsif ($node1->nodeName eq 'value') {
		$value= $node1->textContent;
	    } 
	}
    }
    return "#additionalData#$name=\"$value\"/description=\"$desc\"\n";
}


#Verification des resultats de la requete
sub check_reply_WT
{
    my ($resp, $exp) = @_;
    my @arr = split(/\r\n/, $exp);
    my $key;
    my $value;
    my $msg;
    my $line;
    my $pos;
    my $pos2;
    my $key2;
    my $status ="OK";
    my $i=0;
    $s .= "########### Checking reply\n";


    if ($debug) { print "RESP $resp\n";}

    @arr=sort(@arr);
    #		print "==== ARR ====\n";
    #		print ( Data::Dumper->Dump([\@arr],['*arr']));
    #		print "==== ====\n";

    #Foreach expected Restulsts
    foreach (@arr)
    {
	$line = trim($_);
	if(! $_) {next;} #skip empty lines
	
	$key=$line;
	$msg="";

	#Check the first line of the ResultsExpected to know what test we must do
	if (substr($key, 0, 1) eq "!") # Cas de negation
	{
	    $key = substr($key, 1);

	    #use uc to upercase to rend the index function case insensitive
	    if( index(uc $resp,uc $key) != -1 ) #This expected field is present in the response
	    {
		$msg = "Validation Test : [$ROUGE ERROR $NORMAL] $key found!!!";
		$status="NOK";
	    }
	    else # the expected header is not present in reply
	    {
		$msg = "Validation Test : [ $VERT OK $NORMAL  ] $key not found";
	    }
	    $s .= "$msg\n";
	}
	
	#_>_ KEY VALEUR ==> si valeur de key > VALEUR alors OK
	elsif (substr($key, 0, 3) eq "_>_") # Cas de negation
	{
	    print "_>_ SUP feature\n" if ($debug2);
	    $key = substr($key, 4); # on passe : '_>_ '
	    
	    my ($key,$val1)=split(/ /, $key);
	    
	    print "key=$key et val1=$val1\n" if ($debug2);
	    
	    #use uc to upercase to rend the index function case insensitive
	    if( (my $r = index(uc $resp,uc $key)) != -1 ) #This expected field is present in the response
	    {
		print "OK $r\n" if ($debug2);
		my $val = substr($resp, $r+length($key)+1, 50); # on en garde que 50 ca devrais etre suffisant...		  
		print "OK '$val'\n" if ($debug2);
		if ( $val =~ /([0-9]*).*/ )
		{
		    print "we get '$1'\n" if ($debug2);
		    if ($1 > $val1)
		    {
			print "OK ($1 > $val1)\n" if ($debug2);
			$msg = "Validation Test : [ $VERT OK $NORMAL  ] $key found ($key : $1 > $val1)";
		    }
		    else
		    {
			$msg = "Validation Test : [ $ROUGE ERROR $NORMAL  ] $key found but ($1 not> $val1)";
			$status="NOK";
		    }
		}
		else
		{
		    $msg = "Validation Test : [ $ROUGE ERROR $NORMAL  ] $key found but value not digits";
		    $status="NOK";
		}

	    }
	    else # the expected header is not present in reply
	    {
		print "KO\n" if ($debug2);
		$msg = "Validation Test : [ $ROUGE ERROR $NORMAL  ] $key not found";
		$status="NOK";
	    }
	    $s .= "$msg\n";
	}

	#_$_ REGEXP ==> OK si REGEXP Match
	elsif (substr($key, 0, 3) eq "_\$_") # Cas de negation
	{
	    print "_$_ REGEXP feature\n" if ($debug2);
	    $key = substr($key, 4); # on passe : '_$_ '
	    
	    print "key=$key\n" if ($debug2);

	    #On recupere dans val1 la liste des variables a remplir par la regexp
	    my ($key,$val1)=split(/ \|\| /, $key);
	    print "key='$key' et val1=$val1\n" if ($debug2);
	    
	    if( $resp =~ /$key/i ) #Apply Regexp
	    {
		print "OK\n" if ($debug2);
		{# bloc non strict pour variable dynamique
		    no strict 'refs';
		    my $i=1;
		    my $backup="";
		    my $backup_val="";
		    my @keywords = split(/ /, $val1);
		    #Search for data to backup
		    foreach my $elem (@keywords)
		    {
			#sauvegarde dans la map les variables de la regexp pour utilisation future
			my $tmp = ${$i};
			$tmp =~ s/\x0D//; 		 #permet de supprimer les ^M (\r\n)

			# si le nom se termine par _ENCODE alors on url encode
			if ($elem =~ /_ENCODE$/ ) {
			    $tmp = uri_escape($tmp);
			} 

			$test_datas->{$step_number}->{$elem} = $tmp;
			$backup .= "$elem " if ($elem);
			$backup_val .= $tmp;
			print "elem '$elem' = '$i' '${$i}'\n" if ($debug2);
			$i++;
			if ($elem) {$msg .= "Validation Test : [ $VERT OK $NORMAL  ] $key found (backup data : $elem ($tmp))\n";}
		    }
		    if ($backup) {
			#$msg .= "Validation Test : [ $VERT OK $NORMAL  ] $key found (backup data : $backup ($backup_val))";}
			;#deja fait
		    }else {$msg = "Validation Test : [ $VERT OK $NORMAL  ] $key found (no data backup)";}
		    
		}

	    }
	    else
	    {
		print "KO\n" if ($debug2);
		$msg = "Validation Test : [ $ROUGE ERROR $NORMAL  ] $key NOT found";
		$status="NOK";
	    }
	    $s .= "$msg\n";
	}
	else # cas normal
	{
	    #if ($debug) { print "check $resp / $key"; }
	    if( index(uc $resp, uc $key) != -1 ) #This expected field is present in the response
	    {
		if ($debug) { print "$key==> OK"; }
		$msg = "Validation Test : [ $VERT OK $NORMAL  ] $key";
	    }
	    else # the expected header is not present in reply
	    {
		if ($debug) { print "$key==> KO"; }

		if (($pos = index($key, ":")) > 0)
		{
		    $key2 = substr($key,0,$pos+1);
		}
		elsif (($pos = index($key, "=")) > 0)
		{
		    $key2 = substr($key,0,$pos+1);
		}
		
		if ($pos > 0)
		{
		    if ($debug) { print "key2 = $key2\n"; }
		    if( ($pos = index($resp,$key2)) != -1 )
		    { #This expected field is present in the response
			$pos2 = index($resp,"\n", $pos);
			if ($debug) { print "pos=$pos ; pos2=$pos2\n"; }
			
			$msg .= "Validation Test : [$ROUGE ERROR $NORMAL] $key value attendees but we found: " . substr($resp,$pos,$pos2-$pos);
		    }
		    else
		    {
			$msg .= "Validation Test : [$ROUGE ERROR $NORMAL] $key header not present in reply error parsing = field";
		    }
		}
		else
		{
		    $msg .= "Validation Test : [$ROUGE ERROR $NORMAL] $key header not present in reply";
		}
		$status="NOK";
	    }
	    $s .= "$msg\n";
	}

    }

    $s.= "\n########### Response:\n$resp\n" if ( $status eq "NOK" && !$print_response);

    if ($debug) { print "S=$s"; }

    if($status eq "OK") {$s .= "########### Test Succeeded at line $start_line_number\n\n";return  1;}
    else                {$s .= "########### Test FAILED at line $start_line_number\n\n";   return  0;}

}

sub trim {
    my $string = shift;
    for ($string) {
	s/^\s+//;
	s/\s+$//;
    }
    return $string;
}

