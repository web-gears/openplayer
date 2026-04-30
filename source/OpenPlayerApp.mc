import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Media;
import Toybox.Communications;

class OpenPlayerApp extends Application.AudioContentProviderApp {
    private var _storage as StorageManager;
    var currentPlaylist = null;

    function initialize() {
        AudioContentProviderApp.initialize();
        _storage = new StorageManager();
    }

    function onStart(state as Dictionary?) as Void {}

    function onStop(state as Dictionary?) as Void {}

    function getContentDelegate(playref) as Media.ContentDelegate {
        return new OpenPlayerContentDelegate();
    }

    function getSyncDelegate() as Communications.SyncDelegate? {
        return new OpenPlayerSyncDelegate();
    }

    function getPlaybackConfigurationView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        return [
            new OpenPlayerConfigurePlaybackView(),
            new OpenPlayerConfigurePlaybackDelegate(),
        ];
    }

    function getInitialView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        if (_storage.isConfigured()) {
            return [
                new OpenPlayerConfigurePlaybackView(),
                new OpenPlayerConfigurePlaybackDelegate(),
            ];
        } else {
            var wizardView = new SettingsWizardView();
            return [wizardView, new SettingsWizardDelegate(wizardView)];
        }
    }

    function getSyncConfigurationView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] {
        return [
            new OpenPlayerConfigureSyncView(),
            new OpenPlayerConfigureSyncDelegate(),
        ];
    }

    static function setServer(url as String) as Void {
        var app = Application.getApp() as OpenPlayerApp;
        app.storage().setServer(url);
    }

    static function setApiKey(key as String) as Void {
        var app = Application.getApp() as OpenPlayerApp;
        app.storage().setApiKey(key);
    }

    function storage() as StorageManager {
        return _storage;
    }
}

function getApp() as OpenPlayerApp {
    return Application.getApp() as OpenPlayerApp;
}
