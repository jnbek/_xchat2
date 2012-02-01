#
# X-Away. (c) Weevil 2003
#
# this software is released under the Weevil license:
#
# BY USING THIS SOFTWARE YOU AGREE YOU LIKE IT VERY MUCH.
# IF YOU MOD IT AND IMPROVE IT, PLEASE LET ME KNOW.
#
# If you do not accept the above terms, please delete this software
# immediately.
#
# 1.4c 10 Mar 03.

package IRC::XChat::Away;

my $PKG = __PACKAGE__;
my %SERVERS;
my %NICKCACHE;
my %MODES;
#my %PMCACHE;
my @REASONS;
my $AWAYSTATE = 0;
my $BACKISSUED = 0;
my $DISCONNECT = '';
my $LASTCOMMAND = time;
my $VERSION = "1.4c";


my $XCHATV = IRC::register("X-Away", $VERSION, "", "");

my %SETTINGS = (
	"configfile" => IRC::get_info(4)."/away.conf",
	"xchatconf" => IRC::get_info(4)."/xchat.conf",
	"defaultappend" => "away",
	"defaultmessage" => "I'm away",
	"autoawaytime" => 2,
	"messengerappend" => "%O %B[%BAutomated message%B]%B",
	"pmtabname" => ":PM-Logger:",
	"forcepmloggertimestamp" => "no",
	"autoawaysilent" => "no",
	"autoawaymessage" => "",
	"autoawayappend" => "afk",
	"serveraway" => 0,
	"timeformat" => 0,
	"announcebackfromautoaway" => "no",
	"hideawayfile" => IRC::get_info(4)."/hideaway.conf",
	"reasonlistitem" => '%r [%t]',
	"silentaway" => 0,
	"eatnick" => 1,
	"lockednick" => 0,
	"silentback" => 0,
	"silentreason" => 0,
	"reasonlistjoiner" => ' => ',
	"awaymask" => '/me is away: %r (gone at %D%e %T, %H:%M:%S)',
	"backmask" => '/me returns (%l) (total away time: %t)',
	"reasonmask" => '/me changes away reason from "%o" to "%r"',
	"pmmask" => 'I am away (%r). I have been for %t',
	"pmnotice" => "yes",
	"pmtimer" => "10",
	"backtickpro" => "yes",
	"backperform" => '',
	"awayperform" => '',
	"appendchar" => "`"
);

IRC::print("X-Away\tX-Away v$VERSION loaded.");

IRC::add_message_handler("005","${PKG}::server_capabilities");
IRC::add_message_handler("PRIVMSG","${PKG}::private_message");
IRC::add_message_handler("NICK","${PKG}::nick_change");
IRC::add_message_handler("375","${PKG}::reconnect");
IRC::add_message_handler("MODE","${PKG}::mode");

IRC::add_command_handler("awaymessage","${PKG}::awaymessage");
IRC::add_command_handler("away","${PKG}::away");
IRC::add_command_handler("awayrehash","${PKG}::loadsettings");
IRC::add_command_handler("back","${PKG}::back");
IRC::add_command_handler("nicklen","${PKG}::nicklen");

IRC::add_command_handler("me","${PKG}::reset_awaytimer");
IRC::add_command_handler("msg","${PKG}::reset_awaytimer");
IRC::add_command_handler("","${PKG}::reset_awaytimer");
IRC::add_command_handler("awayreset","${PKG}::reset_awaytimer_cmd");
#IRC::add_command_handler("pmlog","${PKG}::showpmlogger");

IRC::add_timeout_handler(1000,"${PKG}::checkautoaway");

IRC::add_print_handler("Disconnected","${PKG}::disconnected");

&loadsettings($SETTINGS{configfile});
&loadsettings($SETTINGS{xchatconf});

# Map servers
foreach my $server (IRC::server_list()) {
	$SERVERS{$server} = [0,''];
}

sub awaymessage {
	my $line = shift;
	$line =~ s/^\s*|\s*$//;
	if($line =~ /^\S+$/) {
		if(exists($MESSAGES{IRC::get_info(3)}{lc($line)})) {
			delete($MESSAGES{IRC::get_info(3)}{lc($line)});
			IRC::print("X-Away\tMessage for $line cleared.\n");
		}
		else {
			IRC::print("X-Away\tNo message waiting for $nick on ".IRC::get_info(3).".\n");
		}
		if(keys(%{$MESSAGES{IRC::get_info(3)}}) == 0) {
			delete($MESSAGES{IRC::get_info(3)});
		}
	}
	elsif($line =~ /^(\S+)\s+(.+)/) {
		my($nick,$message) = ($1,$2);
		my $timeout = 0;
		my $allserv = 0;
		if($message =~ s/^-t\s*(\d+)\s*//) {
			$timeout = time + ($1 * 60);
		};
		$MESSAGES{IRC::get_info(3)}{lc($nick)} = [$message,0,$timeout];
		IRC::print("X-Away\tMessage for $nick on ".IRC::get_info(3)." set. The message will be delivered if $nick PMs you".($timeout ? " within the next ".int(($timeout - time) / 60)." minutes" : "").".\n");
	}
	else {
		IRC::print("X-Away\t\037Message List:\037\n");
		foreach my $key (sort {$a cmp $b} (keys(%MESSAGES))) {
			IRC::print("X-Away\t \002$key\017\n");
			foreach my $subkey (sort {$a cmp $b} (keys(%{$MESSAGES{$key}}))) {
				IRC::print(sprintf("X-Away\t  %9s : %s \017\002[\017%s\002]\017%s\017\n",$subkey,&domask($MESSAGES{$key}{$subkey}[0],2,1),($MESSAGES{$key}{$subkey}[1] ? "Delivered ".localtime($MESSAGES{$key}{$subkey}[1]) : "Undelivered"),($MESSAGES{$key}{$subkey}[2] != 0 && $MESSAGES{$key}{$subkey}[1] == 0 ? " \002[\002".($MESSAGES{$key}{$subkey}[2] > time ? int(($MESSAGES{$key}{$subkey}[2] - time) / 60)."m ".(($MESSAGES{$key}{$subkey}[2] - time) % 60)."s left" : "Timed out") . "\002]" : "")));
			}
		}
	}
	return 1;
}

sub mode {
	my $line = shift;
	$line =~ /^:{0,1}(.+?)\s+MODE\s+(\S+)\s+(\S+)\s*(.*)$/;
	my($from,$chan,$modes,@targets) = ($1,$2,$3,(split(/\s+/,$4)));
	my($nick,$userhost);
	if($from =~ /^(\S+)!(\S+)$/) { ($nick,$userhost) = ($1,$2); } else { ($nick,$userhost) = ($from, $from) };
	my $modetype = "";
	my $arglessmodes = (grep($_ ne "-" && $_ ne "+",split('',$modes))) - @targets;
	for(my $i = 0; $i < $arglessmodes; $i++) {unshift(@targets,"") };
	foreach my $mode (split("",$modes)) {
		if($mode =~ /(\+|\-)/){$modetype = $mode; next}
		my $arg = shift(@targets);
		if($modetype eq "-") {
			if(exists($MODES{$chan})){ $MODES{$chan} =~ s/$mode//g };
		}
		else {
			$MODES{$chan} = $mode.(exists($MODES{$chan}) ? $MODES{$chan} : "");
		}
	}
	return 0;
}


sub disconnected {
	my $line = shift;
	if($line =~ /^\s*$/){
		# Assume the user disconnected this
		if(exists($SERVERS{IRC::get_info(3)}) && defined($SERVERS{IRC::get_info(3)}->[1]) && $SERVERS{IRC::get_info(3)}->[1] ne ''){IRC::command("/nick ".$SERVERS{IRC::get_info(3)}->[1])}
		elsif($SETTINGS{resetnickondisconnect} =~ /^1|yes/) {IRC::command("/nick ".$SETTINGS{nickname1})};
		delete($SERVERS{IRC::get_info(3)});
		return(0);
	};
	IRC::print("Disconnected with reason on ".IRC::get_info(3)." - assuming next connection is reconnect\n");
	push(@DISCONNECT,IRC::get_info(3));
	return(0);
}

sub reconnect {
	if(!@DISCONNECT){ return(0) };

	if($AWAYSTATE != 0) {
		if($SETTINGS{serveraway} =~ /^y|on|1/i) {
			if($SETTINGS{pmmask} !~ /^\s*$/) {
				IRC::send_raw("AWAY :".&domask($SETTINGS{pmmask},1)."\r\n");
			}
			else {
				IRC::send_raw("AWAY :unknown reason\r\n");
			}
		}
	}

	for(my $i = 0; $i < @DISCONNECT; $i++) {
		if(lc(IRC::get_info(3)) eq lc($DISCONNECT[$i])) {
			splice(@DISCONNECT,$i,1);
			IRC::print("X-Away\tReconnection recognised\n");
			return(1);
		}
	}

	my $server = shift(@DISCONNECT);
	if($server eq IRC::get_info(3)) {return(0)};
	IRC::print("X-Away\tReconnection unrecognised - Assuming this is reconnection to $server\n");
	$SERVERS{IRC::get_info(3)} = $SERVERS{$server};
	delete($SERVERS{$server});
	return(1);
}

# this is here to make sure that if we PM someone with /msg they don't see our
# away message on response.
sub msg {
	my $args = shift;
	if($args =~ /^([^\#\&\+]\S+)\s+/) {
		${lc($1)} = time;
	}
	return(0);
}

sub reset_awaytimer_cmd {
	&reset_awaytimer();
	return 1;
}

sub reset_awaytimer {
	$LASTCOMMAND = time;
	if($AWAYSTATE == 2) {
		&backfromautoaway;
	}
	if(IRC::get_info(2) !~ /^[\#\&\+]/) {
		# We're in a PM. Mod the user's last pm time so we dont show away message:
		$NICKCACHE{lc(IRC::get_info(2))} = time;
	}
	return(0);
}

sub checkautoaway {
	if($SETTINGS{autoawaytime} > 0 && $LASTCOMMAND < time - ($SETTINGS{autoawaytime} * 60) && $AWAYSTATE == 0) {
		# mark away.
		my $arg = '';
		if($SETTINGS{autoawaysilent} =~ /1|yes/){$arg .= "-s "}
		if($SETTINGS{autoawayappend} !~ /^\s*$/){$arg .= '`'.$SETTINGS{autoawayappend}." "};
		if($SETTINGS{autoawaymessage} !~ /^\s*$/){$arg .= $SETTINGS{autoawaymessage}} else { $arg .= "Auto-away after ".$SETTINGS{autoawaytime}." mins idle" };
		&away($arg);
		$AWAYSTATE = 2;
		# correct time since away:
		$REASONS[0]->[0] = time - ($SETTINGS{autoawaytime} * 60);
	}
	foreach my $key (keys(%NICKCACHE)) {
		if($NICKCACHE{$key} < time - ($SETTINGS{pmtimer} * 60)) {
			delete($NICKCACHE{$key});
		}
	}
	IRC::add_timeout_handler(1000,"${PKG}::checkautoaway");

	return(1);
}

# pm logger? How should this work? my methodologies don't allow me to pin down
# just what it does; it should be up to the user to decide how it works. Should
# it really be in this away script at all?

#sub showpmlogger {
#	my @chans = IRC::channel_list();
#	my $createtab = 1;
#	while(@chans) { if( (splice(@chans,0,3))[0] eq $SETTINGS{pmtabname} ) { $createtab = 0 } }
#	if($createtab == 1) {
#		IRC::command("/query ".$SETTINGS{pmtabname});
#		&pmlogprint("PM Logger opened");
#	}
#	return(1);
#}

#sub pmlogprint {
#	my $line = shift;
#	my $time = sprintf("%d %s %02d:%02d:%02d",(localtime(time))[3],("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[(localtime(time))[4]],(localtime(time))[2],(localtime(time))[1],(localtime(time))[0]);
#	IRC::print_with_channel( (IRC::get_prefs("timestamp") != 1 || $SETTINGS{forcepmlogtimestamp} =~ /^1|yes/i ? "[".$time."]" : "")."\t".$line."\n",$SETTINGS{pmtabname},IRC::get_info(3));
#}

sub backfromautoaway {
	my $line = shift;
	if($AWAYSTATE == 2) {
		# Back from auto-away.
		if($SETTINGS{announcebackfromautoaway} !~ /1|yes|on/i) {
			&back("-s");
		}
		else {
			&back;
		}
	}
	return(0);
}

sub back {
	my $line = shift;
	$LASTCOMMAND = time;
	my $silent = 0;
	my $loud = 0;
	if($line =~ /^\s*-s/) {
		$silent = 1;
	}
	if($line =~ /^\s*-a/) {
		$loud = 1;
	}

	if($AWAYSTATE == 0 && $BACKISSUED == 1) {
		return(1);
	}
	$AWAYSTATE = 0;
	$BACKISSUED = 1;
	if(exists($SETTINGS{backperform}) && defined($SETTINGS{backperform}) && $SETTINGS{backperform} !~ /^\s*$/) {
		foreach my $command (split(/\s*\|\s*/,$SETTINGS{backperform})) {
			IRC::command($command);
		}
	}
	foreach my $server (keys(%SERVERS)) {
		if($SERVERS{$server}->[1] ne '') {
			IRC::command_with_server("/NICK ".$SERVERS{$server}->[1], $server);
			$SERVERS{$server}->[1] = '';
		}
		else {
			IRC::command_with_server("/NICK ".$SETTINGS{nickname1}, $server);
		}
	}
	if(!$silent && !($SETTINGS{silentback} =~ /^1|y|on/i && !$loud)) {
		&announce(2);
	}
	@REASONS = ();
	foreach my $key (keys(%NICKCACHE)) {
		delete($NICKCACHE{$key});
	}
	if($SETTINGS{serveraway} =~ /^1|y|on/i) {
		IRC::command("/ALLSERV ".($XCHATV =~ /^2/ ? "/" : "")."QUOTE AWAY");
	}
	return(1);
}

sub server_capabilities {
	my $line = shift;
	if($line =~ /^:{0,1}(\S+)\s+005\s+\S+\s+.*NICKLEN\s*=\s*(\d+).*\s*:/) {
		if(!exists($SERVERS{IRC::get_info(3)})){$SERVERS{IRC::get_info(3)} = [0,'']};
		$SERVERS{IRC::get_info(3)}[0] = $2;
	}
	return(0);
}

sub away {
	my $line = shift;
	my $append = '';
	my $silent = 0;
	my $loud = 0;
	if(!exists($SERVERS{IRC::get_info(3)})){$SERVERS{IRC::get_info(3)} = [0,'']};

	if($line =~ /^\-s\s+/) {
		$line =~ s/^\-s\s+//;
		$silent = 1;
	}

	if($line =~ /^\-a\s+/) {
		$line =~ s/^\-a\s+//;
		$loud = 1;
	}

	if($line =~ /^(\`|\Q$SETTINGS{appendchar}\E)\S+\s+/) {
		$line =~ s/^(\`|\Q$SETTINGS{appendchar}\E)(\S+)\s+//;
		$append = $2;
	}

	if($append eq '' && $AWAYSTATE == 0) { $append = $SETTINGS{defaultappend} };

	if($line =~ /^\s*$/) {
		$line = $SETTINGS{defaultmessage};
	}

	if($AWAYSTATE != 0) {
		# Already away. Assume we should change away reason
		push(@REASONS,[time, $line]);
		if(!$silent && !($SETTINGS{silentreason} =~ /^1|y|on/i && !$loud)) { &announce(1) }
		if($append !~ /^\s*$/) { &awaynick($append)	}
		$AWAYSTATE = 1;
	}
	else {
		# Not already away.
		if(exists($SETTINGS{awayperform}) && defined($SETTINGS{awayperform}) && $SETTINGS{awayperform} !~ /^\s*$/) {
			foreach my $command (split(/\s*\|\s*/,$SETTINGS{awayperform})) {
				IRC::command($command);
			}
		}
		@REASONS = ([time, $line]);
		if(!$silent && !($SETTINGS{silentaway} =~ /^1|y|on/i && !$loud) ) { &announce(0) }
		if($append !~ /^\s*$/) { &awaynick($append)	}
		$AWAYSTATE = 1;
	}
	if($SETTINGS{serveraway} =~ /^y|on|1/i) {
		if($SETTINGS{pmmask} !~ /^\s*$/) {
			IRC::command("/ALLSERV ".($XCHATV =~ /^2/ ? "/" : "")."QUOTE AWAY :".&domask($SETTINGS{pmmask},1))
		}
		else {
			IRC::command("/ALLSERV ".($XCHATV =~ /^2/ ? "/" : "")."QUOTE AWAY :".$line)
		}
	}
	return(1);
}

sub nicklen {
	my $len = shift;
	$len ||= 0;
	# sets nick length for this server
	if($len == 0) {
		foreach my $server (IRC::server_list()) {
			IRC::print("Nick length on $server : ".&getnicklen($server)."\n");
		}
		return(1);
	}
	$SERVERS{IRC::get_info(3)}->[0] = $len;
	IRC::print("Set nick length on ".IRC::get_info(3)." to $len\n");
	return(1);
}

sub awaynick {
	# create awaynick for each server.
	my $append = shift;
	if($SETTINGS{lockednick} =~ /^1|y|on/i) { return };
	if($append !~ /^\s*$/) { $append = $SETTINGS{appendchar}.$append };
	my @servers = IRC::server_list();

	foreach my $server (@servers) {
		my $maxlen = &getnicklen($server);
		my $nick = &getnick($server);

		if(exists($SERVERS{$server}) && defined($SERVERS{$server}) && defined($SERVERS{$server}[1]) && $SERVERS{$server}[1] ne '') {
			# if there's already an away nick, use that.
			$nick = $SERVERS{$server}[1]
		}
		else {
			# if not, ordinarily creating an away nick is OK, unless backtick protection is on and
			# a backtick (or other append char) is found in the current nick. In that case, resort
			# to the default nick.
			if($SETTINGS{backtickpro} =~ /^1|yes$/i && index($nick,$SETTINGS{appendchar}) > -1) {
				$nick = $SETTINGS{nickname1};
			}
		}
		$SERVERS{$server}[1] = $nick;
		if($SETTINGS{eatnick} =~ /^1|y|on/) {
			$nick = substr($nick,0,$maxlen - (length($append))) . $append;
		}
		else {
			$nick = $nick . $append;
		}
		IRC::command_with_server("/NICK ".$nick,$server);
	}
}

sub private_message {
	my $line = shift;
	$line =~ /^:{0,1}(\S+)!(\S+)\s+PRIVMSG\s+(\S+)\s*:(.*)/;
	my($nick,$host,$target,$message) = ($1,$2,$3,$4);
	my $mask;
	if($target eq IRC::get_info(1)) {
		# This is a PM.
		if($message =~ /^\001/ && $message !~ /^\001ACTION/){
			# Ctcp - dont bother responding
			return(0);
		}
		if($SETTINGS{serveraway} =~ /^y|on|1/i || $SETTINGS{pmmask} =~ /^\s*$/) {
			# Server away. The server should deal with these messages.
			return(0);
		}
		if($SETTINGS{pmmask} !~ /^\s*$/ && (!exists($NICKCACHE{lc($nick)}) || $NICKCACHE{lc($nick)} < time - ($SETTINGS{pmtimer} * 60)) && $AWAYSTATE != 0 ) {
			$mask = &domask($SETTINGS{pmmask});
			if($SETTINGS{pmnotice} =~ /1|yes/) {
				IRC::send_raw("NOTICE $nick :$mask\r\n");
				IRC::print_with_channel("\cC13>\cO$nick\cC13<\cO\t$mask\n",$nick,IRC::get_info(3));
			}
			else {
				IRC::send_raw("PRIVMSG $nick :$mask\r\n");
				if($mask =~ /^\001ACTION (.*?)\001/) {
					IRC::print_with_channel("\cC13*\t".IRC::get_info(1)." $1\n",$nick,IRC::get_info(3));
				}
				else {
					IRC::print_with_channel("\cC3>\cO$nick\cC3<\cO\t$mask\n",$nick,IRC::get_info(3));
				}
			}
		}
		if(exists($MESSAGES{IRC::get_info(3)}{lc($nick)}) && $MESSAGES{IRC::get_info(3)}{lc($nick)}[1] == 0 && ($MESSAGES{IRC::get_info(3)}{lc($nick)}[2] > time || $MESSAGES{IRC::get_info(3)}{lc($nick)}[2] == 0)) {
			IRC::send_raw("PRIVMSG $nick :".&domask($MESSAGES{IRC::get_info(3)}{lc($nick)}[0].$SETTINGS{messengerappend},0,1)."\r\n");
			$MESSAGES{IRC::get_info(3)}{lc($nick)}[1] = time;
		}
		$NICKCACHE{lc($nick)} = time;
	}
	return(0);
}

sub nick_change {
	my $line = shift;
	$line =~ /^:{0,1}(\S+)!(\S+)\s+NICK\s*:(.*)\s*/;
	my($nick,$host,$newnick) = ($1,$2,$3);
	if(exists($NICKCACHE{lc($nick)})) {
		$NICKCACHE{lc($newnick)} = $NICKCACHE{lc($nick)};
		delete($NICKCACHE{lc($nick)});
	}
	return(0);
}

sub announce {
	# announce away where type:
	# 0 - away
	# 1 - reason change
	# 2 - back
	my $type = shift;

	my $mask;
	if($type == 0){$mask = &domask($SETTINGS{awaymask})};
	if($type == 1){$mask = &domask($SETTINGS{reasonmask})};
	if($type == 2){$mask = &domask($SETTINGS{backmask})};

	if($mask =~ /^\s*$/) {
		return(1);
	}

	my %noannounce;
	if(open(SILENCE,$SETTINGS{hideawayfile})) {

		while(<SILENCE>) {
			my $line = $_;
			$line =~ s/^\s*(.*?)\s*$/$1/;
			if($line =~ /^\#/) {next};
			if($line =~ /^\s*$/){ next};
			my($key,$value) = split(/\s*\=\s*/,$line,2);
			$noannounce{$key} = [split(/\s+/,$value)];
		}
		close(SILENCE);
	} else {

	}

	my @chans = IRC::channel_list();
	my %announce;
	while(@chans) {
		my($chan,$server,$nick) = splice(@chans,0,3);

		if($chan !~ /^[\#\&\+]/){next};
		my($op,$voice) = &modesin($chan,$server);
		if(exists($MODES{$chan}) && $MODES{$chan} =~ /m/ && $op == 0 && $voice == 0) { next };
		my $ok = 1;
		foreach my $key (keys(%noannounce)) {
			if(eval('$server =~ /$key/i')) {
				my $flags;
				foreach my $exp (@{$noannounce{$key}}) {
					my $expression = $exp;
					if($expression =~ s/([ov]*)([\#\&\+])/$2/) {
						$flags = $1;
						$expression =~ s/^\^*//;
						if(eval('$chan =~ /^$expression/i')) {
							if($op == 1 && $voice == 0 && $flags =~ /o/ && $flags !~ /v/) {
								$ok = 1;
							}
							elsif($voice == 1 && $op == 0 && $flags =~ /v/ && $flags !~ /o/) {
								$ok = 1;
							}
							elsif(($voice == 1 || $op == 1) && ($flags =~ /v/ && $flags =~ /o/)) {
								$ok = 1;
							}
							else {
								$ok = 0;
							}
						}
					}
				}
			}
		}
		if($ok) {
			if(!exists($announce{$server})){$announce{$server} = []};
			push(@{$announce{$server}},$chan);

		}
	}
	# Announce!
	foreach my $server (keys(%announce)) {
		foreach my $chan (@{$announce{$server}}) {
			if($mask =~ /^\001ACTION\s+(.*?)\001$/) {
				IRC::print_with_channel("\cC13*\t".&getnick($server)." ".$1."\n", $chan, $server);
			} else {
				IRC::print_with_channel("\cC13<\017".&getnick($server)."\cC13>\t\017\n".$mask, $chan, $server);
			}

		}
		IRC::command_with_server("/QUOTE PRIVMSG ".join(",",@{$announce{$server}})." :".$mask,$server);
	}
	return(1);
}

sub modesin {
	my($channel, $server) = @_;
	my @users = IRC::user_list($channel, $server);
	while(@users) {
		my($nick, $host, $opped, $voiced, undef) = splice(@users, 0, 5);
		if($nick eq IRC::get_info(1)) { return($opped, $voiced) }
	}
	return(0,0);
}

sub domask {
	my $mask = shift;
	my $fakeme = shift;
	my $nomodreasons = shift;
	$fakeme ||= 0;
	$nomodreasons ||= 0;

	# Create a reason list:
	my $reasonlist = '';
	if(!@REASONS && $nomodreasons == 0) {
		push(@REASONS,[time, "Unknown reason"]);
	}
	for(my $i = 0; $i < @REASONS; $i++) {
		my $minireason = $REASONS[$i];
		my $subreason = $SETTINGS{reasonlistitem};
		my $reason = $minireason->[1];
		my ($dynatime, $secs, $mins, $hours, $days, $weeks) = &nicetime(($i < $#REASONS ? $REASONS[$i+1][0] : time) - $minireason->[0]);
		my ($sec,$min,$hour,$mday,$mon,$year) = ($SETTINGS{timeformat} ? (localtime($minireason->[0])) : (gmtime($minireason->[0])));
		my $txtmon = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
		$mon++;
		$year = 1900 + $year;
		my $shortyear = substr($year,2,2);
		my $mdayend = 'th';
		if(substr($mday,-2,1) ne "1") {
			if(substr($mday,-1,1) eq '1') {$mdayend = "st"}
			if(substr($mday,-1,1) eq '2') {$mdayend = "nd"}
			if(substr($mday,-1,1) eq '3') {$mdayend = "rd"}
		}
		$sec = sprintf("%02d",$sec);
		$min = sprintf("%02d",$min);
		$hour = sprintf("%02d",$hour);
		$subreason =~ s/\%r/$reason/g;
		$subreason =~ s/\%t/$dynatime/g;
		$subreason =~ s/\%h/$hours/g;
		$subreason =~ s/\%m/$mins/g;
		$subreason =~ s/\%s/$secs/g;
		$subreason =~ s/\%d/$days/g;
		$subreason =~ s/\%w/$weeks/g;
		$subreason =~ s/\%H/$hour/g;
		$subreason =~ s/\%M/$min/g;
		$subreason =~ s/\%S/$sec/g;
		$subreason =~ s/\%D/$mday/g;
		$subreason =~ s/\%N/$mon/g;
		$subreason =~ s/\%T/$txtmon/g;
		$subreason =~ s/\%Y/$year/g;
		$subreason =~ s/\%y/$shortyear/g;
		$subreason =~ s/\%e/$mdayend/g;
		if($i != @REASONS - 1) {
			$reasonlist .= $subreason.$SETTINGS{reasonlistjoiner};
		}
		else {
			$reasonlist .= $subreason;
		}
	}

	if(!@REASONS) {
		push(@REASONS,[time, "(Unknown reason)"]);
	}

	# Total away time;
	my ($dynatime, $secs, $mins, $hours, $days, $weeks) = &nicetime(time - $REASONS[0]->[0]);
	my ($sec,$min,$hour,$mday,$mon,$year) = ($SETTINGS{timeformat} ? (localtime($REASONS[0]->[0])) : (gmtime($REASONS[0]->[0])));
	$sec = sprintf("%02d",$sec);
	$min = sprintf("%02d",$min);
	$hour = sprintf("%02d",$hour);
	my $mdayend = 'th';
	if(substr($mday,-2,1) ne "1") {
		if(substr($mday,-1,1) eq '1') {$mdayend = "st"}
		if(substr($mday,-1,1) eq '2') {$mdayend = "nd"}
		if(substr($mday,-1,1) eq '3') {$mdayend = "rd"}
	}
	my $txtmon = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
	$mon++;
	$year = 1900 + $year;
	my $shortyear = substr($year,2,2);

	# Away time since last reason change:
	my ($dynatimeb, $secsb, $minsb, $hoursb, $daysb, $weeksb) = &nicetime(time - $REASONS[$#REASONS]->[0]);
	my ($secb,$minb,$hourb,$mdayb,$monb,$yearb) = ($SETTINGS{timeformat} ? (localtime($REASONS[$#REASONS]->[0])) : (gmtime($REASONS[$#REASONS]->[0])));
	$secb = sprintf("%02d",$secb);
	$minb = sprintf("%02d",$minb);
	$hourb = sprintf("%02d",$hourb);
	my $mdayendb = 'th';
	if(substr($mdayb,-2,1) ne "1") {
		if(substr($mdayb,-1,1) eq '1') {$mdayendb = "st"}
		if(substr($mdayb,-1,1) eq '2') {$mdayendb = "nd"}
		if(substr($mdayb,-1,1) eq '3') {$mdayendb = "rd"}
	}
	my $txtmonb = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$monb];
	$monb++;
	$yearb = 1900 + $yearb;
	my $shortyearb = substr($yearb,2,2);
	my $reason = $REASONS[$#REASONS][1];
	my $oldreason = '';
	if($#REASONS - 1 >= 0) {$oldreason = $REASONS[$#REASONS - 1][1]};

	$mask =~ s/\%C/\003/g;
	$mask =~ s/\%U/\037/g;
	$mask =~ s/\%B/\002/g;
	$mask =~ s/\%R/\026/g;
	$mask =~ s/\%O/\017/g;
	$mask =~ s/\%l/$reasonlist/g;
	$mask =~ s/\%r/$reason/g;
	$mask =~ s/\%o/$oldreason/g;
	$mask =~ s/\%t/$dynatime/g;
	$mask =~ s/\%h/$hours/g;
	$mask =~ s/\%m/$mins/g;
	$mask =~ s/\%s/$secs/g;
	$mask =~ s/\%d/$days/g;
	$mask =~ s/\%w/$weeks/g;
	$mask =~ s/\%H/$hour/g;
	$mask =~ s/\%M/$min/g;
	$mask =~ s/\%S/$sec/g;
	$mask =~ s/\%D/$mday/g;
	$mask =~ s/\%N/$mon/g;
	$mask =~ s/\%T/$txtmon/g;
	$mask =~ s/\%Y/$year/g;
	$mask =~ s/\%y/$shortyear/g;
	$mask =~ s/\%e/$mdayend/g;

	$mask =~ s/\%q/$dynatimeb/g;
	$mask =~ s/\%a/$hoursb/g;
	$mask =~ s/\%b/$minsb/g;
	$mask =~ s/\%c/$secsb/g;
	$mask =~ s/\%f/$daysb/g;
	$mask =~ s/\%g/$weeksb/g;
	$mask =~ s/\%A/$hourb/g;
	$mask =~ s/\%E/$minb/g;
	$mask =~ s/\%F/$secb/g;
	$mask =~ s/\%G/$mdayb/g;
	$mask =~ s/\%H/$monb/g;
	$mask =~ s/\%I/$txtmonb/g;
	$mask =~ s/\%J/$yearb/g;
	$mask =~ s/\%K/$shortyearb/g;
	$mask =~ s/\%L/$mdayendb/g;

	if($fakeme == 1) {
		$mask =~ s/^\/me\s+(.*)/This user $1/i;
	}

	if($fakeme == 0) {
		$mask =~ s/^\/me\s+(.*)/\001ACTION $1\001/i;
	}
	return($mask);
}

sub loadsettings {
	my $file = shift;
	if($file =~ /^\s*$/){$file = $SETTINGS{configfile}};
	open(SETTINGS,$file) or do {IRC::print("X-Away\tFailed to load settings from ".$file." - $!\n");return(1)};

	while(<SETTINGS>) {
		my $line = $_;
		$line =~ s/^\s*(.*?)\s*$/$1/;
		if($line =~ /^\#/) {next};
		if($line =~ /^\s*$/){ next};
		my($key,$value) = split(/\s*\=\s*/,$line,2);
		if($value =~ /^\'(.*?)\'$/){$value = $1};
		$SETTINGS{$key} = $value;
		$SETTINGS{$key} =~ s/\$data/IRC::get_info(4)/eig;
	}

	close(SETTINGS);
	IRC::print("X-Away\tSettings loaded from ".$file."\n");
	return(1);
}

sub nicetime {
	my $time = shift;
	my $weeks = int((gmtime($time))[7] / 7);
	my $days = (gmtime($time))[7] % 7;
	my $hours = (gmtime($time))[2];
	my $mins = (gmtime($time))[1];
	my $secs = (gmtime($time))[0];
	my $dynatime = $secs."s";
	if($mins != 0) { $dynatime = $mins."m ".$secs."s" };
	if($hours != 0) { $dynatime = $hours."h ".$mins."m ".$secs."s" };
	if($days != 0) { $dynatime = $days."d ".$hours."h ".$mins."m ".$secs."s" };
	if($weeks != 0) { $dynatime = $weeks."w ".$days."d ".$hours."h ".$mins."m ".$secs."s" };
	return($dynatime, $secs, $mins, $hours, $days, $weeks);
}

sub getnick {
	# gets your nick on this server
	my $server = shift;
	my @chans = IRC::channel_list();
	while(@chans) {
		my($chan,$lserver,$nick) = splice(@chans,0,3);
		if($lserver eq $server){return($nick)}
	}
	return('');
}

sub getnicklen {
	# Max nick length on this server
	my $server = shift;

	if(exists($SERVERS{$server}) && defined($SERVERS{$server}[0]) && $SERVERS{$server}[0] != 0) {
		# We know this from 005...
		return($SERVERS{$server}[0]);
	}
	# We can only guess this from the nicks we know atm:
	my @chans = IRC::channel_list();
	my $maxlen = 0;
	while(@chans) {
		my($chan,$lserver,$nick) = splice(@chans,0,3);
		if($lserver ne $server) { next };
		my @users = IRC::user_list($chan, $server);
		while(@users) {
			my($unick,undef,undef,undef,undef) = splice(@users,0,5);
			if(length($unick) > $maxlen) { $maxlen = length($unick) };
		}
	}
	if($maxlen < 9){$maxlen = 9};
	return($maxlen);
}
