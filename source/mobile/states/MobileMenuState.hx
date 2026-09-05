package mikolka.vslice.ui;

import mikolka.compatibility.ui.MainMenuHooks;
import mikolka.compatibility.VsliceOptions;
import mikolka.compatibility.ModsHelper;
import mikolka.vslice.ui.title.TitleState;
import mikolka.vslice.freeplay.FreeplayState;
import mikolka.funkin.custom.mobile.MobileScaleMode;
import mobile.objects.GridButtons;
import mobile.objects.grid.*;
import options.OptionsState;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

#if !LEGACY_PSYCH
#if MODS_ALLOWED
import states.ModsMenuState;
#end
import states.AchievementsMenuState;
import states.CreditsState;
import states.editors.MasterEditorMenu;
#else
import editors.MasterEditorMenu;
#end

class MainMenuState extends MusicBeatState
{
	#if !LEGACY_PSYCH
	public static var psychEngineVersion:String = '1.0.4'; // ใช้สำหรับ Discord RPC ด้วย
	#else
	public static var psychEngineVersion:String = '0.6.3'; // ใช้สำหรับ Discord RPC ด้วย
	#end
	public static var MowVersion:String = '6.0';
	public static var funkinVersion:String = '0.7.6'; // เวอร์ชั่นของ funkin' ที่กำลังจำลองอยู่
	public static var CrVersion:String = '1.0'; // เวอร์ชั่นของ Mow Engine
	public static var crazyVersion:String = 'Revival'; // เวอร์ชั่นของ The Crazy of a night

	public var bg:FlxSprite;
	public var magenta:FlxSprite;
	var stickerSubState:Bool;

	// ----- เพิ่มมาจาก MobileMenuState เพื่อรวม UI เป็นตัวเดียว -----
	var selectedSomethin:Bool = false;
	var grid:GridButtons;

	public function new(?stickers:Bool = false)
	{
		super();
		stickerSubState = stickers;
	}

	override function create()
	{
		// ทำให้ touch จำลองเป็น mouse event ได้ด้วย
		// เพื่อให้ปุ่มแบบ Grid (ที่ตรวจจับด้วย FlxG.mouse) ใช้งานได้ทั้งเมาส์และนิ้วสัมผัสพร้อมกัน
		Multitouch.inputMode = MultitouchInputMode.NONE;
		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = true;

		if(stickerSubState) ModsHelper.clearStoredWithoutStickers();
		else CacheSystem.clearStoredMemory();
		CacheSystem.clearUnusedMemory();

		#if (debug && !LEGACY_PSYCH)
		FlxG.console.registerFunction("dumpCache",CacheSystem.cacheStatus); 
		FlxG.console.registerFunction("dumpSystem",backend.Native.buildSystemInfo);
		#end

		ModsHelper.resetActiveMods();
		#if DISCORD_ALLOWED
		// อัปเดต Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		persistentUpdate = persistentDraw = true;

		// แก้ไข: ใช้รูปภาพพื้นหลังจาก shared\images\Menu
		bg = new FlxSprite(-80).loadGraphic(Paths.image('Menu/crBG', 'shared'));
		bg.antialiasing = VsliceOptions.ANTIALIASING;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('Menu/menuDesat', 'shared'));
		magenta.antialiasing = VsliceOptions.ANTIALIASING;
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		#if ACHIEVEMENTS_ALLOWED
		// ปลดล็อกความสำเร็จ "Freaky on a Friday Night" หากเป็นวันศุกร์เวลา 18:00 น. ถึง 23:59 น.
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			MainMenuHooks.unlockFriday();
		#if MODS_ALLOWED
		MainMenuHooks.reloadAchievements();
		#end
		#end

		super.create();

		// ----- ส่วน UI ที่รวมมาจาก MobileMenuState -----
		buildMenuGrid();
	}

	function buildMenuGrid()
	{
		grid = new GridButtons((MobileScaleMode.gameCutoutSize.x / 4) + 30, 20, 2, Math.floor((MobileScaleMode.gameCutoutSize.x / 4) + 750));
		add(grid);

		grid.onItemSelect.add(s ->
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxTransitionableState.skipNextTransIn = false;
			FlxTransitionableState.skipNextTransOut = false;
			selectedSomethin = true;

			if (VsliceOptions.FLASHBANG)
				FlxFlicker.flicker(magenta, 1.1, 0.15, false);
		});

		var storyBtn = grid.makeButton('story_mode', 0, () ->
		{
			MusicBeatState.switchState(new StoryMenuState());
		});
		storyBtn.selectedOffset.set(10, 15);

		grid.makeButton('freeplay', 0, () ->
		{
			persistentDraw = true;
			persistentUpdate = false;
			// Freeplay has its own custom transition
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;

			openSubState(new FreeplayState());
			subStateOpened.addOnce(state ->
			{
				grid.revealButtons();
				selectedSomethin = false;
				grid.selectButton();
			});
		}).selectedOffset.set(10, 20);

		#if MODS_ALLOWED
		grid.makeButton('mods', 0, () ->
		{
			MusicBeatState.switchState(new ModsMenuState());
		});
		#end

		#if ACHIEVEMENTS_ALLOWED
		grid.makeButton('awards', 1, () ->
		{
			MusicBeatState.switchState(new AchievementsMenuState());
		}).selectedOffset.set(70, 15);
		#end

		grid.makeButton('credits', 1, () ->
		{
			MusicBeatState.switchState(new CreditsState());
		}).selectedOffset.set(150, 10);

		#if !switch
		var donateBtn = new GridTileDonate(grid);
		grid.addButton(donateBtn, 1);
		donateBtn.selectedOffset.set(30, 0);
		#end

		var optionsBtn = new OptionsButton(grid, () ->
		{
			goToOptions();
		});
		grid.addButton(optionsBtn, 0);
		optionsBtn.setPosition((MobileScaleMode.gameCutoutSize.x / 4) + 35, FlxG.height - 200);

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('NONE', 'B_C');
		#end

		grid.selectButton();
	}

	public function goToOptions()
	{
		MusicBeatState.switchState(new OptionsState());
		#if !LEGACY_PSYCH OptionsState.onPlayState = false; #end
		if (PlayState.SONG != null)
		{
			PlayState.SONG.arrowSkin = null;
			PlayState.SONG.splashSkin = null;
			#if !LEGACY_PSYCH PlayState.stageUI = 'normal'; #end
		}
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				grid.changeSelection(0, -1);

			if (controls.UI_DOWN_P)
				grid.changeSelection(0, 1);

			if (controls.UI_LEFT_P)
				grid.changeSelection(-1, 0);

			if (controls.UI_RIGHT_P)
				grid.changeSelection(1, 0);

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				selectedSomethin = true;
				grid.confirmCurrentButton();
			}

			if (#if TOUCH_CONTROLS_ALLOWED touchPad.buttonC.justPressed || #end
				#if LEGACY_PSYCH FlxG.keys.anyJustPressed(ClientPrefs.keyBinds.get('debug_1').filter(s -> s != -1)) #else controls.justPressed('debug_1') #end)
			{
				selectedSomethin = true;
				FlxTransitionableState.skipNextTransIn = false;
				FlxTransitionableState.skipNextTransOut = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
	}
}
