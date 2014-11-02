package tk.arukoh.media 
{
	import flash.events.Event;
	
	public class SimpleVideoPlayerEvent extends Event
	{
		public static const LOAD_START:String    = "tk.arukoh.media.SimpleVideoPlayerEvent.LOAD_START";
		public static const LOAD_COMPLETE:String = "tk.arukoh.media.SimpleVideoPlayerEvent.LOAD_COMPLETE";
		public static const ERROR:String         = "tk.arukoh.media.SimpleVideoPlayerEvent.ERROR";
		
		private var _errorEvent:Event;
		
		public function SimpleVideoPlayerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			_errorEvent = null;
		}
		
		public function get errorEvent():Event 
		{
			return _errorEvent;
		}
		
		public static function createLoadStartEvent():SimpleVideoPlayerEvent
		{
			return new SimpleVideoPlayerEvent(LOAD_START);
		}
		
		public static function createLoadCompleteEvent():SimpleVideoPlayerEvent
		{
			return new SimpleVideoPlayerEvent(LOAD_COMPLETE);
		}
		
		public static function createErrorEvent(event:Event):SimpleVideoPlayerEvent
		{
			var e:SimpleVideoPlayerEvent = new SimpleVideoPlayerEvent(ERROR);
			e._errorEvent = event;
			return e;
		}
		
	}

}