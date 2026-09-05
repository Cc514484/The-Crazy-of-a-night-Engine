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
import sys.FileSystem;
import haxe.io.Path;
import mikolka.vslice.ui.MainMenuState;
import backend.ClientPrefs;
import openfl.display.BitmapData;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

// แก้ไขตรงนี้: Import Class DiscordClient ที่อยู่ในไฟล์ Discord.hx [cite: 55, 56]
// import backend.Discord.DiscordClient; 

class ArtGallery extends MusicBeatState
{
    var files:Array<String> = [];
    var currentSelection:Int = 0;
    var isFullScreen:Bool = false;
    var canEnterFull:Bool = true;
    var canChange:Bool = true;
    
    var bgDesat:FlxSprite;
    var imageGroup:FlxSpriteGroup;
    var infoPanel:FlxSprite;
    var titleText:FlxText;
    var countText:FlxText;
    var hintText:FlxText;

    override function create()
    {
        #if DISCORD_ALLOWED
        // แสดงสถานะบน Discord เป็น MOW Engine (หัวข้อ) และ Viewing Art Gallery (รายละเอียด) [cite: 66, 68]
        DiscordClient.changePresence("Viewing Art Gallery", null);
        #end

        FlxG.cameras.reset();

        // จุดที่ขาดไปก่อนหน้านี้: ถ้าไม่เปิดสองบรรทัดนี้ FlxG.mouse จะไม่อัปเดตสถานะ justPressed
        // เลย ทำให้ checkTouchInput() ด้านล่างไม่มีวันทำงาน (นิ้วแตะจะไม่ถูกนับเป็น mouse event)
        Multitouch.inputMode = MultitouchInputMode.NONE;
        FlxG.mouse.enabled = true;
        FlxG.mouse.visible = false;

        bgDesat = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bgDesat.color = 0xFF2A2A2A;
        bgDesat.scrollFactor.set();
        bgDesat.screenCenter();
        add(bgDesat);

        imageGroup = new FlxSpriteGroup();
        add(imageGroup);

        infoPanel = new FlxSprite(0, FlxG.height * 0.8).makeGraphic(FlxG.width, 150, 0xFF000000);
        infoPanel.alpha = 0.6;
        infoPanel.scrollFactor.set();
        add(infoPanel);

        titleText = new FlxText(0, infoPanel.y + 30, FlxG.width, "", 42);
        titleText.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.scrollFactor.set();
        add(titleText);

        countText = new FlxText(FlxG.width - 250, infoPanel.y + 10, 200, "", 24);
        countText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
        countText.scrollFactor.set();
        add(countText);

        hintText = new FlxText(0, infoPanel.y + 100, FlxG.width, "[ENTER] Full View | [BACK] Exit", 20);
        hintText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.GRAY, CENTER);
        hintText.scrollFactor.set();
        add(hintText);

        loadImagesFromFolder();

        if (files.length > 0) {
            createGallery();
            changeSelection(0, false); 
        }
        
        super.create();
    }

    function loadImagesFromFolder()
    {
        var folderPath:String = "assets/shared/images/Art/";
        #if sys
        if (FileSystem.exists(folderPath)) {
            for (file in FileSystem.readDirectory(folderPath)) {
                var ext = Path.extension(file).toLowerCase();
                // เพิ่มการรองรับไฟล์ .gif เข้าไปในลิสต์ 
                if (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif") files.push(file); 
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
                } catch(e:Dynamic) trace("Error loading: " + fileName);
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

    function resetSpriteScale(spr:FlxSprite) {
        if (spr != null && spr.graphic != null) {
            var targetH = FlxG.height * 0.5;
            var ratio = targetH / spr.frameHeight;
            spr.setGraphicSize(Std.int(spr.frameWidth * ratio));
            spr.updateHitbox();
        }
    }

    override function update(elapsed:Float)
    {
        if (files.length > 0) {
            if (!isFullScreen && canChange) {
                if (controls.UI_LEFT_P) changeSelection(-1);
                if (controls.UI_RIGHT_P) changeSelection(1);
            }
            if (FlxG.keys.justPressed.ENTER && canEnterFull) toggleFullScreen();

            checkTouchInput();
        }

        if (controls.BACK) {
            if (isFullScreen) toggleFullScreen();
            else {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new MainMenuState());
            }
        }
        super.update(elapsed);
    }

    /**
     * รองรับนิ้วแตะ/เมาส์คลิกจริงบนอุปกรณ์ (แยกจาก touch->mouse simulation ของระบบ)
     * แบ่งจอเป็น 3 โซน: ซ้าย = รูปก่อนหน้า, ขวา = รูปถัดไป, กลาง = เปิด/ปิดฟูลสกรีน
     */
    function checkTouchInput()
    {
        var tapX = getTapScreenX();
        if (tapX == null) return;

        if (isFullScreen) {
            // แตะที่ไหนก็ได้ตอนฟูลสกรีน = ออกจากฟูลสกรีน
            if (canEnterFull) toggleFullScreen();
            return;
        }

        var leftZone = FlxG.width * 0.25;
        var rightZone = FlxG.width * 0.75;

        if (tapX < leftZone) {
            if (canChange) changeSelection(-1);
        } else if (tapX > rightZone) {
            if (canChange) changeSelection(1);
        } else {
            if (canEnterFull) toggleFullScreen();
        }
    }

    /**
     * คืนตำแหน่ง X บนจอ (screen space) ของการแตะ/คลิกที่เพิ่งเกิดขึ้นในเฟรมนี้
     * เช็คทั้งเมาส์จริงและนิ้วสัมผัสจริงทุกจุด (ไม่พึ่งการจำลอง touch -> mouse อย่างเดียว)
     * คืนค่า null ถ้าเฟรมนี้ไม่มีการแตะ/คลิกใหม่
     */
    function getTapScreenX():Null<Float>
    {
        if (FlxG.mouse.justPressed)
            return FlxG.mouse.screenX;

        #if FLX_TOUCH
        for (touch in FlxG.touches.list) {
            if (touch.justPressed)
                return touch.screenX;
        }
        #end

        return null;
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

        if (isFullScreen) {
            currentArt.scrollFactor.set(0, 0);
            imageGroup.forEach(function(spr:FlxSprite) if (spr.ID != currentSelection) spr.visible = false);
            var ratio = Math.min(FlxG.width / currentArt.frameWidth, FlxG.height / currentArt.frameHeight);
            currentArt.setGraphicSize(Std.int(currentArt.frameWidth * ratio));
            currentArt.updateHitbox();
            currentArt.x = (FlxG.width / 2) - (currentArt.width / 2);
            currentArt.y = (FlxG.height / 2) - (currentArt.height / 2);
        } else {
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
        // แสดงชื่อไฟล์รูปภาพที่กำลังดูอยู่ใน Discord
        var fileName = Path.withoutExtension(files[currentSelection]);
        DiscordClient.changePresence("Viewing Art Gallery", "Looking at: " + fileName);
        #end

        updatePositions(false);
        new FlxTimer().start(0.5, function(tmr:FlxTimer) {
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
                    FlxTween.tween(spr, {x: targetX, y: targetY, alpha: isCurrent ? 1.0 : 0.0001}, 0.4, {
                        ease: FlxEase.quartOut
                    });
                }
            }
        });
    }
}
