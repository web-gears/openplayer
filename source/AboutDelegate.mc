import Toybox.WatchUi;
import Toybox.Lang;

class AboutDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_LAP || key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }
}
