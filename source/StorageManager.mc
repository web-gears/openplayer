import Toybox.Application;
import Toybox.Lang;
import Toybox.Media;
import ScaleHelper;

(:background)
class StorageManager {
    private static const TRACK_DELIM = "|";
    private static const RECORD_DELIM = "\n";
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
        var ids = state.selectedPlaylistIds;
        var idsStr = "";
        for (var i = 0; i < ids.size(); i++) {
            if (i > 0) { idsStr = idsStr + TRACK_DELIM; }
            idsStr = idsStr + ids[i];
        }
        var encoded = idsStr + RECORD_DELIM +
            state.lastSyncTimestamp.toString() + RECORD_DELIM +
            state.totalSizeBytes.toString();
        Storage.setValue("sync_state", encoded);
    }

    function savePlaylists(playlists as Array<JellyfinPlaylist>) as Void {
        var parts = [];
        for (var i = 0; i < playlists.size(); i++) {
            var p = playlists[i];
            parts.add(
                p.id + TRACK_DELIM + p.name + TRACK_DELIM + p.trackCount.toString()
            );
        }
        var encoded = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) { encoded = encoded + RECORD_DELIM; }
            encoded = encoded + parts[i];
        }
        Storage.setValue("cached_playlists", encoded);
    }

    function loadPlaylists() as Array<JellyfinPlaylist> {
        var result = [];
        var raw = Storage.getValue("cached_playlists");

        if (raw instanceof Array) {
            var data = raw as Array;
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
        } else if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
                var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
                for (var i = 0; i < records.size(); i++) {
                    var fields = ScaleHelper.splitString(records[i], TRACK_DELIM);
                    if (fields.size() >= 3) {
                        result.add(
                            new JellyfinPlaylist(
                                fields[0],
                                fields[1],
                                fields[2].toNumber()
                            )
                        );
                    }
                }
            }
        }

        return result;
    }

    function loadSyncState() as SyncState {
        var state = new SyncState();
        var raw = Storage.getValue("sync_state");

        if (raw instanceof Dictionary) {
            var data = raw as Dictionary;
            var size = data["totalSizeBytes"] as Number?;
            if (size != null) {
                state.totalSizeBytes = size;
            }
            var selected = data["selected_playlists"] as Array?;
            if (selected != null) {
                state.selectedPlaylistIds = selected;
            }
        } else if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
                var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
                if (records.size() >= 3) {
                    var idsStr = records[0];
                    if (idsStr.length() > 0) {
                        var idParts = ScaleHelper.splitString(idsStr, TRACK_DELIM);
                        for (var i = 0; i < idParts.size(); i++) {
                            state.selectedPlaylistIds.add(idParts[i]);
                        }
                    }
                    state.lastSyncTimestamp = records[1].toNumber();
                    state.totalSizeBytes = records[2].toNumber();
                }
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

    function clearDownloads() as Void {
        purgeAllCachedAudio();

        Storage.deleteValue("sync_state");
        Storage.deleteValue("synced_tracks_str");
        Storage.deleteValue("synced_tracks");
        Storage.deleteValue("cached_playlists");
        Storage.deleteValue("pending_playlist_ids");
        Storage.deleteValue("pending_playlist_names");
        Storage.deleteValue("pending_playlist_counts");
        Storage.deleteValue("pending_response_code");
        Storage.deleteValue("sync_error_msg");
        Storage.deleteValue("sync_loading");
        Storage.deleteValue("current_playlist_index");
        Storage.deleteValue("current_track_index");
        Storage.deleteValue("playback_position");
        Storage.deleteValue("playback_playlist_selection");
        Storage.deleteValue("playback_track_selection");
        Storage.deleteValue("options_selection");
        Storage.deleteValue("options_track_selection");
        Storage.deleteValue("pending_remove_playlist_id");
        Storage.deleteValue("multi_session_queue");
        Storage.deleteValue("default_playlist_id");
        Storage.deleteValue("active_playlist_id");
        Storage.deleteValue("pending_playlist_id");
    }

    function purgeAllCachedAudio() as Void {
        var refs = [];
        var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
        if (iter != null) {
            var ref = iter.next();
            while (ref != null) {
                refs.add(ref);
                ref = iter.next();
            }
        }
        for (var i = 0; i < refs.size(); i++) {
            Media.deleteCachedItem(refs[i] as Media.ContentRef);
        }
    }

    function cleanupOrphanedCachedAudio(keepTracks as Array) as Void {
        var keepNames = {};
        for (var i = 0; i < keepTracks.size(); i++) {
            var t = keepTracks[i];
            var name = "";
            if (t instanceof Dictionary) {
                name = (t as Dictionary)["name"] as String;
            } else if (t instanceof JellyfinTrack) {
                name = (t as JellyfinTrack).name;
            }
            if (name != null && !name.equals("")) {
                keepNames[name] = true;
            }
        }

        var refs = [];
        var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
        if (iter != null) {
            var ref = iter.next();
            while (ref != null) {
                refs.add(ref);
                ref = iter.next();
            }
        }

        for (var i = 0; i < refs.size(); i++) {
            var contentRef = refs[i] as Media.ContentRef;
            var content = Media.getCachedContentObj(contentRef) as Media.Content?;
            if (content != null) {
                var meta = content.getMetadata();
                if (meta.title == null || keepNames[meta.title] == null) {
                    Media.deleteCachedItem(contentRef);
                }
            }
        }
    }

    function deleteCachedItemByTitle(title as String) as Void {
        var refs = [];
        var iter = Media.getContentRefIter({:contentType => Media.CONTENT_TYPE_AUDIO});
        if (iter != null) {
            var ref = iter.next();
            while (ref != null) {
                refs.add(ref);
                ref = iter.next();
            }
        }
        for (var i = 0; i < refs.size(); i++) {
            var contentRef = refs[i] as Media.ContentRef;
            var content = Media.getCachedContentObj(contentRef) as Media.Content?;
            if (content != null) {
                var meta = content.getMetadata();
                if (meta.title != null && meta.title.equals(title)) {
                    Media.deleteCachedItem(contentRef);
                    return;
                }
            }
        }
    }

    function getAvailableStorageBytes() as Number {
        var stats = System.getSystemStats();
        return stats.freeMemory;
    }

    function saveSyncedTracks(tracks as Array) as Void {
        var parts = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i];
            var id = "";
            var serverId = "";
            var name = "";
            var albumName = "";
            var artistName = "";
            var durationSeconds = 0;
            var downloadSize = 0;
            var playlistId = "";

            if (t instanceof Dictionary) {
                var dict = t as Dictionary;
                id = dict.get("id");
                serverId = dict.get("serverId") as String?;
                name = dict.get("name") as String?;
                albumName = dict.get("albumName") as String?;
                artistName = dict.get("artistName") as String?;
                durationSeconds = dict.get("durationSeconds") as Number?;
                downloadSize = dict.get("downloadSize") as Number?;
                playlistId = dict.get("playlistId") as String?;
            } else if (t instanceof JellyfinTrack) {
                var track = t as JellyfinTrack;
                id = track.id;
                serverId = track.serverId;
                name = track.name;
                albumName = track.albumName;
                artistName = track.artistName;
                durationSeconds = track.durationSeconds;
                downloadSize = track.downloadSize;
                playlistId = track.playlistId;
            }

            parts.add(
                id.toString() +
                TRACK_DELIM + (serverId != null ? serverId : "") +
                TRACK_DELIM + (name != null ? name : "") +
                TRACK_DELIM + (albumName != null ? albumName : "") +
                TRACK_DELIM + (artistName != null ? artistName : "") +
                TRACK_DELIM + durationSeconds.toString() +
                TRACK_DELIM + downloadSize.toString() +
                TRACK_DELIM + (playlistId != null ? playlistId : "")
            );
        }

        var encoded = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) {
                encoded = encoded + RECORD_DELIM;
            }
            encoded = encoded + parts[i];
        }
        Storage.setValue("synced_tracks_str", encoded);
    }

    function makeNumericId(str as String) as Number {
        var digits = "";
        for (var i = 0; i < str.length(); i++) {
            if (digits.length() >= 9) { break; }
            var ch = str.substring(i, i + 1);
            if (ch.equals("0") || ch.equals("1") || ch.equals("2") || ch.equals("3") ||
                ch.equals("4") || ch.equals("5") || ch.equals("6") || ch.equals("7") ||
                ch.equals("8") || ch.equals("9")) {
                digits = digits + ch;
            }
        }
        var num = digits.toNumber();
        if (num != null) {
            return num;
        }
        return str.length();
    }

    function loadSyncedTracks() as Array {
        var tracks = [];
        var raw = Storage.getValue("synced_tracks_str");

        if (raw instanceof Array) {
            return raw as Array;
        }

        if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
            var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
            for (var i = 0; i < records.size(); i++) {
                var fields = ScaleHelper.splitString(records[i], TRACK_DELIM);
                if (fields.size() >= 8) {
                    var idStr = fields[0];
                    var trackServerId = fields[1];
                    var trackName = fields[2];
                    var trackAlbum = fields[3];
                    var trackArtist = fields[4];
                    var trackDuration = fields[5].toNumber();
                    var trackSize = fields[6].toNumber();
                    var trackPlaylistId = fields[7];

                    if (trackServerId.length() > 0 && trackName.length() > 0) {
                        var trackId = idStr;

                        tracks.add(
                            new JellyfinTrack(
                                trackId,
                                trackServerId,
                                trackName,
                                trackAlbum.length() > 0 ? trackAlbum : "Unknown Album",
                                trackArtist.length() > 0 ? trackArtist : "Unknown Artist",
                                trackDuration != null ? trackDuration : 0,
                                trackSize != null ? trackSize : 0,
                                trackPlaylistId
                            )
                        );
                    }
                }
            }
        }
        }

        return tracks;
    }

     function saveSyncTrackQueue(queue as Array) as Void {
        var parts = [];
        for (var i = 0; i < queue.size(); i++) {
            var t = queue[i];
            var id = "";
            var serverId = "";
            var name = "";
            var albumName = "";
            var artistName = "";
            var durationSeconds = "0";
            var downloadSize = "0";
            var playlistId = "";
            if (t instanceof Dictionary) {
                var dict = t as Dictionary;
                id = dict.get("id") != null ? dict.get("id").toString() : "";
                serverId = dict.get("serverId") != null ? dict.get("serverId") as String? : "";
                name = dict.get("name") != null ? dict.get("name") as String? : "";
                albumName = dict.get("albumName") != null ? dict.get("albumName") as String? : "";
                artistName = dict.get("artistName") != null ? dict.get("artistName") as String? : "";
                durationSeconds = dict.get("durationSeconds") != null ? dict.get("durationSeconds").toString() : "0";
                downloadSize = dict.get("downloadSize") != null ? dict.get("downloadSize").toString() : "0";
                playlistId = dict.get("playlistId") != null ? dict.get("playlistId") as String? : "";
            }

            parts.add(
                id + TRACK_DELIM + serverId + TRACK_DELIM + name +
                TRACK_DELIM + albumName + TRACK_DELIM + artistName +
                TRACK_DELIM + durationSeconds + TRACK_DELIM + downloadSize +
                TRACK_DELIM + playlistId
            );
        }

        var encoded = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) { encoded = encoded + RECORD_DELIM; }
            encoded = encoded + parts[i];
        }
        Storage.setValue("multi_session_queue", encoded);
    }

    function loadSyncTrackQueue() as Array? {
        var raw = Storage.getValue("multi_session_queue");
        if (raw == null) { return null; }

        if (raw instanceof Array) {
            return raw as Array;
        }

        var queue = [];
        if (raw instanceof String && raw.length() > 0) {
            var records = ScaleHelper.splitString(raw, RECORD_DELIM);
            for (var i = 0; i < records.size(); i++) {
                var fields = ScaleHelper.splitString(records[i], TRACK_DELIM);
                if (fields.size() >= 8) {
                    queue.add({
                        "id" => fields[0],
                        "serverId" => fields[1],
                        "name" => fields[2],
                        "albumName" => fields[3],
                        "artistName" => fields[4],
                        "durationSeconds" => fields[5].toNumber(),
                        "downloadSize" => fields[6].toNumber(),
                        "playlistId" => fields[7],
                    });
                }
            }
        }
        return queue;
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
                    "downloadSize" => t.downloadSize,
                    "playlistId" => t.playlistId,
                });
            }
        }
        saveSyncedTracks(newTracks);
    }

    private function obfuscate(str as String) as String {
        return str;
    }

    private function deobfuscate(str as String) as String {
        return str;
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

    function saveSyncLoading(loading as Boolean) as Void {
        Storage.setValue("sync_loading", loading);
    }

    function isSyncLoading() as Boolean {
        var val = Storage.getValue("sync_loading") as Boolean?;
        return val != null ? val : false;
    }
}
