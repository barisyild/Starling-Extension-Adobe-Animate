package starling.extensions.animate;

import flash.errors.ArgumentError;
import flash.errors.Error;
import haxe.Constraints.Function;
import starling.animation.IAnimatable;
import starling.display.DisplayObject;
import starling.events.Event;
import starling.events.EventDispatcher;
import starling.utils.MathUtil;


class MovieBehavior extends EventDispatcher implements IAnimatable
{
    public var numFrames(get, set) : Int;
    public var totalTime(get, never) : Float;
    public var currentTime(get, set) : Float;
    public var frameRate(get, set) : Float;
    public var loop(get, set) : Bool;
    public var currentFrame(get, set) : Int;
    public var isPlaying(get, never) : Bool;
    public var isComplete(get, never) : Bool;

    private var _frames : Array<MovieFrame>;
    private var _frameDuration : Float;
    private var _currentTime : Float;
    private var _currentFrame : Int;
    private var _loop : Bool;
    private var _playing : Bool;
    private var _wasStopped : Bool;
    private var _target : DisplayObject;
    private var _onFrameChanged : Function;

    private static inline var E : Float = 0.00001;

    /** Creates a new movie behavior for the given target. Whenever the frame changes,
     *  the callback will be executed. */
    public function new(target : DisplayObject, onFrameChanged : Function,
                        frameRate : Float = 24)
    {
        super();
        if (frameRate <= 0)
        {
            throw new ArgumentError("Invalid frame rate");
        }
        if (target == null)
        {
            throw new ArgumentError("Target cannot be null");
        }
        if (onFrameChanged == null)
        {
            throw new ArgumentError("Callback cannot be null");
        }

        _target = target;
        _onFrameChanged = onFrameChanged;
        _frameDuration = 1.0 / frameRate;
        _frames = [];
        _loop = true;
        _playing = true;
        _currentTime = 0.0;
        _currentFrame = 0;
        _wasStopped = true;
    }

    // playback methods

    /** Starts playback. Beware that the clip has to be added to a juggler, too! */
    public function play() : Void
    {
        _playing = true;
    }

    /** Pauses playback. */
    public function pause() : Void
    {
        _playing = false;
    }

    /** Stops playback, resetting "currentFrame" to zero. */
    public function stop() : Void
    {
        _playing = false;
        _wasStopped = true;
        currentFrame = 0;
    }

    // frame actions

    public function addFrameAction(index : Int, action : Function) : Void
    {
        getFrameAt(index).addAction(action);
    }

    public function removeFrameAction(index : Int, action : Function) : Void
    {
        getFrameAt(index).removeAction(action);
    }

    public function removeFrameActions(index : Int) : Void
    {
        getFrameAt(index).removeActions();
    }

    private function getFrameAt(index : Int) : MovieFrame
    {
        if (index < 0 || index >= numFrames)
        {
            throw new ArgumentError("Invalid frame index");
        }
        return _frames[index];
    }

    // IAnimatable

    /** @inheritDoc */
    public function advanceTime(passedTime : Float) : Void
    {
        if (!_playing)
        {
            return;
        }

        // The tricky part in this method is that whenever a callback is executed
        // (a frame action or a 'COMPLETE' event handler), that callback might modify the movie.
        // Thus, we have to start over with the remaining time whenever that happens.

        var frame : MovieFrame = _frames[_currentFrame];
        var totalTime : Float = this.totalTime;

        if (_wasStopped)
        {
            // if the clip was stopped and started again,{

            // actions of this frame need to be repeated.

            _wasStopped = false;

            if (frame.numActions > 0)
            {
                frame.executeActions(_target, _currentFrame);
                advanceTime(passedTime);
                return;
            }
        }

        if (_currentTime >= totalTime)
        {
            if (_loop)
            {
                _currentTime = 0.0;
                _currentFrame = 0;
                _onFrameChanged(0);
                frame = _frames[0];

                if (frame.numActions > 0)
                {
                    frame.executeActions(_target, _currentFrame);
                    advanceTime(passedTime);
                    return;
                }
            }
            else
            {
                return;
            }
        }

        var finalFrame : Int = (_frames.length - 1);
        var frameStartTime : Float = _currentFrame * _frameDuration;
        var restTimeInFrame : Float = _frameDuration - _currentTime + frameStartTime;
        var dispatchCompleteEvent : Bool = false;
        var previousFrameID : Int = _currentFrame;
        var numActions : Int;

        while (passedTime >= restTimeInFrame)
        {
            passedTime -= restTimeInFrame;
            _currentTime = frameStartTime + _frameDuration;

            if (_currentFrame == finalFrame)
            {
                _currentTime = totalTime;  // prevent floating point problem

                if (hasEventListener(Event.COMPLETE))
                {
                    dispatchCompleteEvent = true;
                }
                else if (_loop)
                {
                    _currentTime = 0;
                    _currentFrame = 0;
                    frameStartTime = 0;
                }
                else
                {
                    return;
                }
            }
            else
            {
                _currentFrame += 1;
                frameStartTime += _frameDuration;
            }

            frame = _frames[_currentFrame];
            numActions = frame.numActions;

            if (dispatchCompleteEvent)
            {
                _onFrameChanged(_currentFrame);
                dispatchEventWith(Event.COMPLETE);
                advanceTime(passedTime);
                return;
            }
            else if (numActions != 0)
            {
                _onFrameChanged(_currentFrame);
                frame.executeActions(_target, _currentFrame);
                advanceTime(passedTime);
                return;
            }

            restTimeInFrame = _frameDuration;

            // prevent a mean floating point problem (issue #851)
            if (passedTime + E > restTimeInFrame && passedTime - E < restTimeInFrame)
            {
                passedTime = restTimeInFrame;
            }
        }

        if (previousFrameID != _currentFrame)
        {
            _onFrameChanged(_currentFrame);
        }

        _currentTime += passedTime;
    }

    // properties

    /** The total number of frames. */
    private function get_numFrames() : Int
    {
        return _frames.length;
    }
    private function set_numFrames(value : Int) : Int
    {
        _frames = [];
        for (i in numFrames...value)
        {
            _frames[i] = new MovieFrame();
        }
        return value;
    }

    /** The total duration of the clip in seconds. */
    private function get_totalTime() : Float
    {
        return numFrames * _frameDuration;
    }

    /** The time that has passed since the clip was started (each loop starts at zero). */
    private function get_currentTime() : Float
    {
        return _currentTime;
    }
    private function set_currentTime(value : Float) : Float
    {
        value = MathUtil.clamp(value, 0, totalTime);

        var prevFrame : Int = _currentFrame;
        _currentFrame = Std.int(value / _frameDuration);
        _currentTime = value;

        if (prevFrame != _currentFrame)
        {
            _onFrameChanged(_currentFrame);
        }
        return value;
    }

    private function get_frameRate() : Float
    {
        return 1.0 / _frameDuration;
    }
    private function set_frameRate(value : Float) : Float
    {
        if (value <= 0)
        {
            throw new ArgumentError("Invalid frame rate");
        }

        var newFrameDuration : Float = 1.0 / value;
        var acceleration : Float = newFrameDuration / _frameDuration;
        _currentTime *= acceleration;
        _frameDuration = newFrameDuration;
        return value;
    }

    /** Indicates if the clip should loop. @default true */
    private function get_loop() : Bool
    {
        return _loop;
    }
    private function set_loop(value : Bool) : Bool
    {
        _loop = value;
        return value;
    }

    /** The index of the frame that is currently displayed. */
    private function get_currentFrame() : Int
    {
        return _currentFrame;
    }
    private function set_currentFrame(value : Int) : Int
    {
        value = Std.int(MathUtil.clamp(value, 0, numFrames));

        var prevFrame : Int = _currentFrame;
        _currentTime = _frameDuration * value;
        _currentFrame = value;

        if (prevFrame != _currentFrame)
        {
            _onFrameChanged(_currentFrame);
        }
        return value;
    }

    /** Indicates if the clip is still playing. Returns <code>false</code> when the end
     *  is reached. */
    private function get_isPlaying() : Bool
    {
        if (_playing)
        {
            return _loop || _currentTime < totalTime;
        }
        else
        {
            return false;
        }
    }

    /** Indicates if a (non-looping) movie has come to its end. */
    private function get_isComplete() : Bool
    {
        return !_loop && _currentTime >= totalTime;
    }
}



class MovieFrame
{
    public var numActions(get, never) : Int;

    private var _actions : Array<Function>;

    public function new()
    {
    }

    public function addAction(action : Function) : Void
    {
        if (action == null)
        {
            throw new ArgumentError("action cannot be null");
        }
        if (_actions == null)
        {
            _actions = [];
        }
        if (Lambda.indexOf(_actions, action) == -1)
        {
            _actions[_actions.length] = action;
        }
    }

    public function removeAction(action : Function) : Void
    {
        if (_actions != null)
        {
            var index : Int = Lambda.indexOf(_actions, action);
            if (index >= 0)
            {
                _actions.splice(index, 1)[0];
            }
        }
    }

    public function removeActions() : Void
    {
        if (_actions != null)
        {
            _actions = [];
        }
    }

    public function executeActions(target : DisplayObject, frameID : Int) : Void
    {
        if (_actions != null)
        {
            var i : Int = 0;
            var len : Int = _actions.length;
            while (i < len)
            {
                var action : Function = _actions[i];
                action(target, frameID);
                ++i;
            }
        }
    }

    private function get_numActions() : Int
    {
        return (_actions != null) ? _actions.length : 0;
    }
}


typedef MovieFrameAction = DisplayObject -> Int -> Void;