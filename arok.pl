#!/usr/bin/perl -w

use strict;

Xchat::register("wumprock","1.0","Amarok xchat info");
IRC::print("Wumprock 1.0 for XChat \cB\cC3loaded\cC0 :)");
IRC::add_command_handler("curplay", "cmd_amacurplay");

sub cmd_amacurplay {
    my $META = `qdbus org.kde.amarok /Player GetMetadata`;

    my ($ARTIST) = ( $META =~ /artist: (.*)/  ? $1 : "-" );
    my ($TITLE)  = ( $META =~ /title: (.*)/   ? $1 : "not playing" );
    my ($ALBUM)  = ( $META =~ /album: (.*)/   ? $1 : "-" );
    IRC::command("/me is now playing '$ARTIST' - '$ALBUM' - '$TITLE'");
}
