package mikolka.vslice.ui;

import mikolka.vslice.ui.mainmenu.DesktopMenuState;
import mikolka.compatibility.ui.MainMenuHooks;
import mikolka.compatibility.VsliceOptions;
import mikolka.vslice.ui.title.TitleState;
import mikolka.compatibility.ModsHelper;
import options.OptionsState;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.FlxColor;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

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

	public function new(?stickers:Bool = false)
	{
		super();
		stickerSubState = stickers;
	}

	override function create()
	{
		// ทำให้ touch จำลองเป็น mouse event ได้ด้วย (ใช้เป็นตัวเสริม เผื่อบางเครื่องรองรับ)
		Multitouch.inputMode = MultitouchInputMode.NONE;

		// เปิดใช้เมาส์เสมอ ไม่ว่าจะเป็นแพลตฟอร์มไหน
		FlxG.mouse.enabled = true;
		#if desktop
		FlxG.mouse.visible = true;
		#else
		// บนมือถือซ่อน cursor ไว้ (นิ้วแตะไม่ต้องมี cursor โผล่)
		FlxG.mouse.visible = false;
		#end

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
		// ส่วนของ psychVer, mowVer, crazyVer, fnfVer ถูกลบออกเพื่อให้ไปขึ้นที่ DesktopMenuState แทน
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
		
		// ใช้ DesktopMenuState เสมอ เพราะรองรับทั้ง mouse และ touch
		new DesktopMenuState(this);
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
		super.update(elapsed);
	}

	/**
	 * เช็คว่ามีการ "แตะเพิ่งกด" (justPressed) ทับวัตถุนี้หรือไม่
	 * รองรับทั้งเมาส์จริง และนิ้วสัมผัสจริงบนอุปกรณ์ (FlxG.touches)
	 * โดยไม่พึ่งพาแค่การจำลอง touch -> mouse ของระบบเพียงอย่างเดียว
	 *
	 * ใช้แทนการเช็ค FlxG.mouse.justPressed && FlxG.mouse.overlaps(obj) เดิม
	 * เช่น: if (MainMenuState.checkPressed(myButton)) { ... }
	 */
	public static function checkPressed(obj:FlxObject):Bool
	{
		// เมาส์จริง (สำหรับเดสก์ท็อป หรือกรณีที่ touch->mouse simulation ทำงาน)
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(obj))
			return true;

		// นิ้วสัมผัสจริงทุกจุดบนจอ (multitouch อิสระ ไม่ผูกกับ mouse pointer เดียว)
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed && touch.overlaps(obj))
				return true;
		}
		#end

		return false;
	}

	/**
	 * เหมือน checkPressed แต่เช็คแบบ "กดค้างอยู่" (pressed) แทน justPressed
	 * มีประโยชน์ตอนทำ hover/scale effect ตอนกดค้าง
	 */
	public static function checkHeld(obj:FlxObject):Bool
	{
		if (FlxG.mouse.pressed && FlxG.mouse.overlaps(obj))
			return true;

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed && touch.overlaps(obj))
				return true;
		}
		#end

		return false;
	}
}
