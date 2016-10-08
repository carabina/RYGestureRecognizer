# RYGestureRecognizer

This a class can recognize gestures like tap, pan, swipe, pinch, rotation. In system gesture, once you register the tap gesture, the pan gesture will not call the action if the finger doesn't move a range. And if you want to recognize some gestures at the same time, you should register all these gesture recognizers. But you just register this class, you can recognize almost all gesture, except the "UIScreenEdgePanGestureRecognizer". 

You can choose the gesture you want to recognize, just set the property of "gestureEnable" with values in the NS_OPTION "RYGestureEnable".

And in the system gesture, if you register single tap and double tap in the same time, the single tap will be recognized with some delay, in RYGestureRecognizer, the delay is less than the system's. which is controll by the property of "mutilClickedSensitivity".

You can also add your custom swipe gesture to RYGestureRecognizer, like gesture up-left-down-right. you just call the method "- (void) addCustomGesture:(NSUInteger) customGesture" with unsign integer paramter of 1324.

##How to use it
```
//initialize and set the action.
RYGestureRecognizer* recognizer = [[RYGestureRecognizer alloc] initWithTarget:self action:@selector(gestureAction:)]; 
recognizer.maxNumberOfTapsRequired = 2; //recognizer single and double taps.
recognizer.gestureEnable ^= RYGestureEnableLongPress; //recognize all supported gestures except the long press gesture
[self.view addGestureRecognizer:recognizer]; //add to the view
```

##The action method
```
- (void) gestureAction:(RYGestureRecognizer*) recognizer {

    if (recognizer.recognizerState == UIGestureRecognizerStateChanged && recognizer.maxFingerNum == 1) {  //one finger move
        CGPoint v = [recognizer velocityInView:self.view]; //get the finger velocity
        CGPoint z = [recognizer translationInView:self.view]; // get the translation
        NSUInteger fingerNum = recognizer.maxFingerNum;  // get the finger number
        //Do other things you want to do...
    }
    
    
    if (recognizer.recognizerState == UIGestureRecognizerStateEnded) {  //recognized the gesture
        CGPoint v = [recognizer velocityInView:self.view]; //get the finger velocity
        CGPoint z = [recognizer translationInView:self.view]; // get the translation
        NSUInteger fingerNum = recognizer.maxFingerNum;  // get the finger number
        RYPanGesture gesture =  recognizer.gesture // get the recognized gesture
        //Do other things you want to do...
    }
}
```

Any bugs report is welcome!

##Change Log
v0.1.0(2016-10-8)
First published version.
