import Toybox.Communications;
import Toybox.Lang;
import Toybox.Media;
import Toybox.PersistedContent;
import Toybox.System;

(:background)
class OpenPlayerSyncDelegate extends Communications.SyncDelegate {
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _currentTrackIndex as Number = 0;
    
    private var _syncTracksQueue as Array<Dictionary> = [];
    private var _finalTrackList as Array = [];
    private var _lastSentProgress as Number = -1;
    private var _syncInProgress as Boolean = false;
    private var _retryCount as Number = 0;
    private static const MAX_RETRY = 2;
    private static const MAX_TRACK_SIZE_BYTES = 52428800;
    private static const LOW_MEMORY_DEVICES = [
        "010-02700", "010-02701",  // FR265, FR265s
        "010-02810", "010-02811",  // FR165, FR165m
    ];

    function initialize() {
        SyncDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _lastSentProgress = -1;
        _syncTracksQueue = [];
        _finalTrackList = [];
        _currentTrackIndex = 0;
        _syncInProgress = false;
        _retryCount = 0;
    }

    function onStartSync() as Void {
        if (_syncInProgress) {
            System.println("SYNC: onStartSync re-entry blocked");
            return;
        }
        _syncInProgress = true;
        System.println("SYNC: onStartSync");
        var token = _storage.getAuthToken();
        if (token == null || token.length() == 0) {
            System.println("SYNC: no token, re-auth");
            _syncInProgress = false;
            _client.authenticateFromSettings(method(:onReAuthResult));
            return;
        }

        var pendingTracks = _storage.loadPendingSyncTracks();
        System.println("SYNC: pending tracks loaded=" + pendingTracks.size());
        if (pendingTracks.size() == 0) {
            System.println("SYNC: no pending tracks");
            _storage.saveSyncProgressDict({
                "phase" => "complete",
                "percent" => 100,
                "current" => 0,
                "total" => 0
            });
            _syncInProgress = false;
            Communications.notifySyncComplete(null);
            return;
        }

        _syncTracksQueue = [];
        _finalTrackList = [];
        var localTracks = _storage.loadSyncedTracks();
        var localIds = {};
        for (var i = 0; i < localTracks.size(); i++) {
            var t = localTracks[i] as JellyfinTrack;
            if (t.id != null) {
                localIds[t.id.toString()] = true;
            }
        }

        for (var i = 0; i < pendingTracks.size(); i++) {
            var track = pendingTracks[i] as Dictionary;
            var trackId = track["id"] != null ? track["id"].toString() : "";
            if (localIds[trackId]) {
                _finalTrackList.add(track);
            } else {
                _syncTracksQueue.add(track);
                _finalTrackList.add(track);
            }
        }
        System.println("SYNC: toDownload=" + _syncTracksQueue.size() + " finalList=" + _finalTrackList.size());

        _currentTrackIndex = 0;
        _storage.saveSyncProgressDict({
            "phase" => "downloading",
            "percent" => 0,
            "current" => 0,
            "total" => _syncTracksQueue.size()
        });

        if (_syncTracksQueue.size() > 0) {
            downloadNextTrack();
        } else {
            System.println("SYNC: nothing to download, finalizing");
            finalizeSync();
        }
    }

    function onReAuthResult(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 200) {
            _syncInProgress = false;
            onStartSync();
        } else {
            _syncInProgress = false;
            Communications.notifySyncComplete(null);
        }
    }

    function downloadNextTrack() as Void {
        if (_storage.isCancelRequested()) {
            System.println("SYNC: cancel requested");
            _storage.clearCancelRequested();
            _storage.clearSyncProgress();
            _syncInProgress = false;
            Communications.notifySyncComplete(null);
            return;
        }
        
        if (_currentTrackIndex >= _syncTracksQueue.size()) {
            System.println("SYNC: all tracks downloaded, finalizing");
            finalizeSync();
            return;
        }

        var cachedDict = _syncTracksQueue[_currentTrackIndex];
        
        if (cachedDict != null && cachedDict["serverId"] != null) {
            var downloadSize = getTrackValueNum(cachedDict, "downloadSize");
            if (downloadSize != null && downloadSize > MAX_TRACK_SIZE_BYTES) {
                System.println("SYNC: skipping oversized track " + downloadSize + " bytes");
                skipCurrentTrack();
                return;
            }

            var progress = ((_currentTrackIndex.toFloat() / _syncTracksQueue.size()) * 100).toNumber();

            _storage.saveSyncProgressDict({
                "current" => _currentTrackIndex + 1,
                "total" => _syncTracksQueue.size(),
                "phase" => "downloading",
                "percent" => progress
            });
            
            if (progress != _lastSentProgress && (progress % 5 == 0 || _currentTrackIndex == 0)) {
                _lastSentProgress = progress;
                Communications.notifySyncProgress(progress);
            }
            
            var bitrate = getDefaultBitrate();
            var dur = getTrackValueNum(cachedDict, "durationSeconds");
            if (dur != null && dur > 1200) {
                bitrate = getPodcastBitrate();
            }
            System.println("SYNC: downloading track " + (_currentTrackIndex + 1) + "/" + _syncTracksQueue.size() + " bitrate=" + bitrate);
            _retryCount = 0;
            _client.downloadAndSaveTrack(cachedDict["serverId"] as String, method(:onTrackDownloaded), bitrate);
        } else {
            System.println("SYNC: skipping null track at " + _currentTrackIndex);
            skipCurrentTrack();
        }
    }

    private function skipCurrentTrack() as Void {
        var failedTrack = _syncTracksQueue[_currentTrackIndex];
        if (failedTrack != null) {
            var failedId = getTrackValue(failedTrack, "id");
            removeTrackFromFinalList(failedId);
        }
        _currentTrackIndex++;
        downloadNextTrack();
    }

    private function removeTrackFromFinalList(failedId as String?) as Void {
        var newFinalList = [];
        for (var i = 0; i < _finalTrackList.size(); i++) {
            var t = _finalTrackList[i] as Dictionary;
            if (t != null) {
                var tid = t["id"] != null ? t["id"].toString() : "";
                if (failedId == null || !tid.equals(failedId)) {
                    newFinalList.add(t);
                }
            }
        }
        _finalTrackList = newFinalList;
    }

    private function getTrackValue(track, key as String) as String? {
        if (track instanceof JellyfinTrack) {
            var jt = track as JellyfinTrack;
            if (key.equals("name")) { return jt.name; }
            if (key.equals("artistName")) { return jt.artistName; }
            if (key.equals("albumName")) { return jt.albumName; }
            if (key.equals("id")) { return jt.id != null ? jt.id.toString() : null; }
            if (key.equals("downloadSize")) { return jt.downloadSize.toString(); }
            if (key.equals("durationSeconds")) { return jt.durationSeconds.toString(); }
            return null;
        }
        if (track instanceof Dictionary) {
            var dict = track as Dictionary;
            if (key.equals("name")) { return dict["name"] as String?; }
            if (key.equals("artistName")) { return dict["artistName"] as String?; }
            if (key.equals("albumName")) { return dict["albumName"] as String?; }
            if (key.equals("id")) { var v = dict["id"]; return v != null ? v.toString() : null; }
            if (key.equals("downloadSize")) { var v = dict["downloadSize"]; return v != null ? v.toString() : null; }
            if (key.equals("durationSeconds")) { var v = dict["durationSeconds"]; return v != null ? v.toString() : null; }
            if (key.equals("serverId")) { var v = dict["serverId"]; return v != null ? v.toString() : null; }
            if (key.equals("playlistId")) { var v = dict["playlistId"]; return v != null ? v.toString() : null; }
            return null;
        }
        return null;
    }

    private function getTrackValueNum(track, key as String) as Number? {
        var val = getTrackValue(track, key);
        if (val != null) { return val.toNumber(); }
        return null;
    }

    private function isLowMemoryDevice() as Boolean {
        var partNumber = System.getDeviceSettings().partNumber;
        if (partNumber == null) { return true; }
        var pn = partNumber as String;
        for (var i = 0; i < LOW_MEMORY_DEVICES.size(); i++) {
            if (pn.equals(LOW_MEMORY_DEVICES[i])) { return true; }
        }
        return false;
    }

    private function getDefaultBitrate() as Number {
        return isLowMemoryDevice() ? 128000 : 256000;
    }

    private function getPodcastBitrate() as Number {
        return isLowMemoryDevice() ? 96000 : 128000;
    }

    function onTrackDownloaded(responseCode as Number, data as Null or Dictionary or String or PersistedContent.Iterator) as Void {
        System.println("SYNC: onTrackDownloaded rc=" + responseCode + " track=" + _currentTrackIndex);
        if (responseCode != 200) {
            if (_retryCount < MAX_RETRY) {
                _retryCount++;
                System.println("SYNC: retry " + _retryCount + "/" + MAX_RETRY + " for track " + _currentTrackIndex);
                var cachedDict = _syncTracksQueue[_currentTrackIndex];
                if (cachedDict != null && cachedDict["serverId"] != null) {
                    var bitrate = getDefaultBitrate();
                    _client.downloadAndSaveTrack(cachedDict["serverId"] as String, method(:onTrackDownloaded), bitrate);
                    return;
                }
            }
            System.println("SYNC: track download failed after retries, removing from final list");
            var failedTrack = _syncTracksQueue[_currentTrackIndex];
            if (failedTrack != null) {
                var failedId = getTrackValue(failedTrack, "id");
                removeTrackFromFinalList(failedId);
            }
        } else if (responseCode == 200 && data != null) {
            System.println("SYNC: track downloaded successfully");
            _retryCount = 0;
            var cachedDict = _syncTracksQueue[_currentTrackIndex];
            if (cachedDict != null) {
                var trackId = cachedDict["id"] != null ? cachedDict["id"].toString() : null;
                if (trackId != null) {
                    Application.Storage.setValue("tr_" + trackId, data.toString());
                }
                var contentObj = Media.getCachedContentObj(data as Media.ContentRef);
                if (contentObj instanceof Media.Content) {
                    var metadata = new Media.ContentMetadata();
                    metadata.title = getTrackValue(cachedDict, "name");
                    metadata.artist = getTrackValue(cachedDict, "artistName");
                    metadata.album = getTrackValue(cachedDict, "albumName");
                    contentObj.setMetadata(metadata);
                }
            }
        }

        _currentTrackIndex++;

        if (_currentTrackIndex >= _syncTracksQueue.size()) {
            System.println("SYNC: all tracks done, finalizing");
            finalizeSync();
        } else {
            downloadNextTrack();
        }
    }

    function finalizeSync() as Void {
        var totalTracks = _syncTracksQueue.size();
        var tracksToSave = _finalTrackList.size() > 0 ? _finalTrackList : _syncTracksQueue;
        var totalBytes = 0;
        for (var i = 0; i < tracksToSave.size(); i++) {
            var t = tracksToSave[i] as Dictionary;
            if (t != null) {
                var size = t["downloadSize"];
                if (size instanceof Number) {
                    totalBytes += size;
                }
            }
        }

        _storage.saveSyncedTracks(tracksToSave);
        _storage.clearPendingSyncTracks();

        var prevProgress = _storage.loadSyncProgressDict();
        var fetchError = prevProgress != null ? prevProgress["fetchError"] as String? : null;
        var progress = {
            "current" => totalTracks,
            "total" => totalTracks,
            "phase" => "complete",
            "percent" => 100
        };
        if (fetchError != null) {
            progress["fetchError"] = fetchError;
        }
        _storage.saveSyncProgressDict(progress);

        var syncState = _storage.loadSyncState();
        syncState.lastSyncTimestamp = System.getTimer();
        syncState.totalSizeBytes = totalBytes;
        _storage.saveSyncState(syncState);

        _syncTracksQueue = [];
        _finalTrackList = [];

        Communications.notifySyncProgress(100);
        _syncInProgress = false;
        Communications.notifySyncComplete(null);

        _storage.cleanupOrphanedCachedAudio(tracksToSave);
    }

    function isSyncNeeded() as Boolean {
        if (_syncInProgress) {
            return false;
        }
        if (!_storage.isConfigured()) {
            return false;
        }
        var pending = _storage.loadPendingSyncTracks();
        return pending.size() > 0;
    }

    function onStopSync() as Void {
        _syncTracksQueue = [];
        _finalTrackList = [];
        _syncInProgress = false;
        _storage.saveSyncProgressDict({
            "phase" => "cancelled"
        });
        _storage.clearCancelRequested();
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }
}
