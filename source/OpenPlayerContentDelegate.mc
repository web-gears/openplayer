import Toybox.Lang;
import Toybox.Media;
import Toybox.System;

class OpenPlayerContentDelegate extends Media.ContentDelegate {
    function initialize() {
        ContentDelegate.initialize();
    }

    function getContentIterator() {
        return new OpenPlayerContentIterator();
    }

    function resetContentIterator() as ContentIterator? {
        return new OpenPlayerContentIterator();
    }

    function onSong(
        contentRefId as Lang.Object,
        songEvent as Media.SongEvent,
        playbackPosition as Lang.Number or Media.PlaybackPosition
    ) as Void {
    }

    function onShuffle() as Void {
        var app = getApp();
        app.setShuffle(!app.getShuffle());
        System.println("CONTENT: onShuffle now=" + app.getShuffle());
    }

    function onRepeat() as Void {
        var mode = getApp().cycleRepeatMode();
        System.println("CONTENT: onRepeat mode=" + mode);
    }
}
