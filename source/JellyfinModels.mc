import Toybox.Lang;

class JellyfinPlaylist {
    var id as String;
    var name as String;
    var trackCount as Number;

    function initialize(id as String, name as String, trackCount as Number) {
        self.id = id;
        self.name = name;
        self.trackCount = trackCount;
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
        serverId as String,
        name as String,
        albumName as String,
        artistName as String,
        durationSeconds as Number,
        downloadSize as Number,
        playlistId as String
    ) {
        self.id = id;
        self.serverId = serverId;
        self.name = name;
        self.albumName = albumName;
        self.artistName = artistName;
        self.durationSeconds = durationSeconds;
        self.downloadSize = downloadSize;
        self.playlistId = playlistId;
    }
}

class SyncState {
    var selectedPlaylistIds as Array;
    var lastSyncTimestamp as Number = 0;
    var totalSizeBytes as Number = 0;

    function initialize() {
        selectedPlaylistIds = [];
    }

    function addPlaylist(id as String) as Void {
        selectedPlaylistIds.add(id);
    }

    function removePlaylist(id as String) as Void {
        var newList = [];
        for (var i = 0; i < selectedPlaylistIds.size(); i++) {
            if (!(selectedPlaylistIds[i] as String).equals(id)) {
                newList.add(selectedPlaylistIds[i]);
            }
        }
        selectedPlaylistIds = newList;
    }

    function isPlaylistSelected(id as String) as Boolean {
        for (var i = 0; i < selectedPlaylistIds.size(); i++) {
            if ((selectedPlaylistIds[i] as String).equals(id)) {
                return true;
            }
        }
        return false;
    }

    function togglePlaylist(id as String) as Void {
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