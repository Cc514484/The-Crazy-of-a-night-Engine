package states;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import sys.FileSystem;
import haxe.io.Path;
import mikolka.vslice.ui.MainMenuState;
import backend.ClientPrefs;
import backend.Paths;
import backend.MusicBeatState;
import openfl.display.BitmapData;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

#if DISCORD_ALLOWED
import backend.Discord.DiscordClient;
#end

/**
 * ArtGallery State สำหรับ FNF P-Slice / V-Slice Engine
 * รองรับ Touch Screen เต็มรูปแบบ (Mobile & Desktop) พร้อมปุ่มออกจากหน้านี้บนจอ (Exit/Back Button)
 */
class ArtGallery extends MusicBeatState
{
    var files:Array<String> = [];
    var currentSelection:Int = 0;
    var isFullScreen:Bool = false;
    var canEnterFull:Bool = true;
    var canChange:Bool = true;
    
    // กราฟิกพื้นหลังและข้อมูล
    var bgDesat:FlxSprite;
    var imageGroup:FlxSpriteGroup;
    var infoPanel:FlxSprite;
    var titleText:FlxText;
    var countText:FlxText;
    var hintText:FlxText;

    // ปุ่มสัมผัสบนจอ (On-Screen Touch Buttons) สำหรับผู้เล่นบนมือถือ
    var btnExit:FlxSprite;
    var btnExitText:FlxText;
    var btnLeft:FlxSprite;
    var btnLeftText:FlxText;
    var btnRight:FlxSprite;
    var btnRightText:FlxText;
    var touchGroup:FlxSpriteGroup;

    // ระบบจับ Gesture Swipe (ปัดนิ้วซ้าย-ขวา)
    var swipeStartX:Float = -1;
    var swipeStartY:Float = -1;
    var isSwiping:Bool = false;

    override function create()
    {
        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Viewing Art Gallery", null);
        #end

        FlxG.cameras.reset();

        // -------------------------------------------------------------
        // [แก้ไขจุดที่ 1]: เปิดโหมด TOUCH_POINT เพื่อให้อุปกรณ์มือถือส่งพิกัดนิ้วเข้า FlxG.touches
        // -------------------------------------------------------------
        #if FLX_TOUCH
        Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
        #else
        Multitouch.inputMode = MultitouchInputMode.NONE;
        #end

        FlxG.mouse.enabled = true;
        FlxG.mouse.visible = false; // ซ่อนเคอร์เซอร์เมาส์ แต่ยังคงรับ Event คลิกและทัชได้

        // พื้นหลังเมนูสีเทาเข้ม
        bgDesat = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bgDesat.color = 0xFF2A2A2A;
        bgDesat.scrollFactor.set(0, 0);
        bgDesat.screenCenter();
        add(bgDesat);

        // กลุ่มรูปภาพ
        imageGroup = new FlxSpriteGroup();
        add(imageGroup);

        // แถบข้อมูลด้านล่าง
        infoPanel = new FlxSprite(0, FlxG.height * 0.8).makeGraphic(FlxG.width, 150, 0xFF000000);
        infoPanel.alpha = 0.65;
        infoPanel.scrollFactor.set(0, 0);
        add(infoPanel);

        // ชื่อรูปภาพ
        titleText = new FlxText(0, infoPanel.y + 25, FlxG.width, "", 40);
        titleText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 2;
        titleText.scrollFactor.set(0, 0);
        add(titleText);

        // ตัวนับลำดับรูป (เช่น 1 / 5)
        countText = new FlxText(FlxG.width - 260, infoPanel.y + 12, 230, "", 24);
        countText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
        countText.borderSize = 2;
        countText.scrollFactor.set(0, 0);
        add(countText);

        // ข้อความแนะนำการควบคุม
        hintText = new FlxText(0, infoPanel.y + 95, FlxG.width, "[TAP / ENTER] Full View | [SWIPE / ARROWS] Browse | [BACK] Exit", 18);
        hintText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.LIGHT_GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        hintText.borderSize = 1.5;
        hintText.scrollFactor.set(0, 0);
        add(hintText);

        // -------------------------------------------------------------
        // [แก้ไขจุดที่ 2]: สร้างปุ่ม GUI บนจอ (ปุ่ม Back/Exit และปุ่มลูกศรซ้ายขวา)
        // -------------------------------------------------------------
        createTouchUI();

        loadImagesFromFolder();

        if (files.length > 0) {
            createGallery();
            changeSelection(0, false);
        } else {
            titleText.text = "No images found in assets/shared/images/Art/";
        }
        
        super.create();
    }

    /**
     * สร้างปุ่มทัชสกรีนบนจอ: ปุ่ม Exit/Back, ปุ่มเลื่อนซ้าย และปุ่มเลื่อนขวา
     */
    function createTouchUI()
    {
        touchGroup = new FlxSpriteGroup();
        touchGroup.scrollFactor.set(0, 0);

        // 1. ปุ่ม Exit / Back ที่มุมบนซ้าย สำหรับแตะออกจากหน้านี้
        btnExit = new FlxSprite(20, 20).makeGraphic(150, 52, 0xFF1E1E24);
        btnExit.alpha = 0.85;
        btnExit.scrollFactor.set(0, 0);
        touchGroup.add(btnExit);

        btnExitText = new FlxText(btnExit.x, btnExit.y + 12, btnExit.width, "< BACK", 22);
        btnExitText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnExitText.borderSize = 1.5;
        btnExitText.scrollFactor.set(0, 0);
        touchGroup.add(btnExitText);

        // 2. ปุ่มลูกศรซ้าย (<) บนจอ
        btnLeft = new FlxSprite(20, FlxG.height * 0.42).makeGraphic(65, 90, 0xFF1E1E24);
        btnLeft.alpha = 0.65;
        btnLeft.scrollFactor.set(0, 0);
        touchGroup.add(btnLeft);

        btnLeftText = new FlxText(btnLeft.x, btnLeft.y + 24, btnLeft.width, "<", 36);
        btnLeftText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnLeftText.scrollFactor.set(0, 0);
        touchGroup.add(btnLeftText);

        // 3. ปุ่มลูกศรขวา (>) บนจอ
        btnRight = new FlxSprite(FlxG.width - 85, FlxG.height * 0.42).makeGraphic(65, 90, 0xFF1E1E24);
        btnRight.alpha = 0.65;
        btnRight.scrollFactor.set(0, 0);
        touchGroup.add(btnRight);

        btnRightText = new FlxText(btnRight.x, btnRight.y + 24, btnRight.width, ">", 36);
        btnRightText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnRightText.scrollFactor.set(0, 0);
        touchGroup.add(btnRightText);

        add(touchGroup);
    }

    function loadImagesFromFolder()
    {
        var folderPath:String = "assets/shared/images/Art/";
        #if sys
        if (FileSystem.exists(folderPath)) {
            for (file in FileSystem.readDirectory(folderPath)) {
                var ext = Path.extension(file).toLowerCase();
                if (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif") {
                    files.push(file);
                }
            }
            files.sort((a, b) -> (a.toLowerCase() < b.toLowerCase() ? -1 : 1));
        }
        #end
    }

    function createGallery()
    {
        for (i in 0...files.length) {
            var fileName = files[i];
            var fullPath = "assets/shared/images/Art/" + fileName;
            var sprite = new FlxSprite();
            #if sys
            if (FileSystem.exists(fullPath)) {
                try {
                    var bmd:BitmapData = BitmapData.fromFile(fullPath);
                    sprite.loadGraphic(bmd);
                } catch(e:Dynamic) {
                    trace("Error loading: " + fileName);
                }
            }
            #end
            if (sprite.graphic != null) {
                sprite.antialiasing = ClientPrefs.data.antialiasing;
                sprite.ID = i;
                resetSpriteScale(sprite);
                imageGroup.add(sprite);
            }
        }
    }

    function resetSpriteScale(spr:FlxSprite)
    {
        if (spr != null && spr.graphic != null) {
            var targetH = FlxG.height * 0.52;
            var ratio = targetH / spr.frameHeight;
            spr.setGraphicSize(Std.int(spr.frameWidth * ratio));
            spr.updateHitbox();
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // ตรวจสอบอินพุตแป้นพิมพ์มาตรฐาน
        if (files.length > 0) {
            if (!isFullScreen && canChange) {
                if (controls.UI_LEFT_P) changeSelection(-1);
                if (controls.UI_RIGHT_P) changeSelection(1);
            }
            if (FlxG.keys.justPressed.ENTER && canEnterFull) toggleFullScreen();
        }

        // ปุ่ม Back จากแป้นพิมพ์หรือคอนโทรลเลอร์
        if (controls.BACK) {
            handleBackAction();
            return;
        }

        // -------------------------------------------------------------
        // [แก้ไขจุดที่ 3]: ระบบตรวจจับทัชสกรีนและการสัมผัสปุ่ม GUI
        // -------------------------------------------------------------
        checkTouchInput();
    }

    /**
     * สลับการทำงานเมื่อกดปุ่ม Back หรือแตะปุ่ม [BACK]
     */
    function handleBackAction()
    {
        if (isFullScreen) {
            toggleFullScreen();
        } else {
            exitGallery();
        }
    }

    /**
     * ออกจาก Art Gallery กลับสู่ MainMenuState
     */
    function exitGallery()
    {
        FlxG.sound.play(Paths.sound('cancelMenu'));
        // เอฟเฟกต์กระพริบปุ่มก่อนสลับ Scene
        FlxTween.color(btnExit, 0.15, FlxColor.WHITE, 0xFF1E1E24, {
            onComplete: function(t:FlxTween) {
                MusicBeatState.switchState(new MainMenuState());
            }
        });
    }

    /**
     * ระบบตรวจสอบการสัมผัส (Touch & Mouse Input System)
     */
    function checkTouchInput()
    {
        // 1. ตรวจจับจังหวะที่เพิ่งเริ่มแตะนิ้ว (Just Pressed)
        var justPressedPoint:FlxPoint = getTouchJustPressed();
        if (justPressedPoint != null) {
            swipeStartX = justPressedPoint.x;
            swipeStartY = justPressedPoint.y;
            isSwiping = true;

            // เช็คว่าแตะโดนปุ่ม BACK/EXIT หรือไม่
            if (isPointInSprite(swipeStartX, swipeStartY, btnExit)) {
                handleBackAction();
                return;
            }

            // ถ้าอยู่ใน Fullscreen แตะตรงไหนก็ได้เพื่อออก
            if (isFullScreen) {
                if (canEnterFull) toggleFullScreen();
                return;
            }

            // แตะปุ่มลูกศรซ้าย
            if (isPointInSprite(swipeStartX, swipeStartY, btnLeft)) {
                if (canChange) {
                    pulseButton(btnLeft);
                    changeSelection(-1);
                }
                return;
            }

            // แตะปุ่มลูกศรขวา
            if (isPointInSprite(swipeStartX, swipeStartY, btnRight)) {
                if (canChange) {
                    pulseButton(btnRight);
                    changeSelection(1);
                }
                return;
            }
        }

        // 2. ตรวจจับจังหวะที่ยกนิ้วขึ้น (Just Released) สำหรับคำนวณการ Swipe หรือ Tap
        var justReleasedPoint:FlxPoint = getTouchJustReleased();
        if (justReleasedPoint != null && isSwiping && !isFullScreen) {
            var diffX:Float = justReleasedPoint.x - swipeStartX;
            var diffY:Float = justReleasedPoint.y - swipeStartY;
            var swipeThreshold:Float = 45.0; // ระยะปัดขั้นต่ำ

            // ถ้าเป็นการปัดแนวนอน
            if (Math.abs(diffX) > swipeThreshold && Math.abs(diffX) > Math.abs(diffY)) {
                if (diffX > 0) {
                    if (canChange) changeSelection(-1); // ปัดขวา = รูปก่อนหน้า
                } else {
                    if (canChange) changeSelection(1);  // ปัดซ้าย = รูปถัดไป
                }
            } else if (Math.abs(diffX) < 15 && Math.abs(diffY) < 15) {
                // หากเป็นการแตะค้างอยู่กับที่ (Tap พื้นที่จอ)
                var leftZone = FlxG.width * 0.25;
                var rightZone = FlxG.width * 0.75;

                if (justReleasedPoint.x < leftZone) {
                    if (canChange) changeSelection(-1);
                } else if (justReleasedPoint.x > rightZone) {
                    if (canChange) changeSelection(1);
                } else {
                    // แตะกึ่งกลางหน้าจอ = เปิดโหมดดูภาพเต็มจอ
                    if (canEnterFull) toggleFullScreen();
                }
            }

            isSwiping = false;
            swipeStartX = -1;
            swipeStartY = -1;
        }
    }

    /**
     * ดึงพิกัดที่เพิ่งถูกแตะในเฟรมนี้ (รองรับทั้ง Mobile Touch และ Mouse)
     */
    function getTouchJustPressed():FlxPoint
    {
        #if FLX_TOUCH
        for (touch in FlxG.touches.list) {
            if (touch.justPressed)
                return new FlxPoint(touch.screenX, touch.screenY);
        }
        #end

        if (FlxG.mouse.justPressed)
            return new FlxPoint(FlxG.mouse.screenX, FlxG.mouse.screenY);

        return null;
    }

    /**
     * ดึงพิกัดที่เพิ่งยกนิ้วออกในเฟรมนี้
     */
    function getTouchJustReleased():FlxPoint
    {
        #if FLX_TOUCH
        for (touch in FlxG.touches.list) {
            if (touch.justReleased)
                return new FlxPoint(touch.screenX, touch.screenY);
        }
        #end

        if (FlxG.mouse.justReleased)
            return new FlxPoint(FlxG.mouse.screenX, FlxG.mouse.screenY);

        return null;
    }

    /**
     * ตรวจสอบว่าพิกัด (X, Y) อยู่ภายใน Sprite หรือไม่ พร้อม Hitbox Padding 10px สำหรับนิ้วมือ
     */
    function isPointInSprite(pointX:Float, pointY:Float, spr:FlxSprite):Bool
    {
        if (spr == null || !spr.visible) return false;
        var pad:Float = 10.0;
        return (pointX >= spr.x - pad && pointX <= spr.x + spr.width + pad &&
                pointY >= spr.y - pad && pointY <= spr.y + spr.height + pad);
    }

    /**
     * เอฟเฟกต์ปุ่มเด้งเมื่อสัมผัส
     */
    function pulseButton(spr:FlxSprite)
    {
        spr.scale.set(1.15, 1.15);
        FlxTween.cancelTweensOf(spr.scale);
        FlxTween.tween(spr.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.backOut});
    }

    function toggleFullScreen()
    {
        var currentArt:FlxSprite = null;
        imageGroup.forEach(function(spr:FlxSprite) if (spr.ID == currentSelection) currentArt = spr);

        if (currentArt == null || currentArt.graphic == null) return;

        isFullScreen = !isFullScreen;
        canChange = !isFullScreen;

        if (isFullScreen) FlxG.sound.play(Paths.sound('scrollMenu'));

        infoPanel.visible = titleText.visible = countText.visible = hintText.visible = !isFullScreen;
        btnLeft.visible = btnLeftText.visible = btnRight.visible = btnRightText.visible = !isFullScreen;

        if (isFullScreen) {
            btnExitText.text = "< CLOSE FULL";
            btnExit.alpha = 0.6;
            currentArt.scrollFactor.set(0, 0);
            imageGroup.forEach(function(spr:FlxSprite) if (spr.ID != currentSelection) spr.visible = false);

            var ratio = Math.min(FlxG.width / currentArt.frameWidth, FlxG.height / currentArt.frameHeight);
            currentArt.setGraphicSize(Std.int(currentArt.frameWidth * ratio));
            currentArt.updateHitbox();
            currentArt.x = (FlxG.width / 2) - (currentArt.width / 2);
            currentArt.y = (FlxG.height / 2) - (currentArt.height / 2);
        } else {
            btnExitText.text = "< BACK";
            btnExit.alpha = 0.85;
            currentArt.scrollFactor.set(1, 1);
            imageGroup.forEach(function(spr:FlxSprite) {
                spr.visible = true;
                resetSpriteScale(spr);
            });
            updatePositions(true);
            canEnterFull = false;
            new FlxTimer().start(0.4, function(tmr:FlxTimer) { canEnterFull = true; });
        }
    }

    function changeSelection(change:Int = 0, playSound:Bool = true)
    {
        var oldSelection = currentSelection;
        currentSelection = Std.int(FlxMath.bound(currentSelection + change, 0, files.length - 1));
        
        if (change != 0 && oldSelection == currentSelection) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            titleText.color = FlxColor.RED;
            FlxG.camera.shake(0.005, 0.1);
            FlxTween.cancelTweensOf(titleText);
            FlxTween.color(titleText, 0.2, FlxColor.RED, FlxColor.WHITE);
            return;
        }

        if (playSound && change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

        canChange = false;
        canEnterFull = false;

        updateTitleText(true); 
        countText.text = (currentSelection + 1) + " / " + files.length;
        hintText.alpha = 0.3;

        #if DISCORD_ALLOWED
        var fileName = Path.withoutExtension(files[currentSelection]);
        DiscordClient.changePresence("Viewing Art Gallery", "Looking at: " + fileName);
        #end

        updatePositions(false);
        new FlxTimer().start(0.4, function(tmr:FlxTimer) {
            canChange = true;
            canEnterFull = true;
            hintText.alpha = 1.0;
        });
    }

    function updateTitleText(punch:Bool = false)
    {
        if (files.length > 0) {
            var fileName = Path.withoutExtension(files[currentSelection]);
            var leftArrow = (currentSelection <= 0) ? "" : "< ";
            var rightArrow = (currentSelection >= files.length - 1) ? "" : " >";
            titleText.text = leftArrow + fileName + rightArrow;
            
            if (punch) {
                titleText.scale.set(1.1, 1.1);
                FlxTween.cancelTweensOf(titleText.scale);
                FlxTween.tween(titleText.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.backOut});
            }
        }
    }

    function updatePositions(immediate:Bool)
    {
        imageGroup.forEach(function(spr:FlxSprite) {
            if (spr != null) {
                var isCurrent = (spr.ID == currentSelection);
                var targetX = ((spr.ID - currentSelection) * FlxG.width) + (FlxG.width / 2) - (spr.width / 2);
                var targetY = (FlxG.height / 2) - (spr.height / 2) - 50;

                FlxTween.cancelTweensOf(spr);
                if (immediate) {
                    spr.x = targetX;
                    spr.y = targetY;
                    spr.alpha = isCurrent ? 1.0 : 0.0001;
                } else {
                    FlxTween.tween(spr, {x: targetX, y: targetY, alpha: isCurrent ? 1.0 : 0.0001}, 0.35, {
                        ease: FlxEase.quartOut
                    });
                }
            }
        });
    }

    override function destroy()
    {
        super.destroy();
    }
}
