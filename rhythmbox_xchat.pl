#!/usr/bin/perl -w

# Rhythmbox XChat Announcer 0.3.1
# (c) Copyright 2006, 2007 - Tim Denholm <tim@codestorm.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use POSIX qw(strftime);

$script_name        = "Rhythmbox XChat Announcer";
$script_version     = "0.3.1";
$script_description = "Announces the current playing song information from Rhythmbox in XChat.";

$rhythmbox_version = `rhythmbox --version`;
$rhythmbox_version =~ s/GNOME\srhythmbox\s//;
chop $rhythmbox_version;

Xchat::register($script_name,$script_version,$script_description,"");

Xchat::print("Loaded \002".$script_name."\002:");
Xchat::print("Use \002/rb_help\002 to display a list of commands.");

Xchat::hook_command("rb",		"rb_announce");
Xchat::hook_command("rb_announce",	"rb_announce");
Xchat::hook_command("rb_next",		"rb_next");
Xchat::hook_command("rb_prev",		"rb_prev");
Xchat::hook_command("rb_play",		"rb_play");
Xchat::hook_command("rb_pause",		"rb_pause");
Xchat::hook_command("rb_version",	"rb_version");
Xchat::hook_command("rb_help",		"rb_help");

sub rb_announce
{
	# Check if a rhythmbox process exists.	
	if (`ps -C rhythmbox` =~ /rhythmbox/) {
		# Get current playing song information.
		$song_info = `rhythmbox-client --print-playing-format %ta\\ -\\ %at\\ -\\ %tt\\ -\\ "(%te/%td)"`;
		chop $song_info;

		Xchat::command("me is listening to: ".$song_info);
	} else {
		Xchat::print("Rhythmbox is not currently running.");
	}

	return 1;
}

sub rb_next
{
	# Skip to the next track.
	eval `rhythmbox-client --next`;
	Xchat::print("Skipped to next track.");
	return 1;
}

sub rb_prev
{
	# Skip to the previous track.
	eval `rhythmbox-client --previous`;
	Xchat::print("Skipped to previous track.");
	return 1;
}

sub rb_play
{
	# Start playback.
	eval `rhythmbox-client --play`;
	Xchat::print("Started playback.");
	return 1;
}

sub rb_pause
{
	# Pause playback.
	eval `rhythmbox-client --pause`;
	Xchat::print("Paused playback.");
	return 1;
}

sub rb_version
{
	# Display version information to a channel.
	Xchat::command("me is using ".$script_name." ".$script_version." with Rhythmbox ".$rhythmbox_version." and XChat ".Xchat::get_info("version"));
	return 1;
}

sub rb_help
{
	# Display help screen.
	Xchat::print("\002\037".$script_name." Help:\037\002");
	Xchat::print(" \002About:\002");
	Xchat::print("  * Author: Tim Denholm <tim\@codestrorm.net>");
	Xchat::print("  * URL:    http://tim.codestorm.net/projects/xchat-rhythmbox/");
	Xchat::print("  * Script Version:    ".$script_version);
	Xchat::print("  * Rhythmbox Version: ".$rhythmbox_version);
	Xchat::print("  * XChat Version:     ".Xchat::get_info("version"));
	Xchat::print(" \002Commands:\002");
	Xchat::print("  * /rb          - See /rb_announce.");
	Xchat::print("  * /rb_announce - Display the current song playing to a channel.");
	Xchat::print("  * /rb_next     - Skip to the next track.");
	Xchat::print("  * /rb_prev     - Skip to the previous track.");
	Xchat::print("  * /rb_play     - Start playback.");
	Xchat::print("  * /rb_pause    - Pause playback.");
	Xchat::print("  * /rb_version  - Display version information for the script, Rhythmbox and XChat to a channel.");
	Xchat::print("  * /rb_help     - Display this help screen.");
	return 1;
}
