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
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import openfl.media.Sound;
import openfl.utils.Assets;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;
import flixel.input.touch.FlxTouch;

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

	// UI Buttons (ขนาด 50x50 px)
	var leftArrow:FlxText;
	var rightArrow:FlxText;
	var btnMuteInst:FlxSprite;
	var btnMuteVocals:FlxSprite;
	var btnRestart:FlxSprite;
	var btnPlayPause:FlxSprite;
	var btnBackward5:FlxSprite;
	var btnForward5:FlxSprite;
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

	// แสดงข้อความดีบักบนจอ
	var debugText:FlxText;

	override function create()
	{
		super.create();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Jukebox - Listening to Music", null);
		#end

		// ปิดเสียงเพลงของ Main Menu ที่อาจจะเล่นค้างอยู่เพื่อไม่ให้ซ้อนกัน
		if (FlxG.sound.music != null && FlxG.sound.music.playing) {
			FlxG.sound.music.stop();
		}

		// เปิดโหมด Touch Point เพื่อให้จอมือถือแตะติด 100%
		#if FLX_TOUCH
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		#end

		FlxG.mouse.visible = true;

		// ช่องเสียงเพลงหลัก
		instSound = new FlxSound();
		FlxG.sound.list.add(instSound);

		vocalsPlayer = new FlxSound();
		FlxG.sound.list.add(vocalsPlayer);

		vocalsOpponent = new FlxSound();
		FlxG.sound.list.add(vocalsOpponent);

		bg = new FlxSprite().loadGraphic(Paths.image('Menu/crBG'));
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(FlxG.width * 1.1), 0);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		// สแกนรายชื่อเพลงจากโฟลเดอร์ MODS
		scanSongsFromMods();

		albumText = new FlxText(0, 40, FlxG.width, "ALBUM: NONE", 32);
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

		progressBG = new FlxSprite(220, 640).makeGraphic(840, 24, FlxColor.BLACK);
		progressBG.alpha = 0.6;
		add(progressBG);

		progressBar = new FlxSprite(220, 640).makeGraphic(1, 24, FlxColor.GREEN);
		progressBar.origin.set(0, 0); 
		add(progressBar);

		controlGuide = new FlxText(0, FlxG.height - 25, FlxG.width, "MODS JUKEBOX: [←/→] Change Song | [SPACE] Play/Pause | Drag Bar to Seek | [BACK] Exit", 12);
		controlGuide.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(controlGuide);

		// ปุ่ม EXIT สำหรับหน้าจอสัมผัส
		btnBackTouch = new FlxSprite(FlxG.width - 130, 20).makeGraphic(110, 42, 0xFF1E1E24);
		btnBackTouch.alpha = 0.85;
		add(btnBackTouch);

		tBackTouch = new FlxText(btnBackTouch.x, btnBackTouch.y + 10, btnBackTouch.width, "< EXIT", 20);
		tBackTouch.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(tBackTouch);

		debugText = new FlxText(10, 10, FlxG.width - 150, "", 14);
		debugText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(debugText);

		// หน้าจอ Loading
		loadingBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		loadingBG.alpha = 0.95; 
		add(loadingBG);

		loadingText = new FlxText(0, 300, FlxG.width, "SCANNING & PRELOADING SONGS FROM MODS...", 24);
		loadingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(loadingText);

		loadingBarBG = new FlxSprite(340, 360).makeGraphic(600, 20, FlxColor.GRAY);
		add(loadingBarBG);

		loadingBar = new FlxSprite(340, 360).makeGraphic(1, 20, FlxColor.GREEN);
		loadingBar.origin.set(0, 0);
		add(loadingBar);

		if (!isAssetsLoaded) {
			preparePreloadQueue();
		} else {
			finishGlobalPreload();
		}
	}

	function scanSongsFromMods()
	{
		songsList = [];
		songsFolderList = [];
		var directories:Map<String, String> = new Map();

		#if sys
		var rootCandidates:Array<String> = ["mods/songs/", "mods/song/"];
		for (rc in rootCandidates) {
			if (FileSystem.exists(rc) && FileSystem.isDirectory(rc)) {
				for (folder in FileSystem.readDirectory(rc)) {
					var fullPath = rc + folder + "/";
					if (FileSystem.isDirectory(fullPath)) {
						directories.set(folder.toLowerCase(), fullPath);
					}
				}
			}
		}

		if (FileSystem.exists("mods/") && FileSystem.isDirectory("mods/")) {
			for (modDir in FileSystem.readDirectory("mods/")) {
				if (modDir != "songs" && modDir != "song" && FileSystem.isDirectory("mods/" + modDir)) {
					var candidateSongPaths:Array<String> = [
						"mods/" + modDir + "/songs/",
						"mods/" + modDir + "/song/"
					];
					for (songsPath in candidateSongPaths) {
						if (FileSystem.exists(songsPath) && FileSystem.isDirectory(songsPath)) {
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
		}

		try {
			var androidCandidatePaths = [
				Paths.mods('songs/'),
				Paths.mods('song/')
			];
			for (androidPath in androidCandidatePaths) {
				if (androidPath != null && FileSystem.exists(androidPath) && FileSystem.isDirectory(androidPath)) {
					for (folder in FileSystem.readDirectory(androidPath)) {
						var fullPath = androidPath + folder + "/";
						if (FileSystem.isDirectory(fullPath)) {
							directories.set(folder.toLowerCase(), fullPath);
						}
					}
				}
			}
		} catch(e:Dynamic) {}
		#end

		for (songKey in directories.keys()) {
			songsList.push(songKey);
			songsFolderList.push(directories.get(songKey));
		}

		if (songsList.length == 0) {
			songsList.push("test");
			songsFolderList.push("mods/songs/test/");
		}
	}

	function preparePreloadQueue()
	{
		loadTasks = [];
		currentTaskIndex = 0;

		#if sys
		for (i in 0...songsList.length) {
			var sName = songsList[i];
			var sFolder = songsFolderList[i];

			var instPath = getCaseInsensitiveFile(sFolder, sName, "Inst.ogg");
			if (instPath != "") loadTasks.push({songName: sName, type: "inst", path: instPath});

			var vpPath = getCaseInsensitiveFile(sFolder, sName, "Voices-Player.ogg");
			if (vpPath != "") loadTasks.push({songName: sName, type: "vp", path: vpPath});

			var voPath = getCaseInsensitiveFile(sFolder, sName, "Voices-Opponent.ogg");
			if (voPath != "") loadTasks.push({songName: sName, type: "vo", path: voPath});

			if (vpPath == "" && voPath == "") {
				var vSingle = getCaseInsensitiveFile(sFolder, sName, "Voices.ogg");
				if (vSingle != "") loadTasks.push({songName: sName, type: "v", path: vSingle});
			}
		}
		#end

		if (loadTasks.length > 0) {
			startNextPreloadTask();
		} else {
			finishGlobalPreload();
		}
	}

	function startNextPreloadTask()
	{
		if (currentTaskIndex >= loadTasks.length) {
			finishGlobalPreload();
			return;
		}

		var task = loadTasks[currentTaskIndex];
		loadingText.text = "PRELOADING AUDIO: " + task.songName.toUpperCase() + " (" + (currentTaskIndex + 1) + "/" + loadTasks.length + ")";
		
		var pct = (currentTaskIndex + 1) / loadTasks.length;
		loadingBar.scale.x = pct * 600;

		var snd:Sound = null;
		#if sys
		try {
			if (FileSystem.exists(task.path)) {
				snd = Sound.fromFile(task.path);
			}
		} catch(e:Dynamic) {}

		if (snd == null) {
			try {
				var bytes = File.getBytes(task.path);
				if (bytes != null && bytes.length > 0) {
					snd = new Sound();
					snd.loadCompressedDataFromByteArray(bytes.getData(), bytes.length);
				}
			} catch(e:Dynamic) {}
		}
		#end

		switch (task.type) {
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
			debugText.text = "WARNING: No audio found in mods/. Songs detected: " + songsList.length;
		}
		
		if (songsList.length > 0) {
			changeSong(0);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isLoading) return;

		// คีย์บอร์ด
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

		// ตรวจจับการกดปุ่ม (เมาส์ + ทัชสกรีน) พร้อมเอฟเฟกต์กะพริบสี
		updateButtonLogic(leftArrow, function() { changeSong(-1); });
		updateButtonLogic(rightArrow, function() { changeSong(1); });
		updateButtonLogic(btnMuteInst, toggleMuteInst);
		updateButtonLogic(btnMuteVocals, toggleMuteVocals);
		updateButtonLogic(btnRestart, restartSong);
		updateButtonLogic(btnBackward5, function() { skipTime(-5000); });
		updateButtonLogic(btnPlayPause, togglePlayPause);
		updateButtonLogic(btnForward5, function() { skipTime(5000); });
		updateButtonLogic(btnBackTouch, function() { goBackToMenu(); });
		updateButtonLogic(tBackTouch, function() { goBackToMenu(); }); // ให้กดที่ตัวอักษร EXIT ได้ด้วย

		// ระบบลากแถบเวลา (รองรับทั้งเมาส์และทัช)
		if (instSound != null && instSound.length > 0) {
			
			var inputJustPressed = FlxG.mouse.justPressed;
			var inputReleased = FlxG.mouse.justReleased;
			var inputX:Float = FlxG.mouse.x;
			var inputY:Float = FlxG.mouse.y;

			#if FLX_TOUCH
			if (FlxG.touches.list.length > 0) {
				var touch = FlxG.touches.list[0];
				inputJustPressed = inputJustPressed || touch.justPressed;
				inputReleased = inputReleased || touch.justReleased;
				inputX = touch.x;
				inputY = touch.y;
			}
			#end

			if (inputJustPressed) {
				var pad = 20.0;
				if (inputX >= progressBG.x - pad && inputX <= progressBG.x + progressBG.width + pad &&
					inputY >= progressBG.y - pad && inputY <= progressBG.y + progressBG.height + pad) {
					isScrubbing = true;
				}
			}
			if (inputReleased) {
				isScrubbing = false;
			}

			if (isScrubbing) {
				var localX:Float = inputX - progressBG.x;
				if (localX < 0) localX = 0;
				if (localX > progressBG.width) localX = progressBG.width;
				
				var pct:Float = localX / progressBG.width;
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
		FlxG.sound.play(Paths.sound('cancelMenu'));
		destroyAudio();
		
		#if FLX_TOUCH
		Multitouch.inputMode = MultitouchInputMode.NONE;
		#end
		
		// กลับไปหน้า Main Menu โดยให้มันจัดการเล่นเพลงเมนูขึ้นมาใหม่เอง
		MusicBeatState.switchState(new mikolka.vslice.ui.MainMenuState());
	}

	function destroyAudio()
	{
		if (instSound != null) {
			instSound.stop();
			FlxG.sound.list.remove(instSound);
		}
		if (vocalsPlayer != null) {
			vocalsPlayer.stop();
			FlxG.sound.list.remove(vocalsPlayer);
		}
		if (vocalsOpponent != null) {
			vocalsOpponent.stop();
			FlxG.sound.list.remove(vocalsOpponent);
		}
	}

	function changeSong(change:Int = 0)
	{
		if (songsList.length == 0) return;

		curSelected += change;
		if (curSelected < 0) curSelected = songsList.length - 1;
		if (curSelected >= songsList.length) curSelected = 0;

		var songName:String = songsList[curSelected];
		var songFolder:String = songsFolderList[curSelected];

		songText.text = "SONG: " + songName.toUpperCase();
		var artist:String = "Unknown";
		var album:String = "Unknown";
		var albumImg:String = "unknown";

		#if sys
		var jsonPath:String = getCaseInsensitiveFile(songFolder, songName, "jukebox.json");
		if (jsonPath != "" && FileSystem.exists(jsonPath)) {
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

		// รีเซ็ตปุ่ม Play/Pause เป็นสถานะ "เล่นอยู่" (สีขาว)
		isPaused = false;
		btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
		btnPlayPause.color = FlxColor.WHITE; 
		btnPlayPause.setGraphicSize(50, 50); 
		btnPlayPause.updateHitbox();
		tPlayPause.text = "PAUSE\n[SPACE]";

		loadCoverImage(songFolder, albumImg);
		playLoadedSong(songName);
	}

	function loadCoverImage(songFolder:String, albumImg:String)
	{
		var cleanImgName:String = albumImg;
		if (cleanImgName == null || cleanImgName.trim() == "") {
			cleanImgName = "unknown";
		}
		if (cleanImgName.endsWith(".png")) {
			cleanImgName = cleanImgName.substr(0, cleanImgName.length - 4);
		}
		if (cleanImgName.startsWith("albums/")) {
			cleanImgName = cleanImgName.substr(7);
		}

		var graphic:FlxGraphic = Paths.image('albums/' + cleanImgName);
		if (graphic == null) graphic = Paths.image(cleanImgName);
		if (graphic == null) graphic = Paths.image('albums/unknown');

		if (graphic != null) {
			albumArt.loadGraphic(graphic);
		} else {
			var loadedBitmap:BitmapData = null;
			#if sys
			var checkPaths:Array<String> = [
				"assets/shared/images/albums/" + cleanImgName + ".png",
				"assets/images/albums/" + cleanImgName + ".png",
				"assets/shared/images/albums/" + cleanImgName + ".jpg",
				"assets/images/albums/" + cleanImgName + ".jpg",
				"assets/shared/images/" + cleanImgName + ".png",
				"assets/images/" + cleanImgName + ".png",
				songFolder + "album.png",
				songFolder + "cover.png",
				songFolder + cleanImgName + ".png",
				"mods/images/albums/" + cleanImgName + ".png",
				"mods/images/albums/" + cleanImgName + ".jpg"
			];

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
		}

		// รักษาอัตราส่วนภาพปกอัลบั้ม
		albumArt.scale.set(1, 1);
		albumArt.updateHitbox();
		
		var scaleX:Float = 440 / albumArt.width;
		var scaleY:Float = 310 / albumArt.height;
		var finalScale:Float = Math.min(scaleX, scaleY);
		
		albumArt.scale.set(finalScale, finalScale);
		albumArt.updateHitbox();
		albumArt.screenCenter(X);
	}

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
			btnPlayPause.color = FlxColor.RED; // หยุดเพลงเปลี่ยนปุ่มเป็นสีแดง
			tPlayPause.text = "PLAY\n[SPACE]";
		} else {
			instSound.resume();
			vocalsPlayer.resume();
			vocalsOpponent.resume();
			btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
			btnPlayPause.color = FlxColor.WHITE; // เล่นเพลงกลับมาเป็นสีขาว
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

		var direct = folder + targetFile;
		if (FileSystem.exists(direct)) return direct;
		#end

		return "";
	}

	// ฟังก์ชันจัดการคลิก/ทัช พร้อมเพิ่มลูกเล่นกระพริบสีเวลากด
	function updateButtonLogic(obj:flixel.FlxObject, onClick:Void->Void)
	{
		if (obj == null || !obj.visible) return;
		
		var pad:Float = 15.0;
		var isClicked = false;

		// ตรวจสอบเมาส์ PC
		if (FlxG.mouse.justPressed) {
			if (FlxG.mouse.x >= obj.x - pad && FlxG.mouse.x <= obj.x + obj.width + pad &&
				FlxG.mouse.y >= obj.y - pad && FlxG.mouse.y <= obj.y + obj.height + pad) {
				isClicked = true;
			}
		}

		// ตรวจสอบหน้าจอสัมผัส
		#if FLX_TOUCH
		for (touch in FlxG.touches.justStarted()) {
			if (touch.x >= obj.x - pad && touch.x <= obj.x + obj.width + pad &&
				touch.y >= obj.y - pad && touch.y <= obj.y + obj.height + pad) {
				isClicked = true;
			}
		}
		#end

		if (isClicked) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
			
			// ถ้าเป็น FlxText (ปุ่มตัวอักษร) ให้กะพริบเป็นสีเหลืองชั่วคราว
			if (Std.isOfType(obj, FlxText)) {
				var txt = cast(obj, FlxText);
				txt.color = FlxColor.YELLOW;
				new FlxTimer().start(0.1, function(tmr:FlxTimer) { txt.color = FlxColor.WHITE; });
			}
			// ถ้าเป็น FlxSprite (ปุ่มไอคอน) และไม่ใช่ปุ่มที่มีสถานะเปิด/ปิด (Mute/Play) ให้กะพริบเป็นสีเทา
			else if (Std.isOfType(obj, FlxSprite)) {
				var spr = cast(obj, FlxSprite);
				if (spr != btnMuteInst && spr != btnMuteVocals && spr != btnPlayPause) {
					spr.color = FlxColor.GRAY;
					new FlxTimer().start(0.1, function(tmr:FlxTimer) { spr.color = FlxColor.WHITE; });
				}
			}
			
			onClick();
		}
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
