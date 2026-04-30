import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.System;
import Toybox.Application;
import Toybox.Timer;

class UrlPickerDelegate extends WatchUi.TextPickerDelegate {
    private var _storage as StorageManager;

    function initialize(storage as StorageManager) {
        TextPickerDelegate.initialize();
        _storage = storage;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (changed && text.length() > 0) {
            _storage.setServer(text);
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

class ApiKeyPickerDelegate extends WatchUi.TextPickerDelegate {
    private var _storage as StorageManager;

    function initialize(storage as StorageManager) {
        TextPickerDelegate.initialize();
        _storage = storage;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (changed && text.length() > 0) {
            _storage.setApiKey(text);
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

class SettingsWizardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SettingsWizardView;
    private var _storage as StorageManager;
    private var _client as JellyfinClient;
    private var _serverUrl as String = "";
    private var _apiKey as String = "";
    private var _isActive as Boolean = false;

    private var _sessionId as String = "";
    private var _attemptCount as Number = 0;
    private var _tickTimer as Timer.Timer?;
    private static const MAX_ATTEMPTS = 10;
    private static const TIMEOUT_SECONDS = 300;

    private static const STEP_CHOICE = 10;
    private static const STEP_QR_LOADING = 11;
    private static const STEP_QR_DISPLAY = 12;
    private static const STEP_ENTER_DATA = 1;
    private static const STEP_REVIEW = 3;
    private static const STEP_DONE = 4;

    function initialize(view as SettingsWizardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _storage = new StorageManager();
        _client = new JellyfinClient(_storage);
        _serverUrl = _storage.getServer();
        _apiKey = _storage.getApiKey();
        _isActive = true;
        _attemptCount = 0;

        if (_serverUrl != null && _serverUrl.length() > 0) {
            _view.setServerUrlFilled(true);
            _view.setServerUrl(_serverUrl);
        }
        if (_apiKey != null && _apiKey.length() > 0) {
            _view.setApiKeyFilled(true);
            _view.setApiKey(_apiKey);
        }
    }

    function onHide() as Void {
        _isActive = false;
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }
    }

    function onShow() as Void {}

    private function refreshFilledFlags() as Void {
        var server = _storage.getServer();
        var apiKey = _storage.getApiKey();
        _view.setServerUrlFilled(server.length() > 0);
        _view.setApiKeyFilled(apiKey.length() > 0);
        if (apiKey.length() > 0) {
            _view.setApiKey(apiKey);
        }
        if (server.length() > 0) {
            _view.setServerUrl(server);
        }
    }

    function onKey(evt) as Lang.Boolean {
        var step = _view.getStep();
        var key = evt.getKey();

        if (step == STEP_CHOICE) {
            if (key == WatchUi.KEY_UP) {
                startQrFlow();
                return true;
            } else if (key == WatchUi.KEY_DOWN) {
                _view.setStep(STEP_ENTER_DATA);
                refreshFilledFlags();
                return true;
            }
            return false;
        }

        if (step == STEP_QR_LOADING) {
            if (key == WatchUi.KEY_ESC) {
                if (_tickTimer != null) {
                    _tickTimer.stop();
                    _tickTimer = null;
                }
                _isActive = false;
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return true;
            } else if (key == WatchUi.KEY_ENTER) {
                _view.setStep(STEP_ENTER_DATA);
                refreshFilledFlags();
                return true;
            }
            return false;
        }

        if (step == STEP_QR_DISPLAY) {
            if (key == WatchUi.KEY_ENTER) {
                fetchResult();
                return true;
            } else if (key == WatchUi.KEY_ESC) {
                _view.setStep(STEP_CHOICE);
                _view.setMessage("Choose method");
                return true;
            }
            return false;
        }

        if (key == WatchUi.KEY_START) {
            if (step == STEP_CHOICE) {
                _view.setStep(STEP_ENTER_DATA);
                refreshFilledFlags();
                return true;
            } else if (step == STEP_DONE) {
                _isActive = false;
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return true;
            }
        }

        if (key == WatchUi.KEY_LAP) {
            if (step == STEP_CHOICE) {
                _view.setStep(STEP_ENTER_DATA);
                refreshFilledFlags();
                return true;
            } else if (step == STEP_ENTER_DATA) {
                _isActive = false;
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return true;
            } else if (step == STEP_DONE) {
                _isActive = false;
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return true;
            }
        }

        if (key == WatchUi.KEY_UP) {
            if (step == STEP_ENTER_DATA) {
                openUrlPicker();
                return true;
            }
        } else if (key == WatchUi.KEY_DOWN) {
            if (step == STEP_ENTER_DATA) {
                openApiKeyPicker();
                return true;
            }
        } else if (key == WatchUi.KEY_ESC) {
            if (step == STEP_REVIEW) {
                _view.setStep(STEP_ENTER_DATA);
                _view.clearError();
                refreshFilledFlags();
                return true;
            } else if (step > 1 && step != STEP_REVIEW) {
                _view.setStep(step - 1);
                _view.clearError();
                return true;
            } else if (step == STEP_ENTER_DATA) {
                _isActive = false;
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return true;
            } else {
                return false;
            }
        } else if (key == WatchUi.KEY_ENTER) {
            if (step == STEP_ENTER_DATA) {
                if (_serverUrl.length() == 0 && _apiKey.length() == 0) {
                    _view.setError("Enter at least one");
                    return true;
                }
                _view.setStep(STEP_REVIEW);
                _view.setMessage("Credentials updated");
                return true;
            } else if (step == STEP_REVIEW) {
                saveSettings();
                return true;
            } else if (step == STEP_DONE) {
                _isActive = false;
                var syncDelegate = new OpenPlayerConfigureSyncDelegate();
                var syncView = new OpenPlayerConfigureSyncView();
                WatchUi.switchToView(
                    syncView,
                    syncDelegate,
                    WatchUi.SLIDE_IMMEDIATE
                );
                syncDelegate.onShow();
                return true;
            }
        }

        return false;
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
                    "id" => "apiKey",
                    "name" => "Jellyfin API key",
                    "type" => "text",
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
        } else if (responseCode < 0) {
            _view.setStep(STEP_QR_LOADING);
            if (responseCode == -200) {
                _view.setError("No internet\nENTER: manual");
            } else if (responseCode == -201) {
                _view.setError("SSL error\nENTER: manual");
            } else if (responseCode == -104) {
                _view.setError("Connection timeout\nENTER: manual");
            } else if (responseCode == -105) {
                _view.setError("Server not found\nENTER: manual");
            } else {
                _view.setError("Network error\nENTER: manual");
            }
        } else {
            _view.setStep(STEP_QR_LOADING);
            _view.setError("Cannot reach service\nENTER: manual");
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
                var apiKeyVal = values["apiKey"] as String?;

                if (serverUrlVal != null && apiKeyVal != null) {
                    _serverUrl = serverUrlVal;
                    _apiKey = apiKeyVal;
                    _view.setStep(3);
                    _view.setServerUrl(_serverUrl);
                    _view.setServerUrlFilled(true);
                    _view.setApiKey(_apiKey);
                    _view.setApiKeyFilled(true);
                    return;
                }
            }
            _view.setStep(STEP_QR_DISPLAY);
            _view.setError(
                "Invalid data received\nMENU: retry | ESC: back | ENTER: manual"
            );
        } else if (responseCode < 0) {
            if (responseCode == -104) {
                _view.setError(
                    "Connection timeout\nMENU: retry | ESC: back | ENTER: manual"
                );
            } else if (responseCode == -105) {
                _view.setError(
                    "Server not found\nMENU: retry | ESC: back | ENTER: manual"
                );
            } else {
                _view.setError(
                    "Network error\nMENU: retry | ESC: back | ENTER: manual"
                );
            }
        } else {
            _view.setStep(STEP_QR_DISPLAY);
            _view.setError(
                "Cannot fetch data\nMENU: retry | ESC: back | ENTER: manual"
            );
        }
        WatchUi.requestUpdate();
    }

    function saveSettings() as Void {
        _view.showLoading();
        _storage.setServer(_serverUrl);
        _storage.setApiKey(_apiKey);

        _client.authenticate(method(:onAuthResult));
    }

    function onAuthResult(responseCode as Number, data as Dictionary?) as Void {
        _view.hideLoading();

        if (responseCode == 200) {
            _view.setStep(STEP_DONE);
            _client.getPlaylists(method(:onPlaylistsForWizard));
        } else if (responseCode == 401) {
            _view.setError("Invalid API key");
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
            if (items == null) {
                return;
            }
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
    }

    function startSync() as Void {
        var syncDelegate = new OpenPlayerConfigureSyncDelegate();
        WatchUi.switchToView(
            new OpenPlayerConfigureSyncView(),
            syncDelegate,
            WatchUi.SLIDE_IMMEDIATE
        );
        syncDelegate.onShow();
    }

    function openUrlPicker() as Void {
        var currentUrl = _storage.getServer();
        var picker = new WatchUi.TextPicker(currentUrl);
        WatchUi.pushView(
            picker,
            new UrlPickerDelegate(_storage),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function openApiKeyPicker() as Void {
        var currentKey = _storage.getApiKey();
        var picker = new WatchUi.TextPicker(currentKey);
        WatchUi.pushView(
            picker,
            new ApiKeyPickerDelegate(_storage),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}
