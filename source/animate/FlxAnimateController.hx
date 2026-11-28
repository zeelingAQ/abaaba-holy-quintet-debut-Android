package animate;

import animate.internal.Timeline;
import animate.internal.Frame;
import flixel.FlxG;
import flixel.animation.FlxAnimation;
import flixel.animation.FlxAnimationController;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;

using StringTools;

@:access(animate.FlxAnimate)
class FlxAnimateController extends FlxAnimationController
{
	public final onFrameLabel = new FlxTypedSignal<(frameLabel:String) -> Void>();

	public function new(sprite:FlxAnimate)
	{
		super(sprite);
	}

	public function addByFrameLabel(name:String, label:String, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool, ?timeline:Timeline):Void
	{
		if (!hasAnimateAtlas) return;
		var usedTimeline = timeline ?? getDefaultTimeline();
		var foundFrames = findFrameLabelIndices(label, usedTimeline);
		if (foundFrames.length <= 0) {
			var collectionTimelines = getCollectionTimelines();
			if (collectionTimelines.length > 0) {
				for (timeline in collectionTimelines) {
					var newFrames = findFrameLabelIndices(label, timeline);
					if (newFrames.length > 0) { foundFrames = newFrames; usedTimeline = timeline; break; }
				}
			} else return;
		}
		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, foundFrames, frameRate, looped, flipX, flipY);
		anim.timeline = usedTimeline;
		_animations.set(name, anim);
	}

	public function addByFrameLabelIndices(name:String, label:String, indices:Array<Int>, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool, ?timeline:Timeline)
	{
		if (!hasAnimateAtlas) return;
		var usedTimeline = timeline ?? getDefaultTimeline();
		var foundFrames:Array<Int> = findFrameLabelIndices(label, usedTimeline);
		var useableFrames:Array<Int> = [];
		if (foundFrames.length <= 0) {
			var collectionTimelines = getCollectionTimelines();
			if (collectionTimelines.length > 0) {
				for (timeline in collectionTimelines) {
					var newFrames = findFrameLabelIndices(label, timeline);
					if (newFrames.length > 0) { foundFrames = newFrames; usedTimeline = timeline; break; }
				}
			}
		}
		for (index in indices) {
			var frameIndex:Null<Int> = foundFrames[index];
			if (frameIndex != null) useableFrames.push(frameIndex);
		}
		if (useableFrames.length <= 0) return;
		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, useableFrames, frameRate, looped, flipX, flipY);
		anim.timeline = usedTimeline;
		_animations.set(name, anim);
	}

	public function addByTimeline(name:String, timeline:Timeline, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool):Void
	{
		if (!hasAnimateAtlas) return;
		addByTimelineIndices(name, timeline, [for (i in 0...timeline.frameCount) i], frameRate, looped, flipX, flipY);
	}

	public function addByTimelineIndices(name:String, timeline:Timeline, indices:Array<Int>, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool):Void
	{
		if (!hasAnimateAtlas) return;
		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped, flipX, flipY);
		anim.timeline = timeline;
		_animations.set(name, anim);
	}

	public function addBySymbol(name:String, symbolName:String, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool):Void
	{
		if (!hasAnimateAtlas) return;
		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null) return;
		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, [for (i in 0...symbol.timeline.frameCount) i], frameRate, looped, flipX, flipY);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	public function addBySymbolIndices(name:String, symbolName:String, indices:Array<Int>, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool):Void
	{
		if (!hasAnimateAtlas) return;
		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null)
		{
			// [oot fix] 找不到同名符号时不再静默 return，退回主时间轴，至少让 indices 能对上帧号
			animate.OotLog.log('[AC] ' + name + ' 缺符号 "' + symbolName + '" → 退回主时间轴');
			addByTimelineIndices(name, _animate.library.timeline, indices, frameRate, looped, flipX, flipY);
			return;
		}
		frameRate ??= getDefaultFramerate();
		if (indices.length > 0 && indices[indices.length - 1] >= symbol.timeline.frameCount)
			animate.OotLog.log('[AC] ' + name + ' idx最大=' + indices[indices.length - 1] + ' 但符号只有 ' + symbol.timeline.frameCount + ' 帧');
		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped, flipX, flipY);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	public function findFrameLabelIndices(label:String, ?timeline:Timeline):Array<Int>
	{
		var mainTimeline = timeline ?? getDefaultTimeline();
		return mainTimeline.findFrameLabelIndices(label);
	}

	override function set_frameIndex(frame:Int):Int
	{
		if (!isAnimate) return super.set_frameIndex(frame);

		var curAnim:Null<FlxAnimateAnimation> = cast _curAnim;
		if (curAnim != null)
		{
			final numFrames = #if (flixel >= "5.4.0") numFrames #else curAnim.timeline.frameCount #end;
			if (numFrames > 0)
			{
				if (frame > 250 && frame < 540)
					animate.OotLog.log('[AC2] ' + curAnim.name + ' f=' + frame + '/' + curAnim.timeline.frameCount + ' af=' + (_animate.frames == null ? -1 : _animate.frames.numFrames));
				// 【底层修复】绝对不取模！保留真实帧号（如 377）
				if (frame < 0) frame = 0;
				if (frame >= curAnim.timeline.frameCount) frame = curAnim.timeline.frameCount - 1;

				_animate.timeline = curAnim.timeline;
				_animate.timeline.currentFrame = frame; 
				_animate.timeline.signalFrameChange(frame, this);
				if (_animate.useRenderTexture) _animate._renderTextureDirty = true;
				frameIndex = frame;
				fireCallback();
				updateTimelineBounds();
			}
		}
		return frameIndex;
	}

	var animateFrame:FlxFrame;

	@:allow(animate.FlxAnimate)
	function updateTimelineBounds():Void
	{
		if (animateFrame == null) {
			@:privateAccess animateFrame = new FlxFrame(_animate.graphic);
			animateFrame.frame = FlxRect.get();
		}
		@:privateAccess var bounds = _animate.timeline._bounds;
		animateFrame.parent = _animate.graphic;
		animateFrame.sourceSize.set(bounds.width, bounds.height);
		if (_animate.applyStageMatrix) {
			animateFrame.sourceSize.x *= _animate.library.matrix.a;
			animateFrame.sourceSize.y *= _animate.library.matrix.d;
		}
		animateFrame.frame.copyFrom(bounds);
		animateFrame.uv.set(0, 0, bounds.width, bounds.height);
		_animate.frame = animateFrame;
	}

	override function play(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0)
	{
		var anim = _animations.get(animName);
		if (anim != null) {
			@:privateAccess _animate.isAnimate = anim is FlxAnimateAnimation;
		}
		super.play(animName, force, reversed, frame);
	}

	var isAnimate(get, never):Bool;
	var hasAnimateAtlas(get, never):Bool;
	public inline function getDefaultFramerate():Float return hasAnimateAtlas ? _animate.library.frameRate : 0.0;
	public inline function getDefaultTimeline():Timeline return hasAnimateAtlas ? _animate.library.timeline : null;
	public inline function getCollectionTimelines():Array<Timeline> return hasAnimateAtlas ? [for (collection in _animate.library.addedCollections) collection.timeline] : [];

	var _animate(get, never):FlxAnimate;
	inline function get__animate():FlxAnimate return cast _sprite;
	inline function get_isAnimate():Bool return _animate.isAnimate;
	inline function get_hasAnimateAtlas():Bool return _animate.library != null;

	override function destroy()
	{
		super.destroy();
		animateFrame = FlxDestroyUtil.destroy(animateFrame);
		FlxDestroyUtil.destroy(onFrameLabel);
	}
}

class FlxAnimateAnimation extends FlxAnimation
{
	public var timeline:Timeline;

	#if (flixel >= "5.3.0")
	override function getCurrentFrameDuration():Float return frameDuration;
	#end

	override function destroy()
	{
		super.destroy();
		timeline = null;
	}
}