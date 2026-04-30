import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.PersistedContent;

const AUTH_METHOD_ONRESPONSE = 0;
const PLAYLISTS_METHOD_ONRESPONSE = 1;
const TRACKS_METHOD_ONRESPONSE = 2;

class JellyfinClient {
    private var _storage as StorageManager;
    private var _pendingMethod as Number = 0;
    private var _pendingPlaylistId as String = "";
    private var _pendingPlaylistIndex as Number = 0;
    private var _callback as
    (Method
        (responseCode as Number, data as Dictionary?) as Void
    )?;
    private var _tracksCallback as
    (Method
        (
            responseCode as Number,
            tracks as Array,
            playlistIndex as Number
        ) as Void
    )?;

    function initialize(storage as StorageManager) {
        _storage = storage;
    }

    function authenticate(
        callback as
            (Method(responseCode as Number, data as Dictionary?) as Void)
    ) as Void {
        _callback = callback;
        _pendingMethod = AUTH_METHOD_ONRESPONSE;

        var server = _storage.getServer();
        var apiKey = _storage.getApiKey();

        if (server == null || apiKey == null) {
            _callback.invoke(401, null);
            return;
        }

        _storage.setApiKeyDirect(apiKey);

        var url = buildUrl(server as String, "/System/Info");
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "X-Emby-Token" => apiKey,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onAuthResponse)
        );
    }

    function authenticateWithPlaylist(
        playlistId as String,
        callback as
            (Method(responseCode as Number, data as Dictionary?) as Void)
    ) as Void {
        _callback = callback;
        _pendingMethod = AUTH_METHOD_ONRESPONSE;
        _pendingPlaylistId = playlistId;

        var server = _storage.getServer();
        var apiKey = _storage.getApiKey();

        if (server == null || apiKey == null) {
            _callback.invoke(401, null);
            return;
        }

        _storage.setApiKeyDirect(apiKey);
        _callback.invoke(200, null);
    }

    function authenticateWithPlaylistList(
        playlistIds as Array,
        callback as
            (Method(responseCode as Number, data as Dictionary?) as Void)
    ) as Void {
        _callback = callback;
        _pendingMethod = AUTH_METHOD_ONRESPONSE;

        var server = _storage.getServer();
        var apiKey = _storage.getApiKey();

        if (server == null || apiKey == null) {
            _callback.invoke(401, null);
            return;
        }

        _storage.setApiKeyDirect(apiKey);
        _callback.invoke(200, null);
    }

    function onAuthResponseWithPlaylist(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (responseCode == 200 && data != null) {
            var sessionInfo = data["SessionInfo"] as Dictionary?;
            var userInfo = data["User"] as Dictionary?;

            if (sessionInfo != null && userInfo != null) {
                var token = sessionInfo["AccessToken"] as String?;
                var userId = userInfo["Id"] as String?;

                if (token != null && userId != null) {
                    _storage.setAuthToken(token);
                    _storage.setUserId(userId);
                    _callback.invoke(200, data);
                    return;
                }
            }
            _callback.invoke(500, null);
        } else {
            _callback.invoke(responseCode, null);
        }
    }

    function onAuthResponse(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (responseCode == 200 && data != null) {
            var userId = data["Id"] as String?;
            if (userId != null) {
                _storage.setUserId(userId);
                _callback.invoke(200, data);
                return;
            }
        }
        _callback.invoke(responseCode, null);
    }

    function getPlaylists(
        callback as
            (Method(responseCode as Number, data as Dictionary?) as Void)
    ) as Void {
        _callback = callback;
        _pendingMethod = PLAYLISTS_METHOD_ONRESPONSE;

        var server = _storage.getServer();
        var apiKey = _storage.getApiKeyDirect();

        if (server == null || apiKey == null) {
            _callback.invoke(401, null);
            return;
        }

        var url = buildUrl(server, "/Items");
        var params = {
            "IncludeItemTypes" => "Playlist",
            "Recursive" => "true",
            "Fields" => "ChildCount",
        };

        Communications.makeWebRequest(
            url,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "X-Emby-Token" => apiKey,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onPlaylistsResponse)
        );
    }

    function onPlaylistsResponse(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (_pendingMethod != PLAYLISTS_METHOD_ONRESPONSE) {
            return;
        }

        if (responseCode == 200 && data != null) {
            _callback.invoke(200, data);
        } else {
            _callback.invoke(responseCode, null);
        }
    }

    private static const PAGE_SIZE = 5;

    function getPlaylistTracks(
        playlistId as String,
        startIndex as Number,
        callback as
            (Method
                (
                    responseCode as Number,
                    tracks as Array,
                    playlistIndex as Number
                ) as Void)
    ) as Void {
        _tracksCallback = callback;
        _pendingMethod = TRACKS_METHOD_ONRESPONSE;
        _pendingPlaylistId = playlistId;
        _pendingPlaylistIndex = startIndex;

        var server = _storage.getServer();
        var apiKey = _storage.getApiKeyDirect();

        if (server == null || apiKey == null) {
            _tracksCallback.invoke(401, [], _pendingPlaylistIndex);
            return;
        }

        var url = buildUrl(server, "/Items");
        var params = {
            "ParentId" => playlistId,
            "IncludeItemTypes" => "Audio",
            "Recursive" => "true",
            "Fields" => "Name",
            "StartIndex" => startIndex,
            "Limit" => PAGE_SIZE,
        };

        Communications.makeWebRequest(
            url,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "X-Emby-Token" => apiKey,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onTracksResponse)
        );
    }

    function onTracksResponse(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (_pendingMethod != TRACKS_METHOD_ONRESPONSE) {
            return;
        }

        if (responseCode == 200 && data != null) {
            var items = data["Items"] as Array?;
            if (items == null) {
                _callback.invoke(200, null);
                return;
            }
            var tracks = [];
            for (var i = 0; i < items.size(); i++) {
                var item = items[i] as Dictionary;
                var id = item["Id"] as String?;
                var name = item["Name"] as String?;
                var album = item["Album"] as String?;
                var artists = item["Artists"] as Array?;
                var runTimeTicks = item["RunTimeTicks"] as Number?;
                var mediaSources = item["MediaSources"] as Array?;

                if (id != null && name != null) {
                    var artistName = "Unknown Artist";
                    if (artists != null && artists.size() > 0) {
                        artistName = artists[0] as String;
                    }

                    var albumName = album != null ? album : "Unknown Album";
                    var durationSeconds =
                        runTimeTicks != null ? runTimeTicks / 10000000 : 0;
                    var downloadSize = 0l;

                    if (mediaSources != null && mediaSources.size() > 0) {
                        var source = mediaSources[0] as Dictionary;
                        var size = source["Size"] as Number?;
                        if (size != null) {
                            downloadSize = size;
                        }
                    }

                    tracks.add(
                        new JellyfinTrack(
                            id,
                            id,
                            name,
                            albumName,
                            artistName,
                            durationSeconds,
                            downloadSize,
                            _pendingPlaylistId
                        )
                    );
                }
            }

            _tracksCallback.invoke(200, tracks, _pendingPlaylistIndex);
        } else {
            _tracksCallback.invoke(responseCode, [], _pendingPlaylistIndex);
        }
    }

    function getDownloadUrl(itemId as Object) as String? {
        var server = _storage.getServer();

        if (server == "") {
            return null;
        }

        return (
            buildUrl(server, "/Items/" + itemId + "/Download") + "&static=true"
        );
    }

    function downloadAndSaveTrack(
        itemId as Object,
        callback as
            (Method
                (
                    responseCode as Number,
                    data as
                        Null or
                            Dictionary or
                            String or
                            PersistedContent.Iterator
                ) as Void
            )
    ) as Void {
        var server = _storage.getServer();
        var apiKey = _storage.getApiKeyDirect();

        if (server == null || apiKey == null) {
            callback.invoke(401, null);
            return;
        }

        var url =
            buildUrl(server, "/Items/" + itemId + "/Download") + "?static=true";
        

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "X-Emby-Token" => apiKey,
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
            :mediaEncoding => Media.ENCODING_MP3,
        };

        Communications.makeWebRequest(url, {}, options, callback);
    }

    function cancelPendingRequests() as Void {
        Communications.cancelAllRequests();
    }

    function getLastPlaylistIndex() as Number {
        return _pendingPlaylistIndex;
    }

    function formatDuration(seconds as Number) as String {
        var minutes = seconds / 60;
        var secs = seconds % 60;
        return minutes + ":" + (secs < 10 ? "0" + secs : secs.toString());
    }

    function formatSize(bytes as Number) as String {
        if (bytes < 1024) {
            return bytes + " B";
        } else if (bytes < 1024 * 1024) {
            return bytes / 1024 + " KB";
        } else if (bytes < 1024 * 1024 * 1024) {
            return bytes / (1024 * 1024) + " MB";
        } else {
            return (
                (bytes / ((1024 * 1024 * 1024) as Float)).format("%.1f") + " GB"
            );
        }
    }

    private function buildUrl(server as String, path as String) as String {
        if (server.length() >= 8 && server.substring(0, 8).equals("https://")) {
            return server + path;
        } else if (
            server.length() >= 7 &&
            server.substring(0, 7).equals("http://")
        ) {
            return server + path;
        }
        return "https://" + server + path;
    }
}
