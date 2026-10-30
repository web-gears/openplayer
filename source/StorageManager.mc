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
        var server = getServer();
        if (server.length() == 0) { return false; }
        var token = getAuthToken();
        if (token != null && token.length() > 0) { return true; }
        var username = getUsername();
        var password = getPassword();
        return username.length() > 0 && password.length() > 0;
    }

    function getDefaultPlaylistId() as String? {
        return Storage.getValue("default_playlist_id") as String?;
    }

    function setDefaultPlaylistId(id as String) as Void {
        Storage.setValue("default_playlist_id", id);
    }

    function getPreferredBitrate(durationSeconds as Number?) as Number {
        var bitrateSetting = 0;
        try {
            var pref = Application.Properties.getValue("audio_bitrate") as Number?;
            if (pref != null) {
                bitrateSetting = pref;
            }
        } catch (e) {
        }
        if (bitrateSetting == 128) {
            return 128000;
        } else if (bitrateSetting == 192) {
            return 192000;
        } else if (bitrateSetting == 256) {
            return 256000;
        } else if (bitrateSetting == 320) {
            return 320000;
        }
        // Auto mode (0 or unset): 128k for tracks > 20 mins, else 256k
        if (durationSeconds != null && durationSeconds > 1200) {
            return 128000;
        }
        return 256000;
    }

    function setServer(url as String?) as Void {
        if (url == null) {
            return;
        }
        var cleanUrl = url;
        var prefix = "";
        if (
            cleanUrl.length() > 7 &&
            cleanUrl.substring(0, 7).equals("http://")
        ) {
            prefix = "http://";
            cleanUrl = cleanUrl.substring(7, cleanUrl.length());
        } else if (
            cleanUrl.length() > 8 &&
            cleanUrl.substring(0, 8).equals("https://")
        ) {
            prefix = "https://";
            cleanUrl = cleanUrl.substring(8, cleanUrl.length());
        }
        while (cleanUrl.length() > 0 && cleanUrl.substring(cleanUrl.length() - 1, cleanUrl.length()).equals("/")) {
            cleanUrl = cleanUrl.substring(0, cleanUrl.length() - 1);
        }
        Storage.setValue("jellyfin_server", prefix + cleanUrl);
    }

    function getServer() as String {
        var propsUrl = Application.Properties.getValue("jellyfin_server") as String?;
        if (propsUrl != null && propsUrl.length() > 0) {
            return propsUrl;
        }
        var url = Storage.getValue("jellyfin_server") as String?;
        return url == null ? "" : url;
    }

    function setUsername(user as String?) as Void {
        if (user == null) { return; }
        Storage.setValue("jellyfin_username", user);
    }

    function getUsername() as String {
        var props = Application.Properties.getValue("jellyfin_username") as String?;
        if (props != null && props.length() > 0) {
            return props;
        }
        var stored = Storage.getValue("jellyfin_username") as String?;
        return stored != null ? stored : "";
    }

    function setPassword(pass as String?) as Void {
        if (pass == null) { return; }
        Storage.setValue("jellyfin_password", obfuscate(pass));
    }

    function getPassword() as String {
        var props = Application.Properties.getValue("jellyfin_password") as String?;
        if (props != null && props.length() > 0) {
            return props;
        }
        var stored = Storage.getValue("jellyfin_password") as String?;
        return stored != null ? deobfuscate(stored) : "";
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
                p.id + TRACK_DELIM + sanitizeField(p.name) + TRACK_DELIM + p.trackCount.toString()
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
                var item = data[i];
                if (item instanceof JellyfinPlaylist) {
                    result.add(item);
                } else if (item instanceof Dictionary) {
                    var dict = item as Dictionary;
                    var id = dict["Id"] != null ? dict["Id"] as String? : (dict["id"] != null ? dict["id"] as String? : null);
                    var name = dict["Name"] != null ? dict["Name"] as String? : (dict["name"] != null ? dict["name"] as String? : null);
                    var count = dict["trackCount"] as Number?;
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
        } else if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
                var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
                for (var i = 0; i < records.size(); i++) {
                    var rec = records[i];
                    if (rec == null || rec.length() == 0) { continue; }
                    var fields = ScaleHelper.splitString(rec, TRACK_DELIM);
                    if (fields.size() >= 2) {
                        var pId = fields[0];
                        var pCount = 0;
                        var pName = "";
                        if (fields.size() == 2) {
                            pName = fields[1];
                        } else if (fields.size() == 3) {
                            pName = fields[1];
                            var cnt = fields[2].toNumber();
                            pCount = cnt != null ? cnt : 0;
                        } else {
                            var cnt = fields[fields.size() - 1].toNumber();
                            pCount = cnt != null ? cnt : 0;
                            for (var f = 1; f < fields.size() - 1; f++) {
                                if (f > 1) { pName = pName + " "; }
                                pName = pName + fields[f];
                            }
                        }
                        if (pId != null && pId.length() > 0) {
                            result.add(new JellyfinPlaylist(pId, pName, pCount));
                        }
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
                    var ts = records[1].toNumber();
                    if (ts != null) { state.lastSyncTimestamp = ts; }
                    var sz = records[2].toNumber();
                    if (sz != null) { state.totalSizeBytes = sz; }
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

    function savePlaybackMode(mode as String) as Void {
        Storage.setValue("playback_mode", mode);
    }

    function getPlaybackMode() as String {
        var mode = Storage.getValue("playback_mode") as String?;
        return mode != null ? mode : "music";
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
        Storage.deleteValue("jellyfin_token");
        Storage.deleteValue("jellyfin_userId");
        Storage.deleteValue("sync_state");
        Storage.deleteValue("synced_tracks");
        Storage.deleteValue("synced_tracks_str");
    }

    function saveShuffle(on as Boolean) as Void {
        Storage.setValue("playback_shuffle", on);
    }

    function getShuffle() as Boolean {
        var val = Storage.getValue("playback_shuffle") as Boolean?;
        return val != null ? val : false;
    }

    function saveRepeatMode(mode as Number) as Void {
        Storage.setValue("playback_repeat_mode", mode);
    }

    function getRepeatMode() as Number? {
        return Storage.getValue("playback_repeat_mode") as Number?;
    }

    function clearDownloads() as Void {
        purgeAllCachedAudio();

        Storage.deleteValue("sync_state");
        Storage.deleteValue("synced_tracks_str");
        Storage.deleteValue("synced_tracks");
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
        var keepRefIds = {};
        var keepNames = {};
        for (var i = 0; i < keepTracks.size(); i++) {
            var t = keepTracks[i];
            var id = null;
            var name = "";
            if (t instanceof Dictionary) {
                var dict = t as Dictionary;
                var idv = dict["id"];
                if (idv != null) { id = idv.toString(); }
                name = dict["name"] as String?;
            } else if (t instanceof JellyfinTrack) {
                var jt = t as JellyfinTrack;
                if (jt.id != null) { id = jt.id.toString(); }
                name = jt.name;
            }
            if (id != null && id.length() > 0) {
                var storedRefId = Storage.getValue("tr_" + id) as String?;
                if (storedRefId != null && storedRefId.length() > 0) {
                    keepRefIds[storedRefId] = true;
                }
            }
            if (name != null && name.length() > 0) {
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
            var refId = contentRef.getId();
            var refIdStr = refId != null ? refId.toString() : null;
            if (refIdStr != null && keepRefIds[refIdStr] != null) {
                continue;
            }
            var content = Media.getCachedContentObj(contentRef) as Media.Content?;
            if (content != null) {
                var meta = content.getMetadata();
                if (meta.title != null && keepNames[meta.title] != null) {
                    continue;
                }
            }
            Media.deleteCachedItem(contentRef);
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
        if (stats has :freeStorage && stats.freeStorage != null) {
            return (stats.freeStorage as Number);
        }
        return 100 * 1024 * 1024;
    }

    private function sanitizeField(str as String?) as String {
        if (str == null) { return ""; }
        if (str.find("|") == null && str.find("\n") == null && str.find("\r") == null) {
            return str;
        }
        var res = "";
        for (var i = 0; i < str.length(); i++) {
            var ch = str.substring(i, i + 1);
            if (ch.equals("|") || ch.equals("\n") || ch.equals("\r")) {
                res = res + " ";
            } else {
                res = res + ch;
            }
        }
        return res;
    }

    function saveSyncedTracks(tracks as Array) as Void {
        var parts = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i];
            if (t != null) {
                parts.add(encodeTrack(t));
            }
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
            var arr = raw as Array;
            for (var i = 0; i < arr.size(); i++) {
                var item = arr[i];
                if (item instanceof JellyfinTrack) {
                    tracks.add(item);
                } else if (item instanceof Dictionary) {
                    var dict = item as Dictionary;
                    tracks.add(new JellyfinTrack(
                        dict["id"],
                        dict["serverId"] != null ? dict["serverId"].toString() : "",
                        dict["name"] != null ? dict["name"].toString() : "",
                        dict["albumName"] != null ? dict["albumName"].toString() : "Unknown Album",
                        dict["artistName"] != null ? dict["artistName"].toString() : "Unknown Artist",
                        dict["durationSeconds"] != null ? (dict["durationSeconds"] as Number) : 0,
                        dict["downloadSize"] != null ? (dict["downloadSize"] as Number) : 0,
                        dict["playlistId"] != null ? dict["playlistId"].toString() : ""
                    ));
                }
            }
            return tracks;
        }

        if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
                var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
                for (var i = 0; i < records.size(); i++) {
                    var rec = records[i];
                    if (rec == null || rec.length() == 0) { continue; }
                    var fields = ScaleHelper.splitString(rec, TRACK_DELIM);
                    if (fields.size() >= 6) {
                        var idStr = fields[0];
                        var trackServerId = fields[1];
                        var trackName = fields[2];
                        var trackAlbum = "Unknown Album";
                        var trackArtist = "Unknown Artist";
                        var trackDuration = 0;
                        var trackSize = 0;
                        var trackPlaylistId = "";

                        if (fields.size() == 8) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[6].toNumber();
                            trackSize = sz != null ? sz : 0;
                            trackPlaylistId = fields[7];
                        } else if (fields.size() > 8) {
                            var dur = fields[fields.size() - 3].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[fields.size() - 2].toNumber();
                            trackSize = sz != null ? sz : 0;
                            trackPlaylistId = fields[fields.size() - 1];
                            trackAlbum = fields[fields.size() - 5];
                            trackArtist = fields[fields.size() - 4];
                            trackName = "";
                            for (var f = 2; f <= fields.size() - 6; f++) {
                                if (f > 2) { trackName = trackName + " "; }
                                trackName = trackName + fields[f];
                            }
                        } else if (fields.size() == 7) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[6].toNumber();
                            trackSize = sz != null ? sz : 0;
                        } else if (fields.size() == 6) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                        }

                        if (trackPlaylistId == null) {
                            trackPlaylistId = "";
                        }

                        if (trackServerId != null && trackServerId.length() > 0 &&
                            trackName != null && trackName.length() > 0) {
                            tracks.add(
                                new JellyfinTrack(
                                    idStr != null ? idStr : trackServerId,
                                    trackServerId,
                                    trackName,
                                    (trackAlbum != null && trackAlbum.length() > 0) ? trackAlbum : "Unknown Album",
                                    (trackArtist != null && trackArtist.length() > 0) ? trackArtist : "Unknown Artist",
                                    trackDuration,
                                    trackSize,
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
                id = dict["id"] != null ? dict["id"].toString() : "";
                serverId = dict["serverId"] != null ? dict["serverId"] as String? : "";
                name = dict["name"] != null ? dict["name"] as String? : "";
                albumName = dict["albumName"] != null ? dict["albumName"] as String? : "";
                artistName = dict["artistName"] != null ? dict["artistName"] as String? : "";
                durationSeconds = dict["durationSeconds"] != null ? dict["durationSeconds"].toString() : "0";
                downloadSize = dict["downloadSize"] != null ? dict["downloadSize"].toString() : "0";
                playlistId = dict["playlistId"] != null ? dict["playlistId"] as String? : "";
            }

            parts.add(
                id + TRACK_DELIM + serverId + TRACK_DELIM + sanitizeField(name) +
                TRACK_DELIM + sanitizeField(albumName) + TRACK_DELIM + sanitizeField(artistName) +
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
                    var qName = fields[2];
                    var qAlbum = fields[3];
                    var qArtist = fields[4];
                    var qDuration = fields[fields.size() - 3].toNumber();
                    var qSize = fields[fields.size() - 2].toNumber();
                    var qPlaylistId = fields[fields.size() - 1];

                    if (fields.size() > 8) {
                        qName = "";
                        for (var f = 2; f <= fields.size() - 6; f++) {
                            if (f > 2) { qName = qName + " "; }
                            qName = qName + fields[f];
                        }
                        qAlbum = fields[fields.size() - 5];
                        qArtist = fields[fields.size() - 4];
                    }

                    queue.add({
                        "id" => fields[0],
                        "serverId" => fields[1],
                        "name" => qName,
                        "albumName" => qAlbum,
                        "artistName" => qArtist,
                        "durationSeconds" => qDuration,
                        "downloadSize" => qSize,
                        "playlistId" => qPlaylistId,
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

    function reconcileSyncedTracks(pendingTracks as Array, selectedPlaylistIds as Array) as Void {
        if (pendingTracks.size() == 0) {
            return;
        }

        var syncedTracks = loadSyncedTracks();
        var selected = {};
        for (var i = 0; i < selectedPlaylistIds.size(); i++) {
            var pid = selectedPlaylistIds[i];
            if (pid != null) {
                selected[pid.toString()] = true;
            }
        }

        var pendingById = {};
        for (var i = 0; i < pendingTracks.size(); i++) {
            var pt = pendingTracks[i] as Dictionary?;
            if (pt == null) { continue; }
            var tid = pt["id"] != null ? pt["id"].toString() : "";
            if (tid.length() > 0) {
                pendingById[tid] = pt;
            }
            var sid = pt["serverId"] != null ? pt["serverId"].toString() : "";
            if (sid.length() > 0) {
                pendingById[sid] = pt;
            }
        }

        var keep = [];
        for (var i = 0; i < syncedTracks.size(); i++) {
            var item = syncedTracks[i];
            if (item == null) { continue; }
            var t = item instanceof JellyfinTrack ? item as JellyfinTrack : null;
            if (t == null) {
                if (item instanceof Dictionary) {
                    var dict = item as Dictionary;
                    t = new JellyfinTrack(
                        dict["id"],
                        dict["serverId"] != null ? dict["serverId"].toString() : "",
                        dict["name"] != null ? dict["name"].toString() : "",
                        dict["albumName"] != null ? dict["albumName"].toString() : "Unknown Album",
                        dict["artistName"] != null ? dict["artistName"].toString() : "Unknown Artist",
                        dict["durationSeconds"] != null ? (dict["durationSeconds"] as Number) : 0,
                        dict["downloadSize"] != null ? (dict["downloadSize"] as Number) : 0,
                        dict["playlistId"] != null ? dict["playlistId"].toString() : ""
                    );
                } else {
                    continue;
                }
            }

            var tid = t.id != null ? t.id.toString() : "";
            var sid = t.serverId != null ? t.serverId.toString() : "";
            var pt = (tid.length() > 0 ? pendingById[tid] : null) as Dictionary?;
            if (pt == null && sid.length() > 0) {
                pt = pendingById[sid] as Dictionary?;
            }

            if (pt != null) {
                // Canonical update from fresh Jellyfin pending tracks:
                var pid = pt["playlistId"] as String?;
                if (pid != null && pid.length() > 0) {
                    t.playlistId = pid;
                }
                var name = pt["name"] as String?;
                if (name != null && name.length() > 0) {
                    t.name = sanitizeField(name);
                }
                var album = pt["albumName"] as String?;
                if (album != null) {
                    t.albumName = sanitizeField(album);
                }
                var artist = pt["artistName"] as String?;
                if (artist != null) {
                    t.artistName = sanitizeField(artist);
                }
                var dur = pt["durationSeconds"] as Number?;
                if (dur != null && dur > 0) {
                    t.durationSeconds = dur;
                }
                var sz = pt["downloadSize"] as Number?;
                if (sz != null && sz > 0) {
                    t.downloadSize = sz;
                }
                keep.add(t);
            } else {
                // Track was not in the pending batch from Jellyfin
                var keepTrack = true;
                if (t.playlistId != null && selected[t.playlistId] != null) {
                    // It belonged to a playlist that was selected for this sync,
                    // but is no longer present in that playlist on Jellyfin -> remove it
                    keepTrack = false;
                }
                // If it belonged to a playlist that was NOT selected in this sync, keepTrack remains true!
                // Its playlistId remains unchanged!
                if (keepTrack) {
                    keep.add(t);
                } else {
                    if (tid.length() > 0) {
                        Storage.deleteValue("tr_" + tid);
                    }
                    if (sid.length() > 0 && !sid.equals(tid)) {
                        Storage.deleteValue("tr_" + sid);
                    }
                }
            }
        }

        saveSyncedTracks(keep);
    }

    private function obfuscate(str as String) as String {
        var result = "";
        for (var i = 0; i < str.length(); i++) {
            result = result + str.substring(str.length() - 1 - i, str.length() - i);
        }
        return result;
    }

    private function deobfuscate(str as String) as String {
        return obfuscate(str);
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

    function savePendingSyncTracks(tracks as Array) as Void {
        var parts = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i];
            if (t != null) {
                parts.add(encodeTrack(t));
            }
        }
        var encoded = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) { encoded = encoded + RECORD_DELIM; }
            encoded = encoded + parts[i];
        }
        Storage.setValue("pending_sync_tracks_str", encoded);
    }

    function loadPendingSyncTracks() as Array {
        var tracks = [];
        var raw = Storage.getValue("pending_sync_tracks_str");
        if (raw instanceof Array) {
            return raw as Array;
        }
        if (raw instanceof String) {
            var encoded = raw as String;
            if (encoded.length() > 0) {
                var records = ScaleHelper.splitString(encoded, RECORD_DELIM);
                for (var i = 0; i < records.size(); i++) {
                    var rec = records[i];
                    if (rec == null || rec.length() == 0) { continue; }
                    var fields = ScaleHelper.splitString(rec, TRACK_DELIM);
                    if (fields.size() >= 6) {
                        var idStr = fields[0];
                        var trackServerId = fields[1];
                        var trackName = fields[2];
                        var trackAlbum = "Unknown Album";
                        var trackArtist = "Unknown Artist";
                        var trackDuration = 0;
                        var trackSize = 0;
                        var trackPlaylistId = "";

                        if (fields.size() == 8) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[6].toNumber();
                            trackSize = sz != null ? sz : 0;
                            trackPlaylistId = fields[7];
                        } else if (fields.size() > 8) {
                            var dur = fields[fields.size() - 3].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[fields.size() - 2].toNumber();
                            trackSize = sz != null ? sz : 0;
                            trackPlaylistId = fields[fields.size() - 1];
                            trackAlbum = fields[fields.size() - 5];
                            trackArtist = fields[fields.size() - 4];
                            trackName = "";
                            for (var f = 2; f <= fields.size() - 6; f++) {
                                if (f > 2) { trackName = trackName + " "; }
                                trackName = trackName + fields[f];
                            }
                        } else if (fields.size() == 7) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                            var sz = fields[6].toNumber();
                            trackSize = sz != null ? sz : 0;
                        } else if (fields.size() == 6) {
                            trackAlbum = fields[3];
                            trackArtist = fields[4];
                            var dur = fields[5].toNumber();
                            trackDuration = dur != null ? dur : 0;
                        }

                        if (trackPlaylistId == null) {
                            trackPlaylistId = "";
                        }

                        if (trackServerId != null && trackServerId.length() > 0 &&
                            trackName != null && trackName.length() > 0) {
                            tracks.add({
                                "id" => idStr != null ? idStr : trackServerId,
                                "serverId" => trackServerId,
                                "name" => trackName,
                                "albumName" => (trackAlbum != null && trackAlbum.length() > 0) ? trackAlbum : "Unknown Album",
                                "artistName" => (trackArtist != null && trackArtist.length() > 0) ? trackArtist : "Unknown Artist",
                                "durationSeconds" => trackDuration,
                                "downloadSize" => trackSize,
                                "playlistId" => trackPlaylistId
                            });
                        }
                    }
                }
            }
        }
        return tracks;
    }

    function clearPendingSyncTracks() as Void {
        Storage.deleteValue("pending_sync_tracks_str");
    }

    function initPendingSyncTracks() as Void {
        Storage.setValue("pending_sync_tracks_str", "");
    }

    function appendPendingSyncTracks(tracks as Array) as Void {
        var pageEncoded = "";
        for (var i = 0; i < tracks.size(); i++) {
            if (i > 0) { pageEncoded = pageEncoded + RECORD_DELIM; }
            pageEncoded = pageEncoded + encodeTrack(tracks[i]);
        }
        if (pageEncoded.length() == 0) { return; }

        var existing = Storage.getValue("pending_sync_tracks_str");
        var combined = "";
        if (existing != null && existing.length() > 0) {
            combined = existing + RECORD_DELIM + pageEncoded;
        } else {
            combined = pageEncoded;
        }
        Storage.setValue("pending_sync_tracks_str", combined);
    }

    private function encodeTrack(t) as String {
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
            var idVal = dict["id"];
            id = idVal != null ? idVal.toString() : "";
            var sVal = dict["serverId"];
            serverId = sVal != null ? sVal.toString() : "";
            var nVal = dict["name"];
            name = nVal != null ? nVal.toString() : "";
            var alVal = dict["albumName"];
            albumName = alVal != null ? alVal.toString() : "";
            var arVal = dict["artistName"];
            artistName = arVal != null ? arVal.toString() : "";
            var durVal = dict["durationSeconds"];
            if (durVal instanceof Number) {
                durationSeconds = durVal as Number;
            } else if (durVal != null) {
                var parsedDur = durVal.toString().toNumber();
                durationSeconds = parsedDur != null ? parsedDur : 0;
            }
            var szVal = dict["downloadSize"];
            if (szVal instanceof Number) {
                downloadSize = szVal as Number;
            } else if (szVal != null) {
                var parsedSz = szVal.toString().toNumber();
                downloadSize = parsedSz != null ? parsedSz : 0;
            }
            var pVal = dict["playlistId"];
            playlistId = pVal != null ? pVal.toString() : "";
        } else if (t instanceof JellyfinTrack) {
            var jt = t as JellyfinTrack;
            id = jt.id != null ? jt.id.toString() : "";
            serverId = jt.serverId != null ? jt.serverId : "";
            name = jt.name != null ? jt.name : "";
            albumName = jt.albumName != null ? jt.albumName : "";
            artistName = jt.artistName != null ? jt.artistName : "";
            durationSeconds = jt.durationSeconds != null ? jt.durationSeconds : 0;
            downloadSize = jt.downloadSize != null ? jt.downloadSize : 0;
            playlistId = jt.playlistId != null ? jt.playlistId : "";
        }

        return id +
            TRACK_DELIM + serverId +
            TRACK_DELIM + sanitizeField(name) +
            TRACK_DELIM + sanitizeField(albumName) +
            TRACK_DELIM + sanitizeField(artistName) +
            TRACK_DELIM + durationSeconds.toString() +
            TRACK_DELIM + downloadSize.toString() +
            TRACK_DELIM + playlistId;
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

    function saveSyncProgressDict(dict as Dictionary) as Void {
        Storage.setValue("sync_progress", dict);
    }

    function loadSyncProgressDict() as Dictionary? {
        return Storage.getValue("sync_progress") as Dictionary?;
    }

    function clearSyncProgress() as Void {
        Storage.deleteValue("sync_progress");
    }

    function saveCancelRequested(val as Boolean) as Void {
        Storage.setValue("sync_cancel", val);
    }

    function isCancelRequested() as Boolean {
        var val = Storage.getValue("sync_cancel") as Boolean?;
        return val != null ? val : false;
    }

    function clearCancelRequested() as Void {
        Storage.deleteValue("sync_cancel");
    }
}
