import Toybox.Lang;

class JellyfinPlaylist {
    var id as String;
    var name as String;
    var trackCount as Number;

    function initialize(id as String?, name as String?, trackCount as Number?) {
        self.id = id != null ? id : "";
        self.name = name != null ? name : "";
        self.trackCount = trackCount != null ? trackCount : 0;
    }
}

class JellyfinTrack {
    var id;
    var serverId as String;
    var name as String;
    var albumName as String;
    var artistName as String;
    var durationSeconds as Number;
    var downloadSize as Number;
    var playlistId as String;

    function initialize(
        id,
        serverId as String?,
        name as String?,
        albumName as String?,
        artistName as String?,
        durationSeconds as Number?,
        downloadSize as Number?,
        playlistId as String?
    ) {
        self.id = id != null ? id : "";
        self.serverId = serverId != null ? serverId : "";
        self.name = name != null ? name : "";
        self.albumName = albumName != null ? albumName : "Unknown Album";
        self.artistName = artistName != null ? artistName : "Unknown Artist";
        self.durationSeconds = durationSeconds != null ? durationSeconds : 0;
        self.downloadSize = downloadSize != null ? downloadSize : 0;
        self.playlistId = playlistId != null ? playlistId : "";
    }
}

class SyncState {
    var selectedPlaylistIds as Array;
    var lastSyncTimestamp as Number = 0;
    var totalSizeBytes as Number = 0;

    function initialize() {
        selectedPlaylistIds = [];
    }

    function addPlaylist(id as String?) as Void {
        if (id != null && !isPlaylistSelected(id)) {
            selectedPlaylistIds.add(id);
        }
    }

    function removePlaylist(id as String?) as Void {
        if (id == null) { return; }
        var newList = [];
        for (var i = 0; i < selectedPlaylistIds.size(); i++) {
            var item = selectedPlaylistIds[i];
            if (item != null && !item.toString().equals(id)) {
                newList.add(item);
            }
        }
        selectedPlaylistIds = newList;
    }

    function isPlaylistSelected(id as String?) as Boolean {
        if (id == null) { return false; }
        for (var i = 0; i < selectedPlaylistIds.size(); i++) {
            var item = selectedPlaylistIds[i];
            if (item != null && item.toString().equals(id)) {
                return true;
            }
        }
        return false;
    }

    function togglePlaylist(id as String?) as Void {
        if (id == null) { return; }
        if (isPlaylistSelected(id)) {
            removePlaylist(id);
        } else {
            addPlaylist(id);
        }
    }

    function clearPlaylists() as Void {
        selectedPlaylistIds = [];
    }
}