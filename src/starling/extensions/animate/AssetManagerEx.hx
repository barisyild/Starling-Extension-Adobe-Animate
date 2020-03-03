package starling.extensions.animate;

import StringTools;
import flash.geom.Rectangle;
import openfl.Vector;
import starling.assets.AssetFactoryHelper;
import starling.assets.AssetManager;
import starling.assets.AssetReference;
import starling.assets.JsonFactory;
import starling.extensions.animate.AnimationAtlas;
import starling.textures.Texture;
import starling.textures.TextureAtlas;
import starling.utils.Pool;

import Type;


class AssetManagerEx extends AssetManager
{
    private static var sNames:Vector<String> = new Vector<String>();

    public function new()
    {
        super();
        registerFactory(new AnimationAtlasFactory(), 10);
    }

    override public function addAsset(name:String, asset:Dynamic, type:String = null):Void
    {
        if (type == null && Std.is(asset, AnimationAtlas))
        type = AnimationAtlas.ASSET_TYPE;

        super.addAsset(name, asset, type);
    }

    /** Returns an animation atlas with a certain name, or null if it's not found. */
    public function getAnimationAtlas(name:String):AnimationAtlas
    {
        return cast(getAsset(AnimationAtlas.ASSET_TYPE, name),AnimationAtlas);
    }

    /** Returns all animation atlas names that start with a certain string, sorted alphabetically.
         *  If you pass an <code>out</code>-vector, the names will be added to that vector. */
    public function getAnimationAtlasNames(prefix:String="", out:Vector<String>=null):Vector<String>
    {
     return getAssetNames(AnimationAtlas.ASSET_TYPE, prefix, true, out);
    }

    public function createAnimation(name:String):Animation
    {
        var atlasNames:Vector<String> = getAnimationAtlasNames("", sNames);
        var animation:Animation = null;

        for(atlasName in atlasNames)
        {
            var atlas:AnimationAtlas = getAnimationAtlas(atlasName);
            if (atlas.hasAnimation(name))
            {
                animation = atlas.createAnimation(name);
            break;
            }
        }

        if (animation == null && atlasNames.indexOf(name) != -1)
            animation = getAnimationAtlas(name).createAnimation();

        sNames = new Vector<String>();
        return animation;
    }

    override public function getNameFromUrl(url:String):String
    {
        var defaultName:String = super.getNameFromUrl(url);
        var defaultExt:String = super.getExtensionFromUrl(url);

        if (defaultName.indexOf("spritemap") != -1 && (defaultExt == "png" || defaultExt == "atf"))
            return AnimationAtlasFactory.getName(url, defaultName, false);
        else
            return defaultName;
    }
}




class AnimationAtlasFactory extends JsonFactory
{
    public static inline var ANIMATION_SUFFIX:String = "_animation";
    public static inline var SPRITEMAP_SUFFIX:String = "_spritemap";

    override public function create(asset:AssetReference, helper:AssetFactoryHelper, onComplete:String->Dynamic->Void, onError:String->Void):Void
    {
        function onObjectComplete(name:String, json:Dynamic):Void
        {
            var baseName:String = getName(asset.url, name, false);
            var fullName:String = getName(asset.url, name, true);

            if (json.ATLAS != null && json.meta != null)
            {
                helper.addPostProcessor(function(assets:AssetManager):Void
                {
                    var texture:Texture = assets.getTexture(baseName);
                    if (texture == null)
                        onError("Missing texture " + baseName);
                    else
                        assets.addAsset(baseName, new JsonTextureAtlas(texture, json));
                }, 100);
            }
            else if ((json.ANIMATION != null && json.SYMBOL_DICTIONARY != null) || (json.AN != null && json.SD != null))
            {
                helper.addPostProcessor(function(assets:AssetManager):Void
                {
                    var atlas:TextureAtlas = assets.getTextureAtlas(baseName);
                    if (atlas == null)
                        onError("Missing texture atlas " + baseName);
                    else
                        assets.addAsset(baseName, new AnimationAtlas(json, atlas), AnimationAtlas.ASSET_TYPE);
                });
            }
            onComplete(fullName, json);
        }

        super.create(asset, helper, onObjectComplete, onError);
    }

    public static function getName(url:String, stdName:String, addSuffix:Bool):String
    {
        var separator:String = "/";

        // embedded classes are stripped of the suffix here
        if (url == null)
        {
            if (addSuffix)
            {
                return stdName; // should already include suffix
            } else {
                stdName = StringTools.replace(stdName, AnimationAtlasFactory.ANIMATION_SUFFIX, "");
                stdName = StringTools.replace(stdName, AnimationAtlasFactory.SPRITEMAP_SUFFIX, "");
            }
        }

        //if ((stdName == "Animation" || stdName.match(/spritemap\d*/)) && url.indexOf(separator) != -1)
        //todo fix this

        if (stdName == "Animation" || stdName.indexOf("spritemap") != -1 && url.indexOf(separator) != -1)
        {
            var elements:Array<String> = url.split(separator);
            var folderName:String = elements[Std.int(elements.length - 2)];
            var suffix:String = stdName == "Animation" ? AnimationAtlasFactory.ANIMATION_SUFFIX : AnimationAtlasFactory.SPRITEMAP_SUFFIX;

            if (addSuffix)
                return folderName + suffix;
            else return folderName;
        }

        return stdName;
    }
}

