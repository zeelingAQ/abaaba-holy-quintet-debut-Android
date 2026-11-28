package animate;

import animate.FlxAnimateFrames.FlxAnimateSettings;
import flixel.FlxG;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.io.Path;

/**
 * 按 PE（Psych Engine 的 PsychFlxAnimate）的用法，给 CNE 的 animate 包补一个入口：
 * 图片 + spritemap 的 .json + Animation.json 三份文件分开传。
 *
 * 这个文件是新增的，不改动任何现有类，冲突面最小。
 */
class PsychFlxAnimate extends FlxAnimate
{
	/** 加载完成后是否自动把主时间轴播起来（PE 里 FlxAnim 就是这种"直接就动"的行为） */
	public var autoPlay:Bool = true;

	/** 是否把 SD 里的符号一次性建出来（这样 addBySymbol 能取到所有符号，但大图集会多占一点内存） */
	public var preloadSymbols:Bool = true;

	public function new(?x:Float = 0, ?y:Float = 0, ?simpleGraphic:FlxGraphicAsset, ?settings:FlxAnimateSettings)
	{
		super(x, y, simpleGraphic, settings);
	}

	/**
	 * @param img            spritemap 对应的图片（路径 / BitmapData / FlxGraphic）
	 * @param spritemapPath  spritemap1.json 的路径
	 * @param animationPath  Animation.json 的路径；不传就自动找 spritemap 同目录下的 Animation.json
	 * @return               是否加载成功
	 */
	public function loadAtlasEx(img:FlxGraphicAsset, spritemapPath:String, ?animationPath:String, ?settings:FlxAnimateSettings, ?key:String):Bool
	{
		if (spritemapPath == null)
		{
			FlxG.log.error("[PsychFlxAnimate] spritemap 路径不能为空");
			return false;
		}

		if (Path.extension(spritemapPath) != "json")
		{
			FlxG.log.error('[PsychFlxAnimate] spritemap 要传 spritemap1.json 这种文件路径，不是文件夹：$spritemapPath');
			return false;
		}

		var spritemapText:String = FlxAnimateAssets.getText(spritemapPath);
		if (spritemapText == null)
		{
			FlxG.log.error('[PsychFlxAnimate] 读不到 spritemap：$spritemapPath');
			return false;
		}

		// 定位 Animation.json（按扩展名判断传的是文件还是图集文件夹，避免对目录调用 getText）
		var animFile:String = null;
		if (animationPath != null)
			animFile = (Path.extension(animationPath) == "json") ? animationPath : animationPath + "/Animation.json";
		else
		{
			var dir:String = Path.directory(spritemapPath);
			var guess:String = (dir.length == 0) ? "Animation.json" : dir + "/Animation.json";
			if (FlxAnimateAssets.getText(guess) != null)
				animFile = guess;
		}

		if (animFile == null)
		{
			FlxG.log.error('[PsychFlxAnimate] 读不到 Animation.json，请用 animationPath 传进来');
			return false;
		}

		var animationText:String = FlxAnimateAssets.getText(animFile);
		if (animationText == null)
		{
			FlxG.log.error('[PsychFlxAnimate] 读不到 Animation.json：$animFile');
			return false;
		}

		// 图集文件夹：用于缓存 key，也用于引擎内部的 LIBRARY/*.json 与音效路径
		var atlasPath:String = Path.directory(animFile);
		if (atlasPath.length == 0) atlasPath = Path.directory(spritemapPath);

		var atlas:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(animationText, [{source: img, json: spritemapText}], null,
			key ?? atlasPath, true, settings);

		if (atlas == null)
		{
			FlxG.log.error("[PsychFlxAnimate] 纹理图集解析失败，检查 Animation.json / spritemap / 图片是否配套");
			return false;
		}

		frames = atlas;

		// 像 PE 的 symbolDictionary 一样，把 SD 里所有符号都建出来，addBySymbol 才能按名字取到
		if (preloadSymbols)
		{
			@:privateAccess
			{
				var sd = library._symbolDictionary;
				if (sd != null)
				{
					for (i in 0...sd.length)
						library.getSymbol(sd[i].SN);
				}
			}
		}

		if (autoPlay)
		{
			var rate:Float = (library.frameRate > 0) ? library.frameRate : 24.0;
			anim.addByTimeline("__atlas", library.timeline, rate);
			anim.play("__atlas", true);
		}

		return true;
	}
}
