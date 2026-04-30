import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class SettingsWizardView extends WatchUi.View {
    private var _step as Number = 0;
    private var _title as String = "";
    private var _message as String = "";
    private var _isLoading as Boolean = false;
    private var _errorMessage as String = "";
    private var _sessionId as String = "";
    private var _timeoutSeconds as Number = 300;
    private var _remainingSeconds as Number = 300;
    private var _startTime as Number = 0;
    private var _serverUrlFilled as Boolean = false;
    private var _apiKeyFilled as Boolean = false;
    private var _apiKey as String = "";
    private var _serverUrl as String = "";

    private static var _qrCodeBitmap as Graphics.BitmapReference?;

    private static const STEP_CHOICE = 10;
    private static const STEP_QR_LOADING = 11;
    private static const STEP_QR_DISPLAY = 12;
    private static const STEP_ENTER_DATA = 1;
    private static const STEP_REVIEW = 3;
    private static const STEP_DONE = 4;

    function initialize() {
        View.initialize();
        _step = STEP_CHOICE;
        if (_qrCodeBitmap == null) {
            _qrCodeBitmap = WatchUi.loadResource($.Rez.Drawables.DisposableFormQrCode) as Graphics.BitmapReference?;
        }
        updateStep();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isLoading) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 20, Graphics.FONT_MEDIUM, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.drawText(dc.getWidth() / 2, 20, Graphics.FONT_MEDIUM, _title, Graphics.TEXT_JUSTIFY_CENTER);

        var msgY = 55;
        var lines = wrapText(_message, dc.getWidth() - 20);
        for (var i = 0; i < lines.size() && i < 3; i++) {
            dc.drawText(dc.getWidth() / 2, msgY + i * 20, Graphics.FONT_TINY, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_step == STEP_CHOICE) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 10, Graphics.FONT_MEDIUM, "UP: QR code", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + 25, Graphics.FONT_MEDIUM, "DOWN: manual", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_QR_LOADING) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, "Creating session...", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_QR_DISPLAY) {
            if (_qrCodeBitmap != null) {
                dc.drawBitmap(dc.getWidth() / 2 - 47, 83, _qrCodeBitmap);
                dc.drawText(dc.getWidth() / 2,  dc.getHeight() - 60, Graphics.FONT_MEDIUM, _sessionId, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                dc.drawRectangle(50, 45, dc.getWidth() - 100, 100);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.drawText(dc.getWidth() / 2, 90, Graphics.FONT_TINY, "[QR]", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth() / 2, 155, Graphics.FONT_TINY, _sessionId, Graphics.TEXT_JUSTIFY_CENTER);
            }
            var mins = _remainingSeconds / 60;
            var secs = _remainingSeconds % 60;
            var timeStr = mins + ":" + (secs < 10 ? "0" + secs : secs.toString());
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 30, Graphics.FONT_XTINY, timeStr + " remaining", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_ENTER_DATA) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            var serverLabel = "UP: Server URL";
            var apiLabel = "DOWN: API Key";
            if (_serverUrlFilled) {
                serverLabel = serverLabel + "[ok]";
            }
            if (_apiKeyFilled) {
                apiLabel = apiLabel + "[ok]";
            }
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 30, Graphics.FONT_MEDIUM, serverLabel, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + 10, Graphics.FONT_MEDIUM, apiLabel, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 50, Graphics.FONT_XTINY, "ENTER: Review", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_REVIEW) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2 - 50, 100, Graphics.FONT_TINY, "Server:", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(dc.getWidth() / 2 - 45, 100, Graphics.FONT_TINY, _serverUrl, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() / 2 - 50, 125, Graphics.FONT_TINY, "API:", Graphics.TEXT_JUSTIFY_RIGHT);
            var masked = "---";
            if (_apiKeyFilled && _apiKey != null && _apiKey.length() > 4) {
                masked = "****" + _apiKey.substring(_apiKey.length() - 4, _apiKey.length());
            }
            dc.drawText(dc.getWidth() / 2 - 45, 125, Graphics.FONT_TINY, masked, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 50, Graphics.FONT_XTINY, "ENTER: save\nBACK: edit", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_DONE) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, 130, Graphics.FONT_MEDIUM, "[Start Sync]", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 50, Graphics.FONT_XTINY, "ENTER: sync now\nBACK: later", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_errorMessage.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 60, Graphics.FONT_SYSTEM_XTINY, _errorMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }

    function setStep(step as Number) as Void {
        _step = step;
        _errorMessage = "";
        updateStep();
        WatchUi.requestUpdate();
    }

    function getStep() as Number {
        return _step;
    }

    function setTitle(title as String) as Void {
        _title = title;
    }

    function setMessage(msg as String) as Void {
        _message = msg;
    }

    function setIsLoading(loading as Boolean) as Void {
        _isLoading = loading;
    }

    function setError(msg as String) as Void {
        _errorMessage = msg;
    }

    function clearError() as Void {
        _errorMessage = "";
    }

    function showLoading() as Void {
        _isLoading = true;
        WatchUi.requestUpdate();
    }

    function hideLoading() as Void {
        _isLoading = false;
        WatchUi.requestUpdate();
    }

    function setSessionId(id as String) as Void {
        _sessionId = id;
    }

    function setRemainingSeconds(seconds as Number) as Void {
        _remainingSeconds = seconds;
    }

    function setStartTime(time as Number) as Void {
        _startTime = time;
    }

    function setServerUrlFilled(filled as Boolean) as Void {
        _serverUrlFilled = filled;
    }

    function setServerUrl(url as String) as Void {
        _serverUrl = url;
    }

    function setApiKeyFilled(filled as Boolean) as Void {
        _apiKeyFilled = filled;
    }

    function setApiKey(apiKey as String) as Void {
        _apiKey = apiKey;
    }

    function isServerUrlFilled() as Boolean {
        return _serverUrlFilled;
    }

    function isApiKeyFilled() as Boolean {
        return _apiKeyFilled;
    }

    function tick() as Void {
        if (_step == STEP_QR_DISPLAY && _startTime > 0) {
            var now = System.getTimer();
            var elapsed = (now - _startTime) / 1000;
            _remainingSeconds = _timeoutSeconds - elapsed;
            if (_remainingSeconds < 0) {
                _remainingSeconds = 0;
            }
            WatchUi.requestUpdate();
        }
    }

    function isTimedOut() as Boolean {
        return _step == STEP_QR_DISPLAY && _remainingSeconds <= 0;
    }

private function updateStep() as Void {
        if (_step == STEP_CHOICE) {
            _title = "Setup";
            _message = "Choose method";
        } else if (_step == STEP_QR_LOADING) {
            _title = "QR Code";
            _message = "Creating session...";
        } else if (_step == STEP_QR_DISPLAY) {
            _title = "Scan QR Code";
            _message = "ENTER: confirm";
        } else if (_step == STEP_ENTER_DATA) {
            if (_serverUrlFilled || _apiKeyFilled) {
                _title = "Edit Data";
            } else {
                _title = "Enter Data";
            }
            _message = "UP/DOWN to choose";
        } else if (_step == STEP_REVIEW) {
            _title = "Review";
            _message = "Ready to connect?";
        } else if (_step == STEP_DONE) {
            _title = "Done";
            _message = "Settings Saved";
        }
    }

    private function wrapText(text as String, maxWidth as Number) as Array {
        var lines = [];
        var words = splitString(text, " ");
        var currentLine = "";

        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            if (currentLine.length() + word.length() + 1 > 30) {
                if (currentLine.length() > 0) {
                    lines.add(currentLine);
                }
                currentLine = word;
            } else {
                if (currentLine.length() > 0) {
                    currentLine = currentLine + " ";
                }
                currentLine = currentLine + word;
            }
        }

        if (currentLine.length() > 0) {
            lines.add(currentLine);
        }

        return lines;
    }

    private function splitString(text as String, delimiter as String) as Array {
        var result = [];
        var current = "";
        
        for (var i = 0; i < text.length(); i++) {
            var char = text.substring(i, i + 1);
            if (char.equals(delimiter)) {
                result.add(current);
                current = "";
            } else {
                current = current + char;
            }
        }
        
        if (current.length() > 0 || text.length() == 0) {
            result.add(current);
        }
        
        return result;
    }
}