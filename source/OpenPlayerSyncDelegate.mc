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
    private var _playlists as Array = [];
    private var _pendingPlaylistId as String = "";
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
        _playlists = [];
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _currentTrackIndex = 0;
    }

    function onStartSync() as Void {
        var server = _storage.getServer();
        var apiKey = _storage.getApiKey();
        if (server == null || apiKey == null) {
            Communications.notifySyncComplete(null);
            return;
        }

        var syncState = _storage.loadSyncState();
        var selectedIds = syncState.selectedPlaylistIds;
        if (selectedIds != null && selectedIds.size() > 0) {
            if (!_storage.canSelectPlaylist(selectedIds.size())) {
                Communications.notifySyncComplete(null);
                return;
            }
            _playlistIndexList = selectedIds;
            _client.authenticateWithPlaylistList(selectedIds, method(:onAuthenticatedWithPlaylists));
        } else {
            _client.authenticate(method(:onAuthenticated));
        }
    }

    function onAuthenticatedWithPlaylists(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }
        
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _syncTimer.stop();
        _syncTimer = new Timer.Timer();
        _syncTimer.start(method(:onInitialCacheCleared), 100, false);
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
            if (remote == null) { continue; }
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
        
        if (_currentTrackIndex >= _syncTracksQueue.size()) {
            finalizeSync();
            return;
        }

        var cachedDict = _syncTracksQueue[_currentTrackIndex];
        
        if (cachedDict != null && cachedDict["serverId"] != null) {
            var progress = ((_currentTrackIndex.toFloat() / _syncTracksQueue.size()) * 100).toNumber();
            
            if (progress != _lastSentProgress && (progress % 5 == 0 || _currentTrackIndex == 0)) {
                _lastSentProgress = progress;
                Communications.notifySyncProgress(progress);
            }
            
            _client.downloadAndSaveTrack(cachedDict["serverId"] as String, method(:onTrackDownloaded));
        } else {
            _currentTrackIndex++;
            
            _syncTimer.stop();
            _syncTimer = new Timer.Timer();
            _syncTimer.start(method(:onSyncTimerExpired), 50, false);
        }
    }

    function onTrackDownloaded(responseCode as Number, data as Null or Dictionary or String or PersistedContent.Iterator) as Void {
        Application.Storage.setValue("debug_last_rsp", responseCode.toString());
        Application.Storage.setValue("debug_track_idx", _currentTrackIndex.toString());

        if (responseCode == 200 && data != null) {
            var cachedDict = _syncTracksQueue[_currentTrackIndex];

            if (data instanceof PersistedContent.Iterator) {
                var items = [];
                var iterator = data as PersistedContent.Iterator;
                var content = iterator.next();
                while (content instanceof Media.Content) {
                    items.add(content);
                    content = iterator.next();
                }

                Application.Storage.setValue("debug_items_count", items.size().toString());

                for (var i = 0; i < items.size(); i++) {
                    if (cachedDict != null) {
                        var metadata = new Media.ContentMetadata();
                        metadata.title = cachedDict["name"] as String;
                        metadata.artist = cachedDict["artistName"] as String;
                        metadata.album = cachedDict["albumName"] as String;
                        items[i].setMetadata(metadata);
                    }
                }
            } else if (data instanceof Media.ContentRef && cachedDict != null) {
                var cRef = data as Media.ContentRef;
                var contentObj = Media.getCachedContentObj(cRef);
                if (contentObj instanceof Media.Content) {
                    var metadata = new Media.ContentMetadata();
                    metadata.title = cachedDict["name"] as String;
                    metadata.artist = cachedDict["artistName"] as String;
                    metadata.album = cachedDict["albumName"] as String;
                    contentObj.setMetadata(metadata);
                }
            }
        }

        _currentTrackIndex++;
        Application.Storage.setValue("debug_done_count", _currentTrackIndex.toString());

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

    function onAuthenticated(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }
        _client.getPlaylists(method(:onPlaylistsLoaded));
    }

    function onAuthenticatedWithPlaylist(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }
        _syncTimer.stop();
        _syncTimer = new Timer.Timer();
        _syncTimer.start(method(:onPlaylistCacheCleared), 100, false);
    }

    function onPlaylistCacheCleared() as Void {
        _syncTimer.stop();
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        _client.getPlaylistTracks(_pendingPlaylistId, 0, method(:onPlaylistTracksLoaded));
    }

    function onPlaylistsLoaded(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200 || data == null) {
            Communications.notifySyncComplete(null);
            return;
        }
        var items = data["Items"] as Array?;
        if (items == null || items.size() == 0) {
            Communications.notifySyncComplete(null);
            return;
        }
        _playlists = items;
        
        _syncTimer.stop();
        _syncTimer = new Timer.Timer();
        _syncTimer.start(method(:onPlaylistsCacheCleared), 100, false);
    }

    function onPlaylistsCacheCleared() as Void {
        _syncTimer.stop();
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        fetchTracksFromPlaylist(0);
    }

    function fetchTracksFromPlaylist(index as Number) as Void {
        if (index >= _playlists.size()) {
            finalizeSync();
            return;
        }
        var playlist = _playlists[index] as Dictionary;
        var playlistId = playlist["Id"] as String;
        _client.getPlaylistTracks(playlistId, index, method(:onPlaylistTracksLoaded));
    }

    function onPlaylistTracksLoaded(responseCode as Number, tracks as Array, playlistIndex as Number) as Void {
        var index = playlistIndex;
        if (responseCode == 200 && tracks != null) {
            for (var i = 0; i < tracks.size(); i++) {
                if (tracks[i] == null) { continue; }
                var track = tracks[i] as JellyfinTrack;
                _syncTracksQueue.add({
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
        fetchTracksFromPlaylist(index + 1);
    }

    function isSyncNeeded() as Boolean {
        return _storage.isConfigured();
    }

    function onStopSync() as Void {
        _syncTimer.stop();
        _syncTracksQueue = [];
        _remoteTracks = [];
        _finalTrackList = [];
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }

    function onWebResponse(code, data) {
        if (code == 200) {
            Communications.notifySyncComplete(null);
        } else {
            Communications.notifySyncComplete("Error: " + code.toString());
        }
    }
}
