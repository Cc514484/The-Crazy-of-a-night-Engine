package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.input.touch.FlxTouch;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;
import sys.FileSystem;
import backend.MusicBeatState;
import backend.Paths;
import backend.Controls;
import mikolka.vslice.ui.MainMenuState;

#if DISCORD_ALLOWED
import backend.Discord.DiscordClient;
#end

using StringTools;

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
    
    // กราฟิกและวัตถุหน้าจอ
    var bgDesat:FlxSprite;
    var imageGroup:FlxSpriteGroup;
    var infoPanel:FlxSprite;
    var titleText:FlxText;
    var countText:FlxText;
    var hintText:FlxText;

    // ปุ่มสัมผัสบนจอ (On-Screen Touch Buttons) สำหรับมือถือ / ทัชสกรีน
    var btnExit:FlxSprite;
    var btnExitText:FlxText;
    var btnLeft:FlxSprite;
    var btnLeftText:FlxText;
    var btnRight:FlxSprite;
    var btnRightText:FlxText;
    var touchGroup:FlxSpriteGroup;

    // ตัวแปรสำหรับเช็ค Gesture Swipe (ปัดหน้าจอเพื่อเปลี่ยนรูป)
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
        // เปิดโหมด Touch Point สำหรับมือถือและทัชสกรีน
        // -------------------------------------------------------------
        #if FLX_TOUCH
        Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
        #else
        Multitouch.inputMode = MultitouchInputMode.NONE;
        #end

        FlxG.mouse.enabled = true;
        FlxG.mouse.visible = false;

        // พื้นหลังสีเทาไล่เฉดเข้มแบบ FNF Desat
        bgDesat = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bgDesat.color = 0xFF2A2A2A;
        bgDesat.scrollFactor.set(0, 0);
        bgDesat.setGraphicSize(Std.int(FlxG.width * 1.1), Std.int(FlxG.height * 1.1));
        bgDesat.updateHitbox();
        bgDesat.screenCenter();
        add(bgDesat);

        imageGroup = new FlxSpriteGroup();
        add(imageGroup);

        // แถบข้อมูลด้านล่าง (Info Panel)
        infoPanel = new FlxSprite(0, FlxG.height - 140).makeGraphic(FlxG.width, 140, 0xFF000000);
        infoPanel.alpha = 0.75;
        infoPanel.scrollFactor.set(0, 0);
        add(infoPanel);

        // ข้อความชื่อรูปภาพ
        titleText = new FlxText(0, infoPanel.y + 10, FlxG.width, "", 40);
        titleText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 2;
        titleText.scrollFactor.set(0, 0);
        add(titleText);

        // ตัวนับจำนวนรูปภาพ (เช่น 1 / 10)
        countText = new FlxText(FlxG.width - 260, infoPanel.y + 12, 230, "", 24);
        countText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
        countText.borderSize = 2;
        countText.scrollFactor.set(0, 0);
        add(countText);

        // คำแนะนำการควบคุม (แก้ไขจุดนี้เรียบร้อยแล้ว: ใช้ 0xFFCCCCCC)
        hintText = new FlxText(0, infoPanel.y + 95, FlxG.width, "[TAP / ENTER] Full View | [SWIPE / ARROWS] Browse | [BACK] Exit", 18);
        hintText.setFormat(Paths.font("vcr.ttf"), 18, 0xFFCCCCCC, CENTER, OUTLINE, FlxColor.BLACK);
        hintText.borderSize = 1.5;
        hintText.scrollFactor.set(0, 0);
        add(hintText);

        // -------------------------------------------------------------
        // สร้างปุ่มทัชสกรีนบนจอ (Touch UI + ปุ่ม EXIT)
        // -------------------------------------------------------------
        createTouchUI();

        // โหลดรูปภาพจากโฟลเดอร์ Art
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
     * สร้างปุ่มทัชสกรีนบนจอ: ปุ่ม Back/Exit, ปุ่มเลื่อนซ้าย และปุ่มเลื่อนขวา
     */
    function createTouchUI()
    {
        touchGroup = new FlxSpriteGroup();
        touchGroup.scrollFactor.set(0, 0);

        // 1. ปุ่ม Exit / Back ที่มุมบนซ้าย (แตะเพื่อออกจากหน้า Art Gallery)
        btnExit = new FlxSprite(20, 20).makeGraphic(150, 52, 0xFF1E1E24);
        btnExit.alpha = 0.85;
        btnExit.scrollFactor.set(0, 0);
        touchGroup.add(btnExit);

        btnExitText = new FlxText(btnExit.x, btnExit.y + 12, btnExit.width, "< BACK", 22);
        btnExitText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnExitText.borderSize = 1.5;
        btnExitText.scrollFactor.set(0, 0);
        touchGroup.add(btnExitText);

        // 2. ปุ่มเลื่อนไปทางซ้าย (Prev) สำหรับทัช
        btnLeft = new FlxSprite(20, FlxG.height * 0.42).makeGraphic(65, 90, 0xFF1E1E24);
        btnLeft.alpha = 0.65;
        btnLeft.scrollFactor.set(0, 0);
        touchGroup.add(btnLeft);

        btnLeftText = new FlxText(btnLeft.x, btnLeft.y + 24, btnLeft.width, "<", 36);
        btnLeftText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnLeftText.borderSize = 2;
        btnLeftText.scrollFactor.set(0, 0);
        touchGroup.add(btnLeftText);

        // 3. ปุ่มเลื่อนไปทางขวา (Next) สำหรับทัช
        btnRight = new FlxSprite(FlxG.width - 85, FlxG.height * 0.42).makeGraphic(65, 90, 0xFF1E1E24);
        btnRight.alpha = 0.65;
        btnRight.scrollFactor.set(0, 0);
        touchGroup.add(btnRight);

        btnRightText = new FlxText(btnRight.x, btnRight.y + 24, btnRight.width, ">", 36);
        btnRightText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        btnRightText.borderSize = 2;
        btnRightText.scrollFactor.set(0, 0);
        touchGroup.add(btnRightText);

        add(touchGroup);
    }

    /**
     * โหลดรายชื่อไฟล์รูปภาพจากโฟลเดอร์ Art
     */
    function loadImagesFromFolder()
    {
        files = [];
        #if sys
        var pathsToCheck:Array<String> = [
            "assets/shared/images/Art/",
            "assets/images/Art/",
            "mods/images/Art/"
        ];

        for (dir in pathsToCheck) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".png")) {
                        var nameOnly = file.substr(0, file.length - 4);
                        if (!files.contains(nameOnly)) {
                            files.push(nameOnly);
                        }
                    }
                }
            }
        }
        #end

        // หากยังไม่พบรูป ให้มีรายการตัวอย่างสำรอง
        if (files.length == 0) {
            files = ["menuDesat", "menuBG", "menuBGBlue", "menuBGMagenta"];
        }
    }

    function createGallery()
    {
        imageGroup.clear();

        for (i in 0...files.length) {
            var item:FlxSprite = new FlxSprite();
            
            var graphic = Paths.image('Art/' + files[i]);
            if (graphic == null) {
                graphic = Paths.image(files[i]);
            }

            if (graphic != null) {
                item.loadGraphic(graphic);
            } else {
                item.makeGraphic(480, 320, 0xFF333333);
            }

            item.ID = i;
            item.antialiasing = true;
            item.scrollFactor.set(0, 0);
            
            fitSpriteToScreen(item, 0.72);
            imageGroup.add(item);
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // จัดการอินพุตทัชสกรีนและเมาส์
        handleTouchInputs();

        if (files.length == 0) return;

        // การควบคุมด้วยคีย์บอร์ด / Gamepad
        if (canChange && !isFullScreen) {
            if (controls.UI_LEFT_P || FlxG.keys.justPressed.LEFT) {
                changeSelection(-1);
            } else if (controls.UI_RIGHT_P || FlxG.keys.justPressed.RIGHT) {
                changeSelection(1);
            }
        }

        // กด Enter / Space เพื่อเปิดหรือปิดโหมดดูเต็มจอ
        if (canEnterFull && (controls.ACCEPT || FlxG.keys.justPressed.SPACE)) {
            toggleFullScreen();
        }

        // กดปุ่มย้อนกลับ (ESC / BACK)
        if (controls.BACK) {
            exitGallery();
        }
    }

    /**
     * ระบบตรวจจับการสัมผัส (Touch Events, On-screen Buttons & Swipe Gesture)
     */
    function handleTouchInputs()
    {
        // -------------------------------------------------------------
        // ตรวจสอบการแตะปุ่มสัมผัสบนจอ (On-screen Buttons)
        // -------------------------------------------------------------
        #if FLX_TOUCH
        for (touch in FlxG.touches.list) {
            if (touch.justPressed) {
                // 1. แตะปุ่ม EXIT บนจอ
                if (isTouchInside(touch, btnExit)) {
                    animateButtonPress(btnExit);
                    exitGallery();
                    return;
                }
                // 2. แตะปุ่มเลื่อนซ้าย (<)
                if (!isFullScreen && isTouchInside(touch, btnLeft)) {
                    animateButtonPress(btnLeft);
                    changeSelection(-1);
                    return;
                }
                // 3. แตะปุ่มเลื่อนขวา (>)
                if (!isFullScreen && isTouchInside(touch, btnRight)) {
                    animateButtonPress(btnRight);
                    changeSelection(1);
                    return;
                }
            }
        }
        #end

        // รองรับเมาส์คลิกปุ่มบนจอ
        if (FlxG.mouse.justPressed) {
            if (isPointInside(FlxG.mouse.x, FlxG.mouse.y, btnExit)) {
                animateButtonPress(btnExit);
                exitGallery();
                return;
            }
            if (!isFullScreen && isPointInside(FlxG.mouse.x, FlxG.mouse.y, btnLeft)) {
                animateButtonPress(btnLeft);
                changeSelection(-1);
                return;
            }
            if (!isFullScreen && isPointInside(FlxG.mouse.x, FlxG.mouse.y, btnRight)) {
                animateButtonPress(btnRight);
                changeSelection(1);
                return;
            }
        }

        // -------------------------------------------------------------
        // ระบบตรวจจับการปัดหน้าจอ (Swipe Gesture) และแตะดูเต็มจอ (Tap to Fullscreen)
        // -------------------------------------------------------------
        #if FLX_TOUCH
        if (FlxG.touches.list.length > 0) {
            var primaryTouch:FlxTouch = FlxG.touches.list[0];

            if (primaryTouch.justPressed) {
                swipeStartX = primaryTouch.screenX;
                swipeStartY = primaryTouch.screenY;
                isSwiping = false;
            } else if (primaryTouch.pressed) {
                var deltaX = primaryTouch.screenX - swipeStartX;
                if (Math.abs(deltaX) > 20) {
                    isSwiping = true;
                }
            } else if (primaryTouch.justReleased) {
                var deltaX = primaryTouch.screenX - swipeStartX;
                var deltaY = primaryTouch.screenY - swipeStartY;

                // ตรวจว่าเป็นการปัด (Swipe) หรือไม่
                if (Math.abs(deltaX) > 60 && Math.abs(deltaX) > Math.abs(deltaY) * 1.2) {
                    if (!isFullScreen) {
                        if (deltaX > 0) {
                            changeSelection(-1); // ปัดขวา -> รูปก่อนหน้า
                        } else {
                            changeSelection(1);  // ปัดซ้าย -> รูปถัดไป
                        }
                    }
                } else if (!isSwiping && Math.abs(deltaX) < 20 && Math.abs(deltaY) < 20) {
                    // หากแตะเฉยๆ ที่บริเวณภาพ -> สลับโหมดเต็มจอ
                    if (swipeStartY < FlxG.height - 140 && swipeStartY > 80) {
                        toggleFullScreen();
                    }
                }
                swipeStartX = -1;
                swipeStartY = -1;
                isSwiping = false;
            }
        }
        #end
    }

    function animateButtonPress(spr:FlxSprite)
    {
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
        spr.scale.set(0.92, 0.92);
        FlxTween.tween(spr.scale, {x: 1.0, y: 1.0}, 0.12, {ease: FlxEase.cubeOut});
        FlxTween.color(btnExit, 0.15, FlxColor.WHITE, 0xFF1E1E24, {
            onComplete: function(_) {
                spr.color = 0xFF1E1E24;
            }
        });
    }

    #if FLX_TOUCH
    function isTouchInside(touch:FlxTouch, spr:FlxSprite):Bool
    {
        var pad:Float = 15; // ขยาย Hitbox ให้นิ้วแตะง่ายขึ้น
        return (touch.screenX >= spr.x - pad && touch.screenX <= spr.x + spr.width + pad &&
                touch.screenY >= spr.y - pad && touch.screenY <= spr.y + spr.height + pad);
    }
    #end

    function isPointInside(px:Float, py:Float, spr:FlxSprite):Bool
    {
        var pad:Float = 15;
        return (px >= spr.x - pad && px <= spr.x + spr.width + pad &&
                py >= spr.y - pad && py <= spr.y + spr.height + pad);
    }

    /**
     * เปลี่ยนรูปภาพที่เลือก
     */
    function changeSelection(change:Int = 0, playSound:Bool = true)
    {
        if (files.length == 0) return;

        canChange = false;
        currentSelection += change;

        if (currentSelection < 0) currentSelection = files.length - 1;
        if (currentSelection >= files.length) currentSelection = 0;

        if (playSound && change != 0) {
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }

        var fileName = files[currentSelection];
        titleText.text = fileName.replace("-", " ").replace("_", " ").toUpperCase();
        countText.text = (currentSelection + 1) + " / " + files.length;

        // เลื่อนตำแหน่งรูปภาพด้วย Tween
        imageGroup.forEach(function(spr:FlxSprite) {
            var offset = spr.ID - currentSelection;
            
            // Loop array offset
            if (offset < -1 && files.length > 2) offset += files.length;
            if (offset > 1 && files.length > 2) offset -= files.length;

            var targetX:Float = (FlxG.width / 2) - (spr.width / 2) + (offset * (FlxG.width * 0.78));
            var targetY:Float = (FlxG.height / 2) - (spr.height / 2) - 40;
            var targetAlpha:Float = (offset == 0) ? 1.0 : 0.35;
            var targetScale:Float = (offset == 0) ? 1.0 : 0.8;

            spr.visible = Math.abs(offset) <= 2;

            FlxTween.cancelTweensOf(spr);
            FlxTween.cancelTweensOf(spr.scale);

            FlxTween.tween(spr, {x: targetX, y: targetY, alpha: targetAlpha}, 0.28, {
                ease: FlxEase.cubeOut,
                onComplete: function(_) {
                    canChange = true;
                }
            });

            FlxTween.tween(spr.scale, {x: targetScale, y: targetScale}, 0.28, {
                ease: FlxEase.cubeOut
            });
        });
    }

    /**
     * สลับโหมดดูภาพเต็มจอ
     */
    function toggleFullScreen()
    {
        if (files.length == 0) return;

        isFullScreen = !isFullScreen;
        canEnterFull = false;

        FlxG.sound.play(Paths.sound(isFullScreen ? 'confirmMenu' : 'cancelMenu'), 0.6);

        var currentSprite:FlxSprite = null;
        imageGroup.forEach(function(spr:FlxSprite) {
            if (spr.ID == currentSelection) currentSprite = spr;
        });

        if (isFullScreen) {
            // ซ่อน UI อื่นๆ เพื่อดูภาพเต็มตา
            FlxTween.tween(infoPanel, {alpha: 0}, 0.2);
            FlxTween.tween(titleText, {alpha: 0}, 0.2);
            FlxTween.tween(countText, {alpha: 0}, 0.2);
            FlxTween.tween(hintText, {alpha: 0}, 0.2);
            FlxTween.tween(btnLeft, {alpha: 0}, 0.2);
            FlxTween.tween(btnLeftText, {alpha: 0}, 0.2);
            FlxTween.tween(btnRight, {alpha: 0}, 0.2);
            FlxTween.tween(btnRightText, {alpha: 0}, 0.2);

            if (currentSprite != null) {
                FlxTween.cancelTweensOf(currentSprite);
                FlxTween.cancelTweensOf(currentSprite.scale);

                fitSpriteToScreen(currentSprite, 0.95);
                FlxTween.tween(currentSprite, {
                    x: (FlxG.width / 2) - (currentSprite.width / 2),
                    y: (FlxG.height / 2) - (currentSprite.height / 2)
                }, 0.25, {
                    ease: FlxEase.cubeOut,
                    onComplete: function(_) { canEnterFull = true; }
                });
            } else {
                canEnterFull = true;
            }
        } else {
            // แสดง UI กลับมาปกติ
            FlxTween.tween(infoPanel, {alpha: 0.75}, 0.2);
            FlxTween.tween(titleText, {alpha: 1.0}, 0.2);
            FlxTween.tween(countText, {alpha: 1.0}, 0.2);
            FlxTween.tween(hintText, {alpha: 1.0}, 0.2);
            FlxTween.tween(btnLeft, {alpha: 0.65}, 0.2);
            FlxTween.tween(btnLeftText, {alpha: 1.0}, 0.2);
            FlxTween.tween(btnRight, {alpha: 0.65}, 0.2);
            FlxTween.tween(btnRightText, {alpha: 1.0}, 0.2);

            if (currentSprite != null) {
                fitSpriteToScreen(currentSprite, 0.72);
                changeSelection(0, false);
            }
            canEnterFull = true;
        }
    }

    /**
     * ออกจาก Art Gallery กลับไปยังหน้า MainMenuState
     */
    function exitGallery()
    {
        if (isFullScreen) {
            toggleFullScreen();
            return;
        }

        FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);

        // ปิด Touch และซ่อนเมาส์ก่อนสลับ State
        #if FLX_TOUCH
        Multitouch.inputMode = MultitouchInputMode.NONE;
        #end
        FlxG.mouse.visible = false;

        MusicBeatState.switchState(new MainMenuState());
    }

    /**
     * ฟังก์ชันคำนวณปรับขนาด FlxSprite ให้พอดีกับหน้าจอ
     */
    function fitSpriteToScreen(spr:FlxSprite, maxScreenRatio:Float = 0.75)
    {
        if (spr.graphic == null) return;

        var maxWidth = FlxG.width * maxScreenRatio;
        var maxHeight = FlxG.height * maxScreenRatio;

        var scaleW = maxWidth / spr.graphic.width;
        var scaleH = maxHeight / spr.graphic.height;
        var finalScale = Math.min(scaleW, scaleH);

        spr.setGraphicSize(Std.int(spr.graphic.width * finalScale), Std.int(spr.graphic.height * finalScale));
        spr.updateHitbox();
    }
}
