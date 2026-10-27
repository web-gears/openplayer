import Toybox.WatchUi;
import Toybox.Lang;

class OpenPlayerPlaybackMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var label = item.getLabel();
        var storage = new StorageManager();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        if (label.equals(WatchUi.loadResource($.Rez.Strings.labelSettings) as String) || label.equals("Settings")) {
            var wizardView = new SettingsWizardView();
            WatchUi.pushView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals(WatchUi.loadResource($.Rez.Strings.labelAbout) as String) || label.equals("About")) {
            var aboutView = new AboutView();
            WatchUi.pushView(
                aboutView,
                new AboutDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals(WatchUi.loadResource($.Rez.Strings.labelClearDownloads) as String) || label.equals("[Remove All] Sync")) {
            storage.purgeAllCachedAudio();
            var syncState = storage.loadSyncState();
            syncState.selectedPlaylistIds = [];
            syncState.lastSyncTimestamp = 0;
            storage.saveSyncState(syncState);
            storage.saveSyncedTracks([]);
            WatchUi.showToast(WatchUi.loadResource($.Rez.Strings.toastDownloadsCleared) as String, null);
            WatchUi.requestUpdate();
        } else if (label.equals(WatchUi.loadResource($.Rez.Strings.labelRemovePlaylist) as String) || label.equals("Remove this Playlist")) {
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
                            } else {
                                storage.deleteCachedItemByTitle(track.name);
                            }
                        }
                        storage.saveSyncedTracks(remaining);
                        playbackView.loadData();
                        WatchUi.requestUpdate();
                    }
                }
            }
        } else if (label.equals(WatchUi.loadResource($.Rez.Strings.labelRemoveTrack) as String) || label.equals("Remove this Track")) {
            var currentIdx = storage.getCurrentTrackIndex();
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
                if (currentIdx >= remaining.size() && remaining.size() > 0) {
                    storage.saveCurrentTrackIndex(remaining.size() - 1);
                }
                WatchUi.requestUpdate();
            }
        }
    }
}