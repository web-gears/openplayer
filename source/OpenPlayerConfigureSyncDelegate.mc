import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.Graphics;
import ScaleHelper;

class OpenPlayerConfigureSyncDelegate extends WatchUi.BehaviorDelegate {
    private var _view as OpenPlayerConfigureSyncView? = null;
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _syncState as SyncState;
    private var _currentPlaylistIndex as Number = 0;
    private var _pendingResponseCode as Number = -1;
    private var _pendingData as Dictionary?;

    function initialize(view as OpenPlayerConfigureSyncView) {
        BehaviorDelegate.initialize();
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _syncState = _storage.loadSyncState();
        _currentPlaylistIndex = _storage.getCurrentPlaylistIndex();
        _view = view;
    }

    function onShow() as Void {
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
    }

    function loadPlaylists() as Void {
        if (!_storage.isConfigured()) {
            _storage.setSyncError("Press LAP to configure");
            WatchUi.requestUpdate();
            return;
        }

        _storage.saveSyncLoading(true);
        WatchUi.requestUpdate();

        var token = _storage.getAuthToken();
        if (token == null || token.length() == 0) {
            _client.authenticateFromSettings(method(:onReAuthForPlaylists));
            return;
        }
        fetchPlaylists();
    }

    function onReAuthForPlaylists(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        _storage.saveSyncLoading(false);
        if (responseCode == 200) {
            fetchPlaylists();
        } else {
            _storage.savePendingPlaylistResponseCode(401);
            _storage.setSyncError("Re-auth failed - check GCM settings");
            WatchUi.requestUpdate();
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
        processPendingResponse();
        _storage.saveSyncLoading(false);
        WatchUi.requestUpdate();
    }

    function onKey(evt) as Boolean {
        var key = evt.getKey();

        if (key == 8) {
            var playlists = _loadPlaylistsFallback();
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
        } else if (key == 13) {
            var playlists = _loadPlaylistsFallback();
            if (playlists.size() > 0) {
                var newIdx = _currentPlaylistIndex - 1;
                if (newIdx >= 0) {
                    _currentPlaylistIndex = newIdx;
                    _storage.saveCurrentPlaylistIndex(newIdx);
                    WatchUi.requestUpdate();
                }
            }
            return true;
        } else if (key == 4) {
            startSync();
            return true;
        } else if (key == 7) {
            toggleCurrentSelection();
            return true;
        } else if (key == 5) {
            var playbackView = new OpenPlayerConfigurePlaybackView();
            WatchUi.pushView(
                playbackView,
                new OpenPlayerConfigurePlaybackDelegate(playbackView),
                WatchUi.SLIDE_UP
            );
            return true;
        }
        return false;
    }

    function toggleCurrentSelection() as Void {
        var playlists = _loadPlaylistsFallback();
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
                    if (_view != null) {
                        _view.setError("Free: max " + _storage.getMaxPlaylists() + " playlist(s)");
                    }
                    return;
                }
                _syncState.selectedPlaylistIds.add(playlist.id);
            }
            _storage.saveSyncState(_syncState);
            WatchUi.requestUpdate();
        }
    }

    function _loadPlaylistsFallback() as Array {
        var playlists = _storage.loadPlaylists();
        if (playlists.size() == 0) {
            var rc = _storage.getPendingPlaylistResponseCode();
            if (rc == 200) {
                var ids = _storage.getPendingPlaylistIds();
                var names = _storage.getPendingPlaylistNames();
                if (ids != null && names != null) {
                    var idArray = ScaleHelper.splitString(ids, ",");
                    var nameArray = ScaleHelper.splitString(names, "|");
                    var min = idArray.size();
                    if (nameArray.size() < min) { min = nameArray.size(); }
                    for (var i = 0; i < min; i++) {
                        playlists.add(new JellyfinPlaylist(idArray[i], nameArray[i], 0));
                    }
                }
            }
        }
        return playlists;
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
            ScaleHelper.scale(dc, 20),
            Graphics.FONT_TINY,
            "Syncing...",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_progress > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.fillRectangle(ScaleHelper.scale(dc, 20), dc.getHeight() / 2, dc.getWidth() - ScaleHelper.scale(dc, 40), ScaleHelper.scale(dc, 10));
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            var barWidth = (
                ((dc.getWidth() - ScaleHelper.scale(dc, 40)) * _progress) /
                100
            ).toNumber();
            dc.fillRectangle(ScaleHelper.scale(dc, 20), dc.getHeight() / 2, barWidth, ScaleHelper.scale(dc, 10));
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 + ScaleHelper.scale(dc, 25),
            Graphics.FONT_TINY,
            _statusText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_isComplete) {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + ScaleHelper.scale(dc, 25),
                Graphics.FONT_MEDIUM,
                "Sync Complete!",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 20),
                Graphics.FONT_TINY,
                "ENTER: Done",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        if (_errorMessage.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 20),
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
