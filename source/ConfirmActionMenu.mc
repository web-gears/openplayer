import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import ScaleHelper;

class ConfirmActionView extends WatchUi.View {
    private var _title;
    private var _selected;

    function initialize(title) {
        View.initialize();
        _title = title;
        _selected = 0;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titleY = ScaleHelper.topSafe(dc, 30, 45);
        var titleFont = Graphics.FONT_SMALL;
        var maxTitleW = dc.getWidth() - (ScaleHelper.listSideSafe(dc) * 2);
        if (dc.getTextWidthInPixels(_title, titleFont) > maxTitleW) {
            titleFont = Graphics.FONT_TINY;
        }
        var truncatedTitle = ScaleHelper.truncateText(dc, _title, titleFont, maxTitleW);
        dc.drawText(dc.getWidth() / 2, titleY, titleFont, truncatedTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var options = [
            WatchUi.loadResource($.Rez.Strings.labelYes) as String,
            WatchUi.loadResource($.Rez.Strings.labelNo) as String
        ];
        var rowH = ScaleHelper.scale(dc, 25);
        var spacing = ScaleHelper.scale(dc, 32);
        var y = ScaleHelper.scale(dc, 85);
        var sideInset = ScaleHelper.listSideSafe(dc);
        for (var i = 0; i < options.size(); i++) {
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(sideInset, y, dc.getWidth() - (sideInset * 2), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(sideInset + ScaleHelper.scale(dc, 15), y, Graphics.FONT_TINY, options[i], Graphics.TEXT_JUSTIFY_LEFT);
            y = y + spacing;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var hintY = ScaleHelper.bottomSafe(dc, 28, 42);
        var hintText = WatchUi.loadResource($.Rez.Strings.hintConfirm) as String;
        dc.drawText(dc.getWidth() / 2, hintY, Graphics.FONT_XTINY, hintText != null ? hintText : "ENTER: choose\nESC: cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getSelected() {
        return _selected;
    }

    function setSelected(idx) {
        _selected = idx;
    }
}

class ConfirmActionDelegate extends WatchUi.BehaviorDelegate {
    private var _view;
    private var _onConfirm;

    function initialize(view, onConfirm) {
        BehaviorDelegate.initialize();
        _view = view;
        _onConfirm = onConfirm;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    function onSwipe(evt) {
        if (evt.getDirection() == WatchUi.SWIPE_UP) { return onPreviousPage(); }
        if (evt.getDirection() == WatchUi.SWIPE_DOWN) { return onNextPage(); }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY = coords[1];
        var dc_w = System.getDeviceSettings().screenWidth;
        var scaleRatio = dc_w / 240.0;
        var startY = (85 * scaleRatio).toNumber();
        var spacing = (32 * scaleRatio).toNumber();
        var rowH = (28 * scaleRatio).toNumber();

        if (tapY >= startY && tapY <= startY + rowH) {
            _view.setSelected(0);
            return onSelect();
        } else if (tapY >= startY + spacing && tapY <= startY + spacing + rowH) {
            _view.setSelected(1);
            return onSelect();
        }
        return false;
    }

    function onSelect() {
        if (_view.getSelected() == 0 && _onConfirm != null) {
            _onConfirm.invoke();
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onPreviousPage() {
        if (_view.getSelected() > 0) {
            _view.setSelected(_view.getSelected() - 1);
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onNextPage() {
        if (_view.getSelected() < 1) {
            _view.setSelected(_view.getSelected() + 1);
            WatchUi.requestUpdate();
        }
        return true;
    }
}
