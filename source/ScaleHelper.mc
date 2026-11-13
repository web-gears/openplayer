import Toybox.Lang;
import Toybox.System;
import Toybox.Math;
import Toybox.Graphics;

module ScaleHelper {
    function scale(dc, value as Number) as Number {
        return (value * dc.getWidth()) / 240;
    }

    function isRound() as Boolean {
        return System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
    }

    function topSafe(dc, squareY as Number, roundY as Number) as Number {
        return scale(dc, isRound() ? roundY : squareY);
    }

    function bottomSafe(dc, squareOffset as Number, roundOffset as Number) as Number {
        return dc.getHeight() - scale(dc, isRound() ? roundOffset : squareOffset);
    }

    function listSideSafe(dc) as Number {
        if (!isRound()) {
            return scale(dc, 10);
        }
        return scale(dc, 22);
    }

    function sideSafe(dc, y as Number) as Number {
        if (!isRound()) {
            return scale(dc, 10);
        }
        var r = (dc.getWidth() / 2.0).toFloat();
        var cy = (dc.getHeight() / 2.0).toFloat();
        var dy = (cy - y.toFloat()).abs();
        if (dy >= r) {
            return scale(dc, 25);
        }
        var chordHalf = Math.sqrt((r * r) - (dy * dy));
        var inset = (r - chordHalf).toNumber() + scale(dc, 8);
        var minInset = scale(dc, 12);
        return inset > minInset ? inset : minInset;
    }

    function truncateText(dc, text as String, font, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var ellipsis = "..";
        var elWidth = dc.getTextWidthInPixels(ellipsis, font);
        var targetWidth = maxWidth - elWidth;
        if (targetWidth <= 0) {
            return text;
        }
        var cur = text;
        while (cur.length() > 0 && dc.getTextWidthInPixels(cur, font) > targetWidth) {
            cur = cur.substring(0, cur.length() - 1);
        }
        return cur + ellipsis;
    }

    function splitString(text as String, delimiter as String) as Array {
        var result = [];
        var delimLen = delimiter.length();
        if (text.length() == 0) {
            return result;
        }

        while (true) {
            var idx = text.find(delimiter);
            if (idx == null) {
                result.add(text);
                break;
            }
            result.add(text.substring(0, idx));
            text = text.substring(idx + delimLen, text.length());
        }

        return result;
    }

    function wrapText(dc, text as String, font, maxWidth as Number) as Array {
        var lines = [];
        var paragraphs = splitString(text, "\n");
        for (var p = 0; p < paragraphs.size(); p++) {
            var para = paragraphs[p] as String;
            var words = splitString(para, " ");
            var currentLine = "";

            for (var i = 0; i < words.size(); i++) {
                var word = words[i];
                var testLine = currentLine.length() == 0 ? word : currentLine + " " + word;
                var fits = false;
                if (dc != null && font != null) {
                    fits = (dc.getTextWidthInPixels(testLine, font) <= maxWidth);
                } else {
                    fits = ((testLine.length() * 8) <= maxWidth);
                }

                if (fits) {
                    currentLine = testLine;
                } else {
                    if (currentLine.length() > 0) {
                        lines.add(currentLine);
                        var singleFits = (dc != null && font != null)
                            ? (dc.getTextWidthInPixels(word, font) <= maxWidth)
                            : ((word.length() * 8) <= maxWidth);
                        if (singleFits) {
                            currentLine = word;
                        } else {
                            lines.add(word);
                            currentLine = "";
                        }
                    } else {
                        lines.add(word);
                        currentLine = "";
                    }
                }
            }

            if (currentLine.length() > 0) {
                lines.add(currentLine);
            }
        }

        return lines;
    }

    //! Draws a bitmap scaled to targetW x targetH centered horizontally at y.
    //! Copies paletted bitmap resources onto a native-format BufferedBitmap
    //! before drawBitmap2 so CIQ 4.2+/5.x GPU devices do not throw palette errors.
    function drawCenteredScaledBitmap(
        dc,
        bitmap as Graphics.BitmapType,
        targetW as Number,
        targetH as Number,
        y as Number
    ) as Void {
        var origW = bitmap.getWidth();
        var origH = bitmap.getHeight();
        if (origW <= 0 || origH <= 0) {
            return;
        }
        var centerX = dc.getWidth() / 2;
        if (Graphics has :AffineTransform && dc has :drawBitmap2) {
            var sourceBitmap = bitmap;
            try {
                if (Graphics has :createBufferedBitmap) {
                    var bufRef = Graphics.createBufferedBitmap({
                        :width => origW,
                        :height => origH
                    });
                    var buf = bufRef.get() as Graphics.BufferedBitmap?;
                    if (buf != null) {
                        var bufDc = buf.getDc();
                        bufDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                        bufDc.clear();
                        bufDc.drawBitmap(0, 0, bitmap);
                        sourceBitmap = buf;
                    }
                }
                var transform = new Graphics.AffineTransform();
                transform.scale(targetW.toFloat() / origW.toFloat(), targetH.toFloat() / origH.toFloat());
                dc.drawBitmap2(
                    centerX - (targetW / 2),
                    y,
                    sourceBitmap,
                    {
                        :bitmapX => 0,
                        :bitmapY => 0,
                        :bitmapWidth => origW,
                        :bitmapHeight => origH,
                        :transform => transform
                    }
                );
                return;
            } catch (ex) {
                // Fall back to unscaled drawBitmap if device rejects transform or buffer
            }
        }
        dc.drawBitmap(centerX - (origW / 2), y, bitmap);
    }

    //! Returns false when device exposes Wi-Fi connectionInfo and Wi-Fi is NOT_INITIALIZED
    //! (no network configured on watch) and no LTE fallback is configured.
    //! Allows CONNECTION_STATE_NOT_CONNECTED because Garmin activates sleeping Wi-Fi during startSync().
    function isSyncTransportConfigured() as Boolean {
        var settings = System.getDeviceSettings();
        if (!(settings has :connectionInfo)) {
            return true;
        }
        var info = settings.connectionInfo;
        var wifi = info[:wifi];
        if (wifi == null) {
            return true;
        }
        if (wifi.state != System.CONNECTION_STATE_NOT_INITIALIZED) {
            return true;
        }
        var lte = info[:lte];
        if (lte != null && lte.state != System.CONNECTION_STATE_NOT_INITIALIZED) {
            return true;
        }
        return false;
    }
}
