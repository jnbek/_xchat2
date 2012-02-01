#!/usr/bin/env python
from dbus import SessionBus, DBusException
import xchat


__module_name__ = "Banshee X-Chat Plugin"
__module_version__ = "1.0"
__module_description__ = "A simple X-Chat announcer for Banshee 1.5+"

__author__ = "Max Noel <maxfnoel at gee mail dot com>"


class Banshee(object):
    BANSHEE_OBJECT = "org.bansheeproject.Banshee"
    PLAYER_ENGINE_NODE = "/org/bansheeproject/Banshee/PlayerEngine"
    def __init__(self):
        session_bus = SessionBus()
        self.player_engine = session_bus.get_object(self.BANSHEE_OBJECT, self.PLAYER_ENGINE_NODE)
        
    def current_track(self):
        return self.player_engine.GetCurrentTrack()
    

def do_track_info(word, word_eol, user_data):
    """/me the current track info."""
    try:
        banshee = Banshee()
    except DBusException:
        # Banshee not launched
        xchat.prnt("Cannot comply: Banshee is not running.")
    else:
        track_data = banshee.current_track()
        template = "me is listening to %(name)s by %(artist)s on %(album)s."
        # TODO Figure out what character encoding X-Chat is using and encode to it.
        # Defaulting to UTF-8 in the meantime.
        xchat.command((template % track_data).encode("utf-8"))
    # X-Chat doesn't know the command.
    return xchat.EAT_XCHAT


media_hook = xchat.hook_command("banshee", do_track_info)


def unload(user_data):
    xchat.unhook(media_hook)
    
    
xchat.hook_unload(unload)
xchat.prnt("Banshee plugin loaded.")
