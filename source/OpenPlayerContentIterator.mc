import Toybox.Lang;
import Toybox.Media;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Math;

class OpenPlayerContentIterator extends Media.ContentIterator {
    private var _tracks as Array = [];
    private var _contentRefs as Array = [];
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
        _contentRefs = [];
        if (allTracks != null) {
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
        }

        refreshContentRefs(allTracks);

        _currentIndex = _storage.getPlaybackPosition();
        if (_currentIndex >= _tracks.size()) {
            _currentIndex = 0;
        }

        if (_shuffle) {
            generateShuffleOrder();
        }
    }

    private function refreshContentRefs(allTracks as Array) as Void {
        _contentRefs = [];
        for (var i = 0; i < _tracks.size(); i++) {
            _contentRefs.add(null);
        }

        var allRefs = [];
        var allMetas = [];
        var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
        if (iter != null) {
            var ref = iter.next();
            while (ref != null) {
                var meta = null;
                var content = Media.getCachedContentObj(ref) as Media.Content?;
                if (content != null) {
                    meta = content.getMetadata();
                }
                allRefs.add(ref);
                allMetas.add(meta);
                ref = iter.next();
            }
        }

        for (var i = 0; i < allRefs.size(); i++) {
            var meta = allMetas[i] as Media.ContentMetadata?;
            if (meta == null || meta.title == null) { continue; }
            for (var j = 0; j < _tracks.size(); j++) {
                if (_contentRefs[j] != null) { continue; }
                var track = _tracks[j] as JellyfinTrack;
                if (track != null && meta.title.equals(track.name)) {
                    _contentRefs[j] = allRefs[i] as Media.ContentRef;
                    break;
                }
            }
        }
        allMetas = [];

        for (var i = 0; i < _tracks.size(); i++) {
            if (_contentRefs[i] != null) { continue; }
            var track = _tracks[i] as JellyfinTrack;
            var storedRefId = Storage.getValue("tr_" + track.id.toString()) as String?;
            if (storedRefId == null) { continue; }
            for (var j = 0; j < allRefs.size(); j++) {
                if (allRefs[j].getId().equals(storedRefId)) {
                    _contentRefs[i] = allRefs[j] as Media.ContentRef;
                    break;
                }
            }
        }

        for (var i = 0; i < _tracks.size(); i++) {
            if (_contentRefs[i] != null) { continue; }
            var track = _tracks[i] as JellyfinTrack;
            for (var j = 0; j < allTracks.size(); j++) {
                var fullTrack = allTracks[j] as JellyfinTrack;
                if (fullTrack.name != null && fullTrack.name.equals(track.name)) {
                    if (j < allRefs.size()) {
                        _contentRefs[i] = allRefs[j] as Media.ContentRef;
                    }
                    break;
                }
            }
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

    function get() as Content? {
        if (_currentIndex >= _tracks.size()) {
            return null;
        }

        if (_currentIndex >= _contentRefs.size()) {
            _currentIndex++;
            return null;
        }

        var contentRef = _contentRefs[_currentIndex] as Media.ContentRef?;
        if (contentRef == null) {
            _currentIndex++;
            return null;
        }

        var contentItem = Media.getCachedContentObj(contentRef) as Media.Content?;

        if (!(contentItem instanceof Media.Content)) {
            _currentIndex++;
            return null;
        }

        return contentItem;
    }

    function getPlaybackProfile() as PlaybackProfile? {
        var profile = new Media.PlaybackProfile();
        profile.playbackControls = [
            Media.PLAYBACK_CONTROL_SKIP_FORWARD,
            Media.PLAYBACK_CONTROL_SKIP_BACKWARD,
            Media.PLAYBACK_CONTROL_PREVIOUS,
            Media.PLAYBACK_CONTROL_NEXT,
            Media.PLAYBACK_CONTROL_VOLUME,
            Media.PLAYBACK_CONTROL_SOURCE,
        ];
        if (profile has :playbackCapabilities) {
            profile.playbackCapabilities = 1;
        }
        if (profile has :playbackNotificationThreshold) {
            profile.playbackNotificationThreshold = 1;
        }
        if (profile has :requirePlaybackNotification) {
            profile.requirePlaybackNotification = false;
        }
        if (profile has :skipPreviousThreshold) {
            profile.skipPreviousThreshold = null;
        }
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

    function canSkip() as Boolean {
        return true;
    }

    function shuffling() as Boolean {
        return _shuffle;
    }
}
