import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.System;
import Toybox.Application;
import Toybox.Timer;

class SettingsWizardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SettingsWizardView;
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _serverUrl as String = "";
    private var _username as String = "";
    private var _password as String = "";
    private var _isActive as Boolean = false;

    private var _sessionId as String = "";
    private var _attemptCount as Number = 0;
    private var _tickTimer as Timer.Timer?;
    private static const MAX_ATTEMPTS = 10;
    private static const TIMEOUT_SECONDS = 300;

    private static const STEP_CHOICE = 10;
    private static const STEP_QR_LOADING = 11;
    private static const STEP_QR_DISPLAY = 12;
    private static const STEP_GCM_INFO = 5;
    private static const STEP_REVIEW = 3;
    private static const STEP_DONE = 4;

    function initialize(view as SettingsWizardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _serverUrl = _storage.getServer();
        _isActive = true;
        _attemptCount = 0;
    }

    function onHide() as Void {
        _isActive = false;
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }
    }

    function onShow() as Void {}

    function onKey(evt) as Lang.Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (key == WatchUi.KEY_LAP) { return onMenu(); }
        return false;
    }

    function onSelect() as Lang.Boolean {
        var step = _view.getStep();
        if (step == STEP_CHOICE) {
            startQrFlow();
            return true;
        }
        if (step == STEP_QR_LOADING) {
            _view.setStep(STEP_GCM_INFO);
            return true;
        }
        if (step == STEP_QR_DISPLAY) {
            fetchResult();
            return true;
        }
        if (step == STEP_GCM_INFO) {
            var username = _storage.getUsername();
            var password = _storage.getPassword();
            if (username.length() > 0 && password.length() > 0) {
                _username = username;
                _password = password;
                _serverUrl = _storage.getServer();
                _view.setServerUrl(_serverUrl);
                _view.setUsername(_username);
                _view.setPassword(_password);
                _view.clearError();
                saveSettings();
            } else {
                _view.setError("Set GCM settings first");
            }
            return true;
        }
        if (step == STEP_REVIEW) {
            saveSettings();
            return true;
        }
        if (step == STEP_DONE) {
            _isActive = false;
            var syncView = new OpenPlayerConfigureSyncView();
            var syncDelegate = new OpenPlayerConfigureSyncDelegate(syncView);
            WatchUi.switchToView(
                syncView,
                syncDelegate,
                WatchUi.SLIDE_IMMEDIATE
            );
            syncDelegate.onShow();
            return true;
        }
        return false;
    }

    function onBack() as Lang.Boolean {
        var step = _view.getStep();
        if (step == STEP_QR_LOADING) {
            if (_tickTimer != null) {
                _tickTimer.stop();
                _tickTimer = null;
            }
            _view.setStep(STEP_CHOICE);
            return true;
        }
        if (step == STEP_QR_DISPLAY) {
            _view.setStep(STEP_CHOICE);
            return true;
        }
        if (step == STEP_GCM_INFO) {
            _view.setStep(STEP_CHOICE);
            return true;
        }
        if (step == STEP_REVIEW) {
            _view.setStep(STEP_CHOICE);
            _view.clearError();
            return true;
        }
        if (step == STEP_CHOICE) {
            _isActive = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        if (step == STEP_DONE) {
            _isActive = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        return false;
    }

    function onNextPage() as Lang.Boolean {
        var step = _view.getStep();
        if (step == STEP_CHOICE) {
            _view.setStep(STEP_GCM_INFO);
            return true;
        }
        return false;
    }

    function onPreviousPage() as Lang.Boolean {
        var step = _view.getStep();
        if (step == STEP_CHOICE) {
            startQrFlow();
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        var step = _view.getStep();
        if (step == STEP_DONE) {
            _isActive = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        return false;
    }

    function onActionMenu() as Lang.Boolean {
        var step = _view.getStep();
        var menu = new WatchUi.ActionMenu(null);
        if (step == STEP_CHOICE) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "QR Code"}, "qr"));
            menu.addItem(new WatchUi.ActionMenuItem({:label => "GCM Settings"}, "gcm"));
        } else if (step == STEP_DONE) {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Done"}, "done"));
        } else {
            menu.addItem(new WatchUi.ActionMenuItem({:label => "Back"}, "back"));
        }
        WatchUi.showActionMenu(menu, new WizardActionMenuDelegate(self));
        return true;
    }

    function startTickTimer() as Void {
        if (_tickTimer == null) {
            _tickTimer = new Timer.Timer();
        }
        _tickTimer.start(method(:onTick), 10000, false);
    }

    function onTick() as Void {
        if (!_isActive) {
            if (_tickTimer != null) {
                _tickTimer.stop();
                _tickTimer = null;
            }
            return;
        }
        var step = _view.getStep();
        if (step != STEP_QR_DISPLAY) {
            if (_tickTimer != null) {
                _tickTimer.stop();
                _tickTimer = null;
            }
            return;
        }
        _view.tick();
        WatchUi.requestUpdate();
    }

    function startQrFlow() as Void {
        _attemptCount = 0;
        createSession();
    }

    function generateSessionId() as String {
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var result = "";
        for (var i = 0; i < 6; i++) {
            var idx = (System.getTimer() + i * 17) % chars.length();
            result = result + chars.substring(idx, idx + 1);
        }
        return result;
    }

    function createSession() as Void {
        _sessionId = generateSessionId();
        _attemptCount = _attemptCount + 1;

        _view.setStep(STEP_QR_LOADING);
        _view.showLoading();

        var url = "https://disposable.webgears.org/create";
        var body = {
            "sessionId" => _sessionId,
            "fields" => [
                {
                    "id" => "serverUrl",
                    "name" => "Jellyfin Server URL",
                    "type" => "text",
                    "required" => true,
                },
                {
                    "id" => "username",
                    "name" => "Jellyfin Username",
                    "type" => "text",
                    "required" => true,
                },
                {
                    "id" => "password",
                    "name" => "Jellyfin Password",
                    "type" => "password",
                    "required" => true,
                },
            ],
            "timeoutSeconds" => TIMEOUT_SECONDS,
        };

        Communications.makeWebRequest(
            url,
            body,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onCreateSessionResponse)
        );
    }

    function onCreateSessionResponse(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        _view.hideLoading();

        if (responseCode == 200 || responseCode == 201) {
            _view.setStep(STEP_QR_DISPLAY);
            _view.setSessionId(_sessionId);
            _view.setRemainingSeconds(TIMEOUT_SECONDS);
            _view.setStartTime(System.getTimer());
            startTickTimer();
            WatchUi.requestUpdate();
        } else if (responseCode == 409 && _attemptCount < MAX_ATTEMPTS) {
            createSession();
        } else if (responseCode == -400) {
            _view.setStep(STEP_QR_LOADING);
            _view.setError("Service unavailable\nESC: back");
        } else if (responseCode < 0) {
            _view.setStep(STEP_QR_LOADING);
            if (responseCode == -200) {
                _view.setError("No internet\nESC: back");
            } else if (responseCode == -201) {
                _view.setError("SSL error\nESC: back");
            } else if (responseCode == -104) {
                _view.setError("Connection timeout\nESC: back");
            } else if (responseCode == -105) {
                _view.setError("Server not found\nESC: back");
            } else {
                _view.setError("Network error\nESC: back");
            }
        } else {
            _view.setStep(STEP_QR_LOADING);
            _view.setError("Service unavailable\nESC: back");
        }
    }

    function fetchResult() as Void {
        if (_view.isTimedOut()) {
            _view.setStep(STEP_QR_DISPLAY);
            _view.setError("Timeout - ESC: back");
            WatchUi.requestUpdate();
            return;
        }

        _view.setTitle("Fetching...");
        _view.showLoading();

        var url = "https://disposable.webgears.org/result/" + _sessionId;

        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onFetchResultResponse)
        );
    }

    function onFetchResultResponse(
        responseCode as Number,
        data as Dictionary?
    ) as Void {
        _view.hideLoading();

        if (responseCode == 200 && data != null) {
            var values = data["values"] as Dictionary?;
            if (values != null) {
                var serverUrlVal = values["serverUrl"] as String?;
                var usernameVal = values["username"] as String?;
                var passwordVal = values["password"] as String?;

                if (serverUrlVal != null && usernameVal != null && passwordVal != null) {
                    _serverUrl = serverUrlVal;
                    _username = usernameVal;
                    _password = passwordVal;
                    _view.setStep(STEP_REVIEW);
                    _view.setServerUrl(_serverUrl);
                    _view.setServerUrlFilled(true);
                    _view.setUsername(_username);
                    _view.setPassword(_password);
                    return;
                }
            }
            _view.setStep(STEP_QR_DISPLAY);
            _view.setError(
                "Invalid data received\nENTER: retry | ESC: back"
            );
        } else if (responseCode < 0) {
            if (responseCode == -104) {
                _view.setError(
                    "Connection timeout\nENTER: retry | ESC: back"
                );
            } else if (responseCode == -105) {
                _view.setError(
                    "Server not found\nENTER: retry | ESC: back"
                );
            } else {
                _view.setError(
                    "Network error\nENTER: retry | ESC: back"
                );
            }
        } else {
            _view.setStep(STEP_QR_DISPLAY);
            _view.setError(
                "Cannot fetch data\nENTER: retry | ESC: back"
            );
        }
        WatchUi.requestUpdate();
    }

    function saveSettings() as Void {
        _view.showLoading();
        _storage.setServer(_serverUrl);

        _client.authenticate(_username, _password, method(:onAuthResult));
    }

    function onAuthResult(responseCode as Number, data as Dictionary?) as Void {
        _view.hideLoading();

        if (responseCode == 200) {
            _view.setStep(STEP_DONE);
            _client.getPlaylists(method(:onPlaylistsForWizard));
        } else if (responseCode == 401) {
            _view.setError("Invalid username or password");
        } else if (responseCode == -200) {
            _view.setError("No internet connection");
        } else if (responseCode == -201) {
            _view.setError("SSL error - check server URL");
        } else if (responseCode == -104) {
            _view.setError("Connection timeout");
        } else {
            _view.setError("Cannot connect to server");
        }
    }

    function onPlaylistsForWizard(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 200 && data != null) {
            var items = data["Items"] as Array?;
            if (items != null) {
                var ids = "";
                var names = "";
                var counts = "";
                for (var i = 0; i < items.size(); i++) {
                    var item = items[i] as Dictionary;
                    if (i > 0) {
                        ids = ids + ",";
                        names = names + "|";
                        counts = counts + ",";
                    }
                    ids = ids + (item["Id"] as String);
                    names = names + (item["Name"] as String);
                    var childCount = item["ChildCount"] as Number?;
                    counts = counts + (childCount != null ? childCount : 0);
                }
                _storage.savePendingPlaylistIds(ids);
                _storage.savePendingPlaylistNames(names);
                _storage.savePendingPlaylistCounts(counts);
                _storage.savePendingPlaylistResponseCode(responseCode);
            }
        } else {
            _storage.savePendingPlaylistResponseCode(responseCode);
        }
        WatchUi.requestUpdate();
    }
}

class WizardActionMenuDelegate extends WatchUi.ActionMenuDelegate {
    private var _delegate as SettingsWizardDelegate;

    function initialize(delegate as SettingsWizardDelegate) {
        ActionMenuDelegate.initialize();
        _delegate = delegate;
    }

    function onSelect(item as WatchUi.ActionMenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("qr")) {
            _delegate.onSelect();
        } else if (id.equals("gcm")) {
            _delegate.onNextPage();
        } else if (id.equals("done")) {
            _delegate.onSelect();
        } else if (id.equals("back")) {
            _delegate.onBack();
        }
    }

    function onBack() as Void {
    }
}
