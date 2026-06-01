import Toybox.Lang;

module ScaleHelper {
    function scale(dc, value as Number) as Number {
        return (value * dc.getWidth()) / 240;
    }

    function splitString(text as String, delimiter as String) as Array {
        var result = [];
        var delimLen = delimiter.length();

        while (text.length() > 0) {
            var idx = text.find(delimiter);
            if (idx == null) {
                result.add(text);
                break;
            }
            result.add(text.substring(0, idx));
            text = text.substring(idx + delimLen, text.length());
        }

        if (result.size() == 0) {
            result.add(text);
        }

        return result;
    }
}
