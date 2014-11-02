package tk.arukoh.utils
{
	
	public class HumanReadablizer
	{
		public static function time(sec:Number):String
		{
			var h:Number = Math.floor(sec / 3600);
			var m:Number = Math.floor((sec % 3600) / 60);
			var s:Number = Math.floor((sec % 3600) % 60);
			var time:Array = [];
			time.push(h < 10 ? "0" + h.toString() : h.toString());
			time.push(m < 10 ? "0" + m.toString() : m.toString());
			time.push(s < 10 ? "0" + s.toString() : s.toString());
			return time.join(":");
		}
		
		public static function bytes(bytes:uint):Array
		{
			if (isNaN(bytes) || bytes == 0) return ["0", "bytes"];
			var s:Array = ['bytes', 'kb', 'MB', 'GB', 'TB', 'PB'];
			var e:Number = Math.floor(Math.log(bytes) / Math.log(1024));
			return [(bytes / Math.pow(1024, Math.floor(e))).toFixed(2), + s[e]];
		}
	}
}