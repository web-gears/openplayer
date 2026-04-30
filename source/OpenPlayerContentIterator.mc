import Toybox.Lang;
import Toybox.Media;
import Toybox.Application.Storage;

class OpenPlayerContentIterator extends Media.ContentIterator {
    private var _tracks as Array = [];
    private var _currentIndex as Number = 0;
    private var _shuffle as Boolean = false;
    private var _shuffleOrder as Array;
    private var _storage as StorageManager;

    function initialize() {
        ContentIterator.initialize();
        _storage = new StorageManager();
        _shuffleOrder = [];
        loadTracks();
    }

    function loadTracks() as Void {
        var allTracks = _storage.loadSyncedTracks();
        var activePlaylistId = _storage.getActivePlaylistId();

        _tracks = [];
        for (var i = 0; i < allTracks.size(); i++) {
            var track = allTracks[i] as JellyfinTrack;
            if (
                activePlaylistId == null ||
                track.playlistId == null ||
                track.playlistId.equals(activePlaylistId)
            ) {
                _tracks.add(track);
            }
        }

        _currentIndex = _storage.getPlaybackPosition();
        if (_currentIndex >= _tracks.size()) {
            _currentIndex = 0;
        }

        if (_shuffle) {
            generateShuffleOrder();
        }
    }

    private function generateShuffleOrder() as Void {
        _shuffleOrder = [];
        for (var i = 0; i < _tracks.size(); i++) {
            _shuffleOrder.add(i);
        }

        for (var i = _shuffleOrder.size() - 1; i > 0; i--) {
            var j = Toybox.System.getTimer() % (i + 1);
            var temp = _shuffleOrder[i] as Number;
            _shuffleOrder[i] = _shuffleOrder[j] as Number;
            _shuffleOrder[j] = temp;
        }
    }

    private function getActualIndex() as Number {
        if (_shuffle && _shuffleOrder.size() > 0) {
            return _shuffleOrder[_currentIndex] as Number;
        }
        return _currentIndex;
    }

    function canSkip() as Boolean {
        return true;
    }

    function get() as Content? {
        if (_currentIndex >= _tracks.size()) {
            return null;
        }

        var track = _tracks[_currentIndex] as JellyfinTrack;
        var rawId = track.id;

        if (rawId == null) {
            _currentIndex++;
            return null;
        }

        // CRITICAL: Ensure the ID is a Number.
        // If it's a String, convert it. If it's already a Number, this is safe.
        var numericId = rawId instanceof Lang.String ? rawId.toNumber() : rawId;

        var contentRef = new Media.ContentRef(
            numericId,
            Media.CONTENT_TYPE_AUDIO
        );
        var contentItem =
            Media.getCachedContentObj(contentRef) as Media.Content?;

        if (!(contentItem instanceof Media.Content)) {
            _currentIndex++;
            return null;
        }

        return contentItem;
    }

    function getPlaybackProfile() as PlaybackProfile? {
        var profile = new Media.PlaybackProfile();
        profile.playbackControls = [
            PLAYBACK_CONTROL_SKIP_FORWARD,
            PLAYBACK_CONTROL_SKIP_BACKWARD,
            PLAYBACK_CONTROL_PREVIOUS,
            PLAYBACK_CONTROL_NEXT,
            PLAYBACK_CONTROL_VOLUME,
        ];
        if (profile has :playbackCapabilities) {
            profile.playbackCapabilities = 1;
        }
        profile.playbackNotificationThreshold = 1;
        profile.requirePlaybackNotification = false;
        profile.skipPreviousThreshold = null;
        return profile;
    }

    function next() as Content? {
        if (
            _tracks == null ||
            _tracks.size() == 0 ||
            _currentIndex >= _tracks.size()
        ) {
            return null;
        }

        _currentIndex = _currentIndex + 1;
        return get();
    }

    function peekNext() as Content? {
        if (
            _tracks == null ||
            _tracks.size() == 0 ||
            _currentIndex + 1 >= _tracks.size()
        ) {
            return null;
        }

        var savedIndex = _currentIndex;
        _currentIndex = _currentIndex + 1;
        var content = get();
        _currentIndex = savedIndex;

        return content;
    }

    function peekPrevious() as Content? {
        if (_currentIndex == 0) {
            return null;
        }

        var savedIndex = _currentIndex;
        _currentIndex = _currentIndex - 1;
        var content = get();
        _currentIndex = savedIndex;

        return content;
    }

    function previous() as Content? {
        if (_currentIndex > 0) {
            _currentIndex = _currentIndex - 1;
        }
        return get();
    }

    function shuffling() as Boolean {
        return _shuffle;
    }
}
