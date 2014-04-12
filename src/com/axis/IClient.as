package com.axis {
  public interface IClient {
    /**
     * Called when the client should start the stream.
     * Any connections should be made at this point
     */
    function start():Boolean;

    /**
     * Called when the client should stop the stream.
     * The video/audio should stop playing at this pont
     * and all connections should be terminated.
     */
    function stop():Boolean;

    /**
     * Called when the client should pause the stream. This should
     * preferrably be accomplished by pausing the incomming stream,
     * but this may not always be possible. If that is not possible,
     * the client should return false and pausing will be accomplished
     * in the player.
     */
    function pause():Boolean;

    /**
     * Called when the stream should be resumed. This will only be
     * called if the client previously claimed to have paused the
     * stream by returning `true` from a call to `stop`.
     */
    function resume():Boolean;
  }
}