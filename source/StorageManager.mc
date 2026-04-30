import Toybox.Application;
import Toybox.Lang;

class StorageManager {
    private static const MAX_PLAYLISTS_FREE = 1;
    private static const MAX_TRACKS_FREE = 5;
    private static const IS_PAID = true;

    function initialize() {}

    function isFreeTier() as Boolean {
        return !IS_PAID;
    }

    function canSelectPlaylist(currentCount as Number) as Boolean {
        if (IS_PAID) {
            return true;
        }
        return currentCount < MAX_PLAYLISTS_FREE;
    }

    function canSyncTrack(currentCount as Number) as Boolean {
        if (IS_PAID) {
            return true;
        }
        return currentCount < MAX_TRACKS_FREE;
    }

    function getMaxPlaylists() as Number {
        if (IS_PAID) {
            return 999;
        }
        return MAX_PLAYLISTS_FREE;
    }

    function getMaxTracks() as Number {
        if (IS_PAID) {
            return 99999;
        }
        return MAX_TRACKS_FREE;
    }

    function isConfigured() as Boolean {
        var server = Storage.getValue("jellyfin_server") as String?;
        var apiKey = Storage.getValue("jellyfin_apikey") as String?;
        return server != null && apiKey != null;
    }

    function getDefaultPlaylistId() as String? {
        return Storage.getValue("default_playlist_id") as String?;
    }

    function setDefaultPlaylistId(id as String) as Void {
        Storage.setValue("default_playlist_id", id);
    }

    function setServer(url as String?) as Void {
        if (url == null) {
            return;
        }
        var cleanUrl = url;
        if (
            cleanUrl.length() > 7 &&
            cleanUrl.substring(0, 7).equals("http://")
        ) {
            cleanUrl = cleanUrl.substring(7, cleanUrl.length());
        } else if (
            cleanUrl.length() > 8 &&
            cleanUrl.substring(0, 8).equals("https://")
        ) {
            cleanUrl = cleanUrl.substring(8, cleanUrl.length());
        }
        var slashPos = indexOf2(cleanUrl, "/");
        if (slashPos < 0) {
            slashPos = indexOf2(cleanUrl, ":");
        }
        if (slashPos >= 0) {
            cleanUrl = cleanUrl.substring(0, slashPos);
        }
        Storage.setValue("jellyfin_server", cleanUrl);
    }

    function getServer() as String {
        var url = Storage.getValue("jellyfin_server") as String?;
        return url == null ? "" : url;
    }

    private function indexOf2(str as String, sub as String) as Number {
        for (var i = 0; i <= str.length() - sub.length(); i++) {
            var found = true;
            for (var j = 0; j < sub.length(); j++) {
                if (
                    !str
                        .substring(i + j, i + j + 1)
                        .equals(sub.substring(j, j + 1))
                ) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return i;
            }
        }
        return -1;
    }

    function setApiKey(key as String?) as Void {
        if (key == null) {
            return;
        }
        Storage.setValue("jellyfin_apikey", obfuscate(key));
        Storage.setValue("jellyfin_apikey_direct", key);
    }

    function getApiKey() as String {
        var obfuscated = Storage.getValue("jellyfin_apikey") as String?;
        if (obfuscated == null) {
            return "";
        }
        return deobfuscate(obfuscated);
    }

    function setApiKeyDirect(key as String?) as Void {
        if (key == null) {
            return;
        }
        Storage.setValue("jellyfin_apikey_direct", key);
    }

    function getApiKeyDirect() as String? {
        return Storage.getValue("jellyfin_apikey_direct") as String?;
    }

    function setAuthToken(token as String?) as Void {
        if (token == null) {
            return;
        }
        Storage.setValue("jellyfin_token", token);
    }

    function getAuthToken() as String? {
        return Storage.getValue("jellyfin_token") as String?;
    }

    function setUserId(userId as String?) as Void {
        if (userId == null) {
            return;
        }
        Storage.setValue("jellyfin_userId", userId);
    }

    function getUserId() as String? {
        return Storage.getValue("jellyfin_userId") as String?;
    }

    function saveSyncState(state as SyncState) as Void {
        var data = {
            "selected_playlists" => state.selectedPlaylistIds,
            "lastSyncTimestamp" => state.lastSyncTimestamp,
            "totalSizeBytes" => state.totalSizeBytes,
        };
        Storage.setValue("sync_state", data);
    }

    function savePlaylists(playlists as Array<JellyfinPlaylist>) as Void {
        var arr = [];
        for (var i = 0; i < playlists.size(); i++) {
            var p = playlists[i];
            arr.add({
                "Id" => p.id,
                "Name" => p.name,
                "trackCount" => p.trackCount,
            });
        }
        Storage.setValue("cached_playlists", arr);
    }

    function loadPlaylists() as Array<JellyfinPlaylist> {
        var data = Storage.getValue("cached_playlists") as Array?;
        var result = [];
        if (data != null) {
            for (var i = 0; i < data.size(); i++) {
                var item = data[i] as Dictionary;
                var id = item["Id"] as String?;
                var name = item["Name"] as String?;
                var count = item["trackCount"] as Number?;
                if (id != null && name != null) {
                    result.add(
                        new JellyfinPlaylist(
                            id,
                            name,
                            count != null ? count : 0
                        )
                    );
                }
            }
        }
        return result;
    }

    function loadSyncState() as SyncState {
        var data = Storage.getValue("sync_state") as Dictionary?;
        var state = new SyncState();

        if (data != null) {
            var size = data["totalSizeBytes"] as Number?;
            if (size != null) {
                state.totalSizeBytes = size;
            }
            var selected = data["selected_playlists"] as Array?;
            if (selected != null) {
                state.selectedPlaylistIds = selected;
            }
        }

        return state;
    }

    function saveCurrentPlaylistIndex(idx as Number) as Void {
        Storage.setValue("current_playlist_index", idx);
    }

    function getCurrentPlaylistIndex() as Number {
        var idx = Storage.getValue("current_playlist_index") as Number?;
        return idx != null ? idx : 0;
    }

    function saveCurrentTrackIndex(idx as Number) as Void {
        Storage.setValue("current_track_index", idx);
    }

    function getCurrentTrackIndex() as Number {
        var idx = Storage.getValue("current_track_index") as Number?;
        return idx != null ? idx : 0;
    }

    function savePlaybackPlaylistSelection(idx as Number) as Void {
        Storage.setValue("playback_playlist_selection", idx);
    }

    function getPlaybackPlaylistSelection() as Number {
        var idx = Storage.getValue("playback_playlist_selection") as Number?;
        return idx != null ? idx : 0;
    }

    function savePlaybackTrackSelection(idx as Number) as Void {
        Storage.setValue("playback_track_selection", idx);
    }

    function getPlaybackTrackSelection() as Number {
        var idx = Storage.getValue("playback_track_selection") as Number?;
        return idx != null ? idx : 0;
    }

    function saveOptionsSelection(idx as Number) as Void {
        Storage.setValue("options_selection", idx);
    }

    function getOptionsSelection() as Number {
        var idx = Storage.getValue("options_selection") as Number?;
        return idx != null ? idx : 0;
    }

    function setOptionsTrackSelection(idx as Number) as Void {
        Storage.setValue("options_track_selection", idx);
    }

    function getOptionsTrackSelection() as Number {
        var idx = Storage.getValue("options_track_selection") as Number?;
        return idx != null ? idx : 0;
    }

    function setPendingRemovePlaylistId(id as String?) as Void {
        Storage.setValue("pending_remove_playlist_id", id);
    }

    function getPendingRemovePlaylistId() as String? {
        return Storage.getValue("pending_remove_playlist_id") as String?;
    }

    function savePlaybackPosition(idx as Number) as Void {
        Storage.setValue("playback_position", idx);
    }

    function getPlaybackPosition() as Number {
        var idx = Storage.getValue("playback_position") as Number?;
        return idx != null ? idx : 0;
    }

    function saveActivePlaylistId(id as String) as Void {
        Storage.setValue("active_playlist_id", id);
    }

    function getActivePlaylistId() as String? {
        return Storage.getValue("active_playlist_id") as String?;
    }

    function clearAll() as Void {
        Storage.deleteValue("jellyfin_server");
        Storage.deleteValue("jellyfin_apikey");
        Storage.deleteValue("jellyfin_token");
        Storage.deleteValue("jellyfin_userId");
        Storage.deleteValue("sync_state");
        Storage.deleteValue("synced_tracks");
    }

    function getAvailableStorageBytes() as Number {
        var stats = System.getSystemStats();
        return stats.freeMemory;
    }

    function saveSyncedTracks(tracks as Array) as Void {
        var trackData = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i] as JellyfinTrack;
            trackData.add({
                "id" => t.id,
                "serverId" => t.serverId,
                "name" => t.name,
                "albumName" => t.albumName,
                "artistName" => t.artistName,
                "durationSeconds" => t.durationSeconds,
                "playlistId" => t.playlistId,
});
        }
        Storage.setValue("synced_tracks", trackData);
    }

    function loadSyncedTracks() as Array {
        var trackData = Storage.getValue("synced_tracks") as Array?;
        var tracks = [];

        if (trackData != null) {
            for (var i = 0; i < trackData.size(); i++) {
                var t = trackData[i] as Dictionary;
                var trackId = t["id"];
                var trackServerId = t["serverId"] as String?;
                var trackName = t["name"] as String?;
                var trackAlbum = t["albumName"] as String?;
                var trackArtist = t["artistName"] as String?;
                var trackDuration = t["durationSeconds"] as Number?;
                var trackPlaylistId = t["playlistId"] as String?;

                if (trackServerId != null && trackName != null) {
                    var numericId = trackId as Number?;
                    if (numericId == null) {
                        numericId = trackId as String?;
                    }
                    tracks.add(
                        new JellyfinTrack(
                            numericId,
                            trackServerId,
                            trackName,
                            trackAlbum != null ? trackAlbum : "Unknown Album",
                            trackArtist != null
                                ? trackArtist
                                : "Unknown Artist",
                            trackDuration != null ? trackDuration : 0,
                            0,
                            trackPlaylistId != null ? trackPlaylistId : ""
                        )
                    );
                }
            }
        }

        return tracks;
    }

    function removeSyncedTrack(trackId as String) as Void {
        var tracks = loadSyncedTracks();
        var newTracks = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i] as JellyfinTrack;
            if (!t.id.equals(trackId)) {
                newTracks.add({
                    "id" => t.id,
                    "serverId" => t.serverId,
                    "name" => t.name,
                    "albumName" => t.albumName,
                    "artistName" => t.artistName,
                    "durationSeconds" => t.durationSeconds,
                    "playlistId" => t.playlistId,
                });
            }
        }
        Storage.setValue("synced_tracks", newTracks);
    }

    private function obfuscate(str as String) as String {
        return str;
    }

    private function deobfuscate(str as String) as String {
        return str;
    }

    private function splitString(text as String, delimiter as String) as Array {
        var result = [];
        var current = "";

        for (var i = 0; i < text.length(); i++) {
            var char = text.substring(i, i + 1);
            if (char.equals(delimiter)) {
                result.add(current);
                current = "";
            } else {
                current = current + char;
            }
        }

        if (current.length() > 0 || text.length() == 0) {
            result.add(current);
        }

        return result;
    }

    function savePendingPlaylistIds(ids as String) as Void {
        Storage.setValue("pending_playlist_ids", ids);
    }

    function savePendingPlaylistNames(names as String) as Void {
        Storage.setValue("pending_playlist_names", names);
    }

    function savePendingPlaylistCounts(counts as String) as Void {
        Storage.setValue("pending_playlist_counts", counts);
    }

    function savePendingPlaylistResponseCode(code as Number) as Void {
        Storage.setValue("pending_response_code", code);
    }

    function getPendingPlaylistIds() as String? {
        return Storage.getValue("pending_playlist_ids") as String?;
    }

    function getPendingPlaylistNames() as String? {
        return Storage.getValue("pending_playlist_names") as String?;
    }

    function getPendingPlaylistCounts() as String? {
        return Storage.getValue("pending_playlist_counts") as String?;
    }

    function getPendingPlaylistResponseCode() as Number {
        var code = Storage.getValue("pending_response_code") as Number;
        return code != null ? code : -1;
    }

    function clearPendingPlaylistResponse() as Void {
        Storage.deleteValue("pending_response_code");
        Storage.deleteValue("pending_playlist_ids");
        Storage.deleteValue("pending_playlist_names");
        Storage.deleteValue("pending_playlist_counts");
    }

    function setSyncError(msg as String) as Void {
        Storage.setValue("sync_error_msg", msg);
    }

    function getSyncError() as String? {
        return Storage.getValue("sync_error_msg") as String?;
    }

    function clearSyncError() as Void {
        Storage.deleteValue("sync_error_msg");
    }
}
