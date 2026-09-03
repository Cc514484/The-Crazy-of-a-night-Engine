package mikolka.vslice.freeplay;

import flixel.text.FlxText;

@:nullSafety
class BGScrollingText extends FlxText
{
  // เก็บตัวแปร public ไว้เผื่อไฟล์อื่นเรียกใช้ จะได้ไม่ Error
  public var widthShit:Float = 0;
  public var placementOffset:Float = 0;
  public var speed:Float = 0;

  public function new(x:Float, y:Float, text:String, widthShit:Float = 0, ?bold:Bool = false, ?size:Int = 0)
  {
    super(x, y, 0, "", size); // ส่งข้อความว่างเปล่าเข้าไป
    this.visible = false;     // ปิดการมองเห็น (ไม่วาดลงจอ)
    this.active = false;      // ปิดการทำงาน (ไม่ต้องคำนวณ)
  }

  override public function update(elapsed:Float):Void
  {
    // ปล่อยว่างไว้ ไม่ต้องให้มีการขยับหรือทำงานใดๆ
  }

  override public function draw():Void
  {
    // ปล่อยว่างไว้ ไม่ต้องวาดอะไรออกมา
  }
} 