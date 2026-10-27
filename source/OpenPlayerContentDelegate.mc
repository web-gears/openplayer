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
        if (contentRefId != null) {
            var storage = new StorageManager();
            var refIdStr = contentRefId.toString();
            var tracks = storage.loadSyncedTracks();
            for (var i = 0; i < tracks.size(); i++) {
                var t = tracks[i] as JellyfinTrack;
                if (t != null && t.id != null) {
                    var storedRef = Application.Storage.getValue("tr_" + t.id.toString()) as String?;
                    if (storedRef != null && storedRef.equals(refIdStr)) {
                        storage.savePlaybackPosition(i);
                        storage.saveCurrentTrackIndex(i);
                        break;
                    }
                }
            }
        }
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
