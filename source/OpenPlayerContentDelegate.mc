import Toybox.Lang;
import Toybox.Media;
import Toybox.Application.Storage;

class OpenPlayerContentDelegate extends Media.ContentDelegate {
    private var mIterator;

    function initialize() {
        ContentDelegate.initialize();
        mIterator = new OpenPlayerContentIterator();
    }

    function getContentIterator() {
        return mIterator;
    }

    function onAdAction(adContext as Object) as Void {}

    function onThumbsUp(contentRefId as Object) as Void {}

    function onThumbsDown(contentRefId as Object) as Void {}

    function onShuffle() as Void {}

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
