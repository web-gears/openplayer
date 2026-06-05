import Toybox.Lang;
import Toybox.Media;

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
}
