import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Timer;
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
        if (key == 4) { return onSelect(); }
        if (key == 7) { return onMenu(); }
        if (key == 13) { return onPreviousPage(); }
        if (key == 8) { return onNextPage(); }
        if (key == 5) {
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

    function onSelect() as Boolean {
        startSync();
        return true;
    }

    function onBack() as Boolean {
        var playlists = _loadPlaylistsFallback();
        if (playlists.size() == 0) {
            _storage.clearPendingPlaylistResponse();
        }
        _storage.clearSyncProgress();
        return false;
    }

    function onNextPage() as Boolean {
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
    }

    function onPreviousPage() as Boolean {
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
    }

    function onMenu() as Boolean {
        toggleCurrentSelection();
        return true;
    }

    function onActionMenu() as Boolean {
        var menu = new WatchUi.ActionMenu(null);
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Toggle Select"}, "toggle"));
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Sync"}, "sync"));
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Play"}, "play"));
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Settings"}, "settings"));
        WatchUi.showActionMenu(menu, new SyncActionMenuDelegate(self));
        return true;
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

    private var _pendingTracks as Array = [];
    private var _currentFetchPlaylistIdx as Number = 0;
    private var _currentFetchPageStart as Number = 0;

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

        _pendingTracks = [];
        _currentFetchPlaylistIdx = 0;
        _currentFetchPageStart = 0;

        _storage.saveCancelRequested(false);
        _storage.saveSyncProgressDict({
            "phase" => "fetching_tracks",
            "percent" => 0,
            "currentPlaylist" => 1,
            "totalPlaylists" => count
        });

        var statusView = new OpenPlayerSyncStatusView();
        WatchUi.pushView(
            statusView,
            new OpenPlayerSyncStatusDelegate(),
            WatchUi.SLIDE_IMMEDIATE
        );

        fetchNextForegroundBatch();
    }

    function fetchNextForegroundBatch() as Void {
        if (_storage.isCancelRequested()) {
            _storage.clearCancelRequested();
            _pendingTracks = [];
            return;
        }
        var ids = _syncState.selectedPlaylistIds;
        if (_currentFetchPlaylistIdx >= ids.size()) {
            onAllForegroundTracksFetched();
            return;
        }
        _client.getPlaylistTracks(
            ids[_currentFetchPlaylistIdx] as String,
            _currentFetchPageStart,
            method(:onForegroundTracksFetched)
        );
    }

    function onForegroundTracksFetched(rc as Number, tracks as Array, pageStart as Number) as Void {
        if (rc == 200 && tracks != null) {
            for (var i = 0; i < tracks.size(); i++) {
                var t = tracks[i] as JellyfinTrack;
                if (t != null) {
                    _pendingTracks.add({
                        "id" => t.id,
                        "serverId" => t.serverId,
                        "name" => t.name,
                        "albumName" => t.albumName,
                        "artistName" => t.artistName,
                        "durationSeconds" => t.durationSeconds,
                        "downloadSize" => t.downloadSize,
                        "playlistId" => t.playlistId
                    });
                }
            }
            if (tracks.size() >= 5) {
                _currentFetchPageStart += 5;
                fetchNextForegroundBatch();
                return;
            }
        }
        _currentFetchPlaylistIdx++;
        _currentFetchPageStart = 0;
        _storage.saveSyncProgressDict({
            "phase" => "fetching_tracks",
            "percent" => (_currentFetchPlaylistIdx.toFloat() / _syncState.selectedPlaylistIds.size() * 100).toNumber(),
            "currentPlaylist" => _currentFetchPlaylistIdx + 1,
            "totalPlaylists" => _syncState.selectedPlaylistIds.size()
        });
        WatchUi.requestUpdate();
        fetchNextForegroundBatch();
    }

    function onAllForegroundTracksFetched() as Void {
        var alreadySyncedIds = {};
        var localTracks = _storage.loadSyncedTracks();
        for (var i = 0; i < localTracks.size(); i++) {
            var lt = localTracks[i] as JellyfinTrack;
            if (lt.id != null) {
                alreadySyncedIds[lt.id.toString()] = true;
            }
        }

        var newTrackCount = 0;
        var newBytes = 0;
        for (var i = 0; i < _pendingTracks.size(); i++) {
            var t = _pendingTracks[i] as Dictionary;
            var id = t["id"] != null ? t["id"].toString() : "";
            if (!alreadySyncedIds[id]) {
                newTrackCount++;
                var size = t["downloadSize"] as Number?;
                if (size != null) { newBytes += size; }
            }
        }

        _storage.savePendingSyncTracks(_pendingTracks);
        _storage.saveSyncProgressDict({
            "phase" => "confirm",
            "playlistCount" => _syncState.selectedPlaylistIds.size(),
            "estimatedTracks" => newTrackCount,
            "freeBytes" => newBytes
        });
        _pendingTracks = [];
        WatchUi.requestUpdate();
    }

    function clearAll() as Void {
        var syncState = _storage.loadSyncState();
        syncState.selectedPlaylistIds = [];
        syncState.totalSizeBytes = 0;
        _storage.saveSyncState(syncState);
        WatchUi.requestUpdate();
    }

    function openPlaybackView() as Void {
        var playbackView = new OpenPlayerConfigurePlaybackView();
        WatchUi.switchToView(
            playbackView,
            new OpenPlayerConfigurePlaybackDelegate(playbackView),
            WatchUi.SLIDE_UP
        );
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

class SyncActionMenuDelegate extends WatchUi.ActionMenuDelegate {
    private var _delegate as OpenPlayerConfigureSyncDelegate;

    function initialize(delegate as OpenPlayerConfigureSyncDelegate) {
        ActionMenuDelegate.initialize();
        _delegate = delegate;
    }

    function onSelect(item as WatchUi.ActionMenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("toggle")) {
            _delegate.toggleCurrentSelection();
        } else if (id.equals("sync")) {
            _delegate.startSync();
        } else if (id.equals("play")) {
            _delegate.openPlaybackView();
        } else if (id.equals("settings")) {
            _delegate.openSettings();
        }
    }

    function onBack() as Void {
    }
}

class OpenPlayerSyncStatusView extends WatchUi.View {
    private var _pollTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        if (WatchUi.View has :setActionMenuIndicator) {
            setActionMenuIndicator({:enabled => true});
        }
        if (_pollTimer == null) {
            _pollTimer = new Timer.Timer();
            (_pollTimer as Timer.Timer).start(method(:onPollTick), 2000, true);
        }
        WatchUi.requestUpdate();
    }

    function onPollTick() as Void {
        var storage = new StorageManager();
        var progress = storage.loadSyncProgressDict();
        var phase = progress != null ? progress["phase"] as String? : null;
        if (phase != null && (phase.equals("complete") || phase.equals("cancelled"))) {
            stopPollTimer();
        }
        WatchUi.requestUpdate();
    }

    private function stopPollTimer() as Void {
        if (_pollTimer != null) {
            (_pollTimer as Timer.Timer).stop();
            _pollTimer = null;
        }
    }

    function onHide() as Void {
        stopPollTimer();
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

            var y = ScaleHelper.scale(dc, 40);
            if (pc != null) {
                dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, pc + " playlist(s) selected", Graphics.TEXT_JUSTIFY_CENTER);
                y += ScaleHelper.scale(dc, 22);
            }
            if (et != null) {
                dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, "Est. " + et + " new tracks", Graphics.TEXT_JUSTIFY_CENTER);
                y += ScaleHelper.scale(dc, 22);
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

        if (phase.equals("fetching_tracks")) {
            dc.drawText(
                dc.getWidth() / 2,
                ScaleHelper.scale(dc, 12),
                Graphics.FONT_TINY,
                "Fetching track data...",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            var cp = progress["currentPlaylist"] as Number?;
            var tp = progress["totalPlaylists"] as Number?;
            if (cp != null && tp != null && tp > 0) {
                dc.drawText(
                    dc.getWidth() / 2,
                    ScaleHelper.scale(dc, 45),
                    Graphics.FONT_TINY,
                    "Playlist " + cp + "/" + tp,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
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
            var err = progress["fetchError"] as String?;
            if (err != null) {
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 - ScaleHelper.scale(dc, 15),
                    Graphics.FONT_XTINY,
                    err,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            } else if (cp != null && tp != null && tp > 0) {
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

            var syncError = storage.getSyncError();
            if (syncError != null && syncError.length() > 0) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 + ScaleHelper.scale(dc, 15),
                    Graphics.FONT_XTINY,
                    syncError,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
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
            var err = progress["fetchError"] as String?;
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
            if (err != null) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.drawText(
                    dc.getWidth() / 2,
                    dc.getHeight() / 2 + ScaleHelper.scale(dc, 10),
                    Graphics.FONT_XTINY,
                    err,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
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
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        return false;
    }

    function onSelect() as Boolean {
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

    function onBack() as Boolean {
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

    function onActionMenu() as Boolean {
        var menu = new WatchUi.ActionMenu(null);
        var progress = _storage.loadSyncProgressDict();
        var phase = progress != null ? progress["phase"] as String? : null;
        if (phase != null && phase.equals("confirm")) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Start Sync"}, "start"));
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Cancel"}, "cancel"));
        } else if (phase != null && (phase.equals("complete") || phase.equals("cancelled"))) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Done"}, "done"));
        } else if (phase != null) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Cancel Sync"}, "cancel"));
        }
        WatchUi.showActionMenu(menu, new SyncStatusActionMenuDelegate(self));
        return true;
    }
}

class SyncStatusActionMenuDelegate extends WatchUi.ActionMenuDelegate {
    private var _delegate as OpenPlayerSyncStatusDelegate;

    function initialize(delegate as OpenPlayerSyncStatusDelegate) {
        ActionMenuDelegate.initialize();
        _delegate = delegate;
    }

    function onSelect(item as WatchUi.ActionMenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("start")) {
            _delegate.onSelect();
        } else if (id.equals("cancel")) {
            _delegate.onBack();
        } else if (id.equals("done")) {
            _delegate.onSelect();
        }
    }

    function onBack() as Void {
    }
}
