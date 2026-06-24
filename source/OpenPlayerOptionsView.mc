import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Communications;
import ScaleHelper;

class OpenPlayerOptionsView extends WatchUi.View {
    private var _options as Array = [];
    private var _selectedIndex as Number = 0;
    private var _playlistId as String?;
    private var _pendingPopAfterConfirm as Boolean = false;

    function initialize() {
        View.initialize();
    }

    function setPlaylistId(id as String?) {
        _playlistId = id;
    }

    function onShow() as Void {
        if (_pendingPopAfterConfirm) {
            _pendingPopAfterConfirm = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function setOptions(options as Array) as Void {
        _options = options;
        var storage = new StorageManager();
        _selectedIndex = storage.getOptionsSelection();
        if (_selectedIndex >= options.size()) {
            _selectedIndex = 0;
        }
        WatchUi.requestUpdate();
    }

    function setSelectedIndex(idx as Number) as Void {
        _selectedIndex = idx;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(dc.getWidth() / 2, ScaleHelper.scale(dc, 20), Graphics.FONT_MEDIUM, "Options", Graphics.TEXT_JUSTIFY_CENTER);

        var startIdx = _selectedIndex;
        if (startIdx > _options.size() - 5) {
            startIdx = _options.size() - 5;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var rowH = ScaleHelper.scale(dc, 25);
        var spacing = ScaleHelper.scale(dc, 30);
        var y = ScaleHelper.scale(dc, 55);
        for (var i = 0; i < 5 && startIdx + i < _options.size(); i++) {
            var optIdx = startIdx + i;
            if (optIdx == _selectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(0, y, dc.getWidth(), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(ScaleHelper.scale(dc, 20), y, Graphics.FONT_TINY, _options[optIdx] as String, Graphics.TEXT_JUSTIFY_LEFT);
            y = y + spacing;
        }

        if (startIdx > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.scale(dc, 10), Graphics.FONT_XTINY, "^ more above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + 5 < _options.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - ScaleHelper.scale(dc, 65), Graphics.FONT_XTINY, "v more below", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onSelect_withIndex(idx as Number) as Void {
        if (idx >= _options.size()) {
            return;
        }
        var label = _options[idx] as String;
        var storage = new StorageManager();

        if (label.equals("Settings")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var wizardView = new SettingsWizardView();
            WatchUi.pushView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals("Sync playlists")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var syncView = new OpenPlayerConfigureSyncView();
            WatchUi.pushView(
                syncView,
                new OpenPlayerConfigureSyncDelegate(syncView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals("Sync Now")) {
            if (!storage.isConfigured()) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                WatchUi.showToast("Configure server first", null);
                return;
            }
            var syncState = storage.loadSyncState();
            if (syncState.selectedPlaylistIds == null || syncState.selectedPlaylistIds.size() == 0) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                WatchUi.showToast("Select playlists first", null);
                return;
            }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            Communications.startSync();
        } else if (label.equals("Remove this Playlist")) {
            if (_playlistId != null && _playlistId.length() > 0) {
                var confirmView = new ConfirmActionView("Remove Playlist?");
                WatchUi.pushView(
                    confirmView,
                    new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmRemovePlaylist)),
                    WatchUi.SLIDE_IMMEDIATE
                );
            } else {
                WatchUi.showToast("No playlist selected", null);
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }

        } else if (label.equals("Remove this Track")) {
            var currentIdx = storage.getOptionsTrackSelection();
            var tracks = storage.loadSyncedTracks();
            if (currentIdx >= 0 && currentIdx < tracks.size()) {
                var confirmView = new ConfirmActionView("Remove Track?");
                WatchUi.pushView(
                    confirmView,
                    new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmRemoveTrack)),
                    WatchUi.SLIDE_IMMEDIATE
                );
            } else {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
        } else if (label.equals("About")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var aboutView = new AboutView();
            WatchUi.pushView(
                aboutView,
                new AboutDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals("Clear All Downloads")) {
            var confirmView = new ConfirmActionView("Clear all downloads?");
            WatchUi.pushView(
                confirmView,
                new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmClearDownloads)),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onConfirmClearDownloads() as Void {
        var storage = new StorageManager();
        storage.clearDownloads();
        WatchUi.showToast("Downloads cleared", null);
        _pendingPopAfterConfirm = true;
    }

    function onConfirmRemovePlaylist() as Void {
        if (_playlistId != null && _playlistId.length() > 0) {
            var storage = new StorageManager();
            var syncState = storage.loadSyncState();
            syncState.removePlaylist(_playlistId);
            storage.saveSyncState(syncState);
            var tracks = storage.loadSyncedTracks();
            var remaining = [];
            for (var i = 0; i < tracks.size(); i++) {
                var track = tracks[i] as JellyfinTrack;
                if (track.playlistId == null || !track.playlistId.equals(_playlistId)) {
                    remaining.add(track);
                }
            }
            storage.saveSyncedTracks(remaining);
            storage.setPendingRemovePlaylistId(null);
            WatchUi.showToast("Playlist removed", null);
            _pendingPopAfterConfirm = true;
        }
    }

    function onConfirmRemoveTrack() as Void {
        var storage = new StorageManager();
        var currentIdx = storage.getOptionsTrackSelection();
        var tracks = storage.loadSyncedTracks();
        if (currentIdx >= 0 && currentIdx < tracks.size()) {
            var removedTrack = tracks[currentIdx] as JellyfinTrack;
            storage.deleteCachedItemByTitle(removedTrack.name);
            var remaining = [];
            for (var i = 0; i < tracks.size(); i++) {
                if (i != currentIdx) {
                    remaining.add(tracks[i]);
                }
            }
            storage.saveSyncedTracks(remaining);
            var newIdx = currentIdx;
            if (newIdx >= remaining.size() && remaining.size() > 0) {
                newIdx = remaining.size() - 1;
            }
            storage.saveCurrentTrackIndex(newIdx);
            storage.savePlaybackTrackSelection(newIdx);
            WatchUi.showToast("Track removed", null);
        }
        _pendingPopAfterConfirm = true;
    }
}

class OpenPlayerOptionsDelegate extends WatchUi.BehaviorDelegate {
    private var _options as Array = [];
    private var _view as OpenPlayerOptionsView?;
    private var _selectedIndex as Number = 0;

    function initialize(view as OpenPlayerOptionsView, options as Array) {
        BehaviorDelegate.initialize();
        _view = view;
        _options = options;
        var storage = new StorageManager();
        _selectedIndex = storage.getOptionsSelection();
        if (_selectedIndex >= options.size()) {
            _selectedIndex = 0;
        }
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    function onSelect() as Boolean {
        if (_view != null) {
            _view.onSelect_withIndex(_selectedIndex);
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_selectedIndex > 0) {
            _selectedIndex = _selectedIndex - 1;
            var storage = new StorageManager();
            storage.saveOptionsSelection(_selectedIndex);
            if (_view != null) {
                _view.setSelectedIndex(_selectedIndex);
            }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onNextPage() as Boolean {
        if (_selectedIndex < _options.size() - 1) {
            _selectedIndex = _selectedIndex + 1;
            var storage = new StorageManager();
            storage.saveOptionsSelection(_selectedIndex);
            if (_view != null) {
                _view.setSelectedIndex(_selectedIndex);
            }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onActionMenu() as Boolean {
        if (_view != null) {
            _view.onSelect_withIndex(_selectedIndex);
        }
        return true;
    }
}
