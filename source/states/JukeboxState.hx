package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer; 
import backend.MusicBeatState;
import backend.Paths;
import backend.Controls;
import backend.WeekData; 
import mikolka.vslice.ui.MainMenuState;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import openfl.media.Sound;
import openfl.utils.Assets;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

#if DISCORD_ALLOWED
import backend.Discord.DiscordClient;
#end

using StringTools;

typedef SongMetadata = {
	var artist:String;
	var album:String;
	var album_image:String;
}

typedef LoadTask = {
	var songName:String;
	var type:String; 
	var path:String;
}

/**
 * JukeboxState สำหรับ FNF P-Slice / Psych Engine
 * แก้ไขให้อ่านเพลงจากโฟลเดอร์ MODS ทั้งหมด (mods/songs/ และ mods/<modDir>/songs/)
 * รองรับ Touch Screen บนมือถือ และปุ่มสัมผัสควบคุมครบทุกฟังก์ชัน
 */
class JukeboxState extends MusicBeatState
{
	var songsList:Array<String> = [];
	var songsFolderList:Array<String> = []; 
	var curSelected:Int = 0;

	// UI Elements
	var bg:FlxSprite;
	var albumText:FlxText;
	var songText:FlxText;
	var artistText:FlxText;
	var speedText:FlxText;
	var timeText:FlxText; 
	var controlGuide:FlxText; 
	var albumArt:FlxSprite;
	var progressBar:FlxSprite;
	var progressBG:FlxSprite;

	// Global Loading Screen Elements
	var loadingBG:FlxSprite;
	var loadingText:FlxText;
	var loadingBarBG:FlxSprite;
	var loadingBar:FlxSprite;  

	// UI Buttons
	var leftArrow:FlxText;
	var rightArrow:FlxText;
	var btnMuteInst = new FlxSprite();
	var btnMuteVocals = new FlxSprite();
	var btnRestart = new FlxSprite();
	var btnPlayPause = new FlxSprite();
	var btnBackward5 = new FlxSprite();
	var btnForward5 = new FlxSprite();
	var tPlayPause:FlxText;

	// ปุ่มย้อนกลับสำหรับหน้าจอสัมผัส (Touch Screen Exit Button)
	var btnBackTouch:FlxSprite;
	var tBackTouch:FlxText;

	// Audio Channels
	var instSound:FlxSound;
	var vocalsPlayer:FlxSound;
	var vocalsOpponent:FlxSound;

	// Global Preload Containers (RAM Cache)
	public static var preloadedInst:Map<String, Sound> = new Map();
	public static var preloadedVP:Map<String, Sound> = new Map();
	public static var preloadedVO:Map<String, Sound> = new Map();
	public static var isAssetsLoaded:Bool = false; 
	
	var loadTasks:Array<LoadTask> = [];
	var currentTaskIndex:Int = 0;

	// States
	var isLoading:Bool = true;
	var isScrubbing:Bool = false;
	var isMuted:Bool = false;
	var vocalsMuted:Bool = false;
	var isPaused:Bool = false;
	var songSpeed:Float = 1.0;

	// แสดงข้อความดีบักบนจอ (สำหรับตรวจเช็คพาธบนอุปกรณ์มือถือ)
	var debugText:FlxText;

	override function create()
	{
		super.create();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Jukebox - Listening to Music", null);
		#end

		// -------------------------------------------------------------
		// [แก้ไขจุดที่ 1]: เปิดโหมด Touch Point เพื่อให้จอมือถือแตะติด 100%
		// -------------------------------------------------------------
		#if FLX_TOUCH
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		#else
		Multitouch.inputMode = MultitouchInputMode.NONE;
		#end

		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = true;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
		}

		bg = new FlxSprite().loadGraphic(Paths.image('Menu/crBG'));
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		// -------------------------------------------------------------
		// [แก้ไขจุดที่ 2]: สแกนเพลงจากโฟลเดอร์ MODS เป็นหลัก
		// รองรับทั้ง:
		// 1) mods/songs/<songName>/
		// 2) mods/<modDir>/songs/<songName>/
		// 3) Paths.mods('songs/') และ Paths.mods(modDir + '/songs/')
		// -------------------------------------------------------------
		scanSongsFromMods();

		albumText = new FlxText(0, 40, FlxG.width, "ALBUMS: NONE", 32);
		albumText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		albumText.borderSize = 2;
		add(albumText);

		albumArt = new FlxSprite(0, 120);
		albumArt.makeGraphic(440, 310, FlxColor.GRAY);
		albumArt.screenCenter(X);
		add(albumArt);

		leftArrow = new FlxText(120, 0, 100, "<", 80);
		leftArrow.setFormat(Paths.font("vcr.ttf"), 80, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		leftArrow.screenCenter(Y).y -= 40;
		add(leftArrow);

		rightArrow = new FlxText(FlxG.width - 220, 0, 100, ">", 80);
		rightArrow.setFormat(Paths.font("vcr.ttf"), 80, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rightArrow.screenCenter(Y).y -= 40;
		add(rightArrow);

		songText = new FlxText(0, 450, FlxG.width, "SONG NAME: NONE", 28);
		songText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		songText.borderSize = 2;
		add(songText);

		artistText = new FlxText(0, 490, FlxG.width, "BY: UNKNOWN", 22);
		artistText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		artistText.borderSize = 1.5;
		add(artistText);

		var btnY:Float = 540;
		var leftStartX:Float = 100;

		btnMuteInst = new FlxSprite(leftStartX, btnY).loadGraphic(Paths.image('JukeboxUI/inst')); 
		btnMuteInst.setGraphicSize(50, 50); btnMuteInst.updateHitbox(); add(btnMuteInst);
		var t1:FlxText = new FlxText(leftStartX - 10, btnY + 55, 70, "INST\n[M]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t1.alignment = CENTER; add(t1);

		btnMuteVocals = new FlxSprite(leftStartX + 80, btnY).loadGraphic(Paths.image('JukeboxUI/voc')); 
		btnMuteVocals.setGraphicSize(50, 50); btnMuteVocals.updateHitbox(); add(btnMuteVocals);
		var t2:FlxText = new FlxText(leftStartX + 70, btnY + 55, 70, "VOC\n[V]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t2.alignment = CENTER; add(t2);

		btnRestart = new FlxSprite(leftStartX + 160, btnY).loadGraphic(Paths.image('JukeboxUI/Reset')); 
		btnRestart.setGraphicSize(50, 50); btnRestart.updateHitbox(); add(btnRestart);
		var t3:FlxText = new FlxText(leftStartX + 150, btnY + 55, 70, "RESET\n[R]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t3.alignment = CENTER; add(t3);

		var centerX:Float = FlxG.width / 2;
		
		btnBackward5 = new FlxSprite(centerX - 115, btnY).loadGraphic(Paths.image('JukeboxUI/back5s')); 
		btnBackward5.setGraphicSize(50, 50); btnBackward5.updateHitbox(); add(btnBackward5);
		var tBack:FlxText = new FlxText(centerX - 125, btnY + 55, 70, "-5S\n[J]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tBack.alignment = CENTER; add(tBack);

		btnPlayPause = new FlxSprite(centerX - 25, btnY).loadGraphic(Paths.image('JukeboxUI/stop')); 
		btnPlayPause.setGraphicSize(50, 50); btnPlayPause.updateHitbox(); add(btnPlayPause);
		tPlayPause = new FlxText(centerX - 50, btnY + 55, 100, "PAUSE\n[SPACE]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tPlayPause.alignment = CENTER; add(tPlayPause);

		btnForward5 = new FlxSprite(centerX + 65, btnY).loadGraphic(Paths.image('JukeboxUI/Re5s')); 
		btnForward5.setGraphicSize(50, 50); btnForward5.updateHitbox(); add(btnForward5);
		var tFor:FlxText = new FlxText(centerX + 55, btnY + 55, 70, "+5S\n[K]", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tFor.alignment = CENTER; add(tFor);

		speedText = new FlxText(120, 630, 100, "1.0x", 28).setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(speedText);
		var speedGuide:FlxText = new FlxText(120, 665, 120, "SPEED [↑/↓]", 12).setFormat(Paths.font("vcr.ttf"), 12, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(speedGuide);

		timeText = new FlxText(FlxG.width - 200, 630, 150, "0:00 / 0:00", 24).setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(timeText);

		progressBG = new FlxSprite(220, 640).makeGraphic(840, 12, FlxColor.BLACK);
		progressBG.alpha = 0.6;
		add(progressBG);

		progressBar = new FlxSprite(220, 640).makeGraphic(1, 12, FlxColor.GREEN);
		progressBar.origin.set(0, 0); 
		add(progressBar);

		// ปุ่มย้อนกลับสำหรับหน้าจอสัมผัส (แตะเพื่อออกจาก Jukebox)
		btnBackTouch = new FlxSprite(FlxG.width - 120, 20).makeGraphic(100, 50, 0xCC1E1E24);
		add(btnBackTouch);
		tBackTouch = new FlxText(FlxG.width - 120, 32, 100, "< EXIT", 20);
		tBackTouch.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(tBackTouch);

		controlGuide = new FlxText(0, FlxG.height - 25, FlxG.width, "MODS JUKEBOX: [← / →] Change Song | [SPACE] Play/Pause | Drag Bar to Seek | [BACK] Exit", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(controlGuide);

		debugText = new FlxText(10, FlxG.height - 60, FlxG.width - 20, "", 14);
		debugText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(debugText);

		loadingBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(loadingBG);

		loadingText = new FlxText(0, (FlxG.height / 2) - 100, FlxG.width, "SCANNING & PRELOADING MODS SONGS...\n(0/0)", 32).setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		loadingText.borderSize = 2;
		add(loadingText);

		loadingBarBG = new FlxSprite(0, (FlxG.height / 2) + 80).makeGraphic(800, 20, 0xFF333333);
		loadingBarBG.screenCenter(X);
		add(loadingBarBG);

		loadingBar = new FlxSprite(loadingBarBG.x, loadingBarBG.y).makeGraphic(1, 20, FlxColor.CYAN);
		loadingBar.origin.set(0, 0);
		add(loadingBar);

		instSound = new FlxSound();
		vocalsPlayer = new FlxSound();
		vocalsOpponent = new FlxSound();
		FlxG.sound.list.add(instSound);
		FlxG.sound.list.add(vocalsPlayer);
		FlxG.sound.list.add(vocalsOpponent);

		if (isAssetsLoaded && preloadedInst.keys().hasNext()) {
			finishGlobalPreload();
		} else {
			buildLoadTasks();
		}
	}

	/**
	 * สแกนหาเพลงจากโฟลเดอร์ mods ทั้งหมด โดยไม่อ่านจาก assets
	 */
	function scanSongsFromMods()
	{
		var directories:Map<String, String> = new Map<String, String>();

		#if sys
		// 1. สแกน mods/songs/ โดยตรง
		var rootModsSongs = "mods/songs/";
		if (FileSystem.exists(rootModsSongs) && FileSystem.isDirectory(rootModsSongs)) {
			for (folder in FileSystem.readDirectory(rootModsSongs)) {
				var fullPath = rootModsSongs + folder + "/";
				if (FileSystem.isDirectory(fullPath)) {
					directories.set(folder.toLowerCase(), fullPath);
				}
			}
		}

		// 2. สแกนแต่ละโฟลเดอร์ของ Mod เช่น mods/<modName>/songs/
		if (FileSystem.exists("mods/") && FileSystem.isDirectory("mods/")) {
			for (modDir in FileSystem.readDirectory("mods/")) {
				var songsPath = "mods/" + modDir + "/songs/";
				if (modDir != "songs" && FileSystem.isDirectory("mods/" + modDir) && FileSystem.exists(songsPath)) {
					if (FileSystem.isDirectory(songsPath)) {
						for (folder in FileSystem.readDirectory(songsPath)) {
							var fullPath = songsPath + folder + "/";
							if (FileSystem.isDirectory(fullPath)) {
								directories.set(folder.toLowerCase(), fullPath);
							}
						}
					}
				}
			}
		}

		// 3. ตรวจสอบผ่าน Paths.mods() ของ Engine (รองรับ Android External Storage Path)
		try {
			var engineModsSongs = Paths.mods('songs/');
			if (engineModsSongs != null && FileSystem.exists(engineModsSongs) && FileSystem.isDirectory(engineModsSongs)) {
				for (folder in FileSystem.readDirectory(engineModsSongs)) {
					var fullPath = engineModsSongs + folder + "/";
					if (FileSystem.isDirectory(fullPath)) {
						directories.set(folder.toLowerCase(), fullPath);
					}
				}
			}
		} catch(e:Dynamic) {}
		#end

		// 4. สแกนเพลงจาก WeekData เฉพาะที่อยู่ใน mods
		try {
			WeekData.reloadWeekFiles(false);
			for (i in 0...WeekData.weeksList.length) {
				var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
				if (weekFile != null && weekFile.songs != null) {
					for (song in weekFile.songs) {
						var songName:String = "";
						if (Reflect.hasField(song, "songName")) {
							songName = Reflect.field(song, "songName");
						} else if (Std.isOfType(song, Array)) {
							songName = song[0];
						}

						var lowSong = songName.toLowerCase();
						if (directories.exists(lowSong)) {
							var folderName = directories.get(lowSong).split("/")[directories.get(lowSong).split("/").length - 2];
							if (!songsList.contains(folderName)) {
								songsList.push(folderName);
								songsFolderList.push(directories.get(lowSong));
							}
						}
					}
				}
			}
		} catch(e:Dynamic) {}

		// ใส่รายชื่อเพลงทั้งหมดที่พบใน mods ที่ยังไม่ได้เพิ่มจาก WeekData
		for (songId in directories.keys()) {
			var folderPath = directories.get(songId);
			var folderName = folderPath.split("/")[folderPath.split("/").length - 2];
			if (!songsList.contains(folderName)) {
				songsList.push(folderName);
				songsFolderList.push(folderPath);
			}
		}

		// หากไม่มีเพลงใน mods เลยสักเพลง ให้แสดงโฟลเดอร์แจ้งเตือนใน mods
		if (songsList.length == 0) {
			debugText.text = "NOTICE: No songs found in 'mods/' folder! Please put song folders in mods/songs/<song>/";
		}
	}

	function buildLoadTasks() 
	{
		loadTasks = [];
		for (i in 0...songsList.length) {
			var name = songsList[i];
			var folder = songsFolderList[i];

			// ดึงไฟล์ Inst และ Vocals จากโฟลเดอร์ Mods
			var instPath:String = getCaseInsensitiveFile(folder, name, "Inst.ogg");
			var vpPath:String = getCaseInsensitiveFile(folder, name, "Voices-Player.ogg");
			var voPath:String = getCaseInsensitiveFile(folder, name, "Voices-Opponent.ogg");
			var vPath:String = getCaseInsensitiveFile(folder, name, "Voices.ogg");

			if (instPath != "") loadTasks.push({songName: name, type: "inst", path: instPath});
			if (vpPath != "" && voPath != "") {
				loadTasks.push({songName: name, type: "vp", path: vpPath});
				loadTasks.push({songName: name, type: "vo", path: voPath});
			} else if (vPath != "") {
				loadTasks.push({songName: name, type: "v", path: vPath});
			}
		}

		if (loadTasks.length == 0) {
			finishGlobalPreload();
		} else {
			currentTaskIndex = 0;
			startNextPreloadTask();
		}
	}

	function startNextPreloadTask() 
	{
		if (currentTaskIndex >= loadTasks.length) {
			loadingBar.scale.x = 800;
			finishGlobalPreload();
			return;
		}

		var task = loadTasks[currentTaskIndex];
		loadingText.text = "PRELOADING MODS ASSETS...\n\n(" + (currentTaskIndex + 1) + " / " + loadTasks.length + ")\nLOADING: " + task.songName.toUpperCase() + " (" + task.type.toUpperCase() + ")";
		
		var progressRatio:Float = currentTaskIndex / loadTasks.length;
		loadingBar.scale.x = progressRatio * 800;

		// -------------------------------------------------------------
		// [แก้ไขจุดที่ 3]: โหลดไฟล์เสียงจากไดเรกทอรี mods โดยตรง (Sound.loadFromFile)
		// -------------------------------------------------------------
		#if sys
		if (FileSystem.exists(task.path)) {
			Sound.loadFromFile(task.path).onComplete(function(snd:Sound) {
				onPreloadTaskLoaded(task, snd);
			}).onError(function(err) {
				// Fallback ในกรณีที่ไดรเวอร์เสียงต้องการอ่านเป็น ByteArray
				try {
					var bytes = File.getBytes(task.path);
					var snd:Sound = new Sound();
					snd.loadCompressedDataFromByteArray(bytes, bytes.length);
					onPreloadTaskLoaded(task, snd);
					return;
				} catch(e:Dynamic) {
					trace("[Jukebox] Error loading bytes from: " + task.path);
				}
				currentTaskIndex++;
				new FlxTimer().start(0.02, function(tmr:FlxTimer) { startNextPreloadTask(); });
			});
			return;
		}
		#end

		currentTaskIndex++;
		new FlxTimer().start(0.02, function(tmr:FlxTimer) {
			startNextPreloadTask();
		});
	}

	function onPreloadTaskLoaded(task:LoadTask, snd:Sound) 
	{
		switch(task.type) {
			case "inst": preloadedInst.set(task.songName, snd);
			case "vp": preloadedVP.set(task.songName, snd);
			case "vo": preloadedVO.set(task.songName, snd);
			case "v":
				preloadedVP.set(task.songName, snd);
				preloadedVO.set(task.songName, snd);
		}
		currentTaskIndex++;

		new FlxTimer().start(0.02, function(tmr:FlxTimer) {
			startNextPreloadTask();
		});
	}

	function finishGlobalPreload() 
	{
		isAssetsLoaded = true; 
		isLoading = false;
		
		loadingBG.visible = false;
		loadingText.visible = false;
		loadingBarBG.visible = false;
		loadingBar.visible = false;

		if (preloadedInst.keys().hasNext() == false) {
			debugText.text = "WARNING: No valid song audio loaded from 'mods/' folder. Found songs: " + songsList.length;
		}
		
		if (songsList.length > 0) {
			changeSong(0);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isLoading) return;

		// การควบคุมด้วยปุ่มคีย์บอร์ด
		if (controls.UI_LEFT_P || FlxG.keys.justPressed.LEFT) changeSong(-1);
		if (controls.UI_RIGHT_P || FlxG.keys.justPressed.RIGHT) changeSong(1);

		if (FlxG.keys.justPressed.M) toggleMuteInst();
		if (FlxG.keys.justPressed.V) toggleMuteVocals();
		if (FlxG.keys.justPressed.R) restartSong();
		if (FlxG.keys.justPressed.SPACE) togglePlayPause();
		if (FlxG.keys.justPressed.J) skipTime(-5000); 
		if (FlxG.keys.justPressed.K) skipTime(5000);  

		if (FlxG.keys.justPressed.UP) adjustSpeed(0.1);
		if (FlxG.keys.justPressed.DOWN) adjustSpeed(-0.1);

		// การควบคุมด้วยเมาส์และทัชสกรีน (Touch Screen Inputs)
		updateTextButtonMouse(leftArrow, function() { changeSong(-1); });
		updateTextButtonMouse(rightArrow, function() { changeSong(1); });

		updateSpriteButtonMouse(btnMuteInst, toggleMuteInst);
		updateSpriteButtonMouse(btnMuteVocals, toggleMuteVocals);
		updateSpriteButtonMouse(btnRestart, restartSong);
		updateSpriteButtonMouse(btnBackward5, function() { skipTime(-5000); });
		updateSpriteButtonMouse(btnPlayPause, togglePlayPause);
		updateSpriteButtonMouse(btnForward5, function() { skipTime(5000); });

		// ปุ่ม Back สัมผัสบนจอ
		updateSpriteButtonMouse(btnBackTouch, function() { goBackToMenu(); });

		// แถบเลื่อนเวลาเพลง (Progress Bar Drag / Scrubbing)
		if (instSound != null && instSound.length > 0) {
			if (isMouseOrTouchOver(progressBG) && FlxG.mouse.justPressed) {
				isScrubbing = true;
			}
			if (FlxG.mouse.justReleased) {
				isScrubbing = false;
			}

			if (isScrubbing) {
				var mouseX:Float = FlxG.mouse.x - progressBG.x;
				if (mouseX < 0) mouseX = 0;
				if (mouseX > progressBG.width) mouseX = progressBG.width;
				
				var pct:Float = mouseX / progressBG.width;
				var targetTime:Float = pct * instSound.length;
				
				instSound.time = targetTime;
				if (vocalsPlayer != null) vocalsPlayer.time = targetTime;
				if (vocalsOpponent != null) vocalsOpponent.time = targetTime;
			}
		}

		if ((instSound.playing || isPaused) && instSound.length > 0) {
			var progressRatio:Float = instSound.time / instSound.length;
			if (progressRatio > 1.0) progressRatio = 1.0;
			progressBar.scale.x = progressRatio * 840;

			timeText.text = formatTime(instSound.time) + " / " + formatTime(instSound.length);
		} else if (!isScrubbing) {
			progressBar.scale.x = 0;
			timeText.text = "0:00 / 0:00";
		}

		if (controls.BACK) {
			goBackToMenu();
		}
	}

	function goBackToMenu() 
	{
		if (instSound != null) instSound.stop();
		if (vocalsPlayer != null) vocalsPlayer.stop();
		if (vocalsOpponent != null) vocalsOpponent.stop();

		FlxG.mouse.visible = false; 
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		MusicBeatState.switchState(new MainMenuState());
	}

	function changeSong(change:Int)
	{
		if (songsList.length == 0) return;

		curSelected += change;
		if (curSelected < 0) curSelected = songsList.length - 1;
		if (curSelected >= songsList.length) curSelected = 0;

		var songName:String = songsList[curSelected];
		var songFolder:String = songsFolderList[curSelected];
		
		songText.text = "SONG: " + songName.toUpperCase().replace("-", " ");

		var artist:String = "Unknown Artist";
		var album:String = "Unknown Album";
		var albumImg:String = "unknown";

		// -------------------------------------------------------------
		// [แก้ไขจุดที่ 4]: อ่าน jukebox.json จากโฟลเดอร์ของ Mod
		// -------------------------------------------------------------
		#if sys
		var jsonPath:String = songFolder + "jukebox.json";
		if (FileSystem.exists(jsonPath)) {
			try {
				var rawJson:String = File.getContent(jsonPath);
				var meta:SongMetadata = Json.parse(rawJson);
				if (meta.artist != null) artist = meta.artist;
				if (meta.album != null) album = meta.album;
				if (meta.album_image != null) albumImg = meta.album_image;
			} catch(e:Dynamic) {}
		}
		#end

		artistText.text = "BY: " + artist.toUpperCase();
		albumText.text = "ALBUM: " + album.toUpperCase();

		isPaused = false;
		btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
		btnPlayPause.color = FlxColor.WHITE;
		btnPlayPause.setGraphicSize(50, 50); 
		btnPlayPause.updateHitbox();
		tPlayPause.text = "PAUSE\n[SPACE]";

		// -------------------------------------------------------------
		// [แก้ไขจุดที่ 5]: โหลดภาพหน้าปกจากโฟลเดอร์ MODS
		// -------------------------------------------------------------
		loadCoverImageFromMod(songFolder, albumImg);

		// เล่นเสียงเพลง Inst และ Vocals จาก RAM Cache
		playLoadedSong(songName);
	}

	/**
	 * ค้นหาและโหลดภาพหน้าปกของเพลงจากโฟลเดอร์ mod
	 */
	function loadCoverImageFromMod(songFolder:String, albumImg:String)
	{
		var modBasePath:String = "mods/";
		var parts = songFolder.split("/songs/");
		if (parts.length > 0) {
			modBasePath = parts[0] + "/";
		}

		var checkPaths:Array<String> = [
			songFolder + "album.png",
			songFolder + "cover.png",
			songFolder + albumImg + ".png",
			modBasePath + "images/albums/" + albumImg + ".png",
			modBasePath + "images/albums/" + albumImg + ".jpg",
			modBasePath + "shared/images/albums/" + albumImg + ".png",
			"mods/images/albums/" + albumImg + ".png",
			"mods/images/albums/" + albumImg + ".jpg"
		];

		var loadedBitmap:BitmapData = null;
		#if sys
		for (p in checkPaths) {
			if (FileSystem.exists(p) && !FileSystem.isDirectory(p)) {
				try {
					loadedBitmap = BitmapData.fromFile(p);
					if (loadedBitmap != null) break;
				} catch(e:Dynamic) {}
			}
		}
		#end

		if (loadedBitmap != null) {
			albumArt.loadGraphic(FlxGraphic.fromBitmapData(loadedBitmap));
		} else {
			albumArt.makeGraphic(440, 310, 0xFF333333);
		}
		albumArt.setGraphicSize(440, 310);
		albumArt.updateHitbox();
		albumArt.screenCenter(X);
	}

	/**
	 * เล่นเพลงที่พรีโหลดไว้จาก Mods
	 */
	function playLoadedSong(songName:String)
	{
		instSound.stop();
		vocalsPlayer.stop();
		vocalsOpponent.stop();

		if (preloadedInst.exists(songName)) {
			instSound.loadEmbedded(preloadedInst.get(songName));
			instSound.volume = isMuted ? 0 : 1;
			instSound.pitch = songSpeed;
			instSound.play();
		}

		if (preloadedVP.exists(songName)) {
			vocalsPlayer.loadEmbedded(preloadedVP.get(songName));
			vocalsPlayer.volume = vocalsMuted ? 0 : 1;
			vocalsPlayer.pitch = songSpeed;
			vocalsPlayer.play();
		}

		if (preloadedVO.exists(songName)) {
			vocalsOpponent.loadEmbedded(preloadedVO.get(songName));
			vocalsOpponent.volume = vocalsMuted ? 0 : 1;
			vocalsOpponent.pitch = songSpeed;
			vocalsOpponent.play();
		}
	}

	function togglePlayPause()
	{
		if (instSound == null || instSound.length == 0) return;

		isPaused = !isPaused;
		if (isPaused) {
			instSound.pause();
			vocalsPlayer.pause();
			vocalsOpponent.pause();
			btnPlayPause.loadGraphic(Paths.image('JukeboxUI/play'));
			tPlayPause.text = "PLAY\n[SPACE]";
		} else {
			instSound.resume();
			vocalsPlayer.resume();
			vocalsOpponent.resume();
			btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
			tPlayPause.text = "PAUSE\n[SPACE]";
		}
		btnPlayPause.setGraphicSize(50, 50);
		btnPlayPause.updateHitbox();
	}

	function toggleMuteInst()
	{
		isMuted = !isMuted;
		instSound.volume = isMuted ? 0 : 1;
		btnMuteInst.color = isMuted ? FlxColor.RED : FlxColor.WHITE;
	}

	function toggleMuteVocals()
	{
		vocalsMuted = !vocalsMuted;
		vocalsPlayer.volume = vocalsMuted ? 0 : 1;
		vocalsOpponent.volume = vocalsMuted ? 0 : 1;
		btnMuteVocals.color = vocalsMuted ? FlxColor.RED : FlxColor.WHITE;
	}

	function restartSong()
	{
		instSound.time = 0;
		vocalsPlayer.time = 0;
		vocalsOpponent.time = 0;
		if (isPaused) togglePlayPause();
	}

	function skipTime(offsetMs:Float)
	{
		if (instSound == null) return;
		var newTime = instSound.time + offsetMs;
		if (newTime < 0) newTime = 0;
		if (newTime > instSound.length) newTime = instSound.length;

		instSound.time = newTime;
		vocalsPlayer.time = newTime;
		vocalsOpponent.time = newTime;
	}

	function adjustSpeed(delta:Float)
	{
		songSpeed += delta;
		if (songSpeed < 0.25) songSpeed = 0.25;
		if (songSpeed > 3.0) songSpeed = 3.0;
		songSpeed = Math.round(songSpeed * 10) / 10;

		speedText.text = songSpeed + "x";
		instSound.pitch = songSpeed;
		vocalsPlayer.pitch = songSpeed;
		vocalsOpponent.pitch = songSpeed;
	}

	/**
	 * ค้นหาชื่อไฟล์ในโฟลเดอร์แบบ Case-Insensitive เพื่อรองรับทั้ง Linux และ Android
	 */
	function getCaseInsensitiveFile(folder:String, songName:String, targetFile:String):String
	{
		#if sys
		if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
			var lowTarget = targetFile.toLowerCase();
			for (f in FileSystem.readDirectory(folder)) {
				if (f.toLowerCase() == lowTarget) {
					return folder + f;
				}
			}
		}

		// ตรวจสอบแบบ Direct Path
		var direct = folder + targetFile;
		if (FileSystem.exists(direct)) return direct;
		#end

		return "";
	}

	function updateSpriteButtonMouse(spr:FlxSprite, onClick:Void->Void)
	{
		if (spr == null || !spr.visible) return;
		if (isMouseOrTouchOver(spr)) {
			spr.scale.set(1.1, 1.1);
			if (FlxG.mouse.justPressed) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				onClick();
			}
		} else {
			spr.scale.set(1.0, 1.0);
		}
	}

	function updateTextButtonMouse(txt:FlxText, onClick:Void->Void)
	{
		if (txt == null || !txt.visible) return;
		if (isMouseOrTouchOver(txt)) {
			txt.color = FlxColor.YELLOW;
			if (FlxG.mouse.justPressed) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				onClick();
			}
		} else {
			txt.color = FlxColor.WHITE;
		}
	}

	function isMouseOrTouchOver(spr:FlxSprite):Bool
	{
		var pad:Float = 12.0; // Hitbox padding ช่วยให้นิ้วแตะติดง่ายขึ้นบนมือถือ
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		return (mx >= spr.x - pad && mx <= spr.x + spr.width + pad &&
				my >= spr.y - pad && my <= spr.y + spr.height + pad);
	}

	function formatTime(ms:Float):String
	{
		var totalSec:Int = Math.floor(ms / 1000);
		var min:Int = Math.floor(totalSec / 60);
		var sec:Int = totalSec % 60;
		return min + ":" + (sec < 10 ? "0" : "") + sec;
	}

	override function destroy()
	{
		if (instSound != null) instSound.stop();
		if (vocalsPlayer != null) vocalsPlayer.stop();
		if (vocalsOpponent != null) vocalsOpponent.stop();
		super.destroy();
	}
}
