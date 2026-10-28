import Toybox.Test;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application;

(:test)
class MockConfirmActionCallback {
    public var invoked as Boolean = false;

    function onConfirm() as Void {
        invoked = true;
    }
}

(:test)
class DelegateFlowTests {

    // Tier 2: Test ConfirmActionDelegate key navigation, clamping, and selection
    (:test)
    static function testConfirmActionKeyNavigation(logger as Test.Logger) as Boolean {
        var view = new ConfirmActionView("Delete playlist?");
        var mockCb = new MockConfirmActionCallback();
        var delegate = new ConfirmActionDelegate(view, mockCb.method(:onConfirm));

        // Initial selection should be 0 ("Yes")
        Test.assertEqualMessage(view.getSelected(), 0, "Initial selection should be 0 (Yes)");

        // Simulate DOWN key -> should move to 1 ("No")
        var downKey = new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION);
        delegate.onKey(downKey);
        Test.assertEqualMessage(view.getSelected(), 1, "Down key should advance selection to 1 (No)");

        // Simulate DOWN key again -> should clamp at 1 (not overflow)
        delegate.onKey(downKey);
        Test.assertEqualMessage(view.getSelected(), 1, "Down key should clamp at 1");

        // Simulate UP key -> should return to 0 ("Yes")
        var upKey = new WatchUi.KeyEvent(WatchUi.KEY_UP, WatchUi.PRESS_TYPE_ACTION);
        delegate.onKey(upKey);
        Test.assertEqualMessage(view.getSelected(), 0, "Up key should move selection back to 0 (Yes)");

        // Simulate UP key again -> should clamp at 0 (not underflow)
        delegate.onKey(upKey);
        Test.assertEqualMessage(view.getSelected(), 0, "Up key should clamp at 0");

        return true;
    }

    // Tier 2: Test Options menu selection bounds clamping
    (:test)
    static function testOptionsMenuPointerClamping(logger as Test.Logger) as Boolean {
        var view = new OpenPlayerOptionsView();
        
        // Set options array with 3 items
        var options = ["Sync", "Settings", "About"];
        view.setOptions(options);

        // Setting a valid index
        view.setSelectedIndex(2);
        
        // Re-setting options with fewer items (e.g. 2 items) should clamp or not crash
        var smallerOptions = ["Sync", "Settings"];
        view.setOptions(smallerOptions);

        return true;
    }

    // Tier 2: Test Swipe navigation on ConfirmActionDelegate
    (:test)
    static function testConfirmActionSwipe(logger as Test.Logger) as Boolean {
        var view = new ConfirmActionView("Clear downloads?");
        var mockCb = new MockConfirmActionCallback();
        var delegate = new ConfirmActionDelegate(view, mockCb.method(:onConfirm));

        Test.assertEqualMessage(view.getSelected(), 0, "Initial selection is 0");

        // SWIPE_DOWN should navigate to next page (1)
        var swipeDown = new WatchUi.SwipeEvent(WatchUi.SWIPE_DOWN);
        delegate.onSwipe(swipeDown);
        Test.assertEqualMessage(view.getSelected(), 1, "Swipe down should move selection to 1");

        // SWIPE_UP should navigate back to previous page (0)
        var swipeUp = new WatchUi.SwipeEvent(WatchUi.SWIPE_UP);
        delegate.onSwipe(swipeUp);
        Test.assertEqualMessage(view.getSelected(), 0, "Swipe up should move selection to 0");

        return true;
    }

    // Tier 2: Test SyncState and playlist selection toggling
    (:test)
    static function testSyncStateSelectionToggle(logger as Test.Logger) as Boolean {
        var syncState = new SyncState();
        Test.assertEqualMessage(syncState.isPlaylistSelected("pl_1"), false, "Initial playlist should not be selected");

        syncState.addPlaylist("pl_1");
        Test.assertEqualMessage(syncState.isPlaylistSelected("pl_1"), true, "Playlist pl_1 should be selected after add");

        syncState.removePlaylist("pl_1");
        Test.assertEqualMessage(syncState.isPlaylistSelected("pl_1"), false, "Playlist pl_1 should not be selected after remove");

        syncState.togglePlaylist("pl_2");
        Test.assertEqualMessage(syncState.isPlaylistSelected("pl_2"), true, "Playlist pl_2 should be selected after toggle on");

        syncState.togglePlaylist("pl_2");
        Test.assertEqualMessage(syncState.isPlaylistSelected("pl_2"), false, "Playlist pl_2 should not be selected after toggle off");

        return true;
    }

    // Tier 2: Test track deserialization robustness when titles contain pipe characters
    (:test)
    static function testTrackDeserializationWithPipes(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();
        var playlistUuid = "abcdef1234567890abcdef1234567890";

        // Construct 2 tracks: 1 standard, 1 with a pipe in title
        // Format: id|serverId|name|albumName|artistName|durationSeconds|downloadSize|playlistId
        var standardRecord = "trk1|srv1|Normal Episode|Podcast Album|Artist Name|180|1024|" + playlistUuid;
        var pipedRecord = "trk2|srv2|Show #42 | Special Guest Interview|Podcast Album|Artist Name|240|2048|" + playlistUuid;

        var encoded = standardRecord + "\n" + pipedRecord;
        Application.Storage.setValue("synced_tracks_str", encoded);

        var tracks = storage.loadSyncedTracks();
        Test.assertEqualMessage(tracks.size(), 2, "Expected 2 tracks loaded");

        var t1 = tracks[0] as JellyfinTrack;
        Test.assertEqualMessage(t1.name, "Normal Episode", "Track 1 name mismatch");
        Test.assertEqualMessage(t1.durationSeconds, 180, "Track 1 duration mismatch");
        Test.assertEqualMessage(t1.downloadSize, 1024, "Track 1 size mismatch");
        Test.assertEqualMessage(t1.playlistId, playlistUuid, "Track 1 playlistId mismatch");

        var t2 = tracks[1] as JellyfinTrack;
        Test.assertEqualMessage(t2.name, "Show #42 Special Guest Interview", "Track 2 name mismatch");
        Test.assertEqualMessage(t2.durationSeconds, 240, "Track 2 duration mismatch");
        Test.assertEqualMessage(t2.downloadSize, 2048, "Track 2 size mismatch");
        Test.assertEqualMessage(t2.playlistId, playlistUuid, "Track 2 playlistId should be playlist UUID, not 0");

        return true;
    }

    // Tier 2: Test auto-healing of legacy corrupted '0' playlist IDs
    (:test)
    static function testCorruptedPlaylistIdHealing(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();
        var playlistUuid = "podcasts_uuid_12345";

        // Save active sync state with known playlist ID
        var syncState = new SyncState();
        syncState.addPlaylist(playlistUuid);
        storage.saveSyncState(syncState);

        // Corrupted track where playlistId was baked as "0"
        var corruptedRecord = "trk_corrupt|srv_c|Corrupted Title|Album|Artist|300|4096|0";
        Application.Storage.setValue("synced_tracks_str", corruptedRecord);

        var tracks = storage.loadSyncedTracks();
        Test.assertEqualMessage(tracks.size(), 1, "Expected 1 track loaded");

        var t = tracks[0] as JellyfinTrack;
        Test.assertEqualMessage(t.playlistId, playlistUuid, "Corrupted playlistId '0' should be auto-healed to active playlist UUID");

        return true;
    }
}
