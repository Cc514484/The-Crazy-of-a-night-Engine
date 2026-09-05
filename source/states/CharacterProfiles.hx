package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import flixel.addons.text.FlxTypeText;
import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;
import mikolka.vslice.ui.MainMenuState;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

// === ส่วนดึงข้อมูลภายนอกแบบเรียลไทม์ และดึงโฟลเดอร์ม็อดอัตโนมัติ ===
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import backend.Mods; // เรียกใช้คลาสจัดการระบบม็อดของ Engine

typedef SingleCharJson = {
    var name:String;
    var isSecretMode:Bool; 
    var bio:String;
    var hasCycle:Bool;
    var cycleImages:Array<String>;
}

class CharacterProfiles extends MusicBeatState
{
    // ตัวแปรหลักสำหรับใช้รันในระบบหน้าจอเกม
    var charList:Array<String> = [];
    var charBios:Array<String> = [];
    var secretList:Array<String> = [];
    var secretBios:Array<String> = [];

    // [ข้อมูลดั้งเดิม - แผนสำรอง] แยกไว้สำหรับล้างค่าเพื่อเริ่มต้นโหลดใหม่ทุกรอบที่สลับเข้าหน้าจอ
    var defaultCharList:Array<String> = ['Stardust', 'Red', 'Audrey','Hank', 'mastercat', 'Rock'];
    var defaultCharBios:Array<String> = [
        "Name: Stardust/Hoshina\nAge: 25\nGender: Male (Femboy)\n\nStory: He is Hank's older brother. He became an orphan at the age of 11 due to unknown circumstances and has lived independently ever since. He raised his younger brother, Red/Hank, through many hardships. Fortunately, their parents left behind an inheritance, providing them with a stroke of luck amidst their misfortune.\n\nPersonality: Hoshina is a natural leader with a kind heart. He deeply loves and cares for his mischievous younger brother.\n\nRelationships: He is in a committed relationship with Katoshi, whom he loves dearly.",
        "Name: Red\nAge: 19\nGender: Male (Loves tomboys)\n\nStory: Red is a very reclusive person. He suffers from recurring nightmares about his parents almost every night, which led to a period of deep depression between the ages of 10 and 15. This lasted until he met Boyfriend and Audrey, who became the lights of his life. He trusts Audrey more than anyone, and over time, she helped him fully recover from his depression. However, he still suffers from side effects—any extreme shock can cause him to lose his sanity and go mad. Eventually, Red asked Audrey to be his girlfriend because he loves her deeply for saving him from his dark times. Through her, he also met Rock, Stardust’s partner. Interestingly, Red is not close with his siblings at all. He was rejected from the experiments for being too weak and mentally unstable. Furthermore, Red deeply despises Hank, as Hank's experiments were the ultimate cause of their parents' death.\n\nPersonality: Around strangers or people he isn't close with, he is incredibly quiet and reserved. However, once he is with close friends, he becomes extremely annoying and mischievous to the max.\n\nRelationships: Audrey is his girlfriend, and they are deeply in love with each other. Stardust is his older brother, whom he loves very much.",
        "Name: Audrey\nAge: 19\nGender: Female (Tomboy)\n\nStory: Audrey is a very cheerful person, especially with her family. She was adopted by Daddy Dearest to become a superstar, but because she didn't inherit the 'singer's blood,' she couldn't perform as expected, leading to constant pressure. While her twin brother, Rock, ran away to live with his lover, Audrey chose to stay.\n\nPersonality: Generally very cheerful and friendly. However, she has a darker, yandere side and suffers from depression due to the pressure she faces, though she masks it by pretending everything is fine.\n\nRelationships: Hank is someone she loves deeply—to the point of wanting him all to herself. Rock is her twin brother.",
        "Name: Hank\nAge: 15\nGender: Male (Loves tomboys)\n\nStory: Hank is one of the modified humans created by his parents before they passed away, when he was just 1 year old. The experiment was known as 'Human Emoji'—a project aimed at transforming newborn babies into emoji faces by completely removing their necks and changing their skin color to match. Hank's creation was considered the ultimate success of this project. However, this catastrophic experiment was also the exact reason why their parents died, wiping out the household and leaving only the children behind.\n\nPersonality: This guy is incredibly annoying, a total crybaby, and extremely spoiled (in a purely trolling and mischievous way).\n\nRelationships: He is the youngest sibling in the family. As for whether he has a girlfriend? Absolutely not—nobody wants him.",
        "Name: Mastercat/Cat\nAge: 16\nGender: Male\n\nStory: Mastercat is one of the test subjects from a project called 'Animal-Human Compilation'—an experiment where cat genes were implanted into a fetus about 4 months before birth. Just like Hank, Mastercat was a successful creation of this project. While he deeply loves his oldest brother Stardust and his younger brother Hank, he does not get along with his older brother Red. Due to various past issues, Red constantly takes his anger out on Mastercat, treating him harshly and completely disregarding his feelings just because he doesn't look like a normal human.\n\nPersonality: Mastercat is extremely family-oriented (with the sole exception of Red). He has a strong habit of seeking out comfortable places to rest, and you can usually find him napping on a cozy sofa or curled up against someone he trusts.\n\nRelationships: He doesn't get along well with women at all, as they often look down on him and treat him like an ugly freak. On the other hand, his bond with his siblings varies greatly: he absolutely adores Stardust and loves to snuggle up against Stardust's thighs almost every chance he gets because it feels incredibly comfortable. Hank is also a younger brother whom Mastercat loves dearly, and Hank similarly enjoys snuggling up on Stardust's thighs too. However, Mastercat deeply detests Red because Red always uses him as a punching bag whenever he has a problem.",
        "Name: Rock/Katoshi\nAge: 19\nGender: Male\n\nStory: Rock lost his parents the moment he was born, alongside his twin sister, Audrey. Fortunately, they were both adopted and raised by Daddy Dearest. However, when Rock turned 17, he decided to run away from home to live with the person he loved most—Stardust/Hoshina. While he completely cut ties with the Dearest family, he still keeps in touch and maintains contact with his sister, Audrey.\n\nPersonality: Rock absolutely despises Daddy Dearest due to the constant, immense pressure Dearest placed on Audrey, which built up his deep resentment over the years. Outside of that, Rock is an incredibly kind-hearted person who is fiercely protective and will not tolerate anyone hurting the people he loves.\n\nRelationships: Audrey is his twin sister, whom he still cares about. Hoshina is his boyfriend, and they are in a deeply committed relationship."
    ];

    var defaultSecretList:Array<String> = ['Yasa', 'Corost', 'someone', 'dodo', 'Taff', 'Maverick', 'Tord', 'kane', 'TaffVsdodo', 'Pepe', 'Tamp'];
    var defaultSecretBios:Array<String> = [
        "Name: Yasa\n\nOne day, I joined Team Tfunk, the crew behind ^The Crazy of a night.^ I’ve worked on it, handling so many different things until the mod finally took shape and is now going incredibly well. Ever since I started working here, I’ve been much happier, and it has been an amazing journey.\n\nOh, and my name is Yasa. You shouldn’t know my age—or my gender. I am a core developer here and handle almost everything except the music; the systems and mechanics are all my doing. If you don’t like me being a furry, $I will turn you into a furry.$\n\nNow, go read the next profile. Who knows?",
        "Name: Corost\n\nHe made a 3 broter broooo",
        "Name: someone\n\nWho Know?",
        "Name: dodo\n\nI love Kane suck femboy",
        "Name: Taff\n\nIDK buddy",
        "Name: Maverick Gamer Channel\n\nDam This is kane SUCKS Fc Nightmares",
        "Name: Tord\n\nThose who knows",
        "Name: kane\n\nKane Suck Broter?",
        "Name: Taff Vs dodo\n\nWho is more Ruthless the Game?",
        "Name: Pepe\nAge: 15\nGender: Male \n\nHe is the boy who love his friends so much. He care and he tell a joke, even if it isn't funny and he admits it.",
        "Name: Tamp\n\nA former tomboy hunter is murdered by a his own tomboy"
    ];
   
    var curSelectedNormal:Int = 0;
    var curSelectedSecret:Int = 0;
    var isSecret:Bool = false;
    var isTransitioning:Bool = false;
    var canChange:Bool = true;

    var bg:FlxSprite;
    var ldiAnim:FlxSprite;
    var bioText:FlxTypeText;
    var mainChar:FlxSprite;
    var nameGroup:FlxSpriteGroup;
    var nameBox:FlxSprite;
    var nameText:FlxText;
    var leftArrow:FlxText; 
    var rightArrow:FlxText;
    var switchHint:FlxText;
    var blackScreen:FlxSprite;

    // ปุ่มย้อนกลับสำหรับหน้าจอสัมผัส
    var btnBackTouch:FlxSprite;
    var tBackTouch:FlxText;

    // ตัวแปรสำหรับลากนิ้วเลื่อนอ่าน bio (แทน mouse wheel ที่ไม่มีบนมือถือ)
    var isDraggingBio:Bool = false;
    var dragStartY:Float = 0;
    var bioStartY:Float = 0;

    var cycleTimer:FlxTimer;
    var currentCycleIdx:Int = 0;
    var loadedJsonProfiles:Map<String, SingleCharJson> = new Map<String, SingleCharJson>();
    
    // ตัวแปรเก็บพาทโฟลเดอร์ที่ตรวจเจอไฟล์ล่าสุด เพื่อเอาไว้ให้พาร์ทโหลดรูปภาพดึงไปใช้งานต่อได้ถูกต้อง
    var activeModPath:String = "mods/"; 

    var bioOffsetX:Float = 100; 
    var bioOffsetY:Float = 120;

    override function create()
    {
        // ทำให้แตะหน้าจอจำลองเป็น mouse event ได้ด้วย (ปุ่มลูกศร/ปุ่มย้อนกลับ ใช้ FlxG.mouse ตรวจจับ)
        Multitouch.inputMode = MultitouchInputMode.NONE;
        FlxG.mouse.enabled = true;

        #if DISCORD_ALLOWED
        backend.Discord.DiscordClient.changePresence("Viewing Character Profiles", null);
        #end

        // สแกนและโหลดข้อมูลไฟล์ภายนอกใหม่ทุกครั้งก่อนสร้างหน้าจอ UI
        scanAndLoadJsonFiles();

        FlxG.mouse.visible = true;

        bg = new FlxSprite().loadGraphic(Paths.image('Menu/crBG'));
        bg.antialiasing = backend.ClientPrefs.data.antialiasing;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        bg.screenCenter();
        add(bg);

        ldiAnim = new FlxSprite(0, 10);
        ldiAnim.frames = Paths.getSparrowAtlas('Menu/Ldi');
        ldiAnim.animation.addByPrefix('wwe', 'wwe', 24, true);
        ldiAnim.animation.play('wwe');
        ldiAnim.scale.set(1.1, 1.1); 
        ldiAnim.updateHitbox();
        add(ldiAnim);

        bioText = new FlxTypeText(ldiAnim.x + bioOffsetX, ldiAnim.y + bioOffsetY, 330, "", 24);
        bioText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        bioText.clipRect = new FlxRect(0, 0, 330, 520);
        add(bioText);

        mainChar = new FlxSprite(720, 80);
        mainChar.antialiasing = backend.ClientPrefs.data.antialiasing;
        add(mainChar);

        nameGroup = new FlxSpriteGroup(800, 580);
        nameBox = new FlxSprite().makeGraphic(320, 70, FlxColor.BLACK); 
        nameGroup.add(nameBox);

        nameText = new FlxText(0, 15, 320, "");
        nameText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
        nameGroup.add(nameText);

        // ลูกศรซ้าย/ขวา — เพิ่มพื้นที่แตะให้ใหญ่ขึ้นด้วย hitbox โปร่งใสซ้อนด้านหลัง เพื่อให้กดง่ายขึ้นบนมือถือ
        leftArrow = new FlxText(-50, 5, 0, "<", 50);
        leftArrow.setFormat(Paths.font("vcr.ttf"), 50, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        nameGroup.add(leftArrow);

        rightArrow = new FlxText(330, 5, 0, ">", 50);
        rightArrow.setFormat(Paths.font("vcr.ttf"), 50, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        nameGroup.add(rightArrow);

        switchHint = new FlxText(0, 75, 320, "[Press TAB to Switch Mode]", 16);
        switchHint.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        nameGroup.add(switchHint);
        add(nameGroup);

        blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        blackScreen.alpha = 0;
        add(blackScreen);

        // ปุ่มย้อนกลับที่แตะได้จริง (เดิมมีแค่ controls.BACK ที่พึ่งปุ่มจริง)
        btnBackTouch = new FlxSprite(20, 20).makeGraphic(90, 50, 0xAA000000);
        add(btnBackTouch);
        tBackTouch = new FlxText(20, 20, 90, "< BACK", 18);
        tBackTouch.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(tBackTouch);

        changeSelection();
        super.create();
    }

    override function update(elapsed:Float)
    {
        if (!isTransitioning) {
            if (controls.UI_LEFT_P) changeSelection(-1);
            if (controls.UI_RIGHT_P) changeSelection(1);

            // ----- Mouse / Touch: ปุ่มลูกศรเปลี่ยนตัวละคร (เดิมวาดไว้เฉยๆ ไม่มี logic) -----
            updateArrowTouch(leftArrow, -1);
            updateArrowTouch(rightArrow, 1);

            // ----- Mouse / Touch: แตะ switchHint เพื่อสลับโหมดลับ (แทนปุ่ม TAB บนคีย์บอร์ด) -----
            if (FlxG.mouse.overlaps(switchHint)) {
                switchHint.scale.set(1.05, 1.05);
                if (FlxG.mouse.justPressed) toggleSecret();
            } else {
                switchHint.scale.set(1.0, 1.0);
            }

            // ----- เมาส์วีล (desktop) -----
            if (FlxG.mouse.wheel != 0) {
                bioText.y += FlxG.mouse.wheel * 45;
                updateBioClip();
            }

            // ----- ลากนิ้วเลื่อนอ่าน bio (touch drag) -----
            var overBio:Bool = FlxG.mouse.overlaps(bioText) || (FlxG.mouse.x > ldiAnim.x + bioOffsetX - 20 && FlxG.mouse.x < ldiAnim.x + bioOffsetX + 350
                && FlxG.mouse.y > ldiAnim.y + bioOffsetY - 20 && FlxG.mouse.y < ldiAnim.y + bioOffsetY + 540);

            if (FlxG.mouse.justPressed && overBio) {
                isDraggingBio = true;
                dragStartY = FlxG.mouse.y;
                bioStartY = bioText.y;
            }
            if (FlxG.mouse.justReleased) {
                isDraggingBio = false;
            }
            if (isDraggingBio) {
                var deltaY:Float = FlxG.mouse.y - dragStartY;
                bioText.y = bioStartY + deltaY;
                updateBioClip();
            }
            
            var topLimit = ldiAnim.y + bioOffsetY;
            var bottomLimit = ldiAnim.y + bioOffsetY - (bioText.height > 420 ? bioText.height - 420 : 0);
            bioText.y = FlxMath.bound(bioText.y, bottomLimit, topLimit);
            updateBioClip();

            if (FlxG.keys.justPressed.TAB) toggleSecret();
        }

        // ----- ปุ่มย้อนกลับที่แตะได้ -----
        if (FlxG.mouse.overlaps(btnBackTouch)) {
            btnBackTouch.alpha = 0.7;
            if (FlxG.mouse.justPressed) goBackToMenu();
        } else {
            btnBackTouch.alpha = 1.0;
        }

        if (controls.BACK) {
            goBackToMenu();
        }

        super.update(elapsed);
    }

    function goBackToMenu() {
        FlxG.sound.play(Paths.sound('cancelMenu'));
        MusicBeatState.switchState(new MainMenuState());
    }

    function updateArrowTouch(arrow:FlxText, direction:Int) {
        if (FlxG.mouse.overlaps(arrow)) {
            arrow.scale.set(1.3, 1.3);
            if (FlxG.mouse.justPressed) changeSelection(direction);
        } else {
            arrow.scale.set(1.0, 1.0);
        }
    }

    function updateBioClip() {
        if (bioText.clipRect != null) {
            var clip = bioText.clipRect;
            clip.y = (ldiAnim.y + bioOffsetY) - bioText.y;
            bioText.clipRect = clip;
        }
    }

    // === ส่วนพัฒนาใหม่: ฟังก์ชันสแกนหาโฟลเดอร์ของม็อดปัจจุบันแบบ Dynamic ===
    function scanAndLoadJsonFiles()
    {
        loadedJsonProfiles.clear();
        charList = defaultCharList.copy();
        charBios = defaultCharBios.copy();
        secretList = defaultSecretList.copy();
        secretBios = defaultSecretBios.copy();

        var pathsToSearch:Array<String> = [];

        // 1. ดึงชื่อโฟลเดอร์ม็อดปัจจุบันที่กำลังเล่นอยู่ (เช่น "The crazy of a night Revival Part 2" หรืออื่นๆ)
        if (Mods.currentModDirectory != null && Mods.currentModDirectory != "") {
            pathsToSearch.push("mods/" + Mods.currentModDirectory + "/CharacterProfiles/");
        }
        
        // 2. โฟลเดอร์สำรองหากวางไว้ในรูทกลางของม็อด
        pathsToSearch.push("mods/CharacterProfiles/");

        // 3. ตรวจสอบและเลือกโฟลเดอร์ที่ใช้งานได้จริง
        var targetDir:String = "";
        for (path in pathsToSearch) {
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                targetDir = path;
                break;
            }
        }

        // 4. แผนสำรองสุดท้าย: ถ้ายังหาไม่เจอ ให้สแกนทุกโฟลเดอร์ใน mods/ เผื่อหาห้อง CharacterProfiles เจอ
        if (targetDir == "" && FileSystem.exists("mods/") && FileSystem.isDirectory("mods/")) {
            for (dir in FileSystem.readDirectory("mods/")) {
                var checkPath = "mods/" + dir + "/CharacterProfiles/";
                if (FileSystem.exists(checkPath) && FileSystem.isDirectory(checkPath)) {
                    targetDir = checkPath;
                    break;
                }
            }
        }

        // พ่นบอกในคอมพิวเตอร์ว่าตอนนี้ระบบกำลังอ่านข้อมูลจากพาทไหนอยู่
        if (targetDir != "") {
            activeModPath = targetDir;
            trace("CharacterProfiles loading from: " + activeModPath);
            
            var files:Array<String> = FileSystem.readDirectory(activeModPath);
            for (file in files) {
                if (std.StringTools.endsWith(file.toLowerCase(), ".json")) {
                    try {
                        var rawJson:String = File.getContent(activeModPath + file);
                        var data:SingleCharJson = Json.parse(rawJson);
                        
                        var keyName:String = file.substring(0, file.length - 5);
                        loadedJsonProfiles.set(keyName, data);

                        if (data.isSecretMode) {
                            if (charList.contains(keyName)) {
                                var idx = charList.indexOf(keyName);
                                charList.splice(idx, 1);
                                charBios.splice(idx, 1);
                            }
                            if (!secretList.contains(keyName)) {
                                secretList.push(keyName);
                                secretBios.push(data.bio);
                            } else {
                                secretBios[secretList.indexOf(keyName)] = data.bio;
                            }
                        } else {
                            if (secretList.contains(keyName)) {
                                var idx = secretList.indexOf(keyName);
                                secretList.splice(idx, 1);
                                secretBios.splice(idx, 1);
                            }
                            if (!charList.contains(keyName)) {
                                charList.push(keyName);
                                charBios.push(data.bio);
                            } else {
                                charBios[charList.indexOf(keyName)] = data.bio;
                            }
                        }
                    } catch(e:Dynamic) {
                        trace("Error loading single json file (" + file + "): " + e);
                    }
                }
            }
        } else {
            // หากไม่มีม็อดใดๆ สร้างโฟลเดอร์นี้ไว้เลย จะรันข้อมูล Fallback ในตัวเกมแทน
            activeModPath = "mods/";
            trace("No CharacterProfiles folder found in any mods. Using defaults.");
        }
    }

    // === ฟังก์ชันโหลดรูปภาพภายนอกตามโฟลเดอร์ม็อดที่ตรวจเจอโดยอัตโนมัติ ===
    function tryLoadImage(sprite:FlxSprite, imageName:String, internalPath:String):Bool {
        var externalPath:String = activeModPath + imageName + ".png";
        
        if (FileSystem.exists(externalPath)) {
            try {
                var bitmap:BitmapData = BitmapData.fromFile(externalPath);
                var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap);
                graphic.persist = false; 
                sprite.loadGraphic(graphic);
                return true;
            } catch(e:Dynamic) {
                trace("Error loading external image: " + e);
            }
        }
        
        if (Paths.fileExists('images/' + internalPath + '.png', IMAGE)) {
            sprite.loadGraphic(Paths.image(internalPath));
            return true;
        }
        
        return false;
    }

    function changeSelection(change:Int = 0)
    {
        if (change != 0 && !canChange) return;
        if (change != 0) {
            FlxG.sound.play(Paths.sound('scrollMenu'));
            canChange = false;
            new FlxTimer().start(0.5, function(tmr:FlxTimer) {
                canChange = true;
            });
        }

        if (cycleTimer != null) {
            cycleTimer.cancel();
            cycleTimer = null;
        }
        currentCycleIdx = 0;

        FlxTween.cancelTweensOf(mainChar);
        if (isSecret) {
            curSelectedSecret = FlxMath.wrap(curSelectedSecret + change, 0, secretList.length - 1);
        } else {
            curSelectedNormal = FlxMath.wrap(curSelectedNormal + change, 0, charList.length - 1);
        }

        var list = isSecret ? secretList : charList;
        var bios = isSecret ? secretBios : charBios;
        var curIdx = isSecret ? curSelectedSecret : curSelectedNormal;

        var defaultName:String = list[curIdx];
        var extJson:SingleCharJson = loadedJsonProfiles.get(defaultName);

        var finalName:String = (extJson != null) ? extJson.name : defaultName;
        var finalBio:String = (extJson != null) ? extJson.bio : bios[curIdx];
        var hasCycleSetting:Bool = false;
        var loopImages:Array<String> = null;

        if (extJson != null) {
            hasCycleSetting = extJson.hasCycle;
            loopImages = extJson.cycleImages;
        } else {
            if (defaultName == 'Yasa') { hasCycleSetting = true; loopImages = ['Yasa', 'Yasa2']; }
            else if (defaultName == 'Hank') { hasCycleSetting = true; loopImages = ['Hank', 'Hank2']; }
        }

        nameText.text = finalName.toUpperCase();

        var redFormat = new FlxTextFormat(0xFFFF0000, true, false, FlxColor.BLACK);
        var blueHighlightFormat = new FlxTextFormat(0xFF00FFFF, true, false, 0xFFFFFFFF); 

        bioText.applyMarkup(finalBio, [
            new FlxTextFormatMarkerPair(redFormat, "$"),
            new FlxTextFormatMarkerPair(blueHighlightFormat, "^")
        ]);
        bioText.start(0.01, true);
        
        bioText.y = ldiAnim.y + bioOffsetY; 
        updateBioClip();

        var charImagePath:String = 'Menu/CharacterProfiles/' + defaultName;

        FlxTween.tween(mainChar, {x: FlxG.width + 100, alpha: 0}, 0.2, {
            ease: FlxEase.cubeIn,
            onComplete: function(twn:FlxTween) {
                var hasImage:Bool = tryLoadImage(mainChar, defaultName, charImagePath);
                
                if (hasImage) {
                    mainChar.visible = true;
                    mainChar.setGraphicSize(0, 520);
                    mainChar.updateHitbox();
                    mainChar.x = FlxG.width + 100;
               
                    FlxTween.tween(mainChar, {x: 980 - (mainChar.width / 2), alpha: 1}, 0.3, {
                        ease: FlxEase.cubeOut,
                        onComplete: function(twn:FlxTween) {
                            if (hasCycleSetting && loopImages != null && loopImages.length > 1) {
                                startCharacterCycle(loopImages);
                            }
                        }
                    });
                } else {
                    mainChar.visible = false;
                }
            }
        });

        var targetArrow = (change > 0) ? rightArrow : leftArrow;
        if (change != 0) {
            targetArrow.scale.set(1.4, 1.4);
            FlxTween.tween(targetArrow.scale, {x: 1, y: 1}, 0.2);
        }
    }

    function startCharacterCycle(images:Array<String>) {
        cycleTimer = new FlxTimer().start(3.0, function(tmr:FlxTimer) {
            FlxTween.tween(mainChar, {alpha: 0}, 0.8, {
                ease: FlxEase.quadInOut,
                onComplete: function(twn:FlxTween) {
                    currentCycleIdx = (currentCycleIdx + 1) % images.length;
                    var nextImgName:String = images[currentCycleIdx];
                    var fallbackPath:String = 'Menu/CharacterProfiles/' + nextImgName;
                    
                    tryLoadImage(mainChar, nextImgName, fallbackPath);
                    
                    FlxTween.tween(mainChar, {alpha: 1}, 0.8, {ease: FlxEase.quadInOut});
                }
            });
        }, 0);
    }

    function toggleSecret()
    {
        isTransitioning = true;
        isSecret = !isSecret; 
        FlxG.sound.play(Paths.sound('confirmMenu'));

        FlxTween.tween(blackScreen, {alpha: 1}, 0.4, {
            ease: FlxEase.quadIn,
            onComplete: function(twn:FlxTween) {
                bg.color = 0xFFFFFFFF;
                bioText.color = FlxColor.WHITE;
                
                ldiAnim.x = -1200;
                bioText.alpha = 0;
                mainChar.x = FlxG.width + 1200;
                nameGroup.alpha = 0;

                changeSelection();

                FlxTween.tween(blackScreen, {alpha: 0}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.1});
                
                FlxTween.tween(ldiAnim, {x: 0}, 0.6, {ease: FlxEase.backOut});
                FlxTween.tween(bioText, {alpha: 1}, 0.4);
                FlxTween.tween(nameGroup, {alpha: 1, y: 580}, 0.5, {ease: FlxEase.backOut});
           
                new FlxTimer().start(0.6, function(tmr:FlxTimer) {
                    isTransitioning = false;
                });
            }
        });
    }
}
