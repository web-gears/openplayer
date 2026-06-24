using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.Graphics;
using ScaleHelper;

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

        dc.drawText(dc.getWidth() / 2, ScaleHelper.scale(dc, 50), Graphics.FONT_MEDIUM, _title, Graphics.TEXT_JUSTIFY_CENTER);

        var options = ["Yes", "No"];
        var rowH = ScaleHelper.scale(dc, 25);
        var spacing = ScaleHelper.scale(dc, 30);
        var y = ScaleHelper.scale(dc, 90);
        for (var i = 0; i < options.size(); i++) {
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(0, y, dc.getWidth(), rowH);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(ScaleHelper.scale(dc, 20), y, Graphics.FONT_TINY, options[i], Graphics.TEXT_JUSTIFY_LEFT);
            y = y + spacing;
        }
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
