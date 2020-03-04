package starling.extensions.animate;

import starling.extensions.animate.AnimationAtlasData.ElementData;
import starling.extensions.animate.AnimationAtlasData.LayerFrameData;
import starling.extensions.animate.AnimationAtlasData.LayerData;
import starling.extensions.animate.AnimationAtlasData.SymbolTimelineData;
import starling.extensions.animate.AnimationAtlasData.SymbolData;
import openfl.utils.Object;
import openfl.Vector;
import openfl.errors.ArgumentError;
import starling.display.Image;
import starling.textures.Texture;
import starling.textures.TextureAtlas;

class AnimationAtlas
{
    public var frameRate(get, set) : Float;

    public static inline var ASSET_TYPE : String = "animationAtlas";
    
    private var _atlas : TextureAtlas;
    private var _symbolData : Map<String, SymbolData>;
    private var _symbolPool : Map<String, Array<Symbol>>;
    private var _imagePool : Array<Image>;
    private var _frameRate : Float;
    private var _defaultSymbolName : String;
    
    private static var STD_MATRIX3D_DATA : Dynamic =
    {
        m00: 1, m01: 0, m02: 0, m03: 0,
        m10: 0, m11: 1, m12: 0, m13: 0,
        m20: 0, m21: 0, m22: 1, m23: 0,
        m30: 0, m31: 0, m32: 0, m33: 1
    };
    
    public function new(dynamicData : Dynamic, atlas : TextureAtlas)
    {
        if (dynamicData  == null) throw new ArgumentError("data must not be null");
        if (atlas == null) throw new ArgumentError("atlas must not be null");

        var data:AnimationAtlasData = cast normalizeJsonKeys(dynamicData);
        parseData(data);

        _atlas = atlas;
        _symbolPool = new Map<String, Array<Symbol>>();
        _imagePool = [];
    }
    
    public function hasAnimation(name : String) : Bool
    {
        return hasSymbol(name);
    }
    
    public function createAnimation(name : String = null) : Animation
    {
        name = (name != null) ? name : _defaultSymbolName;
        if (!hasSymbol(name))
        {
            throw new ArgumentError("Animation not found: " + name);
        }
        return new Animation(name, this);
    }
    
    public function getAnimationNames(prefix : String = "", out : Vector<String> = null) : Vector<String>
    {
        out = (out != null) ? out : new Vector<String>();
        
        for (name in _symbolData.keys())
        {
            if (name != Symbol.BITMAP_SYMBOL_NAME && name.indexOf(prefix) == 0)
            {
                out[out.length] = name;
            }
        }
        
        //out.sort(Array.CASEINSENSITIVE);
		out.sort(function(a1, a2) : Int {
			a1 = a1.toLowerCase();
			a2 = a2.toLowerCase();
			if (a1 < a2){
				return -1;
			}else if (a1 > a2){
				return 1;
			}else{
				return 0;
			}
		});
        return out;
    }
    
    // pooling
    
    @:allow(starling.extensions.animate)
    private function getTexture(name : String) : Texture
    {
        return _atlas.getTexture(name);
    }
    
    @:allow(starling.extensions.animate)
    private function getImage(texture : Texture) : Image
    {
        if (_imagePool.length == 0)
            return new Image(texture);
        else
        {
            var image:Image = cast(_imagePool.pop(), Image);
            image.texture = texture;
            image.readjustSize();
            return image;
        }
    }
    
    @:allow(starling.extensions.animate)
    private function putImage(image : Image) : Void
    {
        _imagePool[_imagePool.length] = image;
    }
    
    @:allow(starling.extensions.animate)
    private function hasSymbol(name : String) : Bool
    {
        return _symbolData.exists(name);
    }
    
    @:allow(starling.extensions.animate)
    private function getSymbol(name : String) : Symbol
    {
        var pool:Array<Symbol> = getSymbolPool(name);
        if (pool.length == 0)
            return new Symbol(getSymbolData(name), this);
        else return pool.pop();
    }
    
    @:allow(starling.extensions.animate)
    private function putSymbol(symbol : Symbol) : Void
    {
        symbol.reset();
        var pool:Array<Symbol> = getSymbolPool(symbol.symbolName);
        pool[pool.length] = symbol;
        symbol.currentFrame = 0;
    }
    
    // helpers
    
    private function parseData(data : AnimationAtlasData) : Void
    {
        var metaData = data.metadata;

        if (metaData != null && metaData.frameRate > 0)
            _frameRate = Std.int(metaData.frameRate);
        else
            _frameRate = 24;

        _symbolData = new Map<String, SymbolData>();

        // the actual symbol dictionary
        for (symbolData in data.symbolDictionary.symbols)
            _symbolData[symbolData.symbolName] = preprocessSymbolData(symbolData);

            // the main animation
        var defaultSymbolData:SymbolData = preprocessSymbolData(data.animation);
        _defaultSymbolName = defaultSymbolData.symbolName;
        _symbolData[_defaultSymbolName] = defaultSymbolData;

        // a purely internal symbol for bitmaps - simplifies their handling
        var symbolData:SymbolData = {symbolName: Symbol.BITMAP_SYMBOL_NAME};
        symbolData.timeline = {layers: []};
         _symbolData[Symbol.BITMAP_SYMBOL_NAME] = symbolData;
    }
    
    private static function preprocessSymbolData(symbolData : SymbolData) : SymbolData
    {
        var timeLineData:SymbolTimelineData  = symbolData.timeline;
        var layerDates:Array<LayerData> = timeLineData.layers;

        // In Animate CC, layers are sorted front to back.
        // In Starling, it's the other way round - so we simply reverse the layer data.

        if (!timeLineData.sortedForRender)
        {
            timeLineData.sortedForRender = true;
            layerDates.reverse();
        }

        // We replace all "ATLAS_SPRITE_instance" elements with symbols of the same contents.
        // That way, we are always only dealing with symbols.

        var numLayers:Int = layerDates.length;

        for (l in 0...numLayers)
        {
            var layerData:LayerData = layerDates[l];
            var frames:Array<LayerFrameData> = layerData.frames;
            var numFrames:Int = frames.length;

            for (f in 0...numFrames)
            {
                var elements:Array<ElementData> = frames[f].elements;
                var numElements:Int = elements.length;

                for (e in 0...numElements)
                {
                    var element:ElementData = elements[e];

                    if (element.atlasSpriteInstance != null)
                    {
                        element = elements[e] = {
                                symbolInstance: {
                                symbolName: Symbol.BITMAP_SYMBOL_NAME,
                                instanceName: "InstName",
                                bitmap: element.atlasSpriteInstance,
                                symbolType: SymbolType.GRAPHIC,
                                firstFrame: 0,
                                loop: LoopMode.LOOP,
                                transformationPoint: { x: 0, y: 0 },
                                matrix3D: STD_MATRIX3D_DATA
                            }
                        }
                    }

                    // not needed - remove decomposed matrix to save some memory
                    if (element.symbolInstance.decomposedMatrix != null)
                    {
                        element.symbolInstance.decomposedMatrix = null;
                    }
                }
            }
        }

        return symbolData;
    }
    
    public function getSymbolData(name : String):SymbolData
    {
        return _symbolData.get(name);
    }
    
    private function getSymbolPool(name : String) : Array<Symbol>
    {
        var pool : Array<Symbol> = cast _symbolPool.get(name);
        if (pool == null)
        {
            pool = new Array<Symbol>();
			_symbolPool.set(name, cast pool);
        }
        return pool;
    }
    
    // properties
    
    private function get_frameRate() : Float
    {
        return _frameRate;
    }

    private function set_frameRate(value : Float) : Float
    {
        _frameRate = value;
        return value;
    }

    private static function normalizeJsonKeys(data:Dynamic):Dynamic
    {
        if (Std.is(data, String) || Std.is(data, Float) || Std.is(data, Int))
            return data;
        else if (Std.is(data, Array))
        {
            var array:Array<Dynamic> = [];
            var arrayLength:Int = data.length;
            for (i in 0...arrayLength)
                array[i] = normalizeJsonKeys(data[i]);
            return array;
        }
        else
        {
            var out:Dynamic = {};

            for (key in Reflect.fields(data))
            {
                var newData:Dynamic = Reflect.field(data, key);
                var value:Dynamic = normalizeJsonKeys(newData);
                if (Reflect.field(JsonKeys, key) != null)
                    key = Reflect.field(JsonKeys, key);
                Reflect.setField(out, key, value);
            }
            return out;
        }
    }


    private static var JsonKeys : Dynamic =
    {
        ANIMATION : "animation",
        ATLAS_SPRITE_instance : "atlasSpriteInstance",
        DecomposedMatrix : "decomposedMatrix",
        Frames : "frames",
        framerate : "frameRate",
        Instance_Name : "instanceName",
        Layer_name : "layerName",
        LAYERS : "layers",
        Matrix3D : "matrix3D",
        Position : "position",
        Rotation : "rotation",
        Scaling : "scaling",
        SYMBOL_DICTIONARY : "symbolDictionary",
        SYMBOL_Instance : "symbolInstance",
        SYMBOL_name : "symbolName",
        Symbols : "symbols",
        TIMELINE : "timeline",
        AN : "animation",
        AM : "alphaMultiplier",
        ASI : "atlasSpriteInstance",
        BM : "bitmap",
        C : "color",
        DU : "duration",
        E : "elements",
        FF : "firstFrame",
        FR : "frames",
        FRT : "frameRate",
        I : "index",
        IN : "instanceName",
        L : "layers",
        LN : "layerName",
        LP : "loop",
        M3D : "matrix3D",
        MD : "metadata",
        M : "mode",
        N : "name",
        POS : "position",
        S : "symbols",
        SD : "symbolDictionary",
        SI : "symbolInstance",
        SN : "symbolName",
        ST : "symbolType",
        TL : "timeline",
        TRP : "transformationPoint"
    };
}

