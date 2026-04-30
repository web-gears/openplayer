import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class OpenPlayerConfigureSyncView extends WatchUi.View {
    private var _statusText as String = "";
    private var _isLoading as Boolean = false;
    private var _playlists as Array;
    private var _selectedIndices as Array;
    private var _currentPlaylistIndex as Number = 0;
    private var _errorMessage as String = "";
    private var _initialized as Boolean = false;

    function initialize() {
        View.initialize();
        _playlists = [];
        _selectedIndices = [];
        _initialized = false;
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        _initialized = false;
        _loadPlaylists();
    }

    function _loadPlaylists() as Void {
        if (_initialized) {
            return;
        }
        var storage = new StorageManager();
        var rc = storage.getPendingPlaylistResponseCode();

if (rc == 200) {
            var ids = storage.getPendingPlaylistIds();
            var names = storage.getPendingPlaylistNames();
            var syncTracks = storage.loadSyncedTracks();
            if (ids != null && names != null) {
                var idArray = splitString(ids, ",");
                var nameArray = splitString(names, "|");
                var newPlaylists = [];
                var minLen = idArray.size();
                if (nameArray.size() < minLen) {
                    minLen = nameArray.size();
                }
                for (var i = 0; i < minLen; i++) {
                    var playlistId = idArray[i] as String;
                    var trackCount = 0;
                    for (var j = 0; j < syncTracks.size(); j++) {
                        var t = syncTracks[j] as JellyfinTrack;
                        if (t.playlistId != null && t.playlistId.equals(playlistId)) {
                            trackCount++;
                        }
                    }
                    var playlist = new JellyfinPlaylist(
                        playlistId,
                        nameArray[i] as String,
                        trackCount
                    );
                    newPlaylists.add(playlist);
                }
                _playlists = newPlaylists;
                _currentPlaylistIndex = 0;
                _errorMessage = "";
                _initialized = true;
            }
        } else if (rc == 401) {
            _errorMessage = "Invalid API key";
        } else if (rc != -1 && rc != 0) {
            _errorMessage = "Failed to load playlists";
        }
    }

    function splitString(text as String, delimiter as String) as Array {
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

    function onUpdate(dc as Dc) as Void {
        _loadPlaylists();

        var storage = new StorageManager();
        _currentPlaylistIndex = storage.getCurrentPlaylistIndex();
        var syncState = storage.loadSyncState();
        _selectedIndices = [];
        for (var i = 0; i < syncState.selectedPlaylistIds.size(); i++) {
            addToSelection(syncState.selectedPlaylistIds[i] as String);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var title = "Sync Playlists";
        dc.drawText(
            dc.getWidth() / 2,
            8,
            Graphics.FONT_TINY,
            title,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_isLoading) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2,
                Graphics.FONT_MEDIUM,
                _statusText,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        if (_playlists.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 - 20,
                Graphics.FONT_TINY,
                _errorMessage.length() > 0
                    ? _errorMessage
                    : "No playlists found",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + 10,
                Graphics.FONT_TINY,
                "LAP: Close",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        var visibleCount = 4;
        var startIdx = _currentPlaylistIndex;
        if (startIdx > _playlists.size() - visibleCount) {
            startIdx = _playlists.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var y = 55;
        for (
            var i = 0;
            i < visibleCount && startIdx + i < _playlists.size();
            i++
        ) {
            var idx = startIdx + i;
            var playlist = _playlists[idx] as JellyfinPlaylist;
            var isSelected = isPlaylistSelected(playlist.id);

            if (idx == _currentPlaylistIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRectangle(5, y, dc.getWidth() - 10, 25);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }

            var checkMark = isSelected ? "[X]" : "[ ]";
            dc.drawText(
                10,
                y,
                Graphics.FONT_TINY,
                checkMark,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                35,
                y,
                Graphics.FONT_TINY,
                playlist.name,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                dc.getWidth() - 10,
                y,
                Graphics.FONT_TINY,
                "[" + playlist.trackCount + "]",
                Graphics.TEXT_JUSTIFY_RIGHT
            );

            y = y + 25;
        }

        if (startIdx > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, 35, Graphics.FONT_XTINY, "^ more above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < _playlists.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 85, Graphics.FONT_XTINY, "v more below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - 65,
            Graphics.FONT_XTINY,
            "MENU: select | ENTER: sync",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - 45,
            Graphics.FONT_XTINY,
            "UP/DOWN: scroll\nLAP: play",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {}

    function isPlaylistSelected(id as String) as Boolean {
        for (var i = 0; i < _selectedIndices.size(); i++) {
            var idx = _selectedIndices[i] as Number;
            if (idx >= 0 && idx < _playlists.size()) {
                var playlist = _playlists[idx] as JellyfinPlaylist;
                if (playlist != null && playlist.id.equals(id)) {
                    return true;
                }
            }
        }
        return false;
    }

    function addToSelection(id as String) as Void {
        for (var i = 0; i < _playlists.size(); i++) {
            var playlist = _playlists[i] as JellyfinPlaylist;
            if (playlist != null && playlist.id.equals(id)) {
                _selectedIndices.add(i);
                return;
            }
        }
    }

    function setError(msg as String) as Void {
        _errorMessage = msg;
    }

    function clearAllSelections() as Void {
        _selectedIndices = [];
    }
}
