# RYGestureRecognizer

This a class can recognize gestures like tap, pan, swipe, pinch, rotation. In system gesture, once you register the tap gesture, the pan gesture will not call the action if the finger doesn't move a range. And if you want to recognize some gestures at the same time, you should register all these gesture recognizers. But you just register this class, you can recognize almost all gesture, except the UIScreenEdgePanGestureRecognizer. 

You can choose the gesture you want to recognize, just set the property of "gestureEnable" with values in the NS_OPTION RYGestureEnable.

And in the system gesture, if you register single tap and double tap in the same time, the single tap will be recognized with some delay, in RYGestureRecognizer, the delay is less than the system's. which is controll by the property of "mutilClickedSensitivity".

You can also add your custom swipe gesture to RYGestureRecognizer, like gesture up-left-down-right. you just call the method - (void) addCustomGesture:(NSUInteger) customGesture with paramter of 1324.
