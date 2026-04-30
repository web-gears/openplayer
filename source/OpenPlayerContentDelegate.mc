import Toybox.Lang;
import Toybox.Media;

class OpenPlayerContentDelegate extends Media.ContentDelegate {
    private var mIterator;

    function initialize() {
        ContentDelegate.initialize();
        mIterator = new OpenPlayerContentIterator();
    }

    function getContentIterator() {
        return mIterator;
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
