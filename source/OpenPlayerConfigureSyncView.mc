import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import ScaleHelper;

class OpenPlayerConfigureSyncView extends WatchUi.View {
    private var _statusText as String = "";
    private var _isLoading as Boolean = false;
    private var _playlists as Array;
    private var _selectedIndices as Array;
    private var _currentPlaylistIndex as Number = 0;
    private var _errorMessage as String = "";
    private var _initialized as Boolean = false;
    private var _delegate as OpenPlayerConfigureSyncDelegate? = null;

    function initialize() {
        View.initialize();
        _playlists = [];
        _selectedIndices = [];
        _initialized = false;
    }

    function setDelegate(delegate as OpenPlayerConfigureSyncDelegate) as Void {
        _delegate = delegate;
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        _initialized = false;
        var storage = new StorageManager();
        System.println("VIEW: onShow pendingRc=" + storage.getPendingPlaylistResponseCode());
        if (storage.getPendingPlaylistResponseCode() != 200) {
            _isLoading = true;
        }
        if (WatchUi.View has :setActionMenuIndicator) {
            setActionMenuIndicator({:enabled => true});
        }
        if (_delegate != null) {
            _delegate.onShow();
        }
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
                var idArray = ScaleHelper.splitString(ids, ",");
                var nameArray = ScaleHelper.splitString(names, "|");
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
        } else if (rc == 0) {
            _errorMessage = "Network error";
        } else if (rc != -1) {
            _errorMessage = "Failed to load playlists (" + rc + ")";
        }
    }

    function onUpdate(dc as Dc) as Void {
        var storage = new StorageManager();
        _isLoading = storage.isSyncLoading();
        if (_isLoading) {
            _statusText = "Loading...";
        }

        _loadPlaylists();

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
            ScaleHelper.scale(dc, 8),
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
                dc.getHeight() / 2 - ScaleHelper.scale(dc, 20),
                Graphics.FONT_TINY,
                _errorMessage.length() > 0
                    ? _errorMessage
                    : "No playlists found",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var hint = _errorMessage.length() > 0 ? "Retry | ESC: Back" : "Retry";
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + ScaleHelper.scale(dc, 10),
                Graphics.FONT_XTINY,
                hint,
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

        var rowH = ScaleHelper.scale(dc, 25);
        var y = ScaleHelper.scale(dc, 55);
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
                dc.fillRectangle(ScaleHelper.scale(dc, 5), y, dc.getWidth() - ScaleHelper.scale(dc, 10), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }

            var checkMark = isSelected ? "[X]" : "[ ]";
            dc.drawText(
                ScaleHelper.scale(dc, 10),
                y,
                Graphics.FONT_TINY,
                checkMark,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                ScaleHelper.scale(dc, 35),
                y,
                Graphics.FONT_TINY,
                playlist.name,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                dc.getWidth() - ScaleHelper.scale(dc, 10),
                y,
                Graphics.FONT_TINY,
                "[" + playlist.trackCount + "]",
                Graphics.TEXT_JUSTIFY_RIGHT
            );

            y = y + rowH;
        }

        if (startIdx > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.scale(dc, 35), Graphics.FONT_XTINY, "^ more above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < _playlists.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - ScaleHelper.scale(dc, 85), Graphics.FONT_XTINY, "v more below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - ScaleHelper.scale(dc, 65),
            Graphics.FONT_XTINY,
            "Select | ENTER: sync",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - ScaleHelper.scale(dc, 45),
            Graphics.FONT_XTINY,
            "Play",
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
