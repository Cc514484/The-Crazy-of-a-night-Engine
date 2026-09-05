package mikolka.vslice.ui.mainmenu;

import mikolka.vslice.freeplay.FreeplayState;
import options.OptionsState;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.effects.FlxFlicker;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import mikolka.vslice.ui.title.TitleState; 
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxObject; 
import flixel.addons.transition.FlxTransitionableState;
import states.ArtGallery;
import states.CharacterProfiles;
import states.JukeboxState;

#if !LEGACY_PSYCH
#if MODS_ALLOWED
import states.ModsMenuState;
import backend.Mods; 
import backend.WeekData; // ใช้เข้าถึงข้อมูลแต่ละ Week
import backend.Highscore; // ใช้ตรวจจับว่า Week นั้นๆ เคยเล่นจบหรือยังจากฐานข้อมูลคะแนน
#end
import states.AchievementsMenuState;
import states.CreditsState;
import states.editors.MasterEditorMenu;
#else
import editors.MasterEditorMenu;
#end

import mikolka.compatibility.VsliceOptions;
import lime.app.Application; 
import flash.system.System;  

@:access(mikolka.vslice.ui.MainMenuState)
class DesktopMenuState extends FlxBasic
{
	var optionShit:Array<String> = ['story_mode', 'freeplay', 'credits', 'options'];
	var sideImageNames:Array<String> = ['me1', 'me2', 'me3', 'me4'];

	public static var curSelected:Int = 0;
	var selectedSomethin:Bool = false;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var camFollow:FlxObject; 
	
	var sideImage:FlxSprite; 
	var leftImage:FlxSprite;
	var sideImageTween:FlxTween;
	var itemTweens:Array<FlxTween> = [];

	// ปุ่มพิเศษฝั่งขวา
	var artButton:FlxSprite;
	var artSelected:Bool = false;
	var bottomLButton:FlxSprite;
	var bottomLSelected:Bool = false;
	var jukeboxButton:FlxSprite;
	var jukeboxSelected:Bool = false;
	
	// เพิ่มตัวแปรสำหรับปุ่ม Mods ฝั่งขวา
	var modsButton:FlxSprite;
	var modsSelected:Bool = false;
	
	var host:MainMenuState;

	public function new(host:MainMenuState) {
		super();
		this.host = host;

		// --- ระบบตรวจจับ MOD (The crazy of a night Revival Part 2) ---
		#if MODS_ALLOWED
		var hasTargetMod:Bool = false;
		var modList:Array<String> = Mods.getModDirectories(); 
		
		for (mod in modList) {
			if (mod == "The crazy of a night Revival Part 2") {
				hasTargetMod = true;
				break;
			}
		}

		if (!hasTargetMod) {
			if (lime.app.Application.current.window != null) {
				lime.app.Application.current.window.alert(
					"Not have a The Crazy of a night mod can't play idiot", 
					"Mod Missing Error"
				);
			}
			System.exit(0);
			return; 
		}
		#end
		// -----------------------------------------------------

		host.add(this);

		FlxG.mouse.visible = false;
		host.bg.scrollFactor.set(0, 0);
		host.bg.screenCenter();
		host.bg.scale.set(1, 1); 

		camFollow = new FlxObject(0, 0, 1, 1);
		host.add(camFollow);
		var scr:Float = (optionShit.length - 4) * 0.135;
		if (optionShit.length < 6) scr = 0;

		leftImage = new FlxSprite(-800, 0);
		leftImage.loadGraphic(Paths.image('Menu/ihatewin11', 'shared'));
		leftImage.antialiasing = VsliceOptions.ANTIALIASING;
		leftImage.scrollFactor.set(0, scr);
		leftImage.screenCenter(Y);
		host.add(leftImage);
		FlxTween.tween(leftImage, {x: 0}, 2.0, {ease: FlxEase.expoOut});
		sideImage = new FlxSprite(FlxG.width + 500, 0);
		sideImage.antialiasing = VsliceOptions.ANTIALIASING;
		sideImage.scrollFactor.set(0, scr);
		host.add(sideImage);

		menuItems = new FlxTypedGroup<FlxSprite>();
		host.add(menuItems);
		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(-500, (i * 150) + offset);
			menuItem.antialiasing = VsliceOptions.ANTIALIASING;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItems.add(menuItem);
			menuItem.scrollFactor.set(0, scr);
			menuItem.updateHitbox();
			itemTweens.push(null);
			FlxTween.tween(menuItem, {x: 100}, 1 + (i * 0.15), {ease: FlxEase.expoOut, startDelay: 0.1});
		} 

		// --- ตั้งค่าปุ่ม Art Gallery (ล่างสุด / ลำดับที่ 4) ---
		artButton = new FlxSprite(FlxG.width + 500, FlxG.height - 120); 
		artButton.loadGraphic(Paths.image('Menu/bottom', 'shared'));
		artButton.antialiasing = VsliceOptions.ANTIALIASING;
		artButton.scale.set(0.5, 0.5);
		artButton.scrollFactor.set();
		artButton.updateHitbox(); 
		host.add(artButton);

		var targetX:Float = FlxG.width - artButton.width - 20;
		var targetArtY:Float = FlxG.height - artButton.height - 20;
		FlxTween.tween(artButton, {x: targetX, y: targetArtY}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.7});

		// --- ตั้งค่าปุ่ม Character Profiles (ลำดับที่ 3) ---
		bottomLButton = new FlxSprite(FlxG.width + 500, targetArtY - 100); 
		bottomLButton.loadGraphic(Paths.image('Menu/bottomL', 'shared'));
		bottomLButton.antialiasing = VsliceOptions.ANTIALIASING;
		bottomLButton.scale.set(0.5, 0.5);
		bottomLButton.scrollFactor.set();
		bottomLButton.updateHitbox();
		host.add(bottomLButton);

		var targetBottomLY:Float = targetArtY - bottomLButton.height - 10;
		FlxTween.tween(bottomLButton, {x: targetX, y: targetBottomLY}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.6});

		// --- ตั้งค่าปุ่ม Jukebox (ลำดับที่ 2 อยู่ใต้ปุ่มมอด) ---
		jukeboxButton = new FlxSprite(FlxG.width + 500, targetBottomLY - 100);
		jukeboxButton.loadGraphic(Paths.image('Menu/Jukebox', 'shared')); 
		jukeboxButton.antialiasing = VsliceOptions.ANTIALIASING;
		jukeboxButton.scale.set(0.5, 0.5);
		jukeboxButton.scrollFactor.set();
		jukeboxButton.updateHitbox();
		host.add(jukeboxButton);

		var targetJukeboxY:Float = targetBottomLY - jukeboxButton.height - 10;
		FlxTween.tween(jukeboxButton, {x: targetX, y: targetJukeboxY}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.5});

		// --- ตั้งค่าปุ่ม Mods (ลำดับที่ 1 อยู่ด้านบนสุดของกลุ่มปุ่มขวา) ---
		modsButton = new FlxSprite(FlxG.width + 500, targetJukeboxY - 100);
		modsButton.loadGraphic(Paths.image('Menu/modpl', 'shared')); 
		modsButton.antialiasing = VsliceOptions.ANTIALIASING;
		modsButton.scale.set(0.5, 0.5);
		modsButton.scrollFactor.set();
		modsButton.updateHitbox();
		host.add(modsButton);

		var targetModsY:Float = targetJukeboxY - modsButton.height - 10;
		FlxTween.tween(modsButton, {x: targetX, y: targetModsY}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.4});

		#if MODS_ALLOWED
		if (!checkAllVisibleWeeksCleared()) {
			modsButton.color = 0xFF777777; 
		}
		#end

		// ตัวหนังสือเวอร์ชัน
		var fnfVer:FlxText = new FlxText(-500, FlxG.height - 18, FlxG.width, 'v${MainMenuState.funkinVersion} (Powered by MOW Engine ${MainMenuState.MowVersion})', 12);
		var mowVer:FlxText = new FlxText(-500, 700 - 18, FlxG.width, "The Crazy Engine " + MainMenuState.CrVersion, 12);
		var psychVer:FlxText = new FlxText(FlxG.width + 500, FlxG.height - 18, FlxG.width, "Psych Engine " + MainMenuState.psychEngineVersion, 12);
		var crazyVer:FlxText = new FlxText(FlxG.width + 500, 700 - 18, FlxG.width, "The Crazy of a Night " + MainMenuState.crazyVersion, 12);
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		mowVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		crazyVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);

		for (text in [psychVer, fnfVer, mowVer, crazyVer]) {
			text.scrollFactor.set();
			host.add(text);
		}

		FlxTween.tween(fnfVer, {x: 0}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.1});
		FlxTween.tween(mowVer, {x: 0}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.2});
		FlxTween.tween(psychVer, {x: 0}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.1});
		FlxTween.tween(crazyVer, {x: 0}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.2});

		FlxG.camera.follow(camFollow, null, 0.06);
		changeItem();
	}

	// --- ฟังก์ชันปลดล็อกมอดถาวร (ให้ส่งค่า true เสมอ) ---
	private function checkAllVisibleWeeksCleared():Bool
	{
		return true; // ปลดล็อกปุ่ม Mods ตั้งแต่เริ่มต้นทันที
	}

	/**
	 * เช็คว่านิ้ว/เมาส์แตะโดนปุ่มไหนในเมนูบ้าง แล้วสั่งงานทันที
	 * (แตะ = เลือกเลยในทีเดียว ไม่ต้องเลื่อนไฮไลต์แบบกดจอย/คีย์บอร์ด)
	 * เรียกทุกเฟรมจาก update() ตอนที่ selectedSomethin ยังเป็น false
	 */
	function checkTouchInput()
	{
		// เมนูหลักฝั่งซ้าย (story_mode / freeplay / credits / options)
		for (item in menuItems.members)
		{
			if (item != null && item.exists && item.visible && MainMenuState.checkPressed(item))
			{
				resetSideSelection();
				if (curSelected != item.ID)
					changeItem(item.ID - curSelected);
				selectItem();
				return;
			}
		}

		// ปุ่มขวา 4 ปุ่ม: mods / jukebox / character profiles / art gallery
		if (modsButton != null && modsButton.exists && modsButton.visible && MainMenuState.checkPressed(modsButton))
		{
			#if MODS_ALLOWED
			deselectMainItems();
			resetSideSelection();
			modsSelected = true;
			selectMods();
			#end
			return;
		}

		if (jukeboxButton != null && jukeboxButton.exists && jukeboxButton.visible && MainMenuState.checkPressed(jukeboxButton))
		{
			deselectMainItems();
			resetSideSelection();
			jukeboxSelected = true;
			selectJukebox();
			return;
		}

		if (bottomLButton != null && bottomLButton.exists && bottomLButton.visible && MainMenuState.checkPressed(bottomLButton))
		{
			deselectMainItems();
			resetSideSelection();
			bottomLSelected = true;
			selectBottomL();
			return;
		}

		if (artButton != null && artButton.exists && artButton.visible && MainMenuState.checkPressed(artButton))
		{
			deselectMainItems();
			resetSideSelection();
			artSelected = true;
			selectArt();
			return;
		}
	}

	function resetSideSelection()
	{
		artSelected = false;
		bottomLSelected = false;
		jukeboxSelected = false;
		modsSelected = false;
	}

	override function update(elapsed:Float)
	{
		if (!selectedSomethin)
		{
			checkTouchInput();
		}

		if (!selectedSomethin)
		{
			if (!artSelected && !bottomLSelected && !jukeboxSelected && !modsSelected) 
			{
				if (host.controls.UI_UP_P) changeItem(-1);
				if (host.controls.UI_DOWN_P) changeItem(1);
				if (host.controls.ACCEPT) selectItem();
				if (host.controls.UI_RIGHT_P) {
					modsSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(modsButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
					deselectMainItems();
				}
			}
			else if (modsSelected) 
			{
				if (host.controls.ACCEPT) selectMods();
				if (host.controls.UI_LEFT_P) {
					modsSelected = false;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(modsButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					changeItem(0); 
				}
				if (host.controls.UI_DOWN_P) {
					modsSelected = false;
					jukeboxSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(modsButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(jukeboxButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
			}
			else if (jukeboxSelected) 
			{
				if (host.controls.ACCEPT) selectJukebox();
				if (host.controls.UI_LEFT_P) {
					jukeboxSelected = false;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(jukeboxButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					changeItem(0); 
				}
				if (host.controls.UI_UP_P) {
					jukeboxSelected = false;
					modsSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(jukeboxButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(modsButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
				if (host.controls.UI_DOWN_P) {
					jukeboxSelected = false;
					bottomLSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(jukeboxButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(bottomLButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
			}
			else if (bottomLSelected) 
			{
				if (host.controls.ACCEPT) selectBottomL();
				if (host.controls.UI_LEFT_P) {
					bottomLSelected = false;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(bottomLButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					changeItem(0); 
				}
				if (host.controls.UI_UP_P) {
					bottomLSelected = false;
					jukeboxSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(bottomLButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(jukeboxButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
				if (host.controls.UI_DOWN_P) {
					bottomLSelected = false;
					artSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(bottomLButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(artButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
			}
			else if (artSelected) 
			{
				if (host.controls.ACCEPT) selectArt();
				if (host.controls.UI_LEFT_P) {
					artSelected = false;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(artButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					changeItem(0); 
				}
				if (host.controls.UI_UP_P) {
					artSelected = false;
					bottomLSelected = true;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					FlxTween.tween(artButton.scale, {x: 0.5, y: 0.5}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(bottomLButton.scale, {x: 0.6, y: 0.6}, 0.1, {ease: FlxEase.quadOut});
				}
			}

			if (host.controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
			
			if (host.controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}
		super.update(elapsed);
	}

	function deselectMainItems() {
		var item = menuItems.members[curSelected];
		item.animation.play('idle');
		item.updateHitbox();
		if (itemTweens[item.ID] != null) itemTweens[item.ID].cancel();
		itemTweens[item.ID] = FlxTween.tween(item, {x: 100}, 0.15, {ease: FlxEase.quadOut});
	}

	function selectItem() {
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		var choice:String = optionShit[curSelected];

		if (choice != 'freeplay')
		{
			FlxTween.tween(FlxG.camera, {zoom: 1.15}, 1.1, {ease: FlxEase.quadInOut});
			FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
		}

		if (VsliceOptions.FLASHBANG)
			FlxFlicker.flicker(host.magenta, 1.1, 0.15, false);

		for (i in 0...menuItems.members.length)
		{
			if (i == curSelected) continue;
			FlxTween.tween(menuItems.members[i], {alpha: 0, x: -500}, 0.5, {
				ease: FlxEase.expoIn,
				onComplete: function(twn:FlxTween) { menuItems.members[i].kill(); }
			});
		} 

		FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, false, false, function(flick:FlxFlicker)
		{
			switch (choice)
			{
				case 'story_mode': MusicBeatState.switchState(new StoryMenuState());
				case 'freeplay':
					{
						host.persistentDraw = true;
						host.persistentUpdate = false;
						host.openSubState(new FreeplayState());
						host.subStateOpened.addOnce(state -> {
							selectedSomethin = false;
							for (item in menuItems.members) {
								item.revive();
								item.visible = true;
								item.alpha = 1;
								item.x = 100;
								if (itemTweens[item.ID] != null) itemTweens[item.ID].cancel();
							}
							changeItem(0);
						});
					}
				case 'credits': MusicBeatState.switchState(new CreditsState());
				case 'options': host.goToOptions();
			}
		});
	}

	function selectMods() {
		#if MODS_ALLOWED
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		modsButton.color = FlxColor.WHITE; 
		FlxTween.tween(FlxG.camera, {zoom: 1.15}, 1.1, {ease: FlxEase.quadInOut});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false, function() {
			MusicBeatState.switchState(new states.ModsMenuState());
		});
		#else
		selectedSomethin = false; 
		#end
	}

	function selectJukebox() {
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxTween.tween(FlxG.camera, {zoom: 1.15}, 1.1, {ease: FlxEase.quadInOut});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false, function() {
			MusicBeatState.switchState(new states.JukeboxState());
		});
	}

	function selectBottomL() {
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxTween.tween(FlxG.camera, {zoom: 1.15}, 1.1, {ease: FlxEase.quadInOut});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false, function() {
			MusicBeatState.switchState(new CharacterProfiles());
		});
	}

	function selectArt() {
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxTween.tween(FlxG.camera, {zoom: 1.15}, 1.1, {ease: FlxEase.quadInOut});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false, function() {
			MusicBeatState.switchState(new ArtGallery());
		});
	}

	function changeItem(huh:Int = 0)
	{
		if ((artSelected || bottomLSelected || jukeboxSelected || modsSelected) && huh != 0) return; 

		if (huh != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
		if (itemTweens[curSelected] != null) itemTweens[curSelected].cancel();
		menuItems.members[curSelected].animation.play('idle');
		menuItems.members[curSelected].updateHitbox();
		itemTweens[curSelected] = FlxTween.tween(menuItems.members[curSelected], {x: 100}, 0.15, {ease: FlxEase.quadOut});

		curSelected += huh;
		if (curSelected >= menuItems.length) curSelected = 0;
		if (curSelected < 0) curSelected = menuItems.length - 1;
		
		var targetItem = menuItems.members[curSelected];
		targetItem.animation.play('selected');
		targetItem.centerOffsets();
		if (itemTweens[curSelected] != null) itemTweens[curSelected].cancel();
		itemTweens[curSelected] = FlxTween.tween(targetItem, {x: 140}, 0.2, {ease: FlxEase.quadOut});
		
		if (sideImageTween != null) sideImageTween.cancel();
		sideImageTween = FlxTween.tween(sideImage, {x: FlxG.width + 300, alpha: 0}, 0.15, {
			ease: FlxEase.expoIn,
			onComplete: function(twn:FlxTween) {
				sideImage.loadGraphic(Paths.image('Menu/' + sideImageNames[curSelected], 'shared'));
				sideImage.updateHitbox();
				sideImage.screenCenter(Y);
				sideImage.x = FlxG.width + 200;
				sideImage.alpha = 0;

				sideImageTween = FlxTween.tween(sideImage, {x: FlxG.width - sideImage.width - 20, alpha: 1}, 0.4, {
					ease: FlxEase.backOut
				});
			}
		});
		camFollow.setPosition(targetItem.getGraphicMidpoint().x, targetItem.getGraphicMidpoint().y);
	}
}
