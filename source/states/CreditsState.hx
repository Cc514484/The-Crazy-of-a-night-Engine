package states;

import objects.Alphabet;
import objects.AttachedSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.ui.FlxBar;
import flixel.util.FlxTimer;
import hxvlc.flixel.FlxVideoSprite; 
import sys.FileSystem;

import mikolka.vslice.ui.MainMenuState;

class CreditsState extends MusicBeatState
{
    var video:FlxVideoSprite;
    var isVideoPlaying:Bool = false;
    
    var creditTitle:Alphabet;
    var creditName:Alphabet;
    var creditIcon:AttachedSprite;
    var creditDesc:FlxText;
    var bg:FlxSprite;

    var skipBar:FlxBar;
    public var skipTime:Float = 0;
    var maxSkipTime:Float = 1.0; // 1. ตั้งเวลา 3 วิ
    var skipText:FlxText;
    var skipTween:FlxTween; 

    override function create()
    {
        // --- Discord Update ---
        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Watching the Ending Cinematic", "The Crazy of a night - Mow Engine", null, true);
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(bg);

        video = new FlxVideoSprite(0, 0);
        video.antialiasing = true;
        add(video); 

        skipBar = new FlxBar(0, FlxG.height - 50, LEFT_TO_RIGHT, Std.int(FlxG.width * 0.5), 15, this, 'skipTime', 0, maxSkipTime);
        skipBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE, true, FlxColor.WHITE);
        skipBar.screenCenter(X);
        skipBar.visible = false;
        add(skipBar);

        skipText = new FlxText(skipBar.x, skipBar.y - 30, skipBar.width, "HOLD ENTER TO SKIP", 20);
        // แก้ไขฟอนต์ตรงปุ่ม Skip เป็น bro.ttf
        skipText.setFormat(Paths.font("bro.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        skipText.visible = false;
        add(skipText);

        var finalPath:String = "assets/shared/videos/creditsVideo.mp4"; 
        if (!FileSystem.exists(finalPath)) finalPath = "assets/shared/videos/creditsVideo.mp4";
        if (FileSystem.exists(finalPath)) {
            playCreditsVideo(finalPath);
        } else {
            startFinalSequence();
        }

        super.create();
    }

    function playCreditsVideo(path:String)
    {
        if(FlxG.sound.music != null) FlxG.sound.music.stop();
        video.load(path);
        
        // --- ส่วนวิดีโอ (คงไว้ตามเดิม ห้ามเปลี่ยน) ---
        video.setGraphicSize(1280, 720);
        video.updateHitbox();
        var finalScale:Float = 1; 
        video.scale.set(finalScale, finalScale);
        video.updateHitbox();
        video.x = 5; 
        video.y = 0; 
        
        video.bitmap.onEndReached.add(onVideoEnd);
        video.play();
        isVideoPlaying = true;
    }

    override function update(elapsed:Float)
    {
        if (isVideoPlaying) {
            if (FlxG.keys.pressed.ENTER || controls.ACCEPT) {
                if (skipTween != null) skipTween.cancel();
                skipTime += elapsed;
                skipBar.visible = true;
                skipText.visible = true;
                skipBar.alpha = 1;
                skipText.alpha = 1;
            } else if (skipBar.visible) {
                // 2. อนิเมชั่นไหลกลับแบบเร็ว
                if (skipTween != null) skipTween.cancel();
                skipTween = FlxTween.tween(this, {skipTime: 0}, 0.5, {
                    ease: FlxEase.expoOut,
                    onComplete: function(twn:FlxTween) {
                        skipTween = null;
                        skipBar.visible = false;
                        skipText.visible = false;
                    }
                });
                FlxTween.tween(skipBar, {alpha: 0}, 0.5, {ease: FlxEase.expoOut});
                FlxTween.tween(skipText, {alpha: 0}, 0.5, {ease: FlxEase.expoOut});
            }

            if (skipTime >= maxSkipTime) {
                if (skipTween != null) skipTween.cancel();
                onVideoEnd();
            }
        }

        if (controls.BACK && !isVideoPlaying) {
            exitCredits();
        }

        super.update(elapsed);
    }

    function onVideoEnd()
    {
        if (video != null) {
            video.stop();
            remove(video);
            video.destroy();
            video = null;
        }
        
        isVideoPlaying = false;
        skipBar.visible = false;
        skipText.visible = false;
        skipTime = 0;
        startFinalSequence();
    }

    function startFinalSequence()
    {
        // แก้ไขให้เหลือแค่ Yasa และเปลี่ยนคำอธิบาย
        var sequence = [
            {title: "Engine Developer", name: "Yasa", icon: "yasa", desc: "Made Engine for The Crazy of a night\n(Made from Mow Engine)"}
        ];
        showNextCredit(sequence, 0);
    }

    function showNextCredit(data:Array<Dynamic>, index:Int)
    {
        if (index >= data.length) {
            exitCredits();
            return;
        }

        var current = data[index];
        
        // --- Discord Update ---
        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Viewing Credits", "Reading about: " + current.name, null, true);
        #end
        
        creditTitle = new Alphabet(0, 0, current.title, true);
        creditTitle.screenCenter(X);
        creditTitle.y = FlxG.height * 0.25;
        creditTitle.alpha = 0;
        add(creditTitle);

        creditName = new Alphabet(0, 0, current.name, false);
        creditName.screenCenter();
        creditName.alpha = 0;
        add(creditName);

        var iconPath:String = 'credits/' + current.icon;
        if (!Paths.fileExists('images/$iconPath.png', IMAGE)) iconPath = 'credits/missing_icon';
        
        creditIcon = new AttachedSprite(iconPath);
        // 3. แก้ไอคอนบัค: จัดการตำแหน่งใหม่ให้แน่นอน
        creditIcon.sprTracker = creditName;
        creditIcon.xAdd = creditName.width + 30;
        // ระยะห่างหลังชื่อ
        creditIcon.yAdd = -10; 
        creditIcon.alpha = 0;
        if (creditIcon.animation.curAnim != null) {
            creditIcon.animation.curAnim.curFrame = 0;
            creditIcon.animation.pause();
        }
        add(creditIcon);

        creditDesc = new FlxText(0, 0, FlxG.width, current.desc, 32);
        // แก้ไขฟอนต์ของคำอธิบายเป็น bro.ttf เพื่อกันตัวหนังสือหาย
        creditDesc.setFormat(Paths.font("bro.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        creditDesc.screenCenter(X);
        creditDesc.y = FlxG.height * 0.7;
        creditDesc.alpha = 0;
        add(creditDesc);

        FlxTween.tween(creditTitle, {alpha: 1}, 0.5);
        FlxTween.tween(creditName, {alpha: 1}, 0.5, {startDelay: 0.2});
        FlxTween.tween(creditIcon, {alpha: 1}, 0.5, {startDelay: 0.2});
        FlxTween.tween(creditDesc, {alpha: 1}, 0.5, {startDelay: 0.4, onComplete: function(twn:FlxTween) {
            
            new FlxTimer().start(2.5, function(tmr:FlxTimer) {
                FlxTween.tween(creditTitle, {alpha: 0}, 0.5);
                FlxTween.tween(creditName, {alpha: 0}, 0.5);
                FlxTween.tween(creditIcon, {alpha: 0}, 0.5);
        
                FlxTween.tween(creditDesc, {alpha: 0}, 0.5, {onComplete: function(twn:FlxTween) {
                    creditTitle.destroy();
                    creditName.destroy();
                    creditIcon.destroy();
                    creditDesc.destroy();
      
                    showNextCredit(data, index + 1);
                }});
            });
        }});
    }

    function exitCredits()
    {
        // 4. เพลงกลับมาเล่นเฉพาะตอนออกจากหน้านี้
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }
        MusicBeatState.switchState(new MainMenuState());
    }
}