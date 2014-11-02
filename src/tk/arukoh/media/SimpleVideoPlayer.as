package tk.arukoh.media
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.AsyncErrorEvent;
	import flash.events.DRMErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.VideoEvent;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import mx.events.FlexEvent;
	import mx.utils.ObjectUtil;
	import spark.components.Image;
	import spark.components.mediaClasses.ScrubBar;
	import spark.components.mediaClasses.VolumeBar;
	import spark.components.supportClasses.SkinnableComponent;
	import spark.components.ToggleButton;
	import spark.core.IDisplayText;
	import spark.events.TrackBaseEvent;
	
	public class SimpleVideoPlayer extends SkinnableComponent
	{
		[SkinPart(required="true")]
		public var display:Image;
		
		[SkinPart(required="true")]
		public var playPauseButton:ToggleButton;
		
		[SkinPart(required="true")]
		public var scrubBar:ScrubBar;
		
		[SkinPart(required="true")]
		public var currentTimeDisplay:IDisplayText;
		
		[SkinPart(required="true")]
		public var durationDisplay:IDisplayText;
		
		[SkinPart(required="true")]
		public var repeatButton:ToggleButton;
		
		[SkinPart(required="true")]
		public var volumeBar:VolumeBar;
		
		private var _autoPlay:Boolean;
		private var _loop:Boolean;
		private var _volume:Number;
		private var _source:String;
		private var _initialized:Boolean;
		private var _duration:Number;
		private var _video:Video;
		private var _netConnection:NetConnection;
		private var _netStream:NetStream;
		private var _wasPlayingBeforeSeeking:Boolean;
		
		public function SimpleVideoPlayer()
		{
			super();
			_autoPlay = false;
			_loop = false;
			_volume = 1;
		}
		
		override protected function partAdded(partName:String, instance:Object):void
		{
			super.partAdded(partName, instance);
			switch (instance)
			{
				case playPauseButton:
					playPauseButton.addEventListener(MouseEvent.CLICK, playPauseButtonClickHandler);
					break;
				case scrubBar:
					scrubBar.addEventListener(Event.CHANGE, scrubBarChangeHandler);
					scrubBar.addEventListener(FlexEvent.CHANGE_START, scrubBarChangeStartHandler);
					scrubBar.addEventListener(FlexEvent.CHANGE_END, scrubBarChangeEndHandler);
					break;
				case currentTimeDisplay:
					break;
				case durationDisplay:
					break;
				case repeatButton:
					repeatButton.addEventListener(MouseEvent.CLICK, repeatButtonClickHandler);
					break;
				case volumeBar:
					volumeBar.minimum = 0;
					volumeBar.maximum = 1;
					volumeBar.value = _volume;
					volumeBar.muted = false;
					volumeBar.addEventListener(Event.CHANGE, volumeBarChangeHandler);
					volumeBar.addEventListener(FlexEvent.MUTED_CHANGE, volumeBarMutedChangeHandler);
					break;
			}
		}
		
		override protected function partRemoved(partName:String, instance:Object):void
		{
			super.partRemoved(partName, instance);
			switch (instance)
			{
				case playPauseButton:
					playPauseButton.removeEventListener(MouseEvent.CLICK, playPauseButtonClickHandler);
					break;
				case scrubBar:
					scrubBar.removeEventListener(Event.CHANGE, scrubBarChangeHandler);
					scrubBar.removeEventListener(FlexEvent.CHANGE_END, scrubBarChangeEndHandler);
					scrubBar.removeEventListener(FlexEvent.CHANGE_START, scrubBarChangeStartHandler);
					break;
				case currentTimeDisplay:
					break;
				case durationDisplay:
					break;
				case repeatButton:
					repeatButton.removeEventListener(MouseEvent.CLICK, repeatButtonClickHandler);
					break;
				case volumeBar:
					volumeBar.removeEventListener(Event.CHANGE, volumeBarChangeHandler);
					volumeBar.removeEventListener(FlexEvent.MUTED_CHANGE, volumeBarMutedChangeHandler);
					break;
			}
		}
		
		public function get loop():Boolean 
		{
			return _loop;
		}
		
		public function set loop(value:Boolean):void 
		{
			_loop = value;
		}
		
		public function get autoPlay():Boolean 
		{
			return _autoPlay;
		}
		
		public function set autoPlay(value:Boolean):void 
		{
			_autoPlay = value;
		}
		
		public function load(url:String):void
		{
			dispose();
			init(url);
			dispatchEvent(SimpleVideoPlayerEvent.createLoadStartEvent());
			_netConnection = newNetConnection();
			_netConnection.connect(null);
		}
		
		public function dispose():void
		{
			disposeVideo(_video);
			_video = null;
			closeNetStream(_netStream);
			_netStream = null;
			closeNetConnection(_netConnection);
			_netConnection = null;
		}
		
		private function init(url:String):void
		{
			_source = url;
			_initialized = false;
			_duration = 0;
			_video = newVideo();
		}
		
		private function newVideo():Video
		{
			var video:Video = new Video();
			video.smoothing = true;
			video.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
			return video;
		}
		
		private function disposeVideo(video:Video):void
		{
			if (video != null)
			{
				video.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
				video.clear();
				video.attachNetStream(null);
			}
		}
		
		private function newNetConnection():NetConnection
		{
			var netConnection:NetConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			netConnection.addEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler);
			netConnection.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			netConnection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
			return netConnection;
		}
		
		private function closeNetConnection(netConnection:NetConnection):void
		{
			if (netConnection != null)
			{
				netConnection.removeEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
				netConnection.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler);
				netConnection.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
				netConnection.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
				netConnection.close();
			}
		}
		
		private function errorHandler(event:Event):void
		{
			dispose();
			trace(event.toString());
			dispatchEvent(SimpleVideoPlayerEvent.createErrorEvent(event));
		}
		
		private function netStatusHandler(event:NetStatusEvent):void
		{
			trace("netStatusHandler", event.info.code);
			switch (event.info.level)
			{
				case "status":
					switch (event.info.code)
					{
						case "NetConnection.Connect.Success": 
							_netStream = newNetStream(NetConnection(event.currentTarget));
							_video.attachNetStream(_netStream);
							_netStream.play(_source);
							playPauseButton.selected = true;
							if (!autoPlay)
							{
								playPauseButton.selected = false;
								_netStream.pause();
							}
							break;
						case "NetStream.Buffer.Empty":
							break;
						case "NetStream.Buffer.Flush":
							break;
						case "NetStream.Buffer.Full":
							break;
						case "NetStream.Play.Start":
							dispatchEvent(SimpleVideoPlayerEvent.createLoadCompleteEvent());
							break;
						case "NetStream.Play.Stop":
							updateTime(true);
							_netStream.play(_source);
							if (!loop)
							{
								_netStream.pause();
							}
							break;
						case "NetStream.Pause.Notify":
							playPauseButton.selected = false;
							break;
						case "NetStream.Unpause.Notify":
							playPauseButton.selected = true;
							break;
						case "NetStream.SeekStart.Notify":
							break;
						case "NetStream.Seek.Notify":
							break;
						case "NetStream.Seek.Complete":
							updateDisplay(_video);
							break;
						case "NetStream.DRM.UpdateNeeded":
						case "NetStream.Play.NoSupportedTrackFound":
							errorHandler(event);
						default:
							break;
					}
					break;
				default: //="error"
					switch (event.info.code)
					{
						case "NetStream.Seek.InvalidTime":
							_netStream.seek(event.info.details);
							break;
						default:
							errorHandler(event);
							break;
					}
					break;
			}
		}
		
		private function newNetStream(netConnection:NetConnection):NetStream
		{
			var netStream:NetStream = new NetStream(netConnection);
			netStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			netStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler);
			netStream.addEventListener(DRMErrorEvent.DRM_ERROR, errorHandler);
			netStream.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			netStream.checkPolicyFile = true;
			netStream.soundTransform = new SoundTransform(_volume);
			netStream.bufferTime = 10;
			netStream.client = this;
			return netStream;
		}
		
		private function closeNetStream(netStream:NetStream):void
		{
			if (netStream != null)
			{
				netStream.removeEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
				netStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler);
				netStream.removeEventListener(DRMErrorEvent.DRM_ERROR, errorHandler);
				netStream.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
				netStream.close();
			}
		}
		
		public function onMetaData(info:Object):void
		{
			trace("onMetaData", ObjectUtil.toString(info));
			if (!_initialized)
			{
				_initialized = true;
				_video.width = info.width;
				_video.height = info.height;
				_duration = info.duration;
				scrubBar.minimum = 0;
				scrubBar.maximum = _duration;
				durationDisplay.text = formatTimeValue(_duration);
				updateTime();
			}
		}
		
		public function onCuePoint(info:Object):void
		{
			trace("onCuePoint", ObjectUtil.toString(info));
		}
		
		public function onImageData(info:Object):void
		{
			trace("onImageData", info.data.length);
		}
		
		public function onTextData(info:Object):void
		{
			trace("onTextData", ObjectUtil.toString(info));
		}
		
		public function onSeekPoint(time:Number, position:uint):void
		{
			trace("onSeekPoint", time, position);
		}
		
		public function onPlayStatus(status:Object):void
		{
			trace("onPlayStatus", ObjectUtil.toString(status));
		}
		
		public function onXMPData(info:Object):void
		{
			trace("onXMPData", ObjectUtil.toString(info));
		}
		
		private function playPauseButtonClickHandler(event:MouseEvent):void
		{
			if (_netStream != null)
			{
				_netStream.togglePause();
			}
		}

		private function scrubBarChangeHandler(event:Event):void
		{
			if (_netStream != null)
			{
				_netStream.seek(scrubBar.value);
			}
		}

		private function scrubBarChangeStartHandler(event:Event):void
		{
			if (_netStream != null)
			{
				_wasPlayingBeforeSeeking = false;
				if (playPauseButton.selected)
				{
					_netStream.pause();
					_wasPlayingBeforeSeeking = true;
				}
				updateTime();
			}
		}

		private function scrubBarChangeEndHandler(event:Event):void
		{
			if (_netStream != null && _wasPlayingBeforeSeeking)
			{
				_netStream.resume();
				_wasPlayingBeforeSeeking = false;
			}
		}
		
		private function repeatButtonClickHandler(event:MouseEvent):void
		{
			loop = ToggleButton(event.currentTarget).selected;
		}

		private function volumeBarChangeHandler(event:Event):void
		{
			if (_netStream != null)
			{
				_volume = VolumeBar(event.currentTarget).value;
				_netStream.soundTransform.volume = _volume;
			}
		}

		private function volumeBarMutedChangeHandler(event:FlexEvent):void
		{
			if (_netStream != null)
			{
				_netStream.soundTransform.volume = VolumeBar(event.currentTarget).muted ? 0 : _volume;
			}
		}
		
		private function enterFrameHandler(event:Event):void
		{
			if (_duration > 0 && playPauseButton.selected)
			{
				var video:Video = event.currentTarget as Video;
				updateTime();
				updateDisplay(video);
			}
		}
		
		private function updateDisplay(video:Video):void
		{
			if (display.source == null)
			{
				display.source = new Bitmap(new BitmapData(width, height));
			}
			var wD : Number = video.width / video.scaleX;
			var hD : Number = video.height / video.scaleY;
			var s : Number = wD / hD >= width / height ? height / hD : width / wD;
			var matrix:Matrix = new Matrix();
			matrix.scale(s, s);
			matrix.translate( -0.5 * (wD * s - width),  -0.5 * (hD * s - height));
			Bitmap(display.source).bitmapData.draw(video, matrix, null, null, null, true);
		}
		
		private function updateTime(completed:Boolean = false):void
		{
			if (completed)
			{
				scrubBar.value = _duration;
				currentTimeDisplay.text = formatTimeValue(_duration);
			}
			else
			{
				scrubBar.value = _netStream.time;
				currentTimeDisplay.text = formatTimeValue(_netStream.time);
			}
		}

		private function formatTimeValue(value:Number):String
		{
			value = Math.round(value);
			var hours:uint = Math.floor(value/3600) % 24;
			var minutes:uint = Math.floor(value/60) % 60;
			var seconds:uint = value % 60;
			var result:String = "";
			if (hours != 0)
				result = hours + ":";
			if (result && minutes < 10)
				result += "0" + minutes + ":";
			else
				result += minutes + ":";
			if (seconds < 10)
				result += "0" + seconds;
			else
				result += seconds;
			return result;
		}
	
	}

}