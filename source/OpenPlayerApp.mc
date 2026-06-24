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
