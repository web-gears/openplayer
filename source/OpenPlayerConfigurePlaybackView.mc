import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class OpenPlayerConfigurePlaybackView extends WatchUi.View {
    private var _tracks as Array = [];
    private var _playlists as Array = [];
    private var _viewMode as String = "playlists";
    private var _selectedIndex as Number = 0;
    private var _trackSelectedIndex as Number = 0;
    private var _scrollOffset as Number = 0;
    private var _playlistIndexForTracks as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        loadData();
        var storage = new StorageManager();
        if (_viewMode.equals("tracks")) {
            _trackSelectedIndex = storage.getPlaybackTrackSelection();
            _scrollOffset = storage.getPlaybackTrackSelection();
        } else {
            _selectedIndex = storage.getPlaybackPlaylistSelection();
            _scrollOffset = storage.getPlaybackPlaylistSelection();
        }
    }

    function loadData() as Void {
        var storage = new StorageManager();
        _tracks = storage.loadSyncedTracks();
        
        var savedPlaylists = storage.loadPlaylists() as Array;
        var unique = [];
        var seenIds = [];
        
        for (var i = 0; i < _tracks.size(); i++) {
            var track = _tracks[i] as JellyfinTrack;
            var pid = track.playlistId;
            if (pid != null && pid.length() > 0) {
                var alreadySeen = false;
                for (var j = 0; j < seenIds.size(); j++) {
                    if ((seenIds[j] as String).equals(pid)) {
                        alreadySeen = true;
                        break;
                    }
                }
                if (!alreadySeen) {
                    seenIds.add(pid);
                    var playlistName = "P-" + pid.substring(0, 8);
                    for (var k = 0; k < savedPlaylists.size(); k++) {
                        var sp = savedPlaylists[k] as JellyfinPlaylist;
                        if (sp.id.equals(pid)) {
                            playlistName = sp.name;
                            break;
                        }
                    }
                    unique.add({
                        "id" => pid,
                        "name" => playlistName
                    });
                }
            }
        }
        _playlists = unique;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (_viewMode.equals("playlists")) {
            renderPlaylistList(dc);
        } else {
            renderTrackList(dc);
        }
    }

    private function renderPlaylistList(dc as Dc) as Void {
        if (_playlists.size() == 0) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 40, Graphics.FONT_MEDIUM, "No synced tracks\nMENU: Setup", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_selectedIndex > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, 35, Graphics.FONT_XTINY, "^ more above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.drawText(dc.getWidth() / 2, 20, Graphics.FONT_MEDIUM, "Select Playlist", Graphics.TEXT_JUSTIFY_CENTER);

        var visibleCount = 3;
        var startIdx = _selectedIndex;
        if (startIdx > _playlists.size() - visibleCount) {
            startIdx = _playlists.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var y = 60;
        for (var i = 0; i < visibleCount && startIdx + i < _playlists.size(); i++) {
            var idx = startIdx + i;
            var playlist = _playlists[idx] as Dictionary;
            if (idx == _selectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(5, y, dc.getWidth() - 10, 25);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(20, y, Graphics.FONT_TINY, (idx + 1) + ": " + (playlist["name"] as String), Graphics.TEXT_JUSTIFY_LEFT);
            y = y + 25;
        }

        if (startIdx + visibleCount < _playlists.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 65, Graphics.FONT_XTINY, "v more below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 50, Graphics.FONT_XTINY, "ENTER: select\nMENU: options", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function renderTrackList(dc as Dc) as Void {
        var playlistId = null;
        if (_viewMode.equals("tracks") && _playlistIndexForTracks < _playlists.size()) {
            playlistId = (_playlists[_playlistIndexForTracks] as Dictionary)["id"];
        }

        var filteredTracks = [];
        for (var i = 0; i < _tracks.size(); i++) {
            var track = _tracks[i] as JellyfinTrack;
            if (playlistId == null || (track.playlistId != null && track.playlistId.equals(playlistId))) {
                filteredTracks.add(track);
            }
        }

        if (filteredTracks.size() == 0) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, "No tracks", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var scrollOffset = _scrollOffset;

        // Keep selected track visible
        var visibleCount = 4;
        if (_trackSelectedIndex < scrollOffset) {
            scrollOffset = _trackSelectedIndex;
        } else if (_trackSelectedIndex >= scrollOffset + visibleCount) {
            scrollOffset = _trackSelectedIndex - visibleCount + 1;
        }
        _scrollOffset = scrollOffset;

        dc.drawText(dc.getWidth() / 2, 20, Graphics.FONT_MEDIUM, "Select Track", Graphics.TEXT_JUSTIFY_CENTER);

        var startIdx = scrollOffset;
        if (startIdx > filteredTracks.size() - visibleCount) {
            startIdx = filteredTracks.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var y = 60;
        for (var i = 0; i < visibleCount && startIdx + i < filteredTracks.size(); i++) {
            var idx = startIdx + i;
            var track = filteredTracks[idx] as JellyfinTrack;
            if (idx == _trackSelectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(5, y, dc.getWidth() - 10, 25);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(20, y, Graphics.FONT_TINY, (idx + 1) + ": " + track.name, Graphics.TEXT_JUSTIFY_LEFT);
            y = y + 25;
        }

        if (scrollOffset > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, 35, Graphics.FONT_XTINY, "^ more above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < filteredTracks.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 65, Graphics.FONT_XTINY, "v more below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 50, Graphics.FONT_XTINY, "LAP: playlists\nENTER: play", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function setMode(mode as String) as Void {
        var storage = new StorageManager();
        _viewMode = mode;
        if (mode.equals("tracks")) {
            _playlistIndexForTracks = _selectedIndex;
            _trackSelectedIndex = storage.getPlaybackTrackSelection();
            _scrollOffset = storage.getPlaybackTrackSelection();
        } else {
            _selectedIndex = storage.getPlaybackPlaylistSelection();
            _scrollOffset = storage.getPlaybackPlaylistSelection();
        }
        WatchUi.requestUpdate();
    }

    function setSelectedIndex(idx as Number) as Void {
        _selectedIndex = idx;
    }

    function setTrackSelectedIndex(idx as Number) as Void {
        _trackSelectedIndex = idx;
    }

    function getTrackSelectedIndex() as Number {
        return _trackSelectedIndex;
    }

    function setScrollOffset(offset as Number) as Void {
        _scrollOffset = offset;
    }

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    function getScrollOffset() as Number {
        return _scrollOffset;
    }

    function getViewMode() as String {
        return _viewMode;
    }

    function getSelectedPlaylistId() as String? {
        if (_selectedIndex < _playlists.size()) {
            return (_playlists[_selectedIndex] as Dictionary)["id"] as String?;
        }
        return null;
    }

    function getPlaylists() as Array {
        return _playlists;
    }

    function getTracks() as Array {
        return _tracks;
    }

    function getPlaylistIndexForTracks() as Number {
        return _playlistIndexForTracks;
    }
}
