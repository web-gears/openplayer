import Toybox.WatchUi;
import Toybox.Lang;

class OpenPlayerPlaylistMenuView extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource($.Rez.Strings.labelSyncPlaylists) as String});
    }
}