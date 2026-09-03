package mikolka.vslice.ui.title;

import mikolka.funkin.custom.mobile.MobileScaleMode;
import mikolka.compatibility.VsliceOptions;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.util.FlxDirectionFlags;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;
import openfl.Assets;
import mikolka.vslice.components.crash.Logger;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import shaders.ColorSwap;
import mikolka.vslice.components.ScreenshotPlugin;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

#if VIDEOS_ALLOWED
import mikolka.vslice.ui.title.AttractState;
#end

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;

	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	var enterTimer:FlxTimer;
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	// ตัวแปรสำหรับ Hank Easter Egg
	var easterEggWord:String = "hank";
	var curWordIndex:Int = 0;

	override public function create():Void
	{
		CacheSystem.clearStoredMemory();
		super.create();
		CacheSystem.clearUnusedMemory();
		startIntro();
	}

	var logoBl:FlxSprite;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;
	var starBG:FlxSprite;
	var titleAD:FlxSprite;
	private var sickBeats:Int = 0; 

	var lerpScore:Float = 0;

	function startIntro()
	{
		#if sys
		Logger.enforceLogSettings = true;
		#end

		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		var cutout_size = MobileScaleMode.gameCutoutSize.x / 2.5;
		
		Conductor.bpm = musicBPM;

		starBG = new FlxSprite().loadGraphic(Paths.image('TitleMenu/starBG', 'shared'));
		starBG.antialiasing = VsliceOptions.ANTIALIASING;
		starBG.screenCenter();
		add(starBG);

		titleAD = new FlxSprite(FlxG.width + 500, 0).loadGraphic(Paths.image('TitleMenu/TitleAD', 'shared'));
		titleAD.antialiasing = VsliceOptions.ANTIALIASING;
		add(titleAD);

		logoBl = new FlxSprite(-1800, logoPosition.y); 
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = VsliceOptions.ANTIALIASING;
		
		logoBl.scale.set(0.8, 0.8); 
		logoBl.updateHitbox();
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		add(logoBl);

		if (VsliceOptions.SHADERS)
		{
			swagShader = new ColorSwap();
			logoBl.shader = swagShader.shader;
		}

		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x + cutout_size, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}

		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', VsliceOptions.FLASHBANG ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		if (initialized)
			skipIntro();
		else
		{
			openSubState(new IntroSubstate());
			initialized = true;
		}
	}

	var logoPosition:FlxPoint = FlxPoint.get(-0, -45); 
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);
	var musicBPM:Float = 102;

	function loadJsonData()
	{
		if (Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			try {
				var titleJSON:TitleData = Json.parse(titleRaw);
				logoPosition.set(titleJSON.titlex, titleJSON.titley);
				enterPosition.set(titleJSON.startx, titleJSON.starty);
				musicBPM = titleJSON.bpm;
			} catch (e:haxe.Exception) {}
		}

		logoPosition.y = 920; //  เปลี่ยนเลขตรงนี้ได้เลย (เช่น 200, 250, 300 ยิ่งมากยิ่งอยู่ล่าง)
	}

	var transitioning:Bool = false;
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if (skippedIntro && !transitioning)
		{
			lerpScore += elapsed;
			logoBl.y = logoPosition.y + (Math.sin(lerpScore * 1.5) * 25);
			logoBl.angle = Math.sin(lerpScore * 1.2) * 4;
		}

		// ระบบตรวจจับการพิมพ์ "hank" (Easter Egg)
		if (FlxG.keys.justPressed.ANY && !transitioning)
		{
			var keyPressed = FlxG.keys.getIsDown()[0].ID.toString().toLowerCase();
			if (keyPressed == easterEggWord.charAt(curWordIndex))
			{
				curWordIndex++;
				if (curWordIndex >= easterEggWord.length)
				{
					showHank();
					curWordIndex = 0; // รีเซ็ตเพื่อให้พิมพ์ใหม่ได้ทันที
				}
			}
			else
			{
				curWordIndex = 0; // พิมพ์ผิดเริ่มใหม่
			}
		}

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT || (TouchUtil.justReleased && !SwipeUtil.swipeAny);

		if (newTitle)
		{
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (pressedEnter)
			{
				titleText.animation.play('press');
				FlxG.camera.flash(VsliceOptions.FLASHBANG ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				FlxTween.tween(logoBl, {x: -700, alpha: 0}, 1.2, {ease: FlxEase.expoIn});
				FlxTween.tween(titleAD, {x: FlxG.width + 800, alpha: 0}, 1.2, {ease: FlxEase.expoIn});
				FlxTween.tween(titleText, {y: FlxG.height + 200, alpha: 0}, 1.2, {ease: FlxEase.expoIn});

				// เอฟเฟกต์ซูมกล้องและเฟดดำหายไปพร้อมกัน
				FlxTween.tween(FlxG.camera, {zoom: 1.3}, 1.2, {ease: FlxEase.expoIn});
				FlxG.camera.fade(FlxColor.BLACK, 1.2, false); 

				new FlxTimer().start(1.2, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro) skipIntro();

		super.update(elapsed);
	}

	function showHank()
	{
		// แก้ไข Error: ลบ 'shared' ออกเพื่อให้ใช้ค่าเริ่มต้น (bool)
		FlxG.sound.play(Paths.sound('hank'));

		// สร้างรูปจ้ำสะแกใหม่
		var jumpHank:FlxSprite = new FlxSprite().loadGraphic(Paths.image('TitleMenu/hank', 'shared'));
		jumpHank.antialiasing = VsliceOptions.ANTIALIASING;
		jumpHank.screenCenter();
		add(jumpHank);

		// เอฟเฟกต์ขยายตัวอย่างรวดเร็ว (Jump Scare)
		jumpHank.scale.set(0.4, 0.4);
		FlxTween.tween(jumpHank.scale, {x: 1.2, y: 1.2}, 0.1, {ease: FlxEase.expoOut});
		
		// สั่นหน้าจอเล็กน้อย
		FlxG.camera.shake(0.01, 0.1);

		// แสดงค้างไว้ครู่หนึ่งแล้วค่อยจางหายและทำลาย Object ทิ้ง
		FlxTween.tween(jumpHank, {alpha: 0}, 0.4, {
			startDelay: 1.2,
			onComplete: function(twn:FlxTween) {
				jumpHank.destroy();
			}
		});
	}

	public static var closedState:Bool = false;

	override function beatHit()
	{
		super.beatHit();
		if (logoBl != null) logoBl.animation.play('bump', true);

		if (!closedState)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			closeSubState();
			FlxG.camera.flash(FlxColor.WHITE, 1);
			skippedIntro = true;

			logoBl.x = -1200;
			titleAD.x = FlxG.width + 500;
			FlxTween.tween(logoBl, {x: -60}, 1.4, {ease: FlxEase.expoOut});
			FlxTween.tween(titleAD, {x: FlxG.width - titleAD.width - 0}, 1.4, {ease: FlxEase.expoOut});
		}
	}
}