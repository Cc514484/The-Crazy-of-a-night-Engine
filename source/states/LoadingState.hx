package states;

import lime.app.Future;
import sys.thread.FixedThreadPool;
import sys.thread.Thread;
import sys.thread.Mutex;
import haxe.Json;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
import flash.media.Sound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup;
import backend.Song;
import backend.StageData;
import backend.Paths;
import backend.ClientPrefs;
import objects.Character;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

#if cpp
@:headerCode('#include <iostream>\n#include <thread>')
#end

class LoadingState extends MusicBeatState
{
	public static var loaded:Int = 0;
	public static var loadMax:Int = 0;
	static var originalBitmapKeys:Map<String, String> = [];
	static var requestedBitmaps:Map<String, BitmapData> = [];
	static var mutex:Mutex;
	static var threadPool:FixedThreadPool = null;
	static var initialThreadCompleted:Bool = true;
	
	static var imagesToPrepare:Array<String> = [];
	static var songsToPrepare:Array<String> = [];

	var target:FlxState;
	var stopMusic:Bool;
	var dontUpdate:Bool = false;
	var transitioning:Bool = false;

	// Visuals
	var bar:FlxSprite;
	var barWidth:Int = 0;
	var curPercent:Float = 0;
	var intendedPercent:Float = 0;
	var loadingText:FlxText;
	var tipText:FlxText;
	var icon:FlxSprite;
	var tipTimer:FlxTimer;
	var timePassed:Float = 0;
	
	// Timer Settings
	var minLoadTime:Float = 3.0;
	var elapsedLoadTime:Float = 0;

	var tips:Array<String> = [
		"Warm up your fingers!", "Press R to restart the song.", 
		"Higher scroll speed isn't always better.", "hank is watching your progress...",
		"Did You Know? Yasa made this!!", "What a Sigma",  
		"Take a break if your hands feel tired.", "Drink some water, stay hydrated!"
	];

	public function new(target:FlxState, stopMusic:Bool) {
		this.target = target;
		this.stopMusic = stopMusic;
		super();
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false, intrusive:Bool = true)
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));

	override function create() {
		#if STRICT_LOADING_SCREEN
		backend.CacheSystem.clearStoredMemory();
		backend.CacheSystem.clearUnusedMemory();
		#end

		persistentUpdate = true;
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(FlxG.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.color = 0xFF1B1B1B;
		add(bg);

		var barBack = new FlxSprite(0, 640).makeGraphic(1, 1, FlxColor.BLACK);
		barBack.scale.set(FlxG.width - 400, 15);
		barBack.updateHitbox();
		barBack.screenCenter(X);
		barBack.alpha = 0.6;
		add(barBack);

		bar = new FlxSprite(barBack.x, barBack.y).makeGraphic(1, 1, 0xFFFF0044);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		add(bar);
		barWidth = Std.int(barBack.width);

		icon = new FlxSprite(barBack.x, barBack.y - 35).loadGraphic(Paths.image('loading_screen/icon'));
		if(icon.graphic == null) icon.makeGraphic(45, 45, FlxColor.WHITE);
		icon.setGraphicSize(50);
		icon.updateHitbox();
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		loadingText = new FlxText(barBack.x, barBack.y - 45, 400, "NOW LOADING...", 24);
		loadingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(loadingText);

		tipText = new FlxText(0, 675, FlxG.width, "", 20);
		tipText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(tipText);
		getNextTip();

		prepareToSong();
		super.create();
	}

	function getNextTip() {
		var selectedTip = "TIP: " + tips[FlxG.random.int(0, tips.length - 1)];
		var curChar = 0;
		if(tipTimer != null) tipTimer.cancel();
		tipText.text = "";
		tipTimer = new FlxTimer().start(0.04, (tmr) -> {
			tipText.text += selectedTip.charAt(curChar++);
			if(curChar >= selectedTip.length) new FlxTimer().start(3.5, (t) -> getNextTip());
		}, selectedTip.length);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if (dontUpdate) return;
		
		timePassed += elapsed;
		elapsedLoadTime += elapsed; // นับเวลาที่ผ่านไป

		loadingText.alpha = 0.5 + (Math.sin(timePassed * 3) * 0.5);
		
		// เงื่อนไข: ต้องโหลดเสร็จ (checkLoaded) และ เวลาต้องเกิน 5 วินาที (elapsedLoadTime >= minLoadTime)
		if (!transitioning && checkLoaded() && elapsedLoadTime >= minLoadTime) {
			transitioning = true;
			onLoad();
			return;
		}

		intendedPercent = (loadMax > 0) ? (loaded / loadMax) : 0;
		
		// ถ้าโหลดเสร็จในทาง Technical แล้ว แต่เวลายังไม่ครบ 5 วิ ให้แถบโหลดค่อยๆ วิ่งไปจนเต็ม
		if(loaded >= loadMax) intendedPercent = 1.0;

		curPercent = FlxMath.lerp(intendedPercent, curPercent, Math.exp(-elapsed * 15));
		bar.scale.x = barWidth * curPercent;
		bar.updateHitbox();
		icon.x = bar.x + (barWidth * curPercent) - (icon.width / 2);
	}

	function onLoad() {
		_loaded();
		if (stopMusic && FlxG.sound.music != null) FlxG.sound.music.stop();
		FlxG.camera.fade(FlxColor.BLACK, 0.5, false, () -> MusicBeatState.switchState(target));
	}

	public static function loadNextDirectory() {}

	public static function checkLoaded():Bool {
		for (key => bitmap in requestedBitmaps) {
			if (bitmap != null) backend.CacheSystem.cacheBitmap(originalBitmapKeys.get(key), bitmap);
		}
		requestedBitmaps.clear();
		return (loaded >= loadMax && initialThreadCompleted);
	}

	static function _loaded() {
		loaded = 0; loadMax = 0;
		initialThreadCompleted = true;
		if (threadPool != null) threadPool.shutdown();
		threadPool = null; mutex = null;
	}

	static function getNextState(target:FlxState, stopMusic = false, intrusive:Bool = true):FlxState {
		return (intrusive) ? new LoadingState(target, stopMusic) : target;
	}

	public static function prepareToSong() {
		if (PlayState.SONG == null) return;
		_startPool();
		imagesToPrepare = []; songsToPrepare = [];
		initialThreadCompleted = false;

		var song = PlayState.SONG;
		imagesToPrepare.push(song.player1);
		imagesToPrepare.push(song.player2);
		imagesToPrepare.push(song.gfVersion != null ? song.gfVersion : 'gf');
		songsToPrepare.push(Paths.formatToSongPath(song.song) + '/Inst');
		
		loadMax = imagesToPrepare.length + songsToPrepare.length;
		startThreads();
	}

	static function _startPool() {
		var threads = #if cpp getCPUThreadsCount() #else 4 #end;
		threadPool = new FixedThreadPool(ClientPrefs.data.cacheOnCPU ? threads : 1);
	}

	static function startThreads() {
		mutex = new Mutex();
		for (img in imagesToPrepare) initThread(() -> { preloadGraphic(img); return null; });
		for (song in songsToPrepare) initThread(() -> { preloadSound(song, 'songs'); return null; });
		initialThreadCompleted = true;
	}

	static function initThread(func:Void->Dynamic) {
		threadPool.run(() -> {
			try { func(); } catch (e:Dynamic) {}
			mutex.acquire(); loaded++; mutex.release();
		});
	}

	static function preloadGraphic(key:String) {
		var requestKey = 'images/$key.png';
		var path = Paths.getPath(requestKey, IMAGE);
		var bmp:BitmapData = null;
		#if sys
		if (FileSystem.exists(path)) bmp = BitmapData.fromFile(path);
		#else
		if (OpenFlAssets.exists(path)) bmp = OpenFlAssets.getBitmapData(path);
		#end

		if (bmp != null) {
			mutex.acquire();
			requestedBitmaps.set(path, bmp);
			originalBitmapKeys.set(path, requestKey);
			mutex.release();
		}
	}

	static function preloadSound(key:String, ?path:String) {
		var file = Paths.getPath(key + '.${Paths.SOUND_EXT}', SOUND, path);
		if (!backend.CacheSystem.currentTrackedSounds.exists(file)) {
			var sound:Sound = null;
			#if sys
			if (FileSystem.exists(file)) sound = Sound.fromFile(file);
			#else
			if (OpenFlAssets.exists(file)) sound = OpenFlAssets.getSound(file);
			#end
			if (sound != null) {
				mutex.acquire();
				backend.CacheSystem.currentTrackedSounds.set(file, sound);
				mutex.release();
			}
		}
	}

	#if cpp
	@:functionCode('return std::thread::hardware_concurrency();')
	static function getCPUThreadsCount():Int return 2;
	#end
}