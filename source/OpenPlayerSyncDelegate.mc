import Toybox.Communications;
import Toybox.Lang;
import Toybox.Media;
import Toybox.PersistedContent;

class OpenPlayerSyncDelegate extends Communications.SyncDelegate {
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _syncedTracks as Array = [];
    private var _playlists as Array;
    private var _pendingPlaylistId as String = "";
    private var _playlistIndexList as Array = [];
    private var _currentTrackIndex as Number = 0;
    private var _downloadList as Array = [];
    private var _currentPlaylistIdx as Number = 0;
    private var _currentPageStart as Number = 0;

    private static const PAGE_SIZE = 5;

    function initialize() {
        SyncDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _syncedTracks = [];
        _playlists = [];
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
            _client.authenticateWithPlaylistList(
                selectedIds,
                method(:onAuthenticatedWithPlaylists)
            );
        } else {
            _client.authenticate(method(:onAuthenticated));
        }
    }

    function onAuthenticatedWithPlaylists(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }

        _syncedTracks = [];
        fetchTracksFromSelectedPlaylist(0);
    }

    function fetchTracksFromSelectedPlaylist(index as Number) as Void {
        if (index >= _playlistIndexList.size()) {
            var newList = [];
            for (var i = 0; i < _syncedTracks.size(); i++) {
                newList.add(_syncedTracks[i]);
            }
            _downloadList = newList;
            _currentTrackIndex = 0;
            downloadNextTrack();
            return;
        }

        if (!_storage.canSyncTrack(_syncedTracks.size())) {
            Communications.notifySyncComplete(null);
            return;
        }

        _currentPlaylistIdx = index;
        _currentPageStart = 0;
        _syncedTracks = [];
        fetchNextPage();
    }

    private function fetchNextPage() as Void {
        var playlistId = _playlistIndexList[_currentPlaylistIdx] as String;
        _client.getPlaylistTracks(
            playlistId,
            _currentPageStart,
            method(:onSelectedPlaylistTracksLoaded)
        );
    }

    function onSelectedPlaylistTracksLoaded(
        responseCode as Number,
        tracks as Array,
        playlistIndex as Number
    ) as Void {
        for (var i = 0; i < tracks.size(); i++) {
            if (!_storage.canSyncTrack(_syncedTracks.size())) {
                break;
            }
            _syncedTracks.add(tracks[i]);
        }

        if (tracks.size() >= PAGE_SIZE) {
            _currentPageStart = _currentPageStart + PAGE_SIZE;
            fetchNextPage();
        } else {
            fetchTracksFromSelectedPlaylist(_currentPlaylistIdx + 1);
        }
    }

    function downloadNextTrack() as Void {
        if (_currentTrackIndex >= _downloadList.size()) {
            _storage.saveSyncedTracks(_syncedTracks);
            var syncState = _storage.loadSyncState();
            syncState.lastSyncTimestamp = System.getTimer();
            syncState.totalSizeBytes = 0;
            for (var i = 0; i < _syncedTracks.size(); i++) {
                var t = _syncedTracks[i] as JellyfinTrack;
                syncState.totalSizeBytes += t.downloadSize;
            }
            Communications.notifySyncProgress(100);
            _storage.saveSyncState(syncState);
            Communications.cancelAllRequests();
            Communications.notifySyncComplete(null);
            return;
        }

        var track = _downloadList[_currentTrackIndex] as JellyfinTrack;
        if (track.serverId != null) {
            var progress = ((_currentTrackIndex.toFloat() / _downloadList.size()) * 100).toNumber();
            Communications.notifySyncProgress(progress);
            _client.downloadAndSaveTrack(track.serverId, method(:onTrackDownloaded));
        } else {
            _currentTrackIndex = _currentTrackIndex + 1;
            downloadNextTrack();
        }
    }

    function onTrackDownloaded(responseCode as Number, data as Null or Dictionary or String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 && data != null) {
            var downloadData = data as Object;

            if (downloadData instanceof Media.ContentRef) {
                var track = _downloadList[_currentTrackIndex] as JellyfinTrack;
                var cRef = data as Object as Media.ContentRef;
                var contentObj = Media.getCachedContentObj(cRef) as Media.Content;
                if (contentObj instanceof Media.Content) {
                    var metadata = new Media.ContentMetadata();
                    metadata.title = track.name;
                    metadata.artist = track.artistName;
                    metadata.album = track.albumName;

                    // Register the metadata
                    contentObj.setMetadata(metadata);
                    track.id = cRef.getId();
                }
            }
        }

        _currentTrackIndex++;
        downloadNextTrack();
    }

    function onAuthenticated(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }

        _client.getPlaylists(method(:onPlaylistsLoaded));
    }

    function onAuthenticatedWithPlaylist(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (responseCode != 200) {
            Communications.notifySyncComplete(null);
            return;
        }

        _syncedTracks = [];
        _client.getPlaylistTracks(
            _pendingPlaylistId,
            0,
            method(:onPlaylistTracksLoaded)
        );
    }

    function onPlaylistsLoaded(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
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
        _syncedTracks = [];
        fetchTracksFromPlaylist(0);
    }

    function fetchTracksFromPlaylist(index as Number) as Void {
        if (index >= _playlists.size()) {
            _storage.saveSyncedTracks(_syncedTracks);
            var syncState = _storage.loadSyncState();
            syncState.selectedPlaylistIds = [];
            for (var i = 0; i < _playlists.size(); i++) {
                var p = _playlists[i] as Dictionary;
                syncState.selectedPlaylistIds.add(p["Id"] as String);
            }
            syncState.lastSyncTimestamp = System.getTimer();
            syncState.totalSizeBytes = 0;
            for (var i = 0; i < _syncedTracks.size(); i++) {
                var t = _syncedTracks[i] as JellyfinTrack;
                syncState.totalSizeBytes += t.downloadSize;
            }
            _storage.saveSyncState(syncState);
            Communications.notifySyncComplete(null);
            return;
        }

        var playlist = _playlists[index] as Dictionary;
        var playlistId = playlist["Id"] as String;

        _client.getPlaylistTracks(
            playlistId,
            index,
            method(:onPlaylistTracksLoaded)
        );
    }

    function onPlaylistTracksLoaded(
        responseCode as Number,
        tracks as Array,
        playlistIndex as Number
    ) as Void {
        var index = playlistIndex;

        for (var i = 0; i < tracks.size(); i++) {
            _syncedTracks.add(tracks[i]);
        }

        fetchTracksFromPlaylist(index + 1);
    }

    function isSyncNeeded() as Boolean {
        if (!_storage.isConfigured()) {
            return false;
        }

        var syncState = _storage.loadSyncState();
        if (syncState.lastSyncTimestamp == 0) {
            return true;
        }

        var syncedTracks = _storage.loadSyncedTracks();
        return syncedTracks.size() == 0;
    }

    function onStopSync() as Void {
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }

    function onWebResponse(code, data) {
        if (code == 200) {
            // Success! This line closes the native battery/percentage screen
            Communications.notifySyncComplete(null);
        } else {
            // Failure! Still closes the screen but shows an error message
            Communications.notifySyncComplete("Error: " + code.toString());
        }
    }
}
