package com.axis.rtspclient {

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.setTimeout;
  import flash.system.Security;
  import flash.external.ExternalInterface;
  import flash.display.LoaderInfo;

  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.RTSPClient;

  import mx.utils.URLUtil;

  [Event(name="connect", type="flash.events.Event")]
  [Event(name="disconnect", type="flash.events.Event")]

  public class HTTPClient extends EventDispatcher {

    private var jsEventCallbackName:String = "console.log";
    private var getChannel:Socket = null;
    private var postChannel:Socket = null;
    private var url:String = "";

    private var getChannelTotalLength:int = -1;
    private var getChannelContentLength:int = -1;
    private var getChannelData:ByteArray = new ByteArray();

    private var rtspClient:RTSPClient;

    public function HTTPClient() {
      // Set up JS API
      ExternalInterface.marshallExceptions = true;
      ExternalInterface.addCallback("play", connect);
      ExternalInterface.addCallback("pause", disconnect);
      ExternalInterface.addCallback("stop", stop);
      ExternalInterface.addCallback("setEventCallbackName", setJsEventCallbackName);

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

      getChannel = new Socket();
      getChannel.timeout = 5000;
      getChannel.addEventListener(Event.CONNECT, onGetChannelConnect);
      getChannel.addEventListener(Event.CLOSE, onGetChannelClose);
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
      getChannel.addEventListener(IOErrorEvent.IO_ERROR, onError);
      getChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      postChannel = new Socket();
      postChannel.timeout = 5000;
      postChannel.addEventListener(Event.CONNECT, onPostChannelConnect);
      postChannel.addEventListener(Event.CLOSE, onPostChannelClose);
      postChannel.addEventListener(IOErrorEvent.IO_ERROR, onError);
      postChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
    }

    public function sendLoadedEvent():void {
      // Tell the external JS environent that we are ready to accept API calls
      ExternalInterface.call(jsEventCallbackName, 'loaded');
    }

    public function setJsEventCallbackName(jsEventCallbackName:String):void {
      this.jsEventCallbackName = jsEventCallbackName;
    }

    public function getJsEventCallbackName():String {
      return jsEventCallbackName;
    }

    private function onError(e:ErrorEvent):void {
      sendError(0, e.text);
    }

    private function sendError(errNo:Number = 0, msg:String = ""):void {
      disconnect();
      dispatchEvent(new Event("error"));
      ExternalInterface.call(jsEventCallbackName, "error", errNo, msg);
    }

    public function disconnect():void {
      if (getChannel.connected) {
        getChannel.close();
      }
      dispatchEvent(new Event("disconnect"));
    }

    public function connect(url:String = null):void {
      disconnect();

      if (url != null) { this.url = url; }

      getChannel.connect(URLUtil.getServerName(this.url), 80);
      postChannel.connect(URLUtil.getServerName(this.url), 80);

      rtspClient = new RTSPClient(getChannel, postChannel, this.url, jsEventCallbackName);
    }

    private function onGetChannelConnect(event:Event):void {
      initializeGetChannel();
      ExternalInterface.call(jsEventCallbackName, "get channel connected");
    }

    private function onPostChannelConnect(event:Event):void {
      dispatchEvent(new Event("connect"));
      ExternalInterface.call(jsEventCallbackName, "post channel connected");
    }

    public function stop():void {
      disconnect();
      dispatchEvent(new Event("clear"));
    }

    private function onGetChannelClose(event:Event):void {
      // Security error is thrown if this line is excluded
      getChannel.close();
      ExternalInterface.call(jsEventCallbackName, "get channel stopped");
    }

    private function onPostChannelClose(event:Event):void {
      ExternalInterface.call(jsEventCallbackName, "post channel stopped");
    }

    private function onGetChannelData(event:ProgressEvent):void {
      getChannel.readBytes(getChannelData);
      ExternalInterface.call(jsEventCallbackName, getChannelData.toString());

      var copy:ByteArray = new ByteArray();
      var index:int = ByteArrayUtils.indexOf(getChannelData, "\r\n\r\n");
      if (index === -1) {
        /* Not a full request yet */
        return;
      }
      var dummy:ByteArray = new ByteArray();
      getChannelData.readBytes(dummy, 0, index + 4);
      getChannel.removeEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);

      initializePostChannel();
      rtspClient.start();
    }

    private function initializeGetChannel():void {
      getChannel.writeUTFBytes("GET " + url + " HTTP/1.0\r\n");
      getChannel.writeUTFBytes("x-sessioncookie: 12" + "\r\n");
      getChannel.writeUTFBytes("\r\n");
      getChannel.flush();
    }

    private function initializePostChannel():void {
      postChannel.writeUTFBytes("POST " + url + " HTTP/1.0\r\n");
      postChannel.writeUTFBytes("x-sessioncookie: 12" + "\r\n");
      postChannel.writeUTFBytes("Content-Length: 32767" + "\r\n");
      postChannel.writeUTFBytes("Content-Type: application/x-rtsp-tunnelled" + "\r\n");
      postChannel.writeUTFBytes("\r\n");
      postChannel.flush();
    }
  }
}
