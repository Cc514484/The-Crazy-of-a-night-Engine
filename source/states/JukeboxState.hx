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

	// ปุ่มย้อนกลับสำหรับหน้าจอสัมผัส
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

	// เก็บ error/debug ไว้แสดงบนจอถ้าโหลดไม่ได้เลยสักเพลง (ช่วยดีบักบนมือถือที่ไม่มี console)
	var debugText:FlxText;

	override function create()
	{
		super.create();

		Multitouch.inputMode = MultitouchInputMode.NONE;
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

		var directories:Map<String, String> = new Map<String, String>();

		if (FileSystem.exists("mods/songs/")) {
			for (folder in FileSystem.readDirectory("mods/songs/")) {
				if (FileSystem.isDirectory("mods/songs/" + folder))
					directories.set(folder.toLowerCase(), "mods/songs/" + folder + "/");
			}
		}

		if (FileSystem.exists("mods/")) {
			for (modDir in FileSystem.readDirectory("mods/")) {
				var songsPath = "mods/" + modDir + "/songs/";
				if (modDir != "songs" && FileSystem.isDirectory("mods/" + modDir) && FileSystem.exists(songsPath)) {
					for (folder in FileSystem.readDirectory(songsPath)) {
						if (FileSystem.isDirectory(songsPath + folder))
							directories.set(folder.toLowerCase(), songsPath + folder + "/");
					}
				}
			}
		}

		#if desktop
		if (FileSystem.exists("assets/songs/")) {
			for (folder in FileSystem.readDirectory("assets/songs/")) {
				if (FileSystem.isDirectory("assets/songs/" + folder))
					directories.set(folder.toLowerCase(), "assets/songs/" + folder + "/");
			}
		}
		#end

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

					#if !desktop
					// บนมือถือ: เก็บ "ชื่อเพลงดิบ" ไว้ตรงๆ (ไม่ต้องเดา case ของโฟลเดอร์ล่วงหน้า)
					// เพราะเราจะลองหลาย case ตอนเช็คไฟล์จริงใน resolveMobileAsset() แทน
					if (!directories.exists(lowSong)) {
						directories.set(lowSong, "assets/songs/" + songName + "/");
					}
					#end

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

		for (songId in directories.keys()) {
			var folderPath = directories.get(songId);
			var folderName = folderPath.split("/")[folderPath.split("/").length - 2];
			if (!songsList.contains(folderName)) {
				songsList.push(folderName);
				songsFolderList.push(folderPath);
			}
		}

		if (songsList.length == 0) {
			songsList.push("tutorial");
			songsFolderList.push("assets/songs/tutorial/");
		}

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

		speedText = new FlxText(120, 630, 100, "1.0", 28).setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

		btnBackTouch = new FlxSprite(FlxG.width - 110, 20).makeGraphic(90, 50, 0xAA000000);
		add(btnBackTouch);
		tBackTouch = new FlxText(FlxG.width - 110, 20, 90, "BACK >", 18);
		tBackTouch.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(tBackTouch);

		controlGuide = new FlxText(0, FlxG.height - 25, FlxG.width, "KEYS: [← / →] Change Song | [ESCAPE] Back | Click & Drag Progress Bar to Seek Time", 14).setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(controlGuide);

		// ข้อความดีบัก (แสดงบนมือถือถ้าโหลดเพลงไม่สำเร็จเลยสักเพลง)
		debugText = new FlxText(10, FlxG.height - 60, FlxG.width - 20, "", 14);
		debugText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(debugText);

		loadingBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(loadingBG);

		loadingText = new FlxText(0, (FlxG.height / 2) - 100, FlxG.width, "PRELOADING ALL SONGS...\n(0/0)", 32).setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

		if (isAssetsLoaded) {
			finishGlobalPreload();
		} else {
			buildLoadTasks();
		}
	}

	function buildLoadTasks() {
		for (i in 0...songsList.length) {
			var name = songsList[i];
			var folder = songsFolderList[i];

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

	function startNextPreloadTask() {
		if (currentTaskIndex >= loadTasks.length) {
			loadingBar.scale.x = 800;
			finishGlobalPreload();
			return;
		}

		var task = loadTasks[currentTaskIndex];
		loadingText.text = "PRELOADING JUKEBOX ASSETS...\n\n(" + (currentTaskIndex + 1) + " / " + loadTasks.length + ")\nLOADING: " + task.songName.toUpperCase() + " (" + task.type.toUpperCase() + ")";
		
		var progressRatio:Float = currentTaskIndex / loadTasks.length;
		loadingBar.scale.x = progressRatio * 800;

		var isModFile:Bool = task.path.startsWith("mods/");

		#if !desktop
		if (!isModFile) {
			try {
				if (Assets.exists(task.path)) {
					var snd:Sound = Assets.getSound(task.path);
					if (snd != null) {
						onPreloadTaskLoaded(task, snd);
						return;
					}
				}
				trace("[Jukebox] Asset not found (mobile): " + task.path);
			} catch(e:Dynamic) {
				trace("[Jukebox] Error loading asset (mobile): " + task.path + " -> " + e);
			}
			currentTaskIndex++;
			new FlxTimer().start(0.03, function(tmr:FlxTimer) { startNextPreloadTask(); });
			return;
		}
		#end

		Sound.loadFromFile(task.path).onComplete(function(snd:Sound) {
			onPreloadTaskLoaded(task, snd);
		}).onError(function(err) {
			trace("[Jukebox] Skipped or Error loading file: " + task.path);
			currentTaskIndex++;
			new FlxTimer().start(0.03, function(tmr:FlxTimer) {
				startNextPreloadTask();
			});
		});
	}

	function onPreloadTaskLoaded(task:LoadTask, snd:Sound) {
		switch(task.type) {
			case "inst": preloadedInst.set(task.songName, snd);
			case "vp": preloadedVP.set(task.songName, snd);
			case "vo": preloadedVO.set(task.songName, snd);
			case "v":
				preloadedVP.set(task.songName, snd);
				preloadedVO.set(task.songName, snd);
		}
		currentTaskIndex++;

		new FlxTimer().start(0.03, function(tmr:FlxTimer) {
			startNextPreloadTask();
		});
	}

	function finishGlobalPreload() {
		isAssetsLoaded = true; 
		isLoading = false;
		
		loadingBG.visible = false;
		loadingText.visible = false;
		loadingBarBG.visible = false;
		loadingBar.visible = false;

		if (preloadedInst.keys().hasNext() == false) {
			// ไม่มีเพลงไหนโหลดสำเร็จเลยสักเพลง — โชว์ debug message บนจอ
			debugText.text = "WARNING: No songs loaded. Songs found: " + songsList.length +
				" | Check folder names/casing match WeekData song names.\nFirst folder tried: " +
				(songsFolderList.length > 0 ? songsFolderList[0] : "(none)");
		}
		
		changeSong(0); 
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isLoading) return;

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

		updateTextButtonMouse(leftArrow, function() { changeSong(-1); });
		updateTextButtonMouse(rightArrow, function() { changeSong(1); });

		updateSpriteButtonMouse(btnMuteInst, toggleMuteInst);
		updateSpriteButtonMouse(btnMuteVocals, toggleMuteVocals);
		updateSpriteButtonMouse(btnRestart, restartSong);
		updateSpriteButtonMouse(btnBackward5, function() { skipTime(-5000); });
		updateSpriteButtonMouse(btnPlayPause, togglePlayPause);
		updateSpriteButtonMouse(btnForward5, function() { skipTime(5000); });

		updateSpriteButtonMouse(btnBackTouch, function() { goBackToMenu(); });

		if (instSound != null && instSound.length > 0) {
			if (FlxG.mouse.overlaps(progressBG) && FlxG.mouse.justPressed) {
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
				vocalsPlayer.time = targetTime;
				vocalsOpponent.time = targetTime;
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

	function goBackToMenu() {
		instSound.stop();
		vocalsPlayer.stop();
		vocalsOpponent.stop();
		FlxG.mouse.visible = false; 
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		MusicBeatState.switchState(new MainMenuState());
	}

	function changeSong(change:Int)
	{
		curSelected += change;
		if (curSelected < 0) curSelected = songsList.length - 1;
		if (curSelected >= songsList.length) curSelected = 0;

		var songName:String = songsList[curSelected];
		var songFolder:String = songsFolderList[curSelected];
		
		songText.text = "SONG NAME: " + songName.toUpperCase().replace("-", " ");

		var artist:String = "Unknown Artist";
		var album:String = "Unknown Album";
		var albumImg:String = "unknown";

		var isModFolder:Bool = songFolder.startsWith("mods/");
		var jsonPath:String = isModFolder ? (songFolder + "jukebox.json") : resolveMobileAsset(songFolder, songName, "jukebox.json");

		var jsonExists:Bool = isModFolder ? FileSystem.exists(jsonPath) : (jsonPath != "" && Assets.exists(jsonPath));
		if (jsonExists) {
			try {
				var rawJson:String = isModFolder ? File.getContent(jsonPath) : Assets.getText(jsonPath);
				var meta:SongMetadata = Json.parse(rawJson);
				if(meta.artist != null) artist = meta.artist;
				if(meta.album != null) album = meta.album;
				if(meta.album_image != null) albumImg = meta.album_image;
			} catch(e:Dynamic) {}
		}

		artistText.text = "BY: " + artist.toUpperCase();
		albumText.text = "ALBUMS: " + album.toUpperCase();

		isPaused = false;
		
		btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
		btnPlayPause.color = FlxColor.WHITE;
		btnPlayPause.setGraphicSize(50, 50); btnPlayPause.updateHitbox();
		tPlayPause.text = "PAUSE\n[SPACE]";

		var modPath:String = "assets/";
		if (isModFolder) {
			var parts = songFolder.split("/songs/");
			if (parts.length > 0) modPath = parts[0] + "/";
		}

		var targetImagePath:String = "";
		
		var checkPaths:Array<String> = [
			modPath + "images/albums/" + albumImg + ".png",
			modPath + "images/albums/" + albumImg + ".jpg",
			modPath + "images/albums/" + albumImg + ".jpeg",
			modPath + "shared/images/albums/" + albumImg + ".png",
			modPath + "shared/images/albums/" + albumImg + ".jpg",
			modPath + "shared/images/albums/" + albumImg + ".jpeg",
			"assets/shared/images/albums/" + albumImg + ".png",
			"assets/shared/images/albums/" + albumImg + ".jpg",
			"assets/shared/images/albums/" + albumImg + ".jpeg",
			"assets/images/albums/" + albumImg + ".png",
			"assets/images/albums/" + albumImg + ".jpg",
			"assets/images/albums/" + albumImg + ".jpeg"
		];

		for (path in checkPaths) {
			var exists:Bool = isModFolder ? FileSystem.exists(path) : Assets.exists(path);
			if (exists) { targetImagePath = path; break; }
		}

		if (targetImagePath != "") {
			try {
				var bitmap:BitmapData = isModFolder ? BitmapData.fromFile(targetImagePath) : Assets.getBitmapData(targetImagePath);
				var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap);
				albumArt.loadGraphic(graphic); 

				var scale:Float = Math.min(400 / albumArt.width, 300 / albumArt.height);
				albumArt.setGraphicSize(Std.int(albumArt.width * scale), Std.int(albumArt.height * scale));
			} catch(e:Dynamic) {
				albumArt.makeGraphic(440, 310, FlxColor.GRAY);
				albumArt.setGraphicSize(400, 300);
			}
		} else {
			albumArt.makeGraphic(440, 310, FlxColor.GRAY);
			albumArt.setGraphicSize(400, 300);
		}
		albumArt.updateHitbox();
		albumArt.screenCenter(X);
		albumArt.y = 120 + (300 - albumArt.height) / 2;

		instSound.stop();
		vocalsPlayer.stop();
		vocalsOpponent.stop();

		var loadedAny:Bool = false;

		if (preloadedInst.exists(songName)) {
			instSound.loadEmbedded(preloadedInst.get(songName), false, false);
			loadedAny = true;
		}

		var hasVocals:Bool = false;
		if (preloadedVP.exists(songName)) {
			vocalsPlayer.loadEmbedded(preloadedVP.get(songName), false, false);
			hasVocals = true;
		}
		if (preloadedVO.exists(songName)) {
			vocalsOpponent.loadEmbedded(preloadedVO.get(songName), false, false);
			hasVocals = true;
		}

		instSound.looped = true;
		if (loadedAny) instSound.play();
		
		if (hasVocals) {
			vocalsPlayer.looped = true;
			vocalsOpponent.looped = true;
			vocalsPlayer.play();
			vocalsOpponent.play();
		}

		if (!loadedAny) {
			debugText.text = "Could not load audio for '" + songName + "'. Check that assets/songs/" + songName + "/Inst.ogg exists (case-sensitive on mobile).";
		} else {
			debugText.text = "";
		}

		setSongSpeed(songSpeed);
		updateVocalsVolume();
		instSound.volume = isMuted ? 0 : 1;
	}

	// ค้นหาไฟล์แบบไม่สนตัวพิมพ์เล็ก-ใหญ่ ทั้งของ mods/ (ผ่าน sys.FileSystem) และไฟล์ในตัวเกม (ผ่าน Assets, มือถือ)
	function getCaseInsensitiveFile(folder:String, songName:String, file:String):String {
		var isModFile:Bool = folder.startsWith("mods/");

		if (isModFile) {
			if (FileSystem.exists(folder + file)) return folder + file;
			if (FileSystem.exists(folder + file.toLowerCase())) return folder + file.toLowerCase();
			if (FileSystem.exists(folder + file.toUpperCase())) return folder + file.toUpperCase();
			if (FileSystem.exists(folder)) {
				for (f in FileSystem.readDirectory(folder)) {
					if (f.toLowerCase() == file.toLowerCase()) return folder + f;
				}
			}
			return "";
		}

		#if desktop
		if (FileSystem.exists(folder + file)) return folder + file;
		if (FileSystem.exists(folder + file.toLowerCase())) return folder + file.toLowerCase();
		if (FileSystem.exists(folder + file.toUpperCase())) return folder + file.toUpperCase();
		return "";
		#else
		return resolveMobileAsset(folder, songName, file);
		#end
	}

	// ===== หัวใจของการแก้บั๊ก =====
	// ลองทุก "การผสมกัน" ของ case ชื่อโฟลเดอร์ (เพลง) + case ชื่อไฟล์ เพราะ Assets.exists() บน
	// Android เป็น case-sensitive แบบเป๊ะๆ ต่างจาก sys.FileSystem บน desktop
	function resolveMobileAsset(originalFolder:String, songName:String, fileName:String):String {
		var basePath:String = "assets/songs/";
		var folderVariants:Array<String> = [];

		// ชื่อดั้งเดิมจาก WeekData/โฟลเดอร์ที่ตรวจเจอ
		if (!folderVariants.contains(songName)) folderVariants.push(songName);
		if (!folderVariants.contains(songName.toLowerCase())) folderVariants.push(songName.toLowerCase());
		if (!folderVariants.contains(songName.toUpperCase())) folderVariants.push(songName.toUpperCase());

		// Title Case (ตัวแรกใหญ่ ที่เหลือเล็ก) เช่น "tutorial" -> "Tutorial"
		if (songName.length > 0) {
			var titleCase = songName.substr(0, 1).toUpperCase() + songName.substr(1).toLowerCase();
			if (!folderVariants.contains(titleCase)) folderVariants.push(titleCase);
		}

		var fileVariants:Array<String> = [fileName, fileName.toLowerCase(), fileName.toUpperCase()];

		for (folderV in folderVariants) {
			for (fileV in fileVariants) {
				var candidate = basePath + folderV + "/" + fileV;
				if (Assets.exists(candidate)) {
					return candidate;
				}
			}
		}

		return "";
	}

	function toggleMuteInst() {
		isMuted = !isMuted;
		instSound.volume = isMuted ? 0 : 1;
		btnMuteInst.color = isMuted ? FlxColor.RED : FlxColor.WHITE;
	}

	function toggleMuteVocals() {
		vocalsMuted = !vocalsMuted;
		btnMuteVocals.color = vocalsMuted ? FlxColor.RED : FlxColor.WHITE;
		updateVocalsVolume();
	}

	function togglePlayPause() {
		isPaused = !isPaused;
		if (isPaused) {
			instSound.pause(); vocalsPlayer.pause(); vocalsOpponent.pause();
			btnPlayPause.loadGraphic(Paths.image('JukeboxUI/sex'));
			btnPlayPause.color = FlxColor.RED; 
			tPlayPause.text = "PLAY\n[SPACE]";
		} else {
			instSound.play(); vocalsPlayer.play(); vocalsOpponent.play();
			btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
			btnPlayPause.color = FlxColor.WHITE; 
			tPlayPause.text = "PAUSE\n[SPACE]";
		}
		btnPlayPause.setGraphicSize(50, 50);
		btnPlayPause.updateHitbox();
	}

	function skipTime(amount:Float) {
		var targetTime:Float = instSound.time + amount;
		if (targetTime < 0) targetTime = 0;
		if (targetTime > instSound.length) targetTime = instSound.length;

		instSound.time = targetTime;
		vocalsPlayer.time = targetTime;
		vocalsOpponent.time = targetTime;
	}

	function restartSong() {
		instSound.time = 0; vocalsPlayer.time = 0; vocalsOpponent.time = 0;
		isPaused = false;
		
		btnPlayPause.loadGraphic(Paths.image('JukeboxUI/stop'));
		btnPlayPause.color = FlxColor.WHITE; 
		btnPlayPause.setGraphicSize(50, 50); btnPlayPause.updateHitbox();
		tPlayPause.text = "PAUSE\n[SPACE]";

		instSound.looped = true;
		vocalsPlayer.looped = true;
		vocalsOpponent.looped = true;

		instSound.play(); vocalsPlayer.play(); vocalsOpponent.play();

		btnRestart.color = FlxColor.YELLOW;
		flixel.tweens.FlxTween.color(btnRestart, 0.2, FlxColor.YELLOW, FlxColor.WHITE);
	}

	function adjustSpeed(change:Float) {
		songSpeed += change;
		if (songSpeed > 2.0) songSpeed = 2.0;
		if (songSpeed < 0.5) songSpeed = 0.5;
		setSongSpeed(songSpeed);
	}

	var _lastSpeedText:String = "";
	function setSongSpeed(speed:Float) {
		songSpeed = speed;
		var displaySpeed = Std.string(Math.round(speed * 10) / 10);
		if (_lastSpeedText != displaySpeed) {
			speedText.text = displaySpeed;
			_lastSpeedText = displaySpeed;
		}
		instSound.pitch = speed;
		vocalsPlayer.pitch = speed;
		vocalsOpponent.pitch = speed;
	}

	function updateVocalsVolume() {
		if (vocalsMuted) {
			vocalsPlayer.volume = 0; vocalsOpponent.volume = 0;
		} else {
			vocalsPlayer.volume = 1;
			var vpPath:String = getCaseInsensitiveFile(songsFolderList[curSelected], songsList[curSelected], "Voices-Player.ogg");
			vocalsOpponent.volume = (vpPath != "") ? 1 : 0;
		}
	}

	function formatTime(milliseconds:Float):String {
		var totalSeconds:Int = Std.int(milliseconds / 1000);
		var minutes:Int = Std.int(totalSeconds / 60);
		var seconds:Int = totalSeconds % 60;
		return minutes + ":" + ((seconds < 10) ? "0" + seconds : Std.string(seconds));
	}

	function updateTextButtonMouse(text:FlxText, onClick:Void->Void) {
		if (FlxG.mouse.overlaps(text)) {
			text.scale.set(1.1, 1.1);
			if (FlxG.mouse.justPressed) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				onClick();
			}
		} else {
			text.scale.set(1.0, 1.0);
		}
	}

	function updateSpriteButtonMouse(sprite:FlxSprite, onClick:Void->Void) {
		if (FlxG.mouse.overlaps(sprite)) {
			sprite.alpha = 0.7; 
			if (FlxG.mouse.justPressed) onClick();
		} else {
			sprite.alpha = 1.0;
		}
	}
}
