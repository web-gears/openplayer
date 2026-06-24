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

    function initialize() {
        SyncDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _lastSentProgress = -1;
        _syncTracksQueue = [];
        _finalTrackList = [];
        _currentTrackIndex = 0;
    }

    function onStartSync() as Void {
        System.println("SYNC: onStartSync");
        var token = _storage.getAuthToken();
        if (token == null || token.length() == 0) {
            System.println("SYNC: no token, re-auth");
            _client.authenticateFromSettings(method(:onReAuthResult));
            return;
        }

        var pendingTracks = _storage.loadPendingSyncTracks();
        System.println("SYNC: pending tracks loaded=" + pendingTracks.size());
        if (pendingTracks.size() == 0) {
            System.println("SYNC: no pending tracks");
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
            onStartSync();
        } else {
            Communications.notifySyncComplete(null);
        }
    }

    function downloadNextTrack() as Void {
        if (_storage.isCancelRequested()) {
            System.println("SYNC: cancel requested");
            _storage.clearCancelRequested();
            _storage.clearSyncProgress();
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
            
            var bitrate = 256000;
            var dur = getTrackValueNum(cachedDict, "durationSeconds");
            if (dur != null && dur > 1200) {
                bitrate = 128000;
            }
            System.println("SYNC: downloading track " + (_currentTrackIndex + 1) + "/" + _syncTracksQueue.size());
            _client.downloadAndSaveTrack(cachedDict["serverId"] as String, method(:onTrackDownloaded), bitrate);
        } else {
            System.println("SYNC: skipping null track at " + _currentTrackIndex);
            _currentTrackIndex++;
            downloadNextTrack();
        }
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

    function onTrackDownloaded(responseCode as Number, data as Null or Dictionary or String or PersistedContent.Iterator) as Void {
        System.println("SYNC: onTrackDownloaded rc=" + responseCode + " track=" + _currentTrackIndex);
        if (responseCode != 200) {
            System.println("SYNC: track download failed, removing from final list");
            var failedTrack = _syncTracksQueue[_currentTrackIndex];
            if (failedTrack != null) {
                var failedId = getTrackValue(failedTrack, "id");
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
        } else if (responseCode == 200 && data != null) {
            System.println("SYNC: track downloaded successfully");
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
        System.println("SYNC: finalizeSync queue=" + _syncTracksQueue.size() + " finalList=" + _finalTrackList.size());
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
        _storage.cleanupOrphanedCachedAudio(tracksToSave);

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

        _syncTracksQueue = [];
        _finalTrackList = [];

        var syncState = _storage.loadSyncState();
        syncState.lastSyncTimestamp = System.getTimer();
        syncState.totalSizeBytes = totalBytes;
        _storage.saveSyncState(syncState);

        Communications.notifySyncProgress(100);

        Communications.notifySyncComplete(null);
    }

    function isSyncNeeded() as Boolean {
        return _storage.isConfigured();
    }

    function onStopSync() as Void {
        _syncTracksQueue = [];
        _finalTrackList = [];
        _storage.saveSyncProgressDict({
            "phase" => "cancelled"
        });
        _storage.clearCancelRequested();
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }
}
