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
        Application.Storage.setValue("db_ci_init", 1);
        loadTracks();
        Application.Storage.setValue("db_ci_done_tracks", _tracks.size());
        Application.Storage.setValue("db_ci_done_refs", _contentRefs.size());
    }

    function loadTracks() as Void {
        var allTracks = _storage.loadSyncedTracks();
        var activePlaylistId = _storage.getActivePlaylistId();

        var allCount = allTracks == null ? 0 : allTracks.size();
        Application.Storage.setValue("db_ci_all", allCount);
        Application.Storage.setValue("db_ci_playlist", activePlaylistId);

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

        Application.Storage.setValue("db_ci_filtered", _tracks.size());
        refreshContentRefs();

        _currentIndex = _storage.getPlaybackPosition();
        if (_currentIndex >= _tracks.size()) {
            _currentIndex = 0;
        }

        if (_shuffle) {
            generateShuffleOrder();
        }
    }

    private function refreshContentRefs() as Void {
        _contentRefs = [];
        Application.Storage.setValue("db_ci_ref_count", 0);
        for (var i = 0; i < _tracks.size(); i++) {
            _contentRefs.add(null);
        }

        var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
        if (iter != null) {
            var ref = iter.next();
            while (ref != null) {
                var content = Media.getCachedContentObj(ref) as Media.Content?;
                if (content != null) {
                    var meta = content.getMetadata();
                    for (var i = 0; i < _tracks.size(); i++) {
                        if (_contentRefs[i] != null) { continue; }
                        var track = _tracks[i] as JellyfinTrack;
                        if (meta.title != null && meta.title.equals(track.name)) {
                            _contentRefs[i] = ref;
                            break;
                        }
                    }
                }
                ref = iter.next();
            }
        }

        var count = 0;
        for (var i = 0; i < _contentRefs.size(); i++) {
            if (_contentRefs[i] != null) { count++; }
        }
        Application.Storage.setValue("db_ci_ref_count", count);
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
        Application.Storage.setValue("db_ci_get_idx", _currentIndex);

        if (_currentIndex >= _tracks.size()) {
            Application.Storage.setValue("db_ci_get_result", -1); // no tracks
            return null;
        }

        if (_currentIndex >= _contentRefs.size()) {
            Application.Storage.setValue("db_ci_get_result", -2); // no ref at index
            _currentIndex++;
            return null;
        }

        var contentRef = _contentRefs[_currentIndex] as Media.ContentRef?;
        if (contentRef == null) {
            Application.Storage.setValue("db_ci_get_result", -3); // null ref
            _currentIndex++;
            return null;
        }
        var refId = contentRef.getId();
        Application.Storage.setValue("db_ci_get_refid", refId);

        var contentItem = Media.getCachedContentObj(contentRef) as Media.Content?;

        if (!(contentItem instanceof Media.Content)) {
            Application.Storage.setValue("db_ci_get_result", -4); // cached obj null
            _currentIndex++;
            return null;
        }

        Application.Storage.setValue("db_ci_get_result", 1); // success
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
            Application.Storage.setValue("db_ci_next_null", _currentIndex);
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
