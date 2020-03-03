package starling.extensions.animate;

import Type.ValueType;
import starling.textures.Texture;
import flash.geom.Rectangle;
import starling.textures.SubTexture;
import starling.textures.Texture;
import starling.textures.TextureAtlas;
import starling.utils.Pool;

class JsonTextureAtlas extends TextureAtlas {
    public function new(texture:Texture, data:Dynamic=null)
    {
        super(texture, data);
    }

    override public function parseAtlasData(data:Dynamic):Void
    {
        if (Type.typeof(data) == ValueType.TObject)
        {
            parseAtlasJson(data);
        }
        else
        {
            super.parseAtlasData(data);
        }
    }

    private function parseAtlasJson(data:Dynamic):Void
    {
        var region:Rectangle = Pool.getRectangle();

        for (element in cast(data.ATLAS.SPRITES, Array<Dynamic>))
        {
            var node:Dynamic = element.SPRITE;
            region.setTo(node.x, node.y, node.w, node.h);
            var subTexture:SubTexture = new SubTexture(texture, region, false, null, node.rotated);
            addSubTexture(node.name, subTexture);
        }

        Pool.putRectangle(region);
    }
}
