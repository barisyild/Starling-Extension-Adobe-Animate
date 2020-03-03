Starling Extension: Animate CC "Texture Atlas" Lazy Port
=========================================================
This is an experimental port and is not optimized.

Please open a issue regarding your problems.

> Example Code

	package;
	import starling.extensions.bunnyate.bunnyation;
	import openfl.display.FPS;
	import starling.extensions.bunnyate.AssetManagerEx;
	import openfl.events.Event;
	import openfl.display.Sprite;
	import openfl.geom.Rectangle;
	import starling.core.Starling;
	import starling.events.Event;

	class StarlingApp extends Sprite {
	    private var _starling:Starling;

	    public function new()
	    {
	        super();

	        var fps:FPS = new FPS();
	        stage.addChild(fps);

	        var viewPort : Rectangle = new Rectangle(0, 0,
	        stage.fullScreenWidth, stage.fullScreenHeight);

	        _starling = new Starling(StarlingClassHere, stage, viewPort);
	        _starling.skipUnchangedFrames = true;
	        _starling.addEventListener(Event.ROOT_CREATED, loadAssets);
	        _starling.start();
	    }

	    private function loadAssets() : Void
	    {
	        var assets : AssetManagerEx = new AssetManagerEx();
	        assets.enqueue(["Assets/bunny/spritemap.png", "Assets/bunny/spritemap.json", "Assets/bunny/Animation.json"]);
	        assets.loadQueue(start.bind(assets));
	    }

	    public function start(assets:AssetManagerEx):Void
	    {
	        var anim:Animation = assets.createbunnyation("bunny");
	        anim.x = Math.random() * stage.stageWidth;
	        anim.y = Math.random() * stage.stageHeight;
	        _starling.stage.addChild(anim);
	        _starling.juggler.add(anim);
	    }
	}
