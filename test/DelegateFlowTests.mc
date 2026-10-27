import Toybox.Test;
import Toybox.WatchUi;
import Toybox.Lang;

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
}
