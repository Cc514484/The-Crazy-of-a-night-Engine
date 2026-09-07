package states;

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
    
    var bg:FlxSprite;

    var skipBar:FlxBar;
    public var skipTime:Float = 0;
    var maxSkipTime:Float = 1.0; // ตั้งเวลาข้าม 1 วิ (ตามโค้ดเดิมของคุณ)
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
            // ถ้าไม่มีไฟล์วิดีโอ ให้ออกไปหน้าเมนูเลย
            exitCredits();
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
                // อนิเมชั่นไหลกลับแบบเร็ว
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
        
        // เรียกใช้ออกเกมกลับเมนูทันทีโดยไม่ต้องโชว์ข้อความเครดิต
        exitCredits();
    }

    function exitCredits()
    {
        // เพลงกลับมาเล่นเฉพาะตอนออกจากหน้านี้
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }
        MusicBeatState.switchState(new MainMenuState());
    }
}
