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

    // ===== องค์ประกอบสำหรับทัชสกรีน =====
    var leftTapZone:FlxSprite;   // โซนแตะฝั่งซ้าย เพื่อเลื่อนไปรูปก่อนหน้า
    var rightTapZone:FlxSprite;  // โซนแตะฝั่งขวา เพื่อเลื่อนไปรูปถัดไป
    var centerTapZone:FlxSprite; // โซนแตะตรงกลาง เพื่อเปิด/ปิด Full View
    var btnExit:FlxSprite;       // ปุ่มออกที่แตะได้จริง (มุมขวาบน)
    var tExit:FlxText;

    override function create()
    {
        #if DISCORD_ALLOWED
        // แสดงสถานะบน Discord เป็น MOW Engine (หัวข้อ) และ Viewing Art Gallery (รายละเอียด) [cite: 66, 68]
        DiscordClient.changePresence("Viewing Art Gallery", null);
        #end

        // ทำให้แตะหน้าจอจำลองเป็น mouse event ได้ (สำคัญ: ใช้คู่กับ .justPressed เท่านั้น
        // ห้ามใช้แค่ .overlaps() เฉยๆ ไม่งั้นจะเกิดบั๊ก "กดรัว" ตอนแตะค้างเหมือนที่เจอมาก่อน)
        Multitouch.inputMode = MultitouchInputMode.NONE;
        FlxG.mouse.enabled = true;

        FlxG.cameras.reset();
        // ยังคงซ่อน cursor ไว้เหมือนเดิม (ไม่กระทบการรับสัมผัส เพราะ overlaps/justPressed
        // ทำงานได้แม้ cursor จะไม่แสดงผลบนจอ)
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

        hintText = new FlxText(0, infoPanel.y + 100, FlxG.width, "[ENTER] Full View | [BACK] Exit | Tap sides to browse, tap center to zoom", 18);
        hintText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.GRAY, CENTER);
        hintText.scrollFactor.set();
        add(hintText);

        // ===== โซนแตะสำหรับเลื่อนรูป (ซ่อนตัวเอง โปร่งใสเต็มพื้นที่) =====
        // แบ่งเป็น 3 โซน: ซ้าย 30% / กลาง 40% / ขวา 30% ของความกว้างจอ
        // สูงเท่ากับพื้นที่แสดงรูป (ไม่รวมแถบข้อมูลด้านล่าง กันชนกับปุ่มอื่น)
        var tapZoneHeight:Float = infoPanel.y;

        leftTapZone = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 0.3), Std.int(tapZoneHeight), FlxColor.WHITE);
        leftTapZone.alpha = 0.001; // มองไม่เห็นแต่ยังรับ overlap ได้ (alpha 0 เป๊ะบางเอนจินจะตัด hit-test ทิ้ง จึงใช้ค่าน้อยมากแทน)
        leftTapZone.scrollFactor.set();
        add(leftTapZone);

        rightTapZone = new FlxSprite(Std.int(FlxG.width * 0.7), 0).makeGraphic(Std.int(FlxG.width * 0.3), Std.int(tapZoneHeight), FlxColor.WHITE);
        rightTapZone.alpha = 0.001;
        rightTapZone.scrollFactor.set();
        add(rightTapZone);

        centerTapZone = new FlxSprite(Std.int(FlxG.width * 0.3), 0).makeGraphic(Std.int(FlxG.width * 0.4), Std.int(tapZoneHeight), FlxColor.WHITE);
        centerTapZone.alpha = 0.001;
        centerTapZone.scrollFactor.set();
        add(centerTapZone);

        // ===== ปุ่มออกที่แตะได้จริง มุมขวาบน =====
        btnExit = new FlxSprite(FlxG.width - 110, 20).makeGraphic(90, 50, 0xAA000000);
        btnExit.scrollFactor.set();
        add(btnExit);

        tExit = new FlxText(FlxG.width - 110, 20, 90, "EXIT >", 18);
        tExit.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        tExit.scrollFactor.set();
        add(tExit);

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

                // ===== ทัชสกรีน: แตะซ้าย/ขวาเพื่อเลื่อนรูป =====
                // สำคัญ: ใช้ .justPressed เท่านั้น (ยิงครั้งเดียวตอนกดลง ไม่ยิงซ้ำตอนกดค้าง)
                // นี่คือจุดที่แก้บั๊ก "กดรัวไปทางขวา" ที่เจอมาก่อนหน้านี้ — เดิมน่าจะเช็คแค่
                // overlaps() เฉยๆ ซึ่งจะ true ทุกเฟรมตราบใดที่นิ้วยังแตะค้างอยู่
                if (FlxG.mouse.justPressed) {
                    if (FlxG.mouse.overlaps(leftTapZone)) {
                        changeSelection(-1);
                    } else if (FlxG.mouse.overlaps(rightTapZone)) {
                        changeSelection(1);
                    }
                }
            }

            if ((FlxG.keys.justPressed.ENTER ||
                (canEnterFull && !isFullScreen == false ? false : (FlxG.mouse.justPressed && FlxG.mouse.overlaps(centerTapZone) && canEnterFull)))
                && canEnterFull) {
                toggleFullScreen();
            }

            // ในโหมด Full View: แตะที่ใดก็ได้บนรูปเพื่อปิดกลับมา (ยกเว้นโดนปุ่ม EXIT)
            if (isFullScreen && FlxG.mouse.justPressed && !FlxG.mouse.overlaps(btnExit) && canEnterFull) {
                toggleFullScreen();
            }
        }

        // ===== ปุ่ม EXIT ที่แตะได้จริง =====
        if (FlxG.mouse.overlaps(btnExit)) {
            btnExit.alpha = 0.7;
            if (FlxG.mouse.justPressed) {
                exitGallery();
            }
        } else {
            btnExit.alpha = 1.0;
        }

        if (controls.BACK) {
            if (isFullScreen) toggleFullScreen();
            else exitGallery();
        }
        super.update(elapsed);
    }

    function exitGallery() {
        FlxG.sound.play(Paths.sound('cancelMenu'));
        MusicBeatState.switchState(new MainMenuState());
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

        // ซ่อนโซนแตะเลื่อนรูป/EXIT ตอนเข้า Full View (กันแตะโดนโดยไม่ตั้งใจ ยกเว้น EXIT ที่ยังให้กดออกได้เสมอ)
        leftTapZone.visible = rightTapZone.visible = centerTapZone.visible = !isFullScreen;

        if (isFullScreen) {
            currentArt.scrollFactor.set(0, 0);
            imageGroup.forEach(function(spr:FlxSprite) if (spr.ID != currentSelection) spr.visible = false);
            var ratio = Math.min(FlxG.width / currentArt.frameWidth, FlxG.height / currentArt.frameHeight);
            currentArt.setGraphicSize(Std.int(currentArt.frameWidth * ratio));
            currentArt.updateHitbox();
            currentArt.x = (FlxG.width / 2) - (currentArt.width / 2);
            currentArt.y = (FlxG.height / 2) - (currentArt.height / 2);

            canEnterFull = false;
            new FlxTimer().start(0.3, function(tmr:FlxTimer) { canEnterFull = true; });
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
