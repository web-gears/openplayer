import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;

class OpenPlayerPlaylistMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;

    function initialize() {
        Menu2InputDelegate.initialize();
        _storage = new StorageManager();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var playlistId = item.getId() as String;
        var syncState = _storage.loadSyncState();

        var isQueued = false;
        for (var i = 0; i < syncState.selectedPlaylistIds.size(); i++) {
            if ((syncState.selectedPlaylistIds[i] as String).equals(playlistId)) {
                isQueued = true;
                break;
            }
        }

        if (isQueued) {
            syncState.removePlaylist(playlistId);
            item.setSubLabel("Not queued");
        } else {
            syncState.addPlaylist(playlistId);
            item.setSubLabel("Queued");
        }

        _storage.saveSyncState(syncState);
        WatchUi.requestUpdate();
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_MENU || key == WatchUi.KEY_ENTER) {
            startSyncIfQueued();
            return true;
        } else if (key == WatchUi.KEY_LAP) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function startSyncIfQueued() as Void {
        var syncState = _storage.loadSyncState();
        if (syncState.selectedPlaylistIds.size() == 0) {
            WatchUi.showToast("No playlists queued", null);
            return;
        }
        Communications.startSync();
    }
}