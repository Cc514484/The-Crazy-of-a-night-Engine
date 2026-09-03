package mikolka.vslice.ui.disclaimer;

import flixel.FlxState;
import flixel.FlxG; // เพิ่ม Import FlxG สำหรับใช้คำสั่งเปลี่ยนหน้า

class OutdatedState extends WarningState
{
	var targetState:FlxState;

	public function new(newVersion:String, nextState:FlxState) {
		this.targetState = nextState;
		
		// ลบข้อความแจ้งเตือนทิ้งไป และส่งค่าว่างให้ WarningState
		super("", () -> {}, onExit, nextState);
	}

	override public function create() {
		super.create();
		
		// เมื่อหน้านี้ถูกสร้างขึ้น ให้บังคับเด้งไปหน้าเมนูหลัก (nextState) ทันที
		FlxG.switchState(targetState);
	}
}

class FlashingState extends WarningState{
	public function new(nextState:FlxState) {

		final enter:String = controls.mobileC ? 'A' : 'ENTER';
		final escape:String = controls.mobileC ? 'B' : 'ESCAPE';
		var text = 	"Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Press " + enter + " to disable them now or go to Options Menu.\n
			Press " + escape + " to ignore this message.\n
			You've been warned!";
		super(text,() ->{
			#if LEGACY_PSYCH
			ClientPrefs.flashing = false;
			#else
			ClientPrefs.data.flashing = false;
			#end
			ClientPrefs.saveSettings();
		},() ->{},nextState);
	}
}