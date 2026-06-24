import Toybox.Communications;
import Toybox.Lang;
import Toybox.Media;
import Toybox.PersistedContent;
import Toybox.Timer;
import Toybox.System;
import Toybox.Application;

(:background)
class OpenPlayerSyncDelegate extends Communications.SyncDelegate {
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _playlistIndexList as Array = [];
    private var _currentTrackIndex as Number = 0;
    private var _currentPlaylistIdx as Number = 0;
    private var _currentPageStart as Number = 0;
    private var _syncTimer as Timer.Timer;
    
    private var _syncTracksQueue as Array<Dictionary> = [];
    private var _remoteTracks as Array<Dictionary> = [];
    private var _finalTrackList as Array = [];
    private var _lastSentProgress as Number = -1;

    private const PAGE_SIZE = 5;

    function initialize() {
        SyncDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _syncTimer = new Timer.Timer();
        _lastSentProgress = -1;
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _currentTrackIndex = 0;
    }

    function onStartSync() as Void {
        var token = _storage.getAuthToken();
        if (token == null || token.length() == 0) {
            _client.authenticateFromSettings(method(:onReAuthResult));
            return;
        }

        var syncState = _storage.loadSyncState();
        var selectedIds = syncState.selectedPlaylistIds;
        if (selectedIds == null || selectedIds.size() == 0) {
            Communications.notifySyncComplete(null);
            return;
        }

        _playlistIndexList = selectedIds;
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _syncTimer.stop();
        _syncTimer = new Timer.Timer();
        _storage.saveSyncProgressDict({
            "phase" => "fetching",
            "percent" => 0,
            "currentPlaylist" => 1,
            "totalPlaylists" => _playlistIndexList.size()
        });
        _syncTimer.start(method(:onInitialCacheCleared), 100, false);
    }

    function onReAuthResult(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 200) {
            onStartSync();
        } else {
            Communications.notifySyncComplete(null);
        }
    }

    function onInitialCacheCleared() as Void {
        _syncTimer.stop();
        fetchTracksFromSelectedPlaylist(0);
    }

    function fetchTracksFromSelectedPlaylist(index as Number) as Void {
        if (index >= _playlistIndexList.size()) {
            buildSyncPlan();
            return;
        }
        _currentPlaylistIdx = index;
        _currentPageStart = 0;
        _storage.saveSyncProgressDict({
            "phase" => "fetching",
            "percent" => 0,
            "currentPlaylist" => index + 1,
            "totalPlaylists" => _playlistIndexList.size()
        });
        fetchNextPage();
    }

    function fetchNextPage() as Void {
        var playlistId = _playlistIndexList[_currentPlaylistIdx] as String;
        _client.getPlaylistTracks(playlistId, _currentPageStart, method(:onSelectedPlaylistTracksLoaded));
    }

    function buildSyncPlan() as Void {
        var localTracks = _storage.loadSyncedTracks();
        var localIds = {};
        for (var i = 0; i < localTracks.size(); i++) {
            var t = localTracks[i] as JellyfinTrack;
            if (t.id != null) {
                localIds[t.id.toString()] = true;
            }
        }

        _syncTracksQueue = [];
        _finalTrackList = [];

        for (var i = 0; i < _remoteTracks.size(); i++) {
            var remote = _remoteTracks[i] as Dictionary;
            var remoteId = remote["id"] != null ? remote["id"].toString() : "";
            if (localIds[remoteId]) {
                _finalTrackList.add(remote);
            } else {
                _syncTracksQueue.add(remote);
                _finalTrackList.add(remote);
            }
        }

        _currentTrackIndex = 0;
        if (_syncTracksQueue.size() > 0) {
            downloadNextTrack();
        } else {
            finalizeSync();
        }
    }

    function onSelectedPlaylistTracksLoaded(responseCode as Number, tracks as Array, playlistIndex as Number) as Void {
        if (responseCode == 200 && tracks != null) {
            for (var i = 0; i < tracks.size(); i++) {
                if (tracks[i] == null) { continue; }
                if (!_storage.canSyncTrack(_remoteTracks.size())) { break; }
                
                var track = tracks[i] as JellyfinTrack;
                _remoteTracks.add({
                    "id" => track.id,
                    "serverId" => track.serverId,
                    "name" => track.name,
                    "albumName" => track.albumName,
                    "artistName" => track.artistName,
                    "durationSeconds" => track.durationSeconds,
                    "downloadSize" => track.downloadSize,
                    "playlistId" => track.playlistId
                });
            }
        }

        if (tracks != null && tracks.size() >= PAGE_SIZE) {
            _currentPageStart = _currentPageStart + PAGE_SIZE;
            
            _syncTimer.stop();
            _syncTimer = new Timer.Timer();
            _syncTimer.start(method(:fetchNextPage), 50, false);
        } else {
            fetchTracksFromSelectedPlaylist(_currentPlaylistIdx + 1);
        }
    }

    function downloadNextTrack() as Void {
        _syncTimer.stop();

        if (_storage.isCancelRequested()) {
            _storage.clearCancelRequested();
            _storage.clearSyncProgress();
            Communications.notifySyncComplete(null);
            return;
        }
        
        if (_currentTrackIndex >= _syncTracksQueue.size()) {
            finalizeSync();
            return;
        }

        var cachedDict = _syncTracksQueue[_currentTrackIndex];
        
        if (cachedDict != null && cachedDict["serverId"] != null) {
            var progress = ((_currentTrackIndex.toFloat() / _syncTracksQueue.size()) * 100).toNumber();

            _storage.saveSyncProgressDict({
                "current" => _currentTrackIndex + 1,
                "total" => _syncTracksQueue.size(),
                "currentPlaylist" => _currentPlaylistIdx + 1,
                "totalPlaylists" => _playlistIndexList.size(),
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
            _client.downloadAndSaveTrack(cachedDict["serverId"] as String, method(:onTrackDownloaded), bitrate);
        } else {
            _currentTrackIndex++;
            
            _syncTimer.stop();
            _syncTimer = new Timer.Timer();
            _syncTimer.start(method(:onSyncTimerExpired), 50, false);
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
        if (responseCode != 200) {
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
            finalizeSync();
        } else {
            downloadNextTrack();
        }
    }

    function onSyncTimerExpired() as Void {
        _syncTimer.stop();
        downloadNextTrack();
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
        _storage.cleanupOrphanedCachedAudio(tracksToSave);

        _storage.saveSyncProgressDict({
            "current" => totalTracks,
            "total" => totalTracks,
            "phase" => "complete",
            "percent" => 100
        });

        _syncTracksQueue = [];
        _remoteTracks = [];
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
        _syncTimer.stop();
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _storage.saveSyncProgressDict({
            "phase" => "cancelled"
        });
        _storage.clearCancelRequested();
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }
}
