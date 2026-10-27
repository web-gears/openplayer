import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Media;
import Toybox.Communications;

(:background)
class OpenPlayerApp extends Application.AudioContentProviderApp {
    private var _storage as StorageManager;
    private var _shuffle as Boolean = false;
    private var _repeatMode as Media.RepeatMode? = null;
    private var _mode as String = "music";

    function initialize() {
        AudioContentProviderApp.initialize();
        _storage = new StorageManager();
        _mode = _storage.getPlaybackMode();
        _shuffle = _storage.getShuffle();
        var rep = _storage.getRepeatMode();
        if (rep != null) {
            _repeatMode = rep as Media.RepeatMode;
        }
    }

    function getMode() as String {
        return _mode;
    }

    function isMusicMode() as Boolean {
        return _mode.equals("music");
    }

    function isPodcastMode() as Boolean {
        return _mode.equals("podcast");
    }

    function toggleMode() as Void {
        if (_mode.equals("music")) {
            _mode = "podcast";
        } else {
            _mode = "music";
        }
        _storage.savePlaybackMode(_mode);
    }

    function getModeToggleLabel() as String {
        return _mode.equals("music")
            ? (WatchUi.loadResource($.Rez.Strings.labelSwitchPodcast) as String)
            : (WatchUi.loadResource($.Rez.Strings.labelSwitchMusic) as String);
    }

    function setShuffle(on as Boolean) as Void {
        _shuffle = on;
        _storage.saveShuffle(on);
    }

    function getShuffle() as Boolean {
        return _shuffle;
    }

    function cycleRepeatMode() as Media.RepeatMode {
        if (_repeatMode == null || _repeatMode == Media.REPEAT_MODE_OFF) {
            _repeatMode = Media.REPEAT_MODE_ONE;
        } else if (_repeatMode == Media.REPEAT_MODE_ONE) {
            _repeatMode = Media.REPEAT_MODE_ALL;
        } else {
            _repeatMode = Media.REPEAT_MODE_OFF;
        }
        _storage.saveRepeatMode(_repeatMode as Number);
        return _repeatMode;
    }

    function getRepeatMode() as Media.RepeatMode {
        return _repeatMode != null ? _repeatMode : Media.REPEAT_MODE_OFF;
    }

    function onStart(state as Dictionary?) as Void {}

    function onStop(state as Dictionary?) as Void {}

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function getContentDelegate(playref) as Media.ContentDelegate {
        return new OpenPlayerContentDelegate();
    }

    function getSyncDelegate() as Communications.SyncDelegate? {
        return new OpenPlayerSyncDelegate();
    }

    function getPlaybackConfigurationView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new OpenPlayerConfigurePlaybackView();
        return [
            view,
            new OpenPlayerConfigurePlaybackDelegate(view),
        ];
    }

    function getInitialView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        var token = _storage.getAuthToken();
        if (token != null && token.length() > 0) {
            var view = new OpenPlayerConfigurePlaybackView();
            return [
                view,
                new OpenPlayerConfigurePlaybackDelegate(view),
            ];
        }
        if (_storage.isConfigured()) {
            var wizardView = new SettingsWizardView();
            wizardView.setStep(SettingsWizardView.STEP_GCM_CONNECT);
            return [wizardView, new SettingsWizardDelegate(wizardView)];
        }
        var wizardView = new SettingsWizardView();
        return [wizardView, new SettingsWizardDelegate(wizardView)];
    }

    function getSyncConfigurationView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        var syncView = new OpenPlayerConfigureSyncView();
        return [
            syncView,
            new OpenPlayerConfigureSyncDelegate(syncView),
        ];
    }

    static function setServer(url as String) as Void {
        var app = Application.getApp() as OpenPlayerApp;
        app.storage().setServer(url);
    }

    function storage() as StorageManager {
        return _storage;
    }
}

function getApp() as OpenPlayerApp {
    return Application.getApp() as OpenPlayerApp;
}
