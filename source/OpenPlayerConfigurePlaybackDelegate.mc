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

        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
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

        if (key == WatchUi.KEY_ENTER) {
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

        if (key == WatchUi.KEY_MENU) {
            openOptionsMenu();
            return true;
        }

        if (key == WatchUi.KEY_UP) {
            if (_viewMode.equals("tracks")) {
                var currentIdx = _view != null ? _view.getTrackSelectedIndex() : 0;
                var newIdx = currentIdx - 1;
                if (newIdx < 0) {
                    newIdx = 0;
                }
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

        if (key == WatchUi.KEY_DOWN) {
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

        return false;
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

    private function openOptionsMenu() as Void {
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