import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import ScaleHelper;

class OpenPlayerOptionsView extends WatchUi.View {
    private var _options as Array = [];
    private var _selectedIndex as Number = 0;
    private var _playlistId as String?;
    private var _pendingPopAfterConfirm as Boolean = false;

    private var _cachedLabelOptions as String?;
    private var _cachedLabelMoreAbove as String?;
    private var _cachedLabelMoreBelow as String?;
    private var _cachedHintChooseBack as String?;

    function initialize() {
        View.initialize();
        _cachedLabelOptions = WatchUi.loadResource($.Rez.Strings.labelOptions) as String;
        _cachedLabelMoreAbove = WatchUi.loadResource($.Rez.Strings.labelMoreAbove) as String;
        _cachedLabelMoreBelow = WatchUi.loadResource($.Rez.Strings.labelMoreBelow) as String;
        _cachedHintChooseBack = WatchUi.loadResource($.Rez.Strings.hintChooseBack) as String;
    }

    function setPlaylistId(id as String?) {
        _playlistId = id;
    }

    function onShow() as Void {
        if (_pendingPopAfterConfirm) {
            _pendingPopAfterConfirm = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function setOptions(options as Array) as Void {
        _options = options;
        var storage = new StorageManager();
        _selectedIndex = storage.getOptionsSelection();
        if (_selectedIndex >= options.size() && options.size() > 0) {
            _selectedIndex = options.size() - 1;
        }
        WatchUi.requestUpdate();
    }

    function setSelectedIndex(idx as Number) as Void {
        _selectedIndex = idx;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titleY = ScaleHelper.topSafe(dc, 12, 20);
        var titleFont = Graphics.FONT_SMALL;
        var maxTitleW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
        var titleStr = _cachedLabelOptions != null ? _cachedLabelOptions : "Options";
        var truncatedTitle = ScaleHelper.truncateText(dc, titleStr, titleFont, maxTitleW);
        dc.drawText(dc.getWidth() / 2, titleY, titleFont, truncatedTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var visibleCount = ScaleHelper.isRound() ? 3 : 5;
        var startIdx = _selectedIndex;
        if (startIdx > _options.size() - visibleCount) {
            startIdx = _options.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        var rowH = ScaleHelper.scale(dc, 25);
        var spacing = ScaleHelper.scale(dc, 30);
        var y = ScaleHelper.topSafe(dc, 45, 62);
        var sideInset = ScaleHelper.listSideSafe(dc);
        var maxTextWidth = dc.getWidth() - (sideInset * 2) - ScaleHelper.scale(dc, 16);
        for (var i = 0; i < visibleCount && startIdx + i < _options.size(); i++) {
            var optIdx = startIdx + i;
            if (optIdx == _selectedIndex) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(sideInset, y, dc.getWidth() - (sideInset * 2), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            var textToDraw = ScaleHelper.truncateText(dc, _options[optIdx] as String, Graphics.FONT_TINY, maxTextWidth);
            dc.drawText(sideInset + ScaleHelper.scale(dc, 8), y, Graphics.FONT_TINY, textToDraw, Graphics.TEXT_JUSTIFY_LEFT);
            y = y + spacing;
        }

        if (startIdx > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var topHintY = ScaleHelper.topSafe(dc, 4, 6);
            dc.drawText(dc.getWidth() / 2, topHintY, Graphics.FONT_XTINY, _cachedLabelMoreAbove != null ? _cachedLabelMoreAbove : "More above", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        if (startIdx + visibleCount < _options.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var bottomHintY = ScaleHelper.bottomSafe(dc, 35, 45);
            dc.drawText(dc.getWidth() / 2, bottomHintY, Graphics.FONT_XTINY, _cachedLabelMoreBelow != null ? _cachedLabelMoreBelow : "More below", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var bottomHintY = ScaleHelper.bottomSafe(dc, 32, 45);
            dc.drawText(dc.getWidth() / 2, bottomHintY, Graphics.FONT_XTINY, _cachedHintChooseBack != null ? _cachedHintChooseBack : "ENTER: choose\nESC: back", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onSelect_withIndex(idx as Number) as Void {
        if (idx >= _options.size()) {
            return;
        }
        var label = _options[idx] as String;
        var storage = new StorageManager();

        var settingsLabel = WatchUi.loadResource($.Rez.Strings.labelSettings) as String;
        var syncLabel = WatchUi.loadResource($.Rez.Strings.labelSyncPlaylists) as String;
        var removePlaylistLabel = WatchUi.loadResource($.Rez.Strings.labelRemovePlaylist) as String;
        var removeTrackLabel = WatchUi.loadResource($.Rez.Strings.labelRemoveTrack) as String;
        var aboutLabel = WatchUi.loadResource($.Rez.Strings.labelAbout) as String;
        var clearLabel = WatchUi.loadResource($.Rez.Strings.labelClearDownloads) as String;
        var switchPodcastLabel = WatchUi.loadResource($.Rez.Strings.labelSwitchPodcast) as String;
        var switchMusicLabel = WatchUi.loadResource($.Rez.Strings.labelSwitchMusic) as String;

        if (label.equals(settingsLabel) || label.equals("Settings")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var wizardView = new SettingsWizardView();
            WatchUi.pushView(
                wizardView,
                new SettingsWizardDelegate(wizardView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals(syncLabel) || label.equals("Sync playlists")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var syncView = new OpenPlayerConfigureSyncView();
            WatchUi.pushView(
                syncView,
                new OpenPlayerConfigureSyncDelegate(syncView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals(removePlaylistLabel) || label.equals("Remove this Playlist")) {
            if (_playlistId != null && _playlistId.length() > 0) {
                var confirmView = new ConfirmActionView(WatchUi.loadResource($.Rez.Strings.promptRemovePlaylist) as String);
                WatchUi.pushView(
                    confirmView,
                    new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmRemovePlaylist)),
                    WatchUi.SLIDE_IMMEDIATE
                );
            } else {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }

        } else if (label.equals(removeTrackLabel) || label.equals("Remove this Track")) {
            var currentIdx = storage.getOptionsTrackSelection();
            var tracks = storage.loadSyncedTracks();
            if (currentIdx >= 0 && currentIdx < tracks.size()) {
                var confirmView = new ConfirmActionView(WatchUi.loadResource($.Rez.Strings.promptRemoveTrack) as String);
                WatchUi.pushView(
                    confirmView,
                    new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmRemoveTrack)),
                    WatchUi.SLIDE_IMMEDIATE
                );
            } else {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
        } else if (label.equals(aboutLabel) || label.equals("About")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var aboutView = new AboutView();
            WatchUi.pushView(
                aboutView,
                new AboutDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (label.equals(switchPodcastLabel) || label.equals(switchMusicLabel) || label.equals("Switch to podcast mode") || label.equals("Switch to music mode")) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            getApp().toggleMode();
            WatchUi.showToast(
                getApp().isPodcastMode()
                    ? (WatchUi.loadResource($.Rez.Strings.toastPodcastMode) as String)
                    : (WatchUi.loadResource($.Rez.Strings.toastMusicMode) as String),
                null
            );
        } else if (label.equals(clearLabel) || label.equals("Clear All Downloads")) {
            var confirmView = new ConfirmActionView(WatchUi.loadResource($.Rez.Strings.promptClearDownloads) as String);
            WatchUi.pushView(
                confirmView,
                new ConfirmActionDelegate(confirmView, new Lang.Method(self, :onConfirmClearDownloads)),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onConfirmClearDownloads() as Void {
        var storage = new StorageManager();
        storage.clearDownloads();
        WatchUi.showToast(WatchUi.loadResource($.Rez.Strings.toastDownloadsCleared) as String, null);
        _pendingPopAfterConfirm = true;
    }

    function onConfirmRemovePlaylist() as Void {
        if (_playlistId != null && _playlistId.length() > 0) {
            var storage = new StorageManager();
            var syncState = storage.loadSyncState();
            syncState.removePlaylist(_playlistId);
            storage.saveSyncState(syncState);
            var tracks = storage.loadSyncedTracks();
            var remaining = [];
            for (var i = 0; i < tracks.size(); i++) {
                var track = tracks[i] as JellyfinTrack;
                if (track.playlistId == null || !track.playlistId.equals(_playlistId)) {
                    remaining.add(track);
                } else {
                    storage.deleteCachedItemByTitle(track.name);
                }
            }
            storage.saveSyncedTracks(remaining);
            storage.setPendingRemovePlaylistId(null);
            WatchUi.showToast(WatchUi.loadResource($.Rez.Strings.toastPlaylistRemoved) as String, null);
            _pendingPopAfterConfirm = true;
        }
    }

    function onConfirmRemoveTrack() as Void {
        var storage = new StorageManager();
        var currentIdx = storage.getOptionsTrackSelection();
        var tracks = storage.loadSyncedTracks();
        var filtered = [];
        for (var i = 0; i < tracks.size(); i++) {
            var t = tracks[i] as JellyfinTrack;
            if (_playlistId == null || (t.playlistId != null && t.playlistId.equals(_playlistId))) {
                filtered.add(t);
            }
        }
        if (currentIdx >= 0 && currentIdx < filtered.size()) {
            var removedTrack = filtered[currentIdx] as JellyfinTrack;
            storage.deleteCachedItemByTitle(removedTrack.name);
            var remaining = [];
            for (var j = 0; j < tracks.size(); j++) {
                var tr = tracks[j] as JellyfinTrack;
                if (tr.id != null && !tr.id.equals(removedTrack.id)) {
                    remaining.add(tr);
                }
            }
            storage.saveSyncedTracks(remaining);
            var newIdx = currentIdx;
            if (newIdx >= filtered.size() - 1 && filtered.size() > 1) {
                newIdx = filtered.size() - 2;
            } else if (filtered.size() <= 1) {
                newIdx = 0;
            }
            storage.saveCurrentTrackIndex(newIdx);
            storage.savePlaybackTrackSelection(newIdx);
            WatchUi.showToast(WatchUi.loadResource($.Rez.Strings.toastTrackRemoved) as String, null);
        }
        _pendingPopAfterConfirm = true;
    }
}

class OpenPlayerOptionsDelegate extends WatchUi.BehaviorDelegate {
    private var _options as Array = [];
    private var _view as OpenPlayerOptionsView?;
    private var _selectedIndex as Number = 0;

    function initialize(view as OpenPlayerOptionsView, options as Array) {
        BehaviorDelegate.initialize();
        _view = view;
        _options = options;
        var storage = new StorageManager();
        _selectedIndex = storage.getOptionsSelection();
        if (_selectedIndex >= options.size() && options.size() > 0) {
            _selectedIndex = options.size() - 1;
        }
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        if (evt.getDirection() == WatchUi.SWIPE_UP) { return onPreviousPage(); }
        if (evt.getDirection() == WatchUi.SWIPE_DOWN) { return onNextPage(); }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY = coords[1];
        var devSettings = System.getDeviceSettings();
        var dc_w = devSettings.screenWidth;
        var scaleRatio = dc_w / 240.0;
        var isRound = devSettings.screenShape == System.SCREEN_SHAPE_ROUND;
        var startY = ((isRound ? 62 : 45) * scaleRatio).toNumber();
        var rowH = (25 * scaleRatio).toNumber();
        var spacing = (30 * scaleRatio).toNumber();
        var visibleCount = isRound ? 3 : 5;

        var startIdx = _selectedIndex;
        if (startIdx > _options.size() - visibleCount) {
            startIdx = _options.size() - visibleCount;
        }
        if (startIdx < 0) {
            startIdx = 0;
        }

        for (var i = 0; i < visibleCount && startIdx + i < _options.size(); i++) {
            var rowTop = startY + (i * spacing);
            if (tapY >= rowTop && tapY <= rowTop + rowH) {
                var targetIdx = startIdx + i;
                _selectedIndex = targetIdx;
                var storage = new StorageManager();
                storage.saveOptionsSelection(_selectedIndex);
                if (_view != null) {
                    _view.setSelectedIndex(_selectedIndex);
                    _view.onSelect_withIndex(_selectedIndex);
                }
                return true;
            }
        }
        if (tapY < startY && startIdx > 0) {
            return onPreviousPage();
        } else if (tapY > startY + (visibleCount * spacing) && startIdx + visibleCount < _options.size()) {
            return onNextPage();
        }
        return false;
    }

    function onSelect() as Boolean {
        if (_view != null) {
            _view.onSelect_withIndex(_selectedIndex);
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_selectedIndex > 0) {
            _selectedIndex = _selectedIndex - 1;
            var storage = new StorageManager();
            storage.saveOptionsSelection(_selectedIndex);
            if (_view != null) {
                _view.setSelectedIndex(_selectedIndex);
            }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onNextPage() as Boolean {
        if (_selectedIndex < _options.size() - 1) {
            _selectedIndex = _selectedIndex + 1;
            var storage = new StorageManager();
            storage.saveOptionsSelection(_selectedIndex);
            if (_view != null) {
                _view.setSelectedIndex(_selectedIndex);
            }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onActionMenu() as Boolean {
        if (_view != null) {
            _view.onSelect_withIndex(_selectedIndex);
        }
        return true;
    }
}
