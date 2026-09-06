import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import ScaleHelper;

class AboutView extends WatchUi.View {
    private var _title as String = "OpenPlayer";
    private var _version as String = "2.0.20";
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
            ScaleHelper.scale(dc, 15),
            Graphics.FONT_MEDIUM,
            _title,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Version
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.scale(dc, 42),
            Graphics.FONT_XTINY,
            "v" + _version,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Description
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.scale(dc, 60),
            Graphics.FONT_XTINY,
            "© webgears.org",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Donation link
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.scale(dc, 80),
            Graphics.FONT_TINY,
            "Support development:",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_qrCodeBitmap != null) {
            if (Graphics has :AffineTransform && dc has :drawBitmap2) {
                // 1. Get original integer dimensions as Floats
                var origW = _qrCodeBitmap.getWidth().toFloat();
                var origH = _qrCodeBitmap.getHeight().toFloat();

                // 2. Determine target size
                // Ensure these values are converted to Float for the math
                var targetW = ScaleHelper.scale(dc, _qrCodeBitmap.getWidth()).toFloat(); 
                var targetH = ScaleHelper.scale(dc, _qrCodeBitmap.getHeight()).toFloat(); // Replace with your target height variable

                // 3. Compute exact Float scaling factors
                var scaleFactorX = targetW / origW;
                var scaleFactorY = targetH / origH;

                // 4. Safely set up the AffineTransform matrix
                var transform = new Graphics.AffineTransform();
                transform.scale(scaleFactorX, scaleFactorY); // This alters 'transform' in place

                // 5. Structure the options dictionary safely 
                var bitmapOptions = {
                    :bitmapX => 0,
                    :bitmapY => 0,
                    :transform => transform
                };

                // 6. Draw clean and centered on the Fenix 8 Pro screen
                dc.drawBitmap2(
                    dc.getWidth() / 2 - ScaleHelper.scale(dc, 47), 
                    ScaleHelper.scale(dc, 110), 
                    _qrCodeBitmap, 
                    bitmapOptions
                );
            } else {
                dc.drawBitmap(dc.getWidth() / 2 - 47, 110, _qrCodeBitmap);
            }
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            ScaleHelper.scale(dc, 202),
            Graphics.FONT_XTINY,
            "http://t.ly/W-7jv",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Button hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - ScaleHelper.scale(dc, 20),
            Graphics.FONT_XTINY,
            "Back",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {
    }
}
