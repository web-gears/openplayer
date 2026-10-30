import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import ScaleHelper;

class OpenPlayerConfigurePlaybackView extends WatchUi.View {
    private var _tracks as Array = [];
    private var _playlists as Array = [];
    private var _viewMode as String = "playlists";
    private var _selectedIndex as Number = 0;
    private var _trackSelectedIndex as Number = 0;
    private var _scrollOffset as Number = 0;
    private var _playlistIndexForTracks as Number = 0;

    private var _cachedLabelPlaylists as String?;
    private var _cachedLabelSelectTrack as String?;
    private var _cachedLabelMoreAbove as String?;
    private var _cachedLabelMoreBelow as String?;
    private var _cachedHintEnterSelect as String?;
    private var _cachedHintBackPlaylists as String?;
    private var _cachedLabelNoTracks as String?;
    private var _cachedHintPressEnterConnect as String?;
    private var _cachedHintMenuSettings as String?;
    private var _cachedHintNoSyncedTracks as String?;

    function initialize() {
        View.initialize();
        _cachedLabelPlaylists = WatchUi.loadResource($.Rez.Strings.labelPlaylists) as String;
        _cachedLabelSelectTrack = WatchUi.loadResource($.Rez.Strings.labelSelectTrack) as String;
        _cachedLabelMoreAbove = WatchUi.loadResource($.Rez.Strings.labelMoreAbove) as String;
        _cachedLabelMoreBelow = WatchUi.loadResource($.Rez.Strings.labelMoreBelow) as String;
        _cachedHintEnterSelect = WatchUi.loadResource($.Rez.Strings.hintEnterSelect) as String;
        _cachedHintBackPlaylists = WatchUi.loadResource($.Rez.Strings.hintBackPlaylists) as String;
        _cachedLabelNoTracks = WatchUi.loadResource($.Rez.Strings.labelNoTracks) as String;
        _cachedHintPressEnterConnect = WatchUi.loadResource($.Rez.Strings.hintPressEnterConnect) as String;
        _cachedHintMenuSettings = WatchUi.loadResource($.Rez.Strings.hintMenuSettings) as String;
        _cachedHintNoSyncedTracks = WatchUi.loadResource($.Rez.Strings.hintNoSyncedTracks) as String;
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
            clampAndSavePlaylistIndex(storage);
            _scrollOffset = _selectedIndex;
        }
        if (WatchUi.View has :setActionMenuIndicator) {
            setActionMenuIndicator({:enabled => true});
        }
    }

    private function clampAndSavePlaylistIndex(storage as StorageManager) as Void {
        if (_playlists.size() == 0) {
            _selectedIndex = 0;
        } else if (_selectedIndex >= _playlists.size()) {
            _selectedIndex = _playlists.size() - 1;
        }
        storage.savePlaybackPlaylistSelection(_selectedIndex);
    }

    function loadData() as Void {
        var storage = new StorageManager();
        _tracks = storage.loadSyncedTracks();
        
        var savedPlaylists = storage.loadPlaylists() as Array;
        if (savedPlaylists.size() == 0) {
            var rc = storage.getPendingPlaylistResponseCode();
            if (rc == 200) {
                var ids = storage.getPendingPlaylistIds();
                var names = storage.getPendingPlaylistNames();
                if (ids != null && names != null) {
                    var idArray = ScaleHelper.splitString(ids, ",");
                    var nameArray = ScaleHelper.splitString(names, "|");
                    var min = idArray.size();
                    if (nameArray.size() < min) { min = nameArray.size(); }
                    for (var i = 0; i < min; i++) {
                        savedPlaylists.add(new JellyfinPlaylist(idArray[i], nameArray[i], 0));
                    }
                }
            }
        }

        // Build name lookup map for all known playlists
        var playlistNameById = {};
        for (var k = 0; k < savedPlaylists.size(); k++) {
            var sp = savedPlaylists[k] as JellyfinPlaylist;
            if (sp.id != null && sp.id.length() > 0 && sp.name != null && sp.name.length() > 0) {
                playlistNameById[sp.id] = sp.name;
            }
        }
        var pIds = storage.getPendingPlaylistIds();
        var pNames = storage.getPendingPlaylistNames();
        if (pIds != null && pNames != null) {
            var idParts = ScaleHelper.splitString(pIds, ",");
            var nameParts = ScaleHelper.splitString(pNames, "|");
            var minP = idParts.size() < nameParts.size() ? idParts.size() : nameParts.size();
            for (var p = 0; p < minP; p++) {
                var pid = idParts[p] as String;
                if (playlistNameById[pid] == null) {
                    playlistNameById[pid] = nameParts[p] as String;
                }
            }
        }

        // Collect all distinct playlist IDs that have downloaded tracks
        var uniqueIds = [];
        var seenIds = {};
        for (var i = 0; i < _tracks.size(); i++) {
            var item = _tracks[i];
            var pid = null as String?;
            if (item instanceof JellyfinTrack) {
                pid = (item as JellyfinTrack).playlistId;
            } else if (item instanceof Dictionary) {
                pid = (item as Dictionary)["playlistId"] as String?;
            }
            if (pid != null && pid.length() > 0 && !pid.equals("0")) {
                if (seenIds[pid] == null) {
                    seenIds[pid] = true;
                    uniqueIds.add(pid);
                }
            }
        }

        // If there are tracks with missing/empty/zero playlistId, heal them if fallback is known
        var hasOrphanChanges = false;
        if (_tracks.size() > 0) {
            var fallbackId = null;
            if (uniqueIds.size() == 1) {
                fallbackId = uniqueIds[0] as String;
            } else if (uniqueIds.size() == 0) {
                var syncState = storage.loadSyncState();
                if (syncState.selectedPlaylistIds.size() == 1) {
                    fallbackId = syncState.selectedPlaylistIds[0] as String;
                } else if (savedPlaylists.size() == 1) {
                    fallbackId = (savedPlaylists[0] as JellyfinPlaylist).id;
                }
            }

            if (fallbackId != null) {
                for (var i = 0; i < _tracks.size(); i++) {
                    var item = _tracks[i];
                    if (item instanceof JellyfinTrack) {
                        var track = item as JellyfinTrack;
                        if (track.playlistId == null || track.playlistId.length() == 0 || track.playlistId.equals("0")) {
                            track.playlistId = fallbackId;
                            hasOrphanChanges = true;
                        }
                    } else if (item instanceof Dictionary) {
                        var dict = item as Dictionary;
                        var pVal = dict["playlistId"] as String?;
                        if (pVal == null || pVal.length() == 0 || pVal.equals("0")) {
                            dict["playlistId"] = fallbackId;
                            hasOrphanChanges = true;
                        }
                    }
                }
                if (seenIds[fallbackId] == null) {
                    seenIds[fallbackId] = true;
                    uniqueIds.add(fallbackId);
                }
            }
        }

        if (hasOrphanChanges) {
            storage.saveSyncedTracks(_tracks);
        }

        // Build _playlists containing EVERY playlist that has tracks
        var unique = [];
        for (var u = 0; u < uniqueIds.size(); u++) {
            var uid = uniqueIds[u] as String;
            var name = playlistNameById[uid] as String?;
            if (name == null || name.length() == 0) {
                name = getApp().isPodcastMode() ? "Podcasts" : "Playlist";
            }
            unique.add({
                "id" => uid,
                "name" => name
            });
        }

        _playlists = unique;

        if (_playlists.size() > 0 && _selectedIndex >= _playlists.size()) {
            _selectedIndex = _playlists.size() - 1;
            storage.savePlaybackPlaylistSelection(_selectedIndex);
        }
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
            var storage = new StorageManager();
            var token = storage.getAuthToken();
            if (token == null || token.length() == 0) {
                var server = storage.getServer();
                dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - ScaleHelper.scale(dc, 40), Graphics.FONT_MEDIUM, _cachedHintPressEnterConnect != null ? _cachedHintPressEnterConnect : "Press ENTER to\nconnect", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                var maxServerW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
                var truncatedServer = ScaleHelper.truncateText(dc, server != null ? server : "", Graphics.FONT_XTINY, maxServerW);
                dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + ScaleHelper.scale(dc, 30), Graphics.FONT_XTINY, truncatedServer, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 30, 45), Graphics.FONT_XTINY, _cachedHintMenuSettings != null ? _cachedHintMenuSettings : "MENU: Settings", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - ScaleHelper.scale(dc, 40), Graphics.FONT_MEDIUM, _cachedHintNoSyncedTracks != null ? _cachedHintNoSyncedTracks : "No synced tracks\nMENU: Setup", Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }

        if (_selectedIndex > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 6, 16), Graphics.FONT_XTINY, _cachedLabelMoreAbove != null ? _cachedLabelMoreAbove : "More above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        var titleY = ScaleHelper.topSafe(dc, 10, 20);
        var titleFont = Graphics.FONT_SMALL;
        var maxTitleW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
        var titleStr = _cachedLabelPlaylists != null ? _cachedLabelPlaylists : "Playlists";
        var truncatedTitle = ScaleHelper.truncateText(dc, titleStr, titleFont, maxTitleW);
        dc.drawText(dc.getWidth() / 2, titleY, titleFont, truncatedTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var visibleCount = 3;
        var startIdx = _selectedIndex;
        if (startIdx > _playlists.size() - visibleCount) {
            startIdx = _playlists.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var rowH = ScaleHelper.scale(dc, 25);
        var y = ScaleHelper.topSafe(dc, 48, 62);
        var sideInset = ScaleHelper.listSideSafe(dc);
        var maxTextWidth = dc.getWidth() - (sideInset * 2) - ScaleHelper.scale(dc, 14);
        for (var i = 0; i < visibleCount && startIdx + i < _playlists.size(); i++) {
            var idx = startIdx + i;
            var playlist = _playlists[idx] as Dictionary;
            var rawName = (idx + 1) + ": " + (playlist["name"] as String);
            var displayName = ScaleHelper.truncateText(dc, rawName, Graphics.FONT_TINY, maxTextWidth);

            if (idx == _selectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(sideInset, y, dc.getWidth() - (sideInset * 2), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(sideInset + ScaleHelper.scale(dc, 8), y, Graphics.FONT_TINY, displayName, Graphics.TEXT_JUSTIFY_LEFT);
            y = y + rowH;
        }

        if (startIdx + visibleCount < _playlists.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 45, 60), Graphics.FONT_XTINY, _cachedLabelMoreBelow != null ? _cachedLabelMoreBelow : "More below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 25, 40), Graphics.FONT_XTINY, _cachedHintEnterSelect != null ? _cachedHintEnterSelect : "ENTER: select", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function renderTrackList(dc as Dc) as Void {
        var playlistId = null;
        if (_viewMode.equals("tracks") && _playlistIndexForTracks < _playlists.size()) {
            playlistId = (_playlists[_playlistIndexForTracks] as Dictionary)["id"];
        }

        var filteredTracks = [];
        for (var i = 0; i < _tracks.size(); i++) {
            var item = _tracks[i];
            var tPid = null as String?;
            if (item instanceof JellyfinTrack) {
                tPid = (item as JellyfinTrack).playlistId;
            } else if (item instanceof Dictionary) {
                tPid = (item as Dictionary)["playlistId"] as String?;
            }
            if (playlistId == null || (tPid != null && tPid.equals(playlistId))) {
                filteredTracks.add(item);
            }
        }

        if (filteredTracks.size() == 0) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, _cachedLabelNoTracks != null ? _cachedLabelNoTracks : "No tracks", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var storage = new StorageManager();
        if (_trackSelectedIndex >= filteredTracks.size()) {
            _trackSelectedIndex = filteredTracks.size() - 1;
            _scrollOffset = _trackSelectedIndex;
            storage.savePlaybackTrackSelection(_trackSelectedIndex);
        } else if (_trackSelectedIndex < 0) {
            _trackSelectedIndex = 0;
            storage.savePlaybackTrackSelection(0);
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

        var titleY = ScaleHelper.topSafe(dc, 10, 20);
        var titleFont = Graphics.FONT_SMALL;
        var maxTitleW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
        var titleStr = _cachedLabelSelectTrack != null ? _cachedLabelSelectTrack : "Select track";
        var truncatedTitle = ScaleHelper.truncateText(dc, titleStr, titleFont, maxTitleW);
        dc.drawText(dc.getWidth() / 2, titleY, titleFont, truncatedTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var startIdx = scrollOffset;
        if (startIdx > filteredTracks.size() - visibleCount) {
            startIdx = filteredTracks.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var rowH = ScaleHelper.scale(dc, 25);
        var y = ScaleHelper.topSafe(dc, 48, 62);
        var sideInset = ScaleHelper.listSideSafe(dc);
        var maxTextWidth = dc.getWidth() - (sideInset * 2) - ScaleHelper.scale(dc, 14);
        for (var i = 0; i < visibleCount && startIdx + i < filteredTracks.size(); i++) {
            var idx = startIdx + i;
            var track = filteredTracks[idx] as JellyfinTrack;
            var rawTrackName = (idx + 1) + ": " + track.name;
            var displayTrackName = ScaleHelper.truncateText(dc, rawTrackName, Graphics.FONT_TINY, maxTextWidth);

            if (idx == _trackSelectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(sideInset, y, dc.getWidth() - (sideInset * 2), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(sideInset + ScaleHelper.scale(dc, 8), y, Graphics.FONT_TINY, displayTrackName, Graphics.TEXT_JUSTIFY_LEFT);
            y = y + rowH;
        }

        if (scrollOffset > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 6, 16), Graphics.FONT_XTINY, _cachedLabelMoreAbove != null ? _cachedLabelMoreAbove : "More above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < filteredTracks.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 45, 60), Graphics.FONT_XTINY, _cachedLabelMoreBelow != null ? _cachedLabelMoreBelow : "More below", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 25, 40), Graphics.FONT_XTINY, _cachedHintBackPlaylists != null ? _cachedHintBackPlaylists : "BACK: playlists", Graphics.TEXT_JUSTIFY_CENTER);
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
            clampAndSavePlaylistIndex(storage);
            _scrollOffset = _selectedIndex;
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
