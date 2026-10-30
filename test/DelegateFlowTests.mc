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

    // Tier 2: Test reconcileSyncedTracks updates existing tracks' playlistId and metadata from pendingTracks
    (:test)
    static function testReconcileUpdatesTrackMetadataAndPlaylistId(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();
        var podcastsUuid = "podcasts_guid_123456789";

        // Suppose existing tracks on disk have 1 track with corrupted '0' and 1 track with an old playlist id
        var track1 = "trk1|srv1|Episode 1|Album|Artist|180|1024|0";
        var track2 = "trk2|srv2|Episode 2 | Guest|Album|Artist|240|2048|other_playlist_id";
        Application.Storage.setValue("synced_tracks_str", track1 + "\n" + track2);

        // Fresh pending tracks from Jellyfin sync for "podcasts"
        var pending = [
            {
                "id" => "trk1",
                "serverId" => "srv1",
                "name" => "Episode 1",
                "albumName" => "Album",
                "artistName" => "Artist",
                "durationSeconds" => 180,
                "downloadSize" => 1024,
                "playlistId" => podcastsUuid
            },
            {
                "id" => "trk2",
                "serverId" => "srv2",
                "name" => "Episode 2 Guest",
                "albumName" => "Album",
                "artistName" => "Artist",
                "durationSeconds" => 240,
                "downloadSize" => 2048,
                "playlistId" => podcastsUuid
            }
        ];

        storage.reconcileSyncedTracks(pending, [podcastsUuid]);

        var updated = storage.loadSyncedTracks();
        Test.assertEqualMessage(updated.size(), 2, "Expected 2 tracks kept after reconcile");

        var u1 = updated[0] as JellyfinTrack;
        var u2 = updated[1] as JellyfinTrack;
        Test.assertEqualMessage(u1.playlistId, podcastsUuid, "Track 1 should be updated to podcastsUuid");
        Test.assertEqualMessage(u2.playlistId, podcastsUuid, "Track 2 should be updated to podcastsUuid");

        return true;
    }

    // Tier 2: Test PlaybackView retains distinct playlists even when only single playlist is selected for sync
    (:test)
    static function testPlaybackViewRetainsMultiplePlaylistsWithSingleSyncSelection(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();
        var podcastsUuid = "podcasts_uuid_99999";
        var testUuid = "test_uuid_00000";

        // Save 2 playlists in cached_playlists: _test and podcasts
        storage.savePlaylists([
            new JellyfinPlaylist(testUuid, "_test", 3),
            new JellyfinPlaylist(podcastsUuid, "podcasts", 21)
        ]);

        // User ONLY selected podcasts in sync screen
        var syncState = new SyncState();
        syncState.addPlaylist(podcastsUuid);
        storage.saveSyncState(syncState);

        // 3 tracks on disk: 2 belonging to podcastsUuid, 1 belonging to testUuid
        var trackRecord = "t1|s1|Ep 1|Alb|Art|100|1000|" + podcastsUuid + "\n" +
                          "t2|s2|Ep 2|Alb|Art|200|2000|" + podcastsUuid + "\n" +
                          "t3|s3|Ep 3 | Pipe Title|Alb|Art|300|3000|" + testUuid;
        Application.Storage.setValue("synced_tracks_str", trackRecord);

        var playbackView = new OpenPlayerConfigurePlaybackView();
        playbackView.loadData();

        var playlists = playbackView.getPlaylists();
        Test.assertEqualMessage(playlists.size(), 2, "Playback view should display both playlists that have tracks");

        var pl1 = playlists[0] as Dictionary;
        var pl2 = playlists[1] as Dictionary;
        Test.assertEqualMessage(pl1["id"], podcastsUuid, "First playlist should be podcastsUuid");
        Test.assertEqualMessage(pl1["name"], "podcasts", "First playlist name should be 'podcasts'");
        Test.assertEqualMessage(pl2["id"], testUuid, "Second playlist should be testUuid");
        Test.assertEqualMessage(pl2["name"], "_test", "Second playlist name should be '_test'");

        var tracks = playbackView.getTracks();
        Test.assertEqualMessage(tracks.size(), 3, "All 3 tracks should be preserved");
        Test.assertEqualMessage((tracks[0] as JellyfinTrack).playlistId, podcastsUuid, "Track 1 belongs to podcastsUuid");
        Test.assertEqualMessage((tracks[1] as JellyfinTrack).playlistId, podcastsUuid, "Track 2 belongs to podcastsUuid");
        Test.assertEqualMessage((tracks[2] as JellyfinTrack).playlistId, testUuid, "Track 3 belongs to testUuid");

        return true;
    }

    // Tier 2: Test PlaybackView heals orphaned '0' tracks when single valid playlist exists
    (:test)
    static function testPlaybackViewDominantPlaylistHealingWithoutSelectedIds(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();
        var podcastsUuid = "podcasts_uuid_99999";
        var testUuid = "test_uuid_00000";

        // Save 2 playlists in cached_playlists: _test (index 0) and podcasts
        storage.savePlaylists([
            new JellyfinPlaylist(testUuid, "_test", 0),
            new JellyfinPlaylist(podcastsUuid, "podcasts", 21)
        ]);

        // selectedPlaylistIds is EMPTY (e.g. fresh launch or unpopulated sync state)
        var syncState = new SyncState();
        storage.saveSyncState(syncState);

        // 4 tracks: 3 with podcastsUuid, 1 orphaned with '0' and a pipe in title
        var trackRecord = "t1|s1|Ep 1|Alb|Art|100|1000|" + podcastsUuid + "\n" +
                          "t2|s2|Ep 2|Alb|Art|200|2000|" + podcastsUuid + "\n" +
                          "t3|s3|Ep 3|Alb|Art|250|2500|" + podcastsUuid + "\n" +
                          "t4|s4|Ep 4 | Pipe Guest|Alb|Art|300|3000|0";
        Application.Storage.setValue("synced_tracks_str", trackRecord);

        var playbackView = new OpenPlayerConfigurePlaybackView();
        playbackView.loadData();

        var playlists = playbackView.getPlaylists();
        Test.assertEqualMessage(playlists.size(), 1, "Playback view should display exactly 1 playlist");

        var pl = playlists[0] as Dictionary;
        Test.assertEqualMessage(pl["name"], "podcasts", "Playlist name should be 'podcasts', never '_test' or 'P-0'");
        Test.assertEqualMessage(pl["id"], podcastsUuid, "Playlist id should be podcastsUuid");

        var tracks = playbackView.getTracks();
        Test.assertEqualMessage(tracks.size(), 4, "All 4 tracks should be preserved");
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i] as JellyfinTrack;
            Test.assertEqualMessage(t.playlistId, podcastsUuid, "All tracks should be unified to podcastsUuid");
        }

        return true;
    }

    // Tier 2: Test safe null handling on corrupt / malformed track and playlist records
    (:test)
    static function testStorageSafeNullHandlingOnCorruptRecords(logger as Test.Logger) as Boolean {
        var storage = new StorageManager();

        // 1. Corrupt cached_playlists (missing count, non-numeric count, extra pipes)
        Application.Storage.setValue("cached_playlists", "pl1|Name Without Count\npl2|Name With Pipe | Extra|not_a_num\npl3|Normal|15");
        var pls = storage.loadPlaylists();
        Test.assertEqualMessage(pls.size(), 3, "All 3 playlists should load without throwing");
        Test.assertEqualMessage((pls[0] as JellyfinPlaylist).trackCount, 0, "Non-numeric/missing count defaults to 0");
        Test.assertEqualMessage((pls[1] as JellyfinPlaylist).trackCount, 0, "Non-numeric count defaults to 0");
        Test.assertEqualMessage((pls[2] as JellyfinPlaylist).trackCount, 15, "Normal count is parsed");

        // 2. Corrupt synced_tracks_str with null/short fields and extra pipes
        Application.Storage.setValue("synced_tracks_str", "t1|s1|Track 1|Alb1|Art1|100|1000|pl1\nt2|s2|Track | With | Multiple | Pipes|Alb2|Art2|200|2000|pl2\nt3|s3|Short Track|Alb3|Art3|300");
        var tracks = storage.loadSyncedTracks();
        Test.assertMessage(tracks.size() >= 2, "Tracks should be loaded without throwing UnexpectedTypeException");

        // 3. Reconcile with unselected playlists retains unselected tracks
        storage.reconcileSyncedTracks([], ["pl1"]);
        var remaining = storage.loadSyncedTracks();
        // pl1 was selected and pending was empty -> t1 removed
        // pl2 was not selected -> t2 retained!
        var foundPl2 = false;
        for (var i = 0; i < remaining.size(); i++) {
            var t = remaining[i] as JellyfinTrack;
            if (t.playlistId.equals("pl2")) {
                foundPl2 = true;
            }
        }
        Test.assertEqualMessage(foundPl2, true, "Unselected playlist pl2 tracks must be retained during reconcile");

        return true;
    }
}
