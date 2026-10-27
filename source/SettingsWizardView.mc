import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import ScaleHelper;

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
    private var _username as String = "";
    private var _password as String = "";
    private var _serverUrl as String = "";

    private static var _qrCodeBitmap as Graphics.BitmapReference?;

    private static const STEP_CHOICE = 10;
    private static const STEP_QR_LOADING = 11;
    private static const STEP_QR_DISPLAY = 12;
    private static const STEP_GCM_INFO = 5;
    static const STEP_GCM_CONNECT = 5;
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
        if (WatchUi.View has :setActionMenuIndicator) {
            setActionMenuIndicator({:enabled => true});
        }
    }

    private var _wrappedLines as Array = [];

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isLoading) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - ScaleHelper.scale(dc, 20), Graphics.FONT_MEDIUM, WatchUi.loadResource($.Rez.Strings.loadingMessage) as String, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var titleY = ScaleHelper.topSafe(dc, 12, 25);
        var titleFont = Graphics.FONT_SMALL;
        var maxTitleW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
        if (dc.getTextWidthInPixels(_title, titleFont) > maxTitleW) {
            titleFont = Graphics.FONT_TINY;
        }
        var truncatedTitle = ScaleHelper.truncateText(dc, _title, titleFont, maxTitleW);
        dc.drawText(dc.getWidth() / 2, titleY, titleFont, truncatedTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var msgY = ScaleHelper.topSafe(dc, 38, 52);
        var msgFont = Graphics.FONT_TINY;
        var maxMsgW = dc.getWidth() - ScaleHelper.scale(dc, ScaleHelper.isRound() ? 85 : 32);
        _wrappedLines = ScaleHelper.wrapText(dc, _message, msgFont, maxMsgW);
        var msgFontH = Graphics.getFontHeight(msgFont);
        var msgLineH = msgFontH + ScaleHelper.scale(dc, 3);
        for (var i = 0; i < _wrappedLines.size() && i < 3; i++) {
            dc.drawText(dc.getWidth() / 2, msgY + i * msgLineH, msgFont, _wrappedLines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var headerBottom = msgY + (_wrappedLines.size() > 0 ? (_wrappedLines.size() - 1) * msgLineH + msgFontH : 0);

        if (_step == STEP_CHOICE) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - ScaleHelper.scale(dc, 10), Graphics.FONT_MEDIUM, WatchUi.loadResource($.Rez.Strings.wizardChoiceQr) as String, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + ScaleHelper.scale(dc, 25), Graphics.FONT_MEDIUM, WatchUi.loadResource($.Rez.Strings.wizardChoiceGcm) as String, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_QR_LOADING) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, WatchUi.loadResource($.Rez.Strings.wizardQrLoading) as String, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_QR_DISPLAY) {
            var qrY = ScaleHelper.topSafe(dc, 68, 78);
            if (_qrCodeBitmap != null) {
                if (Graphics has :AffineTransform && dc has :drawBitmap2) {
                    var origW = _qrCodeBitmap.getWidth().toFloat();
                    var origH = _qrCodeBitmap.getHeight().toFloat();

                    var targetW = ScaleHelper.scale(dc, _qrCodeBitmap.getWidth()).toFloat(); 
                    var targetH = ScaleHelper.scale(dc, _qrCodeBitmap.getHeight()).toFloat();

                    var scaleFactorX = targetW / origW;
                    var scaleFactorY = targetH / origH;

                    var transform = new Graphics.AffineTransform();
                    transform.scale(scaleFactorX, scaleFactorY);

                    var bitmapOptions = {
                        :bitmapX => 0,
                        :bitmapY => 0,
                        :transform => transform
                    };

                    dc.drawBitmap2(
                        dc.getWidth() / 2 - ScaleHelper.scale(dc, 47), 
                        qrY, 
                        _qrCodeBitmap, 
                        bitmapOptions
                    );
                } else {
                    dc.drawBitmap(dc.getWidth() / 2 - 47, qrY, _qrCodeBitmap);
                }

                dc.drawText(dc.getWidth() / 2,  ScaleHelper.bottomSafe(dc, 45, 60), Graphics.FONT_MEDIUM, formatSessionId(), Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.drawRectangle(ScaleHelper.scale(dc, 50), qrY, dc.getWidth() - ScaleHelper.scale(dc, 100), ScaleHelper.scale(dc, 100));
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.drawText(dc.getWidth() / 2, qrY + ScaleHelper.scale(dc, 45), Graphics.FONT_TINY, "[QR]", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 45, 60), Graphics.FONT_TINY, formatSessionId(), Graphics.TEXT_JUSTIFY_CENTER);
            }
            var mins = _remainingSeconds / 60;
            var secs = _remainingSeconds % 60;
            var timeStr = mins + ":" + (secs < 10 ? "0" + secs : secs.toString());
            var remFormat = WatchUi.loadResource($.Rez.Strings.wizardTimeRemaining) as String;
            var remText = Lang.format(remFormat, [timeStr]);
            var legacyIdx = remText.find("{0}");
            if (legacyIdx != null) {
                remText = remText.substring(0, legacyIdx) + timeStr + remText.substring(legacyIdx + 3, remText.length());
            }
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 20, 32), Graphics.FONT_XTINY, remText, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_GCM_INFO) {
            var storage = new StorageManager();
            var server = storage.getServer();
            var username = storage.getUsername();
            if (server.length() > 0) {
                var maxTextW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
                var truncServer = ScaleHelper.truncateText(dc, server, Graphics.FONT_TINY, maxTextW);
                var truncUser = ScaleHelper.truncateText(dc, username, Graphics.FONT_TINY, maxTextW);
                dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 70, 85), Graphics.FONT_TINY, truncServer, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 95, 110), Graphics.FONT_TINY, truncUser, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 45, 62), Graphics.FONT_XTINY, WatchUi.loadResource($.Rez.Strings.wizardGcmEnterConnect) as String, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                var bodyFont = Graphics.FONT_TINY;
                var maxBodyW = dc.getWidth() - ScaleHelper.scale(dc, ScaleHelper.isRound() ? 50 : 24);
                var gcmText = WatchUi.loadResource($.Rez.Strings.wizardGcmUseGcm) as String;
                var gcmLines = ScaleHelper.wrapText(dc, gcmText, bodyFont, maxBodyW);
                var bodyFontH = Graphics.getFontHeight(bodyFont);
                var bodyLineH = bodyFontH + ScaleHelper.scale(dc, 4);
                var totalBodyH = (gcmLines.size() - 1) * bodyLineH + bodyFontH;

                var footerY = ScaleHelper.bottomSafe(dc, 45, 62);
                var availableSpace = footerY - headerBottom;
                if (totalBodyH > availableSpace && bodyFont != Graphics.FONT_XTINY) {
                    bodyFont = Graphics.FONT_XTINY;
                    bodyFontH = Graphics.getFontHeight(bodyFont);
                    bodyLineH = bodyFontH + ScaleHelper.scale(dc, 3);
                    gcmLines = ScaleHelper.wrapText(dc, gcmText, bodyFont, maxBodyW);
                    totalBodyH = (gcmLines.size() - 1) * bodyLineH + bodyFontH;
                }

                var gcmStartY = headerBottom + (availableSpace - totalBodyH) / 2;
                for (var k = 0; k < gcmLines.size(); k++) {
                    dc.drawText(dc.getWidth() / 2, gcmStartY + k * bodyLineH, bodyFont, gcmLines[k] as String, Graphics.TEXT_JUSTIFY_CENTER);
                }
                dc.drawText(dc.getWidth() / 2, footerY, Graphics.FONT_XTINY, WatchUi.loadResource($.Rez.Strings.wizardGcmCheckSettings) as String, Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 20, 35), Graphics.FONT_XTINY, WatchUi.loadResource($.Rez.Strings.wizardGcmEscBack) as String, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_REVIEW) {
            var maxValW = dc.getWidth() / 2 - ScaleHelper.scale(dc, 10);
            var serverVal = ScaleHelper.truncateText(dc, _serverUrl, Graphics.FONT_TINY, maxValW);
            var userVal = ScaleHelper.truncateText(dc, _username, Graphics.FONT_TINY, maxValW);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 50), ScaleHelper.topSafe(dc, 75, 90), Graphics.FONT_TINY, WatchUi.loadResource($.Rez.Strings.wizardReviewServer) as String, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 45), ScaleHelper.topSafe(dc, 75, 90), Graphics.FONT_TINY, serverVal, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 50), ScaleHelper.topSafe(dc, 100, 115), Graphics.FONT_TINY, WatchUi.loadResource($.Rez.Strings.wizardReviewUser) as String, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 45), ScaleHelper.topSafe(dc, 100, 115), Graphics.FONT_TINY, userVal, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 50), ScaleHelper.topSafe(dc, 125, 140), Graphics.FONT_TINY, WatchUi.loadResource($.Rez.Strings.wizardReviewPass) as String, Graphics.TEXT_JUSTIFY_RIGHT);
            var masked = "---";
            if (_password.length() > 0) {
                masked = "********";
            }
            dc.drawText(dc.getWidth() / 2 - ScaleHelper.scale(dc, 45), ScaleHelper.topSafe(dc, 125, 140), Graphics.FONT_TINY, masked, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 30, 48), Graphics.FONT_XTINY, WatchUi.loadResource($.Rez.Strings.wizardReviewSave) as String, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_step == STEP_DONE) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.topSafe(dc, 110, 125), Graphics.FONT_SMALL, WatchUi.loadResource($.Rez.Strings.wizardDoneStartSync) as String, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 30, 48), Graphics.FONT_XTINY, WatchUi.loadResource($.Rez.Strings.wizardDoneSyncNow) as String, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_errorMessage.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, ScaleHelper.bottomSafe(dc, 40, 58), Graphics.FONT_SYSTEM_XTINY, _errorMessage, Graphics.TEXT_JUSTIFY_CENTER);
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
        _wrappedLines = wrapText(_message, 200);
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

    function setUsername(username as String) as Void {
        _username = username;
    }

    function setPassword(password as String) as Void {
        _password = password;
    }

    function isServerUrlFilled() as Boolean {
        return _serverUrlFilled;
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
            _title = WatchUi.loadResource($.Rez.Strings.welcomeTitle) as String;
            _message = WatchUi.loadResource($.Rez.Strings.welcomeMessage) as String;
        } else if (_step == STEP_QR_LOADING) {
            _title = WatchUi.loadResource($.Rez.Strings.wizardQrTitle) as String;
            _message = WatchUi.loadResource($.Rez.Strings.wizardQrLoading) as String;
        } else if (_step == STEP_QR_DISPLAY) {
            _title = WatchUi.loadResource($.Rez.Strings.wizardQrTitle) as String;
            _message = WatchUi.loadResource($.Rez.Strings.wizardQrConfirm) as String;
        } else if (_step == STEP_GCM_INFO) {
            _title = WatchUi.loadResource($.Rez.Strings.wizardGcmTitle) as String;
            _message = WatchUi.loadResource($.Rez.Strings.wizardGcmConfigure) as String;
        } else if (_step == STEP_REVIEW) {
            _title = WatchUi.loadResource($.Rez.Strings.reviewTitle) as String;
            _message = WatchUi.loadResource($.Rez.Strings.reviewMessage) as String;
        } else if (_step == STEP_DONE) {
            _title = WatchUi.loadResource($.Rez.Strings.labelDone) as String;
            _message = WatchUi.loadResource($.Rez.Strings.syncComplete) as String;
        }
        _wrappedLines = wrapText(_message, 200);
    }

    private function formatSessionId() as String {
        var result = "";
        for (var i = 0; i < _sessionId.length(); i++) {
            var ch = _sessionId.substring(i, i + 1);
            if (ch.equals("0")) {
                result = result + "\u00D8";
            } else {
                result = result + ch;
            }
        }
        return result;
    }

    private function wrapText(text as String, maxWidth as Number) as Array {
        return ScaleHelper.wrapText(null, text, null, maxWidth);
    }
}
