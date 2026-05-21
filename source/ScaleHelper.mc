import Toybox.Lang;

module ScaleHelper {
    function scale(dc, value as Number) as Number {
        return (value * dc.getWidth()) / 240;
    }

    function splitString(text as String, delimiter as String) as Array {
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
