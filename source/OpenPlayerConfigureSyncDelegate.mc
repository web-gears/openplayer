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
            var token = _storage.getAuthToken();
            if (token != null && token.length() > 0) {
                loadPlaylists();
            } else {
                var wizardView = new SettingsWizardView();
                wizardView.setStep(SettingsWizardView.STEP_GCM_CONNECT);
                WatchUi.switchToView(
                    wizardView,
                    new SettingsWizardDelegate(wizardView),
                    WatchUi.SLIDE_IMMEDIATE
                );
            }
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
        fetchPlaylists();
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
            var playlists = _loadPlaylistsFallback();
            if (playlists.size() == 0) {
                _storage.clearPendingPlaylistResponse();
                loadPlaylists();
                return true;
            }
            var playbackView = new OpenPlayerConfigurePlaybackView();
            WatchUi.switchToView(
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

        var estimatedTracks = 0;
        var playlists = _storage.loadPlaylists();
        for (var i = 0; i < playlists.size(); i++) {
            var p = playlists[i] as JellyfinPlaylist;
            for (var j = 0; j < _syncState.selectedPlaylistIds.size(); j++) {
                if (p.id.equals(_syncState.selectedPlaylistIds[j] as String)) {
                    estimatedTracks += p.trackCount;
                }
            }
        }

        var syncedTracks = _storage.loadSyncedTracks();
        var newTrackEstimate = estimatedTracks > syncedTracks.size() ? estimatedTracks - syncedTracks.size() : 0;
        var totalSyncedSize = 0;
        for (var i = 0; i < syncedTracks.size(); i++) {
            totalSyncedSize += syncedTracks[i].downloadSize;
        }

        _storage.saveSyncProgressDict({
            "phase" => "confirm",
            "playlistCount" => count,
            "estimatedTracks" => newTrackEstimate,
            "freeBytes" => totalSyncedSize
        });

        var statusView = new OpenPlayerSyncStatusView();
        WatchUi.pushView(
            statusView,
            new OpenPlayerSyncStatusDelegate(),
            WatchUi.SLIDE_IMMEDIATE
        );
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
    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function formatBytes(bytes as Number) as String {
        if (bytes < 1024) {
            return bytes + " B";
        } else if (bytes < 1024 * 1024) {
            return bytes / 1024 + " KB";
        } else {
            return (bytes / (1024 * 1024)).format("%.1f") + " MB";
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var storage = new StorageManager();
        var progress = storage.loadSyncProgressDict();
        var phase = progress != null ? progress["phase"] as String? : null;
        var percent = progress != null ? progress["percent"] as Number? : 0;

        if (phase == null) {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2,
                Graphics.FONT_TINY,
                "Starting...",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        if (phase.equals("confirm")) {
            dc.drawText(
                dc.getWidth() / 2,
                ScaleHelper.scale(dc, 12),
                Graphics.FONT_TINY,
                "Ready to Sync",
                Graphics.TEXT_JUSTIFY_CENTER
            );

            var pc = progress["playlistCount"] as Number?;
            var et = progress["estimatedTracks"] as Number?;
            var fb = progress["freeBytes"] as Number?;

            var y = ScaleHelper.scale(dc, 40);
            if (pc != null) {
                dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, pc + " playlist(s) selected", Graphics.TEXT_JUSTIFY_CENTER);
                y += ScaleHelper.scale(dc, 22);
            }
            if (et != null) {
                dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, "Est. " + et + " new tracks", Graphics.TEXT_JUSTIFY_CENTER);
                y += ScaleHelper.scale(dc, 22);
            }
            if (fb != null) {
                dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, "Synced: " + formatBytes(fb), Graphics.TEXT_JUSTIFY_CENTER);
            }

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 45),
                Graphics.FONT_XTINY,
                "ENTER: Start | ESC: Back",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        if (phase.equals("cancelled")) {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 - ScaleHelper.scale(dc, 15),
                Graphics.FONT_TINY,
                "Sync Cancelled",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 15),
                Graphics.FONT_XTINY,
                "ENTER: Done",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.scale(dc, 15),
            Graphics.FONT_MEDIUM,
            "Sync",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (phase.equals("fetching")) {
            var cp = progress["currentPlaylist"] as Number?;
            var tp = progress["totalPlaylists"] as Number?;
            if (cp != null && tp != null && tp > 0) {
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 - ScaleHelper.scale(dc, 15),
                    Graphics.FONT_TINY,
                    "Fetch playlist " + cp + "/" + tp,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            } else {
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 - ScaleHelper.scale(dc, 15),
                    Graphics.FONT_TINY,
                    "Fetching playlists...",
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
            return;
        }

        if (phase.equals("downloading")) {
            var current = progress["current"] as Number?;
            var total = progress["total"] as Number?;
            if (current != null && total != null && total > 0) {
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 - ScaleHelper.scale(dc, 30),
                    Graphics.FONT_TINY,
                    "Track " + current + "/" + total,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }

            if (percent != null) {
                var barX = ScaleHelper.scale(dc, 20);
                var barW = dc.getWidth() - ScaleHelper.scale(dc, 40);
                var barY = dc.getHeight() / 2 - ScaleHelper.scale(dc, 5);
                var barH = ScaleHelper.scale(dc, 10);
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                dc.fillRectangle(barX, barY, barW, barH);
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
                var fillW = (barW * percent / 100).toNumber();
                dc.fillRectangle(barX, barY, fillW, barH);
            }

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 15),
                Graphics.FONT_XTINY,
                "ESC: Cancel",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        if (phase.equals("complete")) {
            var total = progress["total"] as Number?;
            var msg = "Sync Complete!";
            if (total != null && total > 0) {
                msg = total + " tracks synced";
            }
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 - ScaleHelper.scale(dc, 15),
                Graphics.FONT_TINY,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() - ScaleHelper.scale(dc, 15),
                Graphics.FONT_XTINY,
                "ENTER: Done",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_TINY,
            "Syncing...",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}

class OpenPlayerSyncStatusDelegate extends WatchUi.BehaviorDelegate {
    private var _storage as StorageManager;

    function initialize() {
        BehaviorDelegate.initialize();
        _storage = new StorageManager();
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_ENTER) {
            var progress = _storage.loadSyncProgressDict();
            if (progress != null) {
                var phase = progress["phase"] as String?;
                if (phase != null && phase.equals("confirm")) {
                    _storage.saveSyncProgressDict({
                        "phase" => "starting"
                    });
                    Communications.startSync();
                    return true;
                }
                if (phase != null && (phase.equals("complete") || phase.equals("cancelled"))) {
                    _storage.clearSyncProgress();
                    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                    return true;
                }
            }
            return true;
        }

        if (key == WatchUi.KEY_ESC) {
            var progress = _storage.loadSyncProgressDict();
            if (progress != null) {
                var phase = progress["phase"] as String?;
                if (phase == null || phase.equals("confirm")) {
                    _storage.clearSyncProgress();
                    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                    return true;
                }
                if (!phase.equals("complete") && !phase.equals("cancelled")) {
                    _storage.saveCancelRequested(true);
                }
            }
            _storage.clearSyncProgress();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }
}
