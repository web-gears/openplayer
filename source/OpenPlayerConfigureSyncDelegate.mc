import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.Graphics;

class OpenPlayerConfigureSyncDelegate extends WatchUi.BehaviorDelegate {
    private var _view as OpenPlayerConfigureSyncView? = null;
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _syncState as SyncState;
    private var _currentPlaylistIndex as Number = 0;
    private var _isActive as Boolean = false;
    private var _pendingResponseCode as Number = -1;
    private var _pendingData as Dictionary?;
    private var _hasPendingResponse as Boolean = false;
    private var _pendingDataReady as Boolean = false;
    private var _lastResponseCode as Number = -1;
    private var _lastResponseData as Dictionary?;

    function hasPendingData() as Boolean {
        return _pendingDataReady;
    }

    function getPendingResponseCode() as Number {
        return _lastResponseCode;
    }

    function getPendingResponseData() as Dictionary? {
        return _lastResponseData;
    }

    function clearPendingData() as Void {
        _pendingDataReady = false;
        _lastResponseCode = -1;
        _lastResponseData = null;
    }

    function initialize() {
        BehaviorDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _syncState = _storage.loadSyncState();
        _currentPlaylistIndex = _storage.getCurrentPlaylistIndex();
        
        var viewArray = WatchUi.getCurrentView();
        if (viewArray != null && viewArray.size() > 0) {
            _view = viewArray[0] as OpenPlayerConfigureSyncView;
        }
    }

    function onShow() as Void {
        _isActive = true;
        var viewArray = WatchUi.getCurrentView();
        if (viewArray != null && viewArray.size() > 0) {
            _view = viewArray[0] as OpenPlayerConfigureSyncView;
        }
        if (_pendingResponseCode != -1) {
            processPendingResponse();
        }
        
        if (_storage.isConfigured()) {
            loadPlaylists();
        } else {
            var wizardView = new SettingsWizardView();
            WatchUi.switchToView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onHide() as Void {
        _isActive = false;
    }

    function loadPlaylists() as Void {
        if (!_storage.isConfigured()) {
            _storage.setSyncError("Press LAP to configure");
            WatchUi.requestUpdate();
            return;
        }

        WatchUi.requestUpdate();

        var apiKey = _storage.getApiKeyDirect();
        if (apiKey == null) {
            _client.authenticate(method(:onAuthForPlaylists));
        } else {
            fetchPlaylists();
        }
    }

    function onAuthForPlaylists(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        if (!_isActive) {
            return;
        }
        if (responseCode == 200) {
            fetchPlaylists();
        } else {
            _storage.savePendingPlaylistResponseCode(401);
        }
    }

    function fetchPlaylists() as Void {
        _client.getPlaylists(method(:onPlaylistsLoaded));
    }

    function onPlaylistsLoaded(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        _pendingResponseCode = responseCode;
        _pendingData = data;
        _hasPendingResponse = true;
        if (responseCode == 200 && data != null) {
            var items = data["Items"] as Array;
            if (items != null) {
                var ids = "";
                var names = "";
                var counts = "";
                for (var i = 0; i < items.size(); i++) {
                    var item = items[i] as Dictionary;
                    if (i > 0) {
                        ids = ids + ",";
                        names = names + "|";
                        counts = counts + ",";
                    }
                    ids = ids + (item["Id"] as String);
                    names = names + (item["Name"] as String);
                    var childCount = item["ChildCount"] as Number?;
                    counts = counts + (childCount != null ? childCount : 0);
                }
                _storage.savePendingPlaylistIds(ids);
                _storage.savePendingPlaylistNames(names);
                _storage.savePendingPlaylistCounts(counts);
                _storage.savePendingPlaylistResponseCode(responseCode);
            }
        } else {
            _storage.savePendingPlaylistResponseCode(responseCode);
        }
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (_view == null) {
            return false;
        }

        if (_hasPendingResponse) {
            processPendingResponse();
            _hasPendingResponse = false;
            _pendingResponseCode = -1;
            _pendingData = null;
        }

        if (key == WatchUi.KEY_DOWN) {
            var playlists = _storage.loadPlaylists();
            if (playlists.size() > 0) {
                var newIdx = _currentPlaylistIndex + 1;
                if (newIdx < playlists.size()) {
                    _currentPlaylistIndex = newIdx;
                    _storage.saveCurrentPlaylistIndex(newIdx);
                    _storage.saveSyncState(_syncState);
                    WatchUi.requestUpdate();
                }
            }
            return true;
        } else if (key == WatchUi.KEY_UP) {
            var playlists = _storage.loadPlaylists();
            if (playlists.size() > 0) {
                var newIdx = _currentPlaylistIndex - 1;
                if (newIdx >= 0) {
                    _currentPlaylistIndex = newIdx;
                    _storage.saveCurrentPlaylistIndex(newIdx);
                    WatchUi.requestUpdate();
                }
            }
            return true;
        } else if (key == WatchUi.KEY_ENTER) {
            startSync();
            return true;
        } else if (key == WatchUi.KEY_MENU) {
            toggleCurrentSelection();
            return true;
        } else if (key == WatchUi.KEY_LAP) {
            WatchUi.pushView(
                new OpenPlayerConfigurePlaybackView(),
                new OpenPlayerConfigurePlaybackDelegate(),
                WatchUi.SLIDE_UP
            );
            return true;
        }
        return false;
    }

    function toggleCurrentSelection() as Void {
        var playlists = _storage.loadPlaylists();
        if (playlists.size() > 0 && _currentPlaylistIndex < playlists.size()) {
            var playlist = playlists[_currentPlaylistIndex] as JellyfinPlaylist;
            var isSelected = _syncState.selectedPlaylistIds.indexOf(playlist.id) >= 0;
            if (isSelected) {
                var newSelected = [];
                for (var i = 0; i < _syncState.selectedPlaylistIds.size(); i++) {
                    if ((_syncState.selectedPlaylistIds[i] as String).equals(playlist.id) == false) {
                        newSelected.add(_syncState.selectedPlaylistIds[i]);
                    }
                }
                _syncState.selectedPlaylistIds = newSelected;
            } else {
                if (!_storage.canSelectPlaylist(_syncState.selectedPlaylistIds.size())) {
                    _view.setError("Free: max " + _storage.getMaxPlaylists() + " playlist(s)");
                    return;
                }
                _syncState.selectedPlaylistIds.add(playlist.id);
            }
            _storage.saveSyncState(_syncState);
            WatchUi.requestUpdate();
        }
    }

    function processPendingResponse() as Void {
        var rc = _pendingResponseCode;
        var data = _pendingData;
        _pendingResponseCode = -1;
        _pendingData = null;

        if (rc == -1 || rc == 0) {
            return;
        }

        _storage.savePendingPlaylistResponseCode(rc);

        if (rc == 200 && data != null) {
            var items = data["Items"] as Array?;
            if (items == null) {
                return;
            }
            var newPlaylists = [];
            for (var i = 0; i < items.size(); i++) {
                var item = items[i] as Dictionary;
                var id = item["Id"] as String?;
                var name = item["Name"] as String?;
                var childCount = item["ChildCount"] as Number?;

                if (id != null && name != null) {
                    newPlaylists.add(
                        new JellyfinPlaylist(
                            id,
                            name,
                            childCount != null ? childCount : 0
                        )
                    );
                }
            }
            _storage.savePlaylists(newPlaylists);

            _storage.saveSyncState(_syncState);
        }
    }

    function updateStateFromView() as Void {
        _storage.saveSyncState(_syncState);
    }

    function startSync() as Void {
        _syncState = _storage.loadSyncState();
        var count = _syncState.selectedPlaylistIds.size();
        if (count == 0) {
            _storage.setSyncError("Select playlists first");
            WatchUi.requestUpdate();
            return;
        }

        Communications.startSync();
    }

    function clearAll() as Void {
        var syncState = _storage.loadSyncState();
        syncState.selectedPlaylistIds = [];
        syncState.totalSizeBytes = 0;
        _storage.saveSyncState(syncState);
        WatchUi.requestUpdate();
    }

    function openSettings() as Void {
        var wizardView = new SettingsWizardView();
        WatchUi.pushView(
            wizardView,
            new SettingsWizardDelegate(wizardView),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class OpenPlayerSyncStatusView extends WatchUi.View {
    private var _statusText as String = "";
    private var _progress as Number = 0;
    private var _isComplete as Boolean = false;
    private var _errorMessage as String = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {}

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        dc.drawText(
            dc.getWidth() / 2,
            20,
            Graphics.FONT_TINY,
            "Syncing...",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_progress > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.fillRectangle(20, dc.getHeight() / 2, dc.getWidth() - 40, 10);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            var barWidth = (
                ((dc.getWidth() - 40) * _progress) /
                100
            ).toNumber();
            dc.fillRectangle(20, dc.getHeight() / 2, barWidth, 10);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 + 25,
            Graphics.FONT_TINY,
            _statusText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_isComplete) {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + 25,
                Graphics.FONT_MEDIUM,
                "Sync Complete!",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - 20,
                Graphics.FONT_TINY,
                "ENTER: Done",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        if (_errorMessage.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - 20,
                Graphics.FONT_TINY,
                _errorMessage,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    function setStatus(text as String) as Void {
        _statusText = text;
        WatchUi.requestUpdate();
    }

    function setProgress(progress as Number) as Void {
        _progress = progress;
        WatchUi.requestUpdate();
    }

    function setComplete() as Void {
        _isComplete = true;
        WatchUi.requestUpdate();
    }

    function setError(msg as String) as Void {
        _errorMessage = msg;
        WatchUi.requestUpdate();
    }
}
