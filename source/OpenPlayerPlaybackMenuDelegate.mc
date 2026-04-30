import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;

class OpenPlayerPlaybackMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var label = item.getLabel();
        var storage = new StorageManager();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        if (label.equals("Settings")) {
            var wizardView = new SettingsWizardView();
            WatchUi.pushView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals("About")) {
            var aboutView = new AboutView();
            WatchUi.pushView(
                aboutView,
                new AboutDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals("Sync Now")) {
            var syncState = storage.loadSyncState();
            if (syncState.selectedPlaylistIds.size() == 0) {
                WatchUi.showToast("No playlists queued", null);
                return;
            }
            Communications.startSync();
        } else if (label.equals("[Remove All] Sync")) {
            var syncState = storage.loadSyncState();
            syncState.selectedPlaylistIds = [];
            syncState.lastSyncTimestamp = 0;
            storage.saveSyncState(syncState);
            storage.saveSyncedTracks([]);
            WatchUi.showToast("Sync cleared", null);
            WatchUi.requestUpdate();
        } else if (label.equals("Remove this Playlist")) {
            var view = WatchUi.getCurrentView();
            if (view != null && view.size() > 0) {
                var playbackView = view[0] as OpenPlayerConfigurePlaybackView;
                var playlists = playbackView.getPlaylists();
                var selectedIdx = playbackView.getSelectedIndex();
                if (selectedIdx < playlists.size()) {
                    var playlist = playlists[selectedIdx] as Dictionary;
                    var playlistId = playlist["id"];
                    if (playlistId != null) {
                        var syncState = storage.loadSyncState();
                        syncState.removePlaylist(playlistId);
                        storage.saveSyncState(syncState);
                        var tracks = storage.loadSyncedTracks();
                        var remaining = [];
                        for (var i = 0; i < tracks.size(); i++) {
                            var track = tracks[i] as JellyfinTrack;
                            if (track.playlistId == null || !track.playlistId.equals(playlistId)) {
                                remaining.add(track);
                            }
                        }
                        storage.saveSyncedTracks(remaining);
                        playbackView.loadData();
                        WatchUi.requestUpdate();
                    }
                }
            }
        } else if (label.equals("Remove this Track")) {
            var currentIdx = storage.getCurrentTrackIndex();
            var tracks = storage.loadSyncedTracks();
            if (currentIdx >= 0 && currentIdx < tracks.size()) {
                tracks.remove(currentIdx);
                storage.saveSyncedTracks(tracks);
                if (currentIdx >= tracks.size() && tracks.size() > 0) {
                    storage.saveCurrentTrackIndex(tracks.size() - 1);
                }
                WatchUi.requestUpdate();
            }
        }
    }
}