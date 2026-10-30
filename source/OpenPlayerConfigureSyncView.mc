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
    private var _errorCode as Number = -1;

    private var _cachedLabelSyncPlaylists as String?;
    private var _cachedNoPlaylistsMessage as String?;
    private var _cachedHintRetryBack as String?;
    private var _cachedLabelMoreAbove as String?;
    private var _cachedLabelMoreBelow as String?;
    private var _cachedHintSelectEnterSync as String?;
    private var _cachedHintBackPlay as String?;

    function initialize() {
        View.initialize();
        _playlists = [];
        _selectedIndices = [];
        _initialized = false;
        _cachedLabelSyncPlaylists = WatchUi.loadResource($.Rez.Strings.labelSyncPlaylists) as String;
        _cachedNoPlaylistsMessage = WatchUi.loadResource($.Rez.Strings.noPlaylistsMessage) as String;
        _cachedHintRetryBack = WatchUi.loadResource($.Rez.Strings.hintRetryBack) as String;
        _cachedLabelMoreAbove = WatchUi.loadResource($.Rez.Strings.labelMoreAbove) as String;
        _cachedLabelMoreBelow = WatchUi.loadResource($.Rez.Strings.labelMoreBelow) as String;
        _cachedHintSelectEnterSync = WatchUi.loadResource($.Rez.Strings.hintSelectEnterSync) as String;
        _cachedHintBackPlay = WatchUi.loadResource($.Rez.Strings.hintBackPlay) as String;
    }

    function setDelegate(delegate as OpenPlayerConfigureSyncDelegate) as Void {
        _delegate = delegate;
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        _initialized = false;
        var storage = new StorageManager();
        System.println("VIEW: onShow pendingRc=" + storage.getPendingPlaylistResponseCode());
        var hasCached = storage.getPendingPlaylistResponseCode() == 200;
        if (!hasCached) {
            _isLoading = true;
        }
        if (WatchUi.View has :setActionMenuIndicator) {
            setActionMenuIndicator({:enabled => true});
        }
        if (_delegate != null) {
            if (hasCached) {
                _delegate.onShowWithCached();
            } else {
                _delegate.onShow();
            }
        }
        _loadPlaylists();
        _refreshSyncSelections(storage);
    }

    private function _refreshSyncSelections(storage as StorageManager) as Void {
        var syncState = storage.loadSyncState();
        _selectedIndices = [];
        for (var i = 0; i < syncState.selectedPlaylistIds.size(); i++) {
            addToSelection(syncState.selectedPlaylistIds[i] as String);
        }
    }

    function refreshSelections() as Void {
        var storage = new StorageManager();
        _refreshSyncSelections(storage);
        WatchUi.requestUpdate();
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
                        var item = syncTracks[j];
                        var tPid = null as String?;
                        if (item instanceof JellyfinTrack) {
                            tPid = (item as JellyfinTrack).playlistId;
                        } else if (item instanceof Dictionary) {
                            tPid = (item as Dictionary)["playlistId"] as String?;
                        }
                        if (tPid != null && tPid.equals(playlistId)) {
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
                _errorCode = -1;
                _initialized = true;
                _currentPlaylistIndex = storage.getCurrentPlaylistIndex();
                if (_currentPlaylistIndex >= _playlists.size() && _playlists.size() > 0) {
                    _currentPlaylistIndex = _playlists.size() - 1;
                    storage.saveCurrentPlaylistIndex(_currentPlaylistIndex);
                }
                if (_currentPlaylistIndex < 0) {
                    _currentPlaylistIndex = 0;
                }
            }
        } else if (rc != -1) {
            _errorMessage = networkErrorText(rc);
            _errorCode = rc;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var storage = new StorageManager();
        var syncState = storage.loadSyncState();
        _isLoading = storage.isSyncLoading();
        if (_isLoading) {
            _statusText = "Loading...";
        }

        if (!_initialized) {
            _loadPlaylists();
        }
        _refreshSyncSelections(storage);

        _currentPlaylistIndex = storage.getCurrentPlaylistIndex();
        if (_playlists.size() > 0 && _currentPlaylistIndex >= _playlists.size()) {
            _currentPlaylistIndex = _playlists.size() - 1;
            storage.saveCurrentPlaylistIndex(_currentPlaylistIndex);
        }
        if (_currentPlaylistIndex < 0) {
            _currentPlaylistIndex = 0;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titleY = ScaleHelper.topSafe(dc, 14, 24);
        dc.drawText(
            dc.getWidth() / 2,
            titleY,
            Graphics.FONT_TINY,
            _cachedLabelSyncPlaylists != null ? _cachedLabelSyncPlaylists : "Sync Playlists",
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
                    : (_cachedNoPlaylistsMessage != null ? _cachedNoPlaylistsMessage : "No playlists"),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            if (_errorCode != -1) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 - ScaleHelper.scale(dc, 4),
                    Graphics.FONT_XTINY,
                    "(" + _errorCode + ")",
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var hint = _cachedHintRetryBack != null ? _cachedHintRetryBack : "ENTER: Retry | ESC: Back";
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + ScaleHelper.scale(dc, 14),
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
        var y = ScaleHelper.topSafe(dc, 45, 58);
        var sideInset = ScaleHelper.listSideSafe(dc);
        var rowWidth = dc.getWidth() - (sideInset * 2);
        for (
            var i = 0;
            i < visibleCount && startIdx + i < _playlists.size();
            i++
        ) {
            var idx = startIdx + i;
            var playlist = _playlists[idx] as JellyfinPlaylist;
            var isSelected = syncState.isPlaylistSelected(playlist.id);

            if (idx == _currentPlaylistIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRectangle(sideInset, y, rowWidth, rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }

            var checkMark = isSelected ? "[X]" : "[ ]";
            dc.drawText(
                sideInset + ScaleHelper.scale(dc, 4),
                y,
                Graphics.FONT_TINY,
                checkMark,
                Graphics.TEXT_JUSTIFY_LEFT
            );

            var badgeText = "[" + playlist.trackCount + "]";
            var badgeW = dc.getTextWidthInPixels(badgeText, Graphics.FONT_TINY);
            var checkW = dc.getTextWidthInPixels(checkMark, Graphics.FONT_TINY) + ScaleHelper.scale(dc, 8);
            var nameMaxW = rowWidth - checkW - badgeW - ScaleHelper.scale(dc, 8);
            var displayName = ScaleHelper.truncateText(dc, playlist.name, Graphics.FONT_TINY, nameMaxW);

            dc.drawText(
                sideInset + checkW,
                y,
                Graphics.FONT_TINY,
                displayName,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                sideInset + rowWidth - ScaleHelper.scale(dc, 4),
                y,
                Graphics.FONT_TINY,
                badgeText,
                Graphics.TEXT_JUSTIFY_RIGHT
            );

            y = y + rowH;
        }

        if (startIdx > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 4, 8), Graphics.FONT_XTINY, _cachedLabelMoreAbove != null ? _cachedLabelMoreAbove : "More above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < _playlists.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 65, 80), Graphics.FONT_XTINY, _cachedLabelMoreBelow != null ? _cachedLabelMoreBelow : "More below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.bottomSafe(dc, 45, 60),
            Graphics.FONT_XTINY,
            _cachedHintSelectEnterSync != null ? _cachedHintSelectEnterSync : "MENU: select | ENTER: sync",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        
        // High contrast fix: COLOR_LT_GRAY instead of COLOR_DK_GRAY for sunlight readability
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.bottomSafe(dc, 25, 40),
            Graphics.FONT_XTINY,
            _cachedHintBackPlay != null ? _cachedHintBackPlay : "BACK: play",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {}

    function isPlaylistSelected(id as String) as Boolean {
        var storage = new StorageManager();
        var syncState = storage.loadSyncState();
        return syncState.isPlaylistSelected(id);
    }

    function addToSelection(id as String?) as Void {
        if (id == null) { return; }
        for (var i = 0; i < _playlists.size(); i++) {
            var playlist = _playlists[i] as JellyfinPlaylist;
            if (playlist != null && playlist.id != null && playlist.id.equals(id)) {
                _selectedIndices.add(i);
                return;
            }
        }
    }

    function setError(msg as String) as Void {
        _errorMessage = msg;
        _errorCode = -1;
    }

    function clearAllSelections() as Void {
        _selectedIndices = [];
    }
}
