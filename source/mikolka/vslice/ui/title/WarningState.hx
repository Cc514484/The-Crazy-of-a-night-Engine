package mikolka.vslice.ui.title;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import states.InitState;

class WarningState extends flixel.FlxState 
{
    var titleText:FlxText;
    var bodyText:FlxText;
    var hintText:FlxText;
    var canContinue:Bool = false;
    var isTransitioning:Bool = false;

    override public function create():Void
    {
        super.create();

        // Black Background
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(bg);

        // Big Red Title at the Top
        titleText = new FlxText(0, 100, FlxG.width, "WARNING", 72);
        titleText.setFormat(Paths.font("vcr.ttf"), 84, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 4;
        titleText.screenCenter(X);
        add(titleText);

        // White Warning Content (Centered)
        var warnMsg:String = "This mod contains flashing lights and disturbing content (Blood/Gore).\n"
            + "If you have epilepsy or are sensitive to violence,\n"
            + "please proceed with caution.";

        bodyText = new FlxText(0, 0, FlxG.width * 0.9, warnMsg, 32);
        bodyText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        bodyText.borderSize = 2;
        bodyText.screenCenter(XY); // Perfectly centered on screen
        bodyText.y += 30; // Slight offset so it doesn't overlap the title
        bodyText.alpha = 0;
        add(bodyText);

        // Footer Hint
        hintText = new FlxText(0, FlxG.height - 80, FlxG.width, "Press ENTER to Continue", 24);
        hintText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.GRAY, CENTER);
        hintText.screenCenter(X);
        add(hintText);

        // Entrance Animation
        FlxTween.tween(bodyText, {alpha: 1}, 1.0, {ease: FlxEase.quadInOut, onComplete: function(twn:FlxTween) {
            canContinue = true;
        }});
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // Direct Key Input to avoid crash from uninitialized controls
        if (canContinue && !isTransitioning && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE))
        {
            isTransitioning = true;
            
            // Fade out using a sprite to prevent camera alpha bugs
            var transitionOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            transitionOverlay.alpha = 0;
            add(transitionOverlay);
            
            FlxTween.tween(transitionOverlay, {alpha: 1}, 0.6, {onComplete: function(twn:FlxTween) {
                // Switch to InitState for game setup
                FlxG.switchState(new InitState()); 
            }});
        }
    }
}