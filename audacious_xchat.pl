#!/usr/bin/perl -w

# Audacious XChat Announcer 0.2.1-jn
# (C) Copyright 2007 - Milad Rastian <rastian AT gmail dot com>
# Thanks to Tim Denholm for his Rhythmbox XChat Announcer Plugin
# With this script you can control your Audacious playe from XChat
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

#How To Use ?
#1.Rename this file to xchat_audacious.pl
#2.Just copy this file in ~/.xchat2 and in IRC write /ab_help to more help ;)
use POSIX qw(strftime);

$script_name    = "Audacious XChat Announcer";
$script_version = "0.2.1-jn";
$script_description =
  "Announces the current playing song information from Audacious in XChat.";

$audacious_version = `audacious --version`;
$audacious_version =~ s/\saudacious\s//;
chop $audacious_version;

IRC::register( $script_name, $script_version, $script_description, "" );

IRC::print( "Loaded \002" . $script_name . "\002:" );
IRC::print("Use \002/ab_help\002 to display a list of commands.");

IRC::add_command_handler( "ab_announce", "ab_announce" );
IRC::add_command_handler( "audacious",   "ab_announce" );
IRC::add_command_handler( "ab_next",     "ab_next" );
IRC::add_command_handler( "ab_prev",     "ab_prev" );
IRC::add_command_handler( "ab_play",     "ab_play" );
IRC::add_command_handler( "ab_pause",    "ab_pause" );
IRC::add_command_handler( "ab_version",  "ab_version" );
IRC::add_command_handler( "ab_help",     "ab_help" );
my @greeting = (
    "With extreme prejuduce, I choose to hear:",
    "Without a second thought, I\'m listening to:",
    "Audacious is being forced at gunpoint to play:",
    "Just for Kicks and Giggles, I\'m jamming to:",
    "For some reason known only to God, I\'m playing:",
    "Guess What!!!, I\'m headbanging to:",
    "Hmmm, I seem to be listening to:",
    "You know what?? I'll just listen to:",
    "Some d00d decided to make Audacious play:",
    "Sam Fisher snuck into my house and hacked Audacious into playing:",
    "If you know what\'s good for ya, you\'ll also listen to:",
    "Why are you looking at me like that, it\'s just:",
"....And then there was this time at band camp, ...and ...and, we were listening to:",
    "Yea, that\'s right, I\'m listening to:",
    "MMmmMMmmMmmmMmmmm, Chocolate.... OOooo and:",
    "Hey some dude wanted me to tell you to listen to:",
    "Audacious decided to thrash out to:",
    "Yea so what if my mama dresses me funny, at least I\'m listening to:",
    "Tommy Vercetti jacked my car and all I have left is:",
    "Carl Johnson told me that I better listen to:",
    "I visited Carlsbad Caverns and all I got was:",
    "Look !!! Up in the sky, it\'s a bird, it\'s a plane, it\'s:",
    "Vinnie and Guido said they\'d break my legs if I didn\'t play:",
    "Suprise !!! You're Fred, Guess What... Barney\'s Dead, Huh?? Oh Wait:",
    "Only cool people are allowed to listen to:",
"Vic Vance beat up his brother Lance, just so I could devastate you all with:",
    "Tony Cipriani convinced me it was in my best interest to listen to:",
    "Real men don't eat quiche, but they sure as heck listen to:",
    "Music to destroy all mankind to, it\'s:",
    "You know you\'re cool when your theme song becomes: ",
    "Run Away, RUN AWAY!!! It\'s..:",
);

# Needed audtool parameters
#   current-song                       - returns current song title
#   current-song-filename              - returns current song filename
#   current-song-length                - returns current song length
#   current-song-output-length         - returns current song output length
#   current-song-bitrate-kbps          - returns current song bitrate in kilobits per second
#   current-song-frequency             - returns current song frequency in hertz
#   current-song-channels              - returns current song channels
#   current-song-tuple-data            - returns the value of a tuple field for the current song
#   playlist-position                  - returns the position in the playlist
#   playlist-length                    - returns the total length of the playlist
#   get-volume                         - returns the current player volume
#
# This will output the following format:
# <::>Vic Vance beat up his brother Lance, just so I could devastate you all with: /mp3/music/Amorphis/Amorphis - Elegy - 11 - My Kantele (Acoustic Reprise).mp3 [1:28/5:55] [192 kbps] Freq: [44100] Current Volume: [80%] Genre: [Melodic Death Metal] Playlist position: [196 of 1198]<:-^-_-^-:>
sub ab_announce {
    if ( `ps -C audacious` =~ /audacious/ ) {

        # Get current playing song information.
        my $song_info = `audtool --current-song-filename `;
        if ( $song_info =~ m/file:\/\/\//g ) {
            $song_info =~ s/file:\/\/\///gmi;
            $song_info =~ s/%20/ /gmi;
        }
        my $song_length =
          `audtool --current-song-length `;    # Full Length of the Song
        my $song_output_length = `audtool --current-song-output-length `
          ;    # How much of the song has been played thus far
        my $song_bitrate  = `audtool --current-song-bitrate-kbps `;
        my $song_freq     = `audtool --current-song-frequency `;
        my $song_volume   = `audtool --get-volume `;
        my $song_genre    = `audtool --current-song-tuple-data genre `;
        my $song_position = `audtool --playlist-position `;
        my $song_playlist = `audtool --playlist-length `;

        chop $song_info;
        chop $song_length;
        chop $song_output_length;
        chop $song_bitrate;
        chop $song_freq;
        chop $song_volume;
        chop $song_genre;
        chop $song_position;
        chop $song_playlist;
        my $index   = rand @greeting;
        my $JAMMING = $greeting[$index];

        IRC::command(
qq(\0035<::>$JAMMING $song_info [$song_output_length/$song_length] [$song_bitrate kbps] Freq: [$song_freq] Current Volume: [$song_volume%] Genre: [$song_genre] Playlist position: [$song_position/$song_playlist]\003)
        );
    }
    else {
        IRC::print("Audacious is not currently running.");
    }

    return 1;
}

sub ab_next {

    # Skip to the next track.
    eval `audtool --playlist-advance`;
    IRC::print("Skipped to next track.");
    return 1;
}

sub ab_prev {

    # Skip to the previous track.
    eval `audtool --playlist-reverse`;
    IRC::print("Skipped to previous track.");
    return 1;
}

sub ab_play {

    # Start playback.
    eval `audtool --playback-play`;
    IRC::print("Started playback.");
    return 1;
}

sub ab_pause {

    # Pause playback.
    eval `audtool playback-pause`;
    IRC::print("Paused playback.");
    return 1;
}

sub ab_version {

    # Display version information to a channel.
    IRC::command( "/me is using "
          . $script_name . " "
          . $script_version
          . " with "
          . $audacious_version
          . " and XChat "
          . IRC::get_info(0) );
    return 1;
}

sub ab_help {

    # Display help screen.
    IRC::print( "\002\037" . $script_name . " Help:\037\002" );
    IRC::print(" \002About:\002");
    IRC::print("  * Author: Milad Rastian <rastian AT gmail DOT com>");
    IRC::print("  * URL:    http://fritux.com/");
    IRC::print( "  * Script Version:    " . $script_version );
    IRC::print( "  * Audacious Version: " . $audacious_version );
    IRC::print( "  * XChat Version:     " . IRC::get_info(0) );
    IRC::print(" \002Commands:\002");
    IRC::print(
        "  * /ab_announce - Display the current song playing to a channel.");
    IRC::print("  * /ab_next     - Skip to the next track.");
    IRC::print("  * /ab_prev     - Skip to the previous track.");
    IRC::print("  * /ab_play     - Start playback.");
    IRC::print("  * /ab_pause    - Pause playback.");
    IRC::print(
"  * /ab_version  - Display version information for the script, Rhythmbox and XChat to a channel."
    );
    IRC::print("  * /ab_help     - Display this help screen.");
    return 1;
}

