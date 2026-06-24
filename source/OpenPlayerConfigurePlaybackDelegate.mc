import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Media;

class OpenPlayerConfigurePlaybackDelegate extends WatchUi.BehaviorDelegate {
    private var _storage as StorageManager;
    private var _view as OpenPlayerConfigurePlaybackView?;
    private var _viewMode as String = "playlists";

    function initialize(view as OpenPlayerConfigurePlaybackView?) {
        BehaviorDelegate.initialize();
        _storage = new StorageManager();
        _viewMode = "playlists";
        _view = view;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) { return onBack(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_MENU) { return onMenu(); }
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    function onBack() as Boolean {
        if (_viewMode.equals("tracks")) {
            _viewMode = "playlists";
            if (_view != null) {
                _view.setMode("playlists");
            }
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        if (_viewMode.equals("playlists")) {
            var token = _storage.getAuthToken();
            if (token == null || token.length() == 0) {
                var wizardView = new SettingsWizardView();
                wizardView.setStep(SettingsWizardView.STEP_GCM_CONNECT);
                WatchUi.pushView(
                    wizardView,
                    new SettingsWizardDelegate(wizardView),
                    WatchUi.SLIDE_IMMEDIATE
                );
                return true;
            }
            var playlists = _view != null ? _view.getPlaylists() : [];
            if (playlists.size() == 0) {
                var syncView = new OpenPlayerConfigureSyncView();
                WatchUi.pushView(
                    syncView,
                    new OpenPlayerConfigureSyncDelegate(syncView),
                    WatchUi.SLIDE_IMMEDIATE
                );
                return true;
            }
            var selectedIdx = _view != null ? _view.getSelectedIndex() : 0;
            if (selectedIdx >= 0 && selectedIdx < playlists.size()) {
                _storage.savePlaybackPlaylistSelection(selectedIdx);
                var playlist = playlists[selectedIdx] as Dictionary;
                var playlistId = playlist["id"] as String?;
                if (playlistId != null) {
                    _storage.saveActivePlaylistId(playlistId);
                }
                _viewMode = "tracks";
                if (_view != null) {
                    _view.setMode("tracks");
                }
                WatchUi.requestUpdate();
                return true;
            }
            return true;
        } else {
            var trackIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
            _storage.savePlaybackPosition(trackIdx);
            _storage.savePlaybackTrackSelection(trackIdx);
            Media.startPlayback(null);
            return true;
        }
    }

    function onMenu() as Boolean {
        openOptionsMenu();
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_viewMode.equals("tracks")) {
            var currentIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
            var newIdx = currentIdx - 1;
            if (newIdx < 0) { newIdx = 0; }
            if (_view != null) {
                _view.setTrackSelectedIndex(newIdx);
                if (newIdx < _view.getScrollOffset()) {
                    _view.setScrollOffset(newIdx);
                }
                _storage.savePlaybackTrackSelection(newIdx);
            }
            WatchUi.requestUpdate();
            return true;
        }
        var currentIdx = _view != null ? _view.getSelectedIndex() : 0;
        if (currentIdx > 0) {
            if (_view != null) {
                _view.setSelectedIndex(currentIdx - 1);
                _storage.savePlaybackPlaylistSelection(currentIdx - 1);
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        if (_viewMode.equals("tracks")) {
            var filteredTracks = getFilteredTracks();
            var currentIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
            var maxIdx = filteredTracks.size() - 1;
            if (currentIdx < maxIdx && maxIdx >= 0) {
                var newIdx = currentIdx + 1;
                if (_view != null) {
                    _view.setTrackSelectedIndex(newIdx);
                    var scrollOffset = _view.getScrollOffset();
                    if (newIdx >= scrollOffset + 4) {
                        _view.setScrollOffset(scrollOffset + 1);
                    }
                    _storage.savePlaybackTrackSelection(newIdx);
                }
                WatchUi.requestUpdate();
            }
            return true;
        }
        var playlists = _view != null ? _view.getPlaylists() : [];
        var currentIdx = _view != null ? _view.getSelectedIndex() : 0;
        if (currentIdx < playlists.size() - 1) {
            if (_view != null) {
                _view.setSelectedIndex(currentIdx + 1);
                _storage.savePlaybackPlaylistSelection(currentIdx + 1);
            }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onActionMenu() as Boolean {
        var menu = new WatchUi.ActionMenu(null);
        var playlistId = _view != null ? _view.getSelectedPlaylistId() : null;
        if (_storage.isConfigured()) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Sync Now"}, "sync_now"));
        }
        if (_storage.isConfigured()) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Sync playlists"}, "sync_playlists"));
        }
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Settings"}, "settings"));
        if (_viewMode.equals("playlists")) {
            if (playlistId != null) {
                menu.addItem(new WatchUi.ActionMenuItem({:label => "Remove Playlist"}, "remove_playlist"));
            }
        } else {
            var tracks = _storage.loadSyncedTracks();
            var viewIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
            _storage.setOptionsTrackSelection(viewIdx);
            if (tracks.size() > 0 && viewIdx >= 0 && viewIdx < tracks.size()) {
                menu.addItem(new WatchUi.ActionMenuItem({:label => "Remove Track"}, "remove_track"));
            }
        }
        menu.addItem(new WatchUi.ActionMenuItem({:label => "About"}, "about"));
        menu.addItem(new WatchUi.ActionMenuItem({:label => "Clear Downloads"}, "clear"));
        WatchUi.showActionMenu(menu, new PlaybackActionMenuDelegate(self));
        return true;
    }

    private function getFilteredTracks() as Array {
        if (_view == null) {
            return [];
        }
        var tracks = _view.getTracks();
        var playlists = _view.getPlaylists();
        var playlistId = null;
        if (_viewMode.equals("tracks")) {
            var playlistIndex = _view.getPlaylistIndexForTracks();
            if (playlistIndex < playlists.size()) {
                playlistId = (playlists[playlistIndex] as Dictionary)["id"];
            }
        } else {
            var selectedIdx = _view.getSelectedIndex();
            if (selectedIdx < playlists.size()) {
                playlistId = (playlists[selectedIdx] as Dictionary)["id"];
            }
        }
        var filtered = [];
        for (var i = 0; i < tracks.size(); i++) {
            var track = tracks[i] as JellyfinTrack;
            if (playlistId == null || (track.playlistId != null && track.playlistId.equals(playlistId))) {
                filtered.add(track);
            }
        }
        return filtered;
    }

    function onConfirmClearDownloads() as Void {
        var storage = new StorageManager();
        storage.clearDownloads();
        WatchUi.showToast("Downloads cleared", null);
        WatchUi.requestUpdate();
    }

    function onConfirmRemovePlaylist() as Void {
        var playlistId = _storage.getPendingRemovePlaylistId();
        if (playlistId != null && playlistId.length() > 0) {
            var syncState = _storage.loadSyncState();
            syncState.removePlaylist(playlistId);
            _storage.saveSyncState(syncState);
            var tracks = _storage.loadSyncedTracks();
            var remaining = [];
            for (var i = 0; i < tracks.size(); i++) {
                var track = tracks[i] as JellyfinTrack;
                if (track.playlistId == null || !track.playlistId.equals(playlistId)) {
                    remaining.add(track);
                }
            }
            _storage.saveSyncedTracks(remaining);
            _storage.setPendingRemovePlaylistId(null);
            WatchUi.showToast("Playlist removed", null);
            if (_view != null) {
                _view.loadData();
            }
            WatchUi.requestUpdate();
        }
    }

    function onConfirmRemoveTrack() as Void {
        var currentIdx = _storage.getOptionsTrackSelection();
        var tracks = _storage.loadSyncedTracks();
        if (currentIdx >= 0 && currentIdx < tracks.size()) {
            var removedTrack = tracks[currentIdx] as JellyfinTrack;
            _storage.deleteCachedItemByTitle(removedTrack.name);
            var remaining = [];
            for (var i = 0; i < tracks.size(); i++) {
                if (i != currentIdx) {
                    remaining.add(tracks[i]);
                }
            }
            _storage.saveSyncedTracks(remaining);
            var newIdx = currentIdx;
            if (newIdx >= remaining.size() && remaining.size() > 0) {
                newIdx = remaining.size() - 1;
            }
            _storage.saveCurrentTrackIndex(newIdx);
            _storage.savePlaybackTrackSelection(newIdx);
            WatchUi.showToast("Track removed", null);
            if (_view != null) {
                _view.loadData();
            }
            WatchUi.requestUpdate();
        }
    }

    function pushSyncView() as Void {
        var syncView = new OpenPlayerConfigureSyncView();
        WatchUi.pushView(
            syncView,
            new OpenPlayerConfigureSyncDelegate(syncView),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function openOptionsMenu() as Void {
        var options = [] as Array;
        var playlistId = _view != null ? _view.getSelectedPlaylistId() : null;

        if (_storage.isConfigured()) {
            options.add("Sync Now");
        }
        if (_storage.isConfigured()) {
            options.add("Sync playlists");
        }
        options.add("Settings");

        if (_viewMode.equals("playlists")) {
            if (playlistId != null) {
                options.add("Remove this Playlist");
            }
        } else {
            var tracks = _storage.loadSyncedTracks();
            var viewIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
            _storage.setOptionsTrackSelection(viewIdx);
            if (tracks.size() > 0 && viewIdx >= 0 && viewIdx < tracks.size()) {
                options.add("Remove this Track");
            }
        }

        options.add("About");
        options.add("Clear All Downloads");

        var optionsView = new OpenPlayerOptionsView();
        optionsView.setOptions(options);
        optionsView.setPlaylistId(playlistId);
        var optionsDelegate = new OpenPlayerOptionsDelegate(optionsView, options);

        WatchUi.pushView(
            optionsView,
            optionsDelegate,
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class PlaybackActionMenuDelegate extends WatchUi.ActionMenuDelegate {
    private var _delegate as OpenPlayerConfigurePlaybackDelegate;

    function initialize(delegate as OpenPlayerConfigurePlaybackDelegate) {
        ActionMenuDelegate.initialize();
        _delegate = delegate;
    }

    function onSelect(item as WatchUi.ActionMenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("sync_now")) {
            var storage = new StorageManager();
            var syncState = storage.loadSyncState();
            if (syncState.selectedPlaylistIds == null || syncState.selectedPlaylistIds.size() == 0) {
                WatchUi.showToast("Select playlists first", null);
                return;
            }
            Communications.startSync();
        } else if (id.equals("sync_playlists")) {
            _delegate.pushSyncView();
        } else if (id.equals("settings")) {
            var wizardView = new SettingsWizardView();
            WatchUi.pushView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (id.equals("remove_playlist")) {
            var confirmView = new ConfirmActionView("Remove Playlist?");
            WatchUi.pushView(
                confirmView,
                new ConfirmActionDelegate(confirmView, new Lang.Method(_delegate, :onConfirmRemovePlaylist)),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (id.equals("remove_track")) {
            var confirmView = new ConfirmActionView("Remove Track?");
            WatchUi.pushView(
                confirmView,
                new ConfirmActionDelegate(confirmView, new Lang.Method(_delegate, :onConfirmRemoveTrack)),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (id.equals("about")) {
            var aboutView = new AboutView();
            WatchUi.pushView(
                aboutView,
                new AboutDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (id.equals("clear")) {
            var confirmView = new ConfirmActionView("Clear all downloads?");
            WatchUi.pushView(
                confirmView,
                new ConfirmActionDelegate(confirmView, new Lang.Method(_delegate, :onConfirmClearDownloads)),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onBack() as Void {
    }
}