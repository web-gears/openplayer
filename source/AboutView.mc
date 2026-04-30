import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class AboutView extends WatchUi.View {
    private var _title as String = "OpenPlayer";
    private var _version as String = "1.0";
    private static var _qrCodeBitmap as Graphics.BitmapReference?;


    function initialize() {
        if (_qrCodeBitmap == null) {
            _qrCodeBitmap = WatchUi.loadResource($.Rez.Drawables.CoffeeQrCode) as Graphics.BitmapReference?;
        }
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.drawText(
            dc.getWidth() / 2,
            15,
            Graphics.FONT_MEDIUM,
            _title,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Version
        dc.drawText(
            dc.getWidth() / 2,
            42,
            Graphics.FONT_XTINY,
            "v" + _version,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Description
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            60,
            Graphics.FONT_XTINY,
            "© webgears.org",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Donation link
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            80,
            Graphics.FONT_TINY,
            "Support development:",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_qrCodeBitmap != null) {
            dc.drawBitmap(dc.getWidth() / 2 - 47, 110, _qrCodeBitmap);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            202,
            Graphics.FONT_XTINY,
            "http://t.ly/W-7jv",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Button hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - 20,
            Graphics.FONT_XTINY,
            "LAP: back",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {
    }
}
