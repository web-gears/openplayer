import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import ScaleHelper;

class AboutView extends WatchUi.View {
    private var _title as String = "OpenPlayer";
    private var _version as String = "2.0.41";
    private var _qrCodeBitmap as Graphics.BitmapType?;


    private var _cachedLabelSupportDev as String?;
    private var _cachedHintBack as String?;

    function initialize() {
        View.initialize();
        _cachedLabelSupportDev = WatchUi.loadResource($.Rez.Strings.labelSupportDev) as String;
        _cachedHintBack = WatchUi.loadResource($.Rez.Strings.hintBack) as String;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        if (_qrCodeBitmap == null) {
            _qrCodeBitmap = WatchUi.loadResource($.Rez.Drawables.CoffeeQrCode) as Graphics.BitmapType?;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        var titleY = ScaleHelper.topSafe(dc, 10, 10);
        dc.drawText(
            dc.getWidth() / 2,
            titleY,
            Graphics.FONT_SMALL,
            _title,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Version
        var versionY = ScaleHelper.topSafe(dc, 25, 35);
        dc.drawText(
            dc.getWidth() / 2,
            versionY,
            Graphics.FONT_XTINY,
            "v" + _version,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Description
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var descY = ScaleHelper.topSafe(dc, 40, 50);
        dc.drawText(
            dc.getWidth() / 2,
            descY,
            Graphics.FONT_XTINY,
            "© webgears.org",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Donation link
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var supportY = ScaleHelper.topSafe(dc, 58, 68);
        dc.drawText(
            dc.getWidth() / 2,
            supportY,
            Graphics.FONT_XTINY,
            _cachedLabelSupportDev != null ? _cachedLabelSupportDev : "Support:",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var qrSize = ScaleHelper.scale(dc, 76);
        var qrY = ScaleHelper.topSafe(dc, 80, 90);
        if (_qrCodeBitmap == null) {
            _qrCodeBitmap = WatchUi.loadResource($.Rez.Drawables.CoffeeQrCode) as Graphics.BitmapType?;
        }
        if (_qrCodeBitmap != null) {
            ScaleHelper.drawCenteredScaledBitmap(dc, _qrCodeBitmap, qrSize, qrSize, qrY);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var urlY = ScaleHelper.bottomSafe(dc, 45, 60);
        dc.drawText(
            dc.getWidth() / 2,
            urlY,
            Graphics.FONT_XTINY,
            "http://t.ly/W-7jv",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Button hint: COLOR_LT_GRAY for sunlight readability (WCAG AA)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var backHintY = ScaleHelper.bottomSafe(dc, 24, 38);
        dc.drawText(
            dc.getWidth() / 2,
            backHintY,
            Graphics.FONT_XTINY,
            _cachedHintBack != null ? _cachedHintBack : "BACK: Back",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {
        _qrCodeBitmap = null;
    }
}
