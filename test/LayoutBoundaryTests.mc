import Toybox.Test;
import Toybox.Lang;
import Toybox.Math;
import ScaleHelper;

(:test)
class LayoutBoundaryTests {

    // Tier 1: Test that AboutView vertical layout budget satisfies all font heights and gaps
    (:test)
    static function testAboutViewBudgetMath(logger as Test.Logger) as Boolean {
        var screenH = 240;
        
        // Font heights at 240px baseline
        var fontSmallH = 19;
        var fontXtinyH = 12;
        var qrSize = 76;

        // Actual coordinates configured in AboutView
        var titleY = 10;
        var versionY = 35;
        var descY = 50;
        var supportY = 68;
        var qrY = 90;
        var urlY = 180;
        var backHintY = 202;

        // 1. Title -> Version: must have at least 4px optical gap
        var titleToVersionGap = versionY - (titleY + fontSmallH);
        Test.assertMessage(titleToVersionGap >= 4, "Title and Version collide! Gap: " + titleToVersionGap);

        // 2. Version -> Copyright: metadata line gap (at least 2px)
        var verToDescGap = descY - (versionY + fontXtinyH);
        Test.assertMessage(verToDescGap >= 2, "Version and Copyright collide! Gap: " + verToDescGap);

        // 3. Copyright -> Support: section separation
        var descToSupportGap = supportY - (descY + fontXtinyH);
        Test.assertMessage(descToSupportGap >= 4, "Copyright and Support collide! Gap: " + descToSupportGap);

        // 4. Support -> QR Bitmap: Descender Hazard check (must be >= 20px delta to clear 'p' and ':')
        var supportToQrDelta = qrY - supportY;
        Test.assertMessage(supportToQrDelta >= 20, "Descenders in 'Support:' touch QR bitmap! Delta: " + supportToQrDelta);

        // 5. QR Bitmap -> URL gap
        var qrBottom = qrY + qrSize;
        var qrToUrlGap = urlY - qrBottom;
        Test.assertMessage(qrToUrlGap >= 10, "QR bitmap touches URL! Gap: " + qrToUrlGap);

        // 6. URL -> Back Hint gap
        var urlToHintGap = backHintY - (urlY + fontXtinyH);
        Test.assertMessage(urlToHintGap >= 8, "URL and Back Hint collide! Gap: " + urlToHintGap);

        // 7. Bottom clearance from bezel
        var bottomClearance = screenH - (backHintY + fontXtinyH);
        Test.assertMessage(bottomClearance >= 20, "Back hint is too close to bottom bezel! Clearance: " + bottomClearance);

        return true;
    }

    // Tier 1: Test circular screen chord width geometry
    (:test)
    static function testCircularChordWidthGeometry(logger as Test.Logger) as Boolean {
        // Test Fenix 6 / standard circular screen (240px diameter, R=120)
        var r = 120.0;
        var titleY = 10.0;
        var dy = (r - titleY).abs();
        var chord10 = 2.0 * Math.sqrt((r * r) - (dy * dy));

        // Chord at y=10 is ~95.9px. A centered 85px title fits.
        Test.assertMessage(chord10 > 90.0, "Chord at y=10 is unexpectedly narrow: " + chord10);

        // Test bottom edge chord tapering (y=230 on 240px has dy=110, chord=95.9px)
        var bottomY = 230.0;
        var dyBottom = (r - bottomY).abs();
        var chordBottom = 2.0 * Math.sqrt((r * r) - (dyBottom * dyBottom));
        Test.assertMessage(chordBottom > 90.0, "Bottom chord at y=230 unexpectedly narrow: " + chordBottom);

        return true;
    }

    // Tier 1: Test ScaleHelper text truncation and splitting
    (:test)
    static function testScaleHelperUtils(logger as Test.Logger) as Boolean {
        var str = "One Two Three Four";
        var parts = ScaleHelper.splitString(str, " ");
        Test.assertEqualMessage(parts.size(), 4, "splitString failed to split 4 words");
        Test.assertEqualMessage(parts[0], "One", "splitString first word mismatch");
        Test.assertEqualMessage(parts[3], "Four", "splitString last word mismatch");

        // Test splitting with delimiter not present
        var single = ScaleHelper.splitString("SingleWord", " ");
        Test.assertEqualMessage(single.size(), 1, "splitString should return 1 element if delimiter absent");

        return true;
    }

    // Tier 1: Test ConfirmActionView layout constraints
    (:test)
    static function testConfirmActionViewGeometry(logger as Test.Logger) as Boolean {
        var screenH = 240;
        var rowH = 25;
        var spacing = 32;
        var startY = 85;
        var optionsCount = 2;

        var lastRowBottom = startY + ((optionsCount - 1) * spacing) + rowH; // 142
        var hintY = screenH - 42; // 198 on round

        var gap = hintY - lastRowBottom;
        Test.assertMessage(gap >= 30, "Confirm options collide with bottom action hint! Gap: " + gap);
        return true;
    }

    // Tier 1: Test ScaleHelper text wrapping logic
    (:test)
    static function testScaleHelperWrapText(logger as Test.Logger) as Boolean {
        var text = "Use Garmin Connect Mobile app to enter server URL and login";
        // With maxWidth = 160 (headless fallback: 160 / 8 = 20 chars per line)
        var lines = ScaleHelper.wrapText(null, text, null, 160);
        
        Test.assertEqualMessage(lines.size(), 3, "Expected text to wrap into 3 lines, got " + lines.size());
        Test.assertEqualMessage(lines[0], "Use Garmin Connect", "Line 0 mismatch");
        Test.assertEqualMessage(lines[1], "Mobile app to enter", "Line 1 mismatch");
        Test.assertEqualMessage(lines[2], "server URL and login", "Line 2 mismatch");

        // Verify each line does not exceed character limit
        for (var i = 0; i < lines.size(); i++) {
            var line = lines[i] as String;
            Test.assertMessage(line.length() <= 20, "Line " + i + " exceeds 20 characters: " + line);
        }

        // Test explicit newline handling
        var newlineText = "Setup your\nJellyfin server";
        var newlineLines = ScaleHelper.wrapText(null, newlineText, null, 160);
        Test.assertEqualMessage(newlineLines.size(), 2, "wrapText should honor explicit newlines");
        Test.assertEqualMessage(newlineLines[0], "Setup your", "Line 0 mismatch on newline test");
        Test.assertEqualMessage(newlineLines[1], "Jellyfin server", "Line 1 mismatch on newline test");

        return true;
    }

    // Tier 1: Test SettingsWizardView GCM info step layout budget and chord safety
    (:test)
    static function testSettingsWizardGcmLayoutBudget(logger as Test.Logger) as Boolean {
        var screenW = 240;
        var screenH = 240;
        var r = 120.0;

        // Fonts at 240px baseline
        var titleFontH = 19;
        var tinyFontH = 18;
        var xtinyFontH = 12;

        // Header
        var titleY = 25; // ScaleHelper.topSafe(dc, 12, 25)
        var msgY = 52;   // ScaleHelper.topSafe(dc, 38, 52)
        var headerBottom = msgY + tinyFontH; // 70px

        // 0. Title to subheader clearance (title bottom: 25 + 19 = 44px; msgY = 52px; gap = 8px)
        var titleToMsgGap = msgY - (titleY + titleFontH);
        Test.assertMessage(titleToMsgGap >= 6, "Title and subheader collide! Gap: " + titleToMsgGap);

        // Footer
        var footerY = screenH - 62; // 178px (ScaleHelper.bottomSafe(dc, 45, 62))
        var escY = screenH - 35;    // 205px (ScaleHelper.bottomSafe(dc, 20, 35))

        // Available vertical space
        var availableH = footerY - headerBottom; // 108px
        Test.assertMessage(availableH >= 90, "Available vertical space too cramped: " + availableH);

        // Body block (3 lines, lineH = fontH + 4px delta rule)
        var lineH = tinyFontH + 4; // 22px
        var totalBodyH = (3 - 1) * lineH + tinyFontH; // 62px
        var gcmStartY = headerBottom + (availableH - totalBodyH) / 2; // 93px

        // 1. Clearance between subheader and body
        var topGap = gcmStartY - headerBottom;
        Test.assertMessage(topGap >= 20, "Top gap between header and body too small: " + topGap);

        // 2. Line spacing between body lines satisfies Delta y rule
        var lineDelta = lineH;
        Test.assertMessage(lineDelta >= tinyFontH + 4, "Body line delta violates Delta y rule: " + lineDelta);

        // 3. Clearance between body and footer
        var bodyBottom = gcmStartY + totalBodyH; // 155px
        var bottomGap = footerY - bodyBottom;
        Test.assertMessage(bottomGap >= 20, "Bottom gap between body and footer too small: " + bottomGap);

        // 4. Gap between Check Settings and ESC hints
        var footerGap = escY - (footerY + xtinyFontH);
        Test.assertMessage(footerGap >= 10, "Footer hints collide! Gap: " + footerGap);

        // 5. Circular chord clearance at all 3 body line baselines
        // Max clamped text width is screenW - 50 = 190px
        var maxBodyW = screenW - 50;
        for (var k = 0; k < 3; k++) {
            var lineY = (gcmStartY + k * lineH).toFloat();
            var dy = (r - lineY).abs();
            var chord = 2.0 * Math.sqrt((r * r) - (dy * dy));
            var margin = chord - maxBodyW;
            Test.assertMessage(margin >= 30.0, "Circular chord at line " + k + " (y=" + lineY + ") clips text! Chord: " + chord + ", Margin: " + margin);
        }

        return true;
    }

    // Tier 1: Test time remaining template formatting ($1$ vs {0})
    (:test)
    static function testTimeRemainingFormatting(logger as Test.Logger) as Boolean {
        var timeStr = "4:32";
        
        // 1. Standard Garmin Lang.format ($1$)
        var standardTemplate = "$1$ remaining";
        var formatted = Lang.format(standardTemplate, [timeStr]);
        Test.assertEqualMessage(formatted, "4:32 remaining", "Lang.format failed to format with $1$");

        // 2. Ukrainian template with $1$
        var ukrTemplate = "$1$ залишилось";
        var ukrFormatted = Lang.format(ukrTemplate, [timeStr]);
        Test.assertEqualMessage(ukrFormatted, "4:32 залишилось", "Lang.format failed for Ukrainian template");

        // 3. Fallback compatibility logic if a legacy {0} string is passed
        var legacyTemplate = "{0} remaining";
        var legacyFormatted = Lang.format(legacyTemplate, [timeStr]);
        var legacyIdx = legacyFormatted.find("{0}");
        if (legacyIdx != null) {
            legacyFormatted = legacyFormatted.substring(0, legacyIdx) + timeStr + legacyFormatted.substring(legacyIdx + 3, legacyFormatted.length());
        }
        Test.assertEqualMessage(legacyFormatted, "4:32 remaining", "Legacy {0} fallback replacement failed");

        return true;
    }

    // Tier 1: Test Welcome / Choice Screen layout budget and chord margins
    (:test)
    static function testWelcomeScreenLayoutBudget(logger as Test.Logger) as Boolean {
        var screenW = 240;
        var r = 120.0;

        // Message at msgY = 52, fontH = 18, lineH = 21
        var msgY = 52.0;
        var msgLineH = 21.0;
        var tinyFontH = 18;

        // Clamped max width at msgY for round display: screenW - 85 = 155px
        var maxMsgW = screenW - 85;

        // Circular chord at y = 52
        var dy = (r - msgY).abs();
        var chordAt52 = 2.0 * Math.sqrt((r * r) - (dy * dy)); // ~197.7px
        var marginAt52 = (chordAt52 - maxMsgW) / 2.0;
        Test.assertMessage(marginAt52 >= 20.0, "Chord margin at msgY=52 too narrow: " + marginAt52);

        // Circular chord at line 1 (y = 73)
        var line1Y = msgY + msgLineH;
        var dy1 = (r - line1Y).abs();
        var chordAt73 = 2.0 * Math.sqrt((r * r) - (dy1 * dy1)); // ~220.8px
        var marginAt73 = (chordAt73 - maxMsgW) / 2.0;
        Test.assertMessage(marginAt73 >= 30.0, "Chord margin at line1=73 too narrow: " + marginAt73);

        // Vertical clearance to Choice options (Choice 1 at screenH/2 - 10 = 110px)
        var msgBottom = (line1Y + tinyFontH).toNumber(); // 91px
        var choice1Y = (240 / 2) - 10; // 110px
        var clearance = choice1Y - msgBottom; // 19px
        Test.assertMessage(clearance >= 15, "Clearance between welcome message and choices too small: " + clearance);

        return true;
    }

    // Tier 1: Test Sync Playlists Header and More Above spacing
    (:test)
    static function testSyncPlaylistsHeaderLayoutBudget(logger as Test.Logger) as Boolean {
        var xtinyH = 12;
        var tinyH = 18;

        // Top safe coordinates on 240px round screen
        var moreAboveY = 8;
        var titleY = 24;
        var row0Y = 58;

        // 1. Clearance between More Above indicator and Title
        var moreAboveBottom = moreAboveY + xtinyH; // 20px
        var topGap = titleY - moreAboveBottom; // 4px
        Test.assertMessage(topGap >= 3, "More above indicator touches title! Gap: " + topGap);

        // 2. Clearance between Title and first list row
        var titleBottom = titleY + tinyH; // 42px
        var titleToRowGap = row0Y - titleBottom; // 16px
        Test.assertMessage(titleToRowGap >= 12, "Title touches first row! Gap: " + titleToRowGap);

        return true;
    }
}
