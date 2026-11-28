package animate;

import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * 临时调试用：把关键数字直接画在屏幕左上角（黄字），
 * 手机端不需要控制台 / adb。测完删掉调用处两行即可。
 */
class OotLog
{
	static var _lines:Array<String> = [];
	static var _field:TextField = null;
	static var _last:String = "";

	public static function log(s:String):Void
	{
		if (s == _last)
			return; // 同样的内容不重复刷
		_last = s;

		#if (cpp || hl || android || neko)
		if (_field == null)
		{
			var stage = Lib.current.stage;
			if (stage != null)
			{
				_field = new TextField();
				_field.width = 1000;
				_field.height = 240;
				_field.x = 16;
				_field.y = 16;
				_field.multiline = true;
				_field.wordWrap = false;
				_field.mouseEnabled = false;
				_field.selectable = false;
				_field.defaultTextFormat = new TextFormat("_sans", 20, 0xFFFF00, true);
				_field.text = "";
				stage.addChild(_field);
			}
		}

		if (_field != null)
		{
			_lines.push(s);
			while (_lines.length > 6)
				_lines.shift();
			_field.text = _lines.join("\n");
		}
		#end

		trace(s);
	}
}
