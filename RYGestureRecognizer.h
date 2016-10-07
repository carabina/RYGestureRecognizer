//
//  RYUIGestureRecognizer.h
//  XTools
//
//  Created by aahu on 16/9/22.
//  Copyright © 2016年 Royole. All rights reserved.
//

#import <UIKit/UIKit.h>


//如果是斜着划的话，两个顺序识别不准确，比如向左上角滑动，可能会识别为左上或者上左。下面的常量赋值按照一定规则，上下左右分别是1、2、3、4.
//This is the define of gestures. The property of "gesture" is one of the value of below.
typedef NS_ENUM(int, RYPanGesture) {
    RYGestureNone = 0,
    RYGestureUp = 1,
    RYGestureDown = 2,
    RYGestureLeft = 3,
    RYGestureRight = 4,
    RYGestureUpLeft = 13,
    RYGestureUpRight = 14,
    RYGestureDownLeft = 23,
    RYGestureDownRight = 24,
    RYGestureUpDown = 12,
    RYGestureDownUp = 21,
    RYGestureLeftUp = 31,
    RYGestureLeftDown = 32,
    RYGestureRightUp = 41,
    RYGestureRightDown = 42,
    RYGestureLeftRight = 34,
    RYGestureRightLeft = 43,
    RYTapGesture = -100,
    RYRotaionOrScaleGesture = -200,
    RYLongPressGesture = -300
};

//手势开启的枚举量
//you can use these flags to enable to gestures. The default is all enable.
typedef NS_OPTIONS (NSUInteger, RYGestureEnable) {
    RYGestureEnableTap =       1 << 0,
    RYGestureEnableSwipe =     1 << 1,
    RYGestureEnablePan =       1 << 2,
    RYGestureEnableLongPress = 1 << 3,
    RYGestureEnablePinch =     1 << 4,
    RYGestureEnableRotation =  1 << 5,
    RYGestureEnableAll = RYGestureEnableTap | RYGestureEnableSwipe | RYGestureEnablePan | RYGestureEnableLongPress | RYGestureEnablePinch
    | RYGestureEnableRotation
};

/**滑动手势识别类，可以识别上边定义的手势。
 手势识别中，如果有手指按下后，有手指抬起来（但仍有手指按着），此时再按下手指的话，判断这个手势为无效，不再响应回调方法。直到所有手指离开，才重新开始下一次的手势判断。
 * 回调方法的说明：1、获取手势类的状态请用recognizerState，这个数值的定义和UIGestureRecognizer的state一样。在长按手势中，state的值为changed，但recognizerState为ended。其他手势二者值一样。
 *              2、长按手势只在识别后响应一次，并且如果响应后手指不全部离开，那么不会进行下一次手势判断。对应的recognizerState值为UIGestureRecognizerStateEnded。
 *              3、拖动、旋转和捏合手势会在手指移动的时候一直响应。此时可以获得速度、位移、角度、缩放这些值。对应的recognizerState值为UIGestureRecognizerStateChanged。
 *              4、默认在手指按下的时候不会响应回调函数，如果需要的话，可以修改shouldDoActionAtTouchBegin为true。
 *
   This is a class to recognize gestures, which can recognize gestures like tap, swipe, pan, pinch, rotation, long press. You can use the class to replace the iOS sdk. 
 * 1. One gesture cycle begins with a touch in the screen and ends with all touches leave the screen. In one gesture recognize cycle, if there is a finger leaves the screen, but there are still fingers touches, and then another new touch occure, this gesture cycle will be considered a invaild gesture.
 * 2. In action method, if you want to get the recognizer state(UIGestureRecognizerState), you should use the property of "recognizerState" rather than "state". The property of "state" in long press gesture is changed not ended. On other gestures the "state" is the same as "recognizerState".
 * 3. In long press gesture, the action will called right after the long press gesture recognized once. and before all fingers leave the screen, the new gesture cycle will not begin. the recognizeState is UIGestureRecognizerStateEnded.
 * 4. In rotation and pan gesture, the action method will call when the touches move. the recognizeState is UIGestureRecognizerStateChanged.
 * 5. The aciton method will not call at the begin of touch, if you wish, set the shouldDoActionAtTouchBegin with true.
 */
@interface RYGestureRecognizer : UIGestureRecognizer<UIGestureRecognizerDelegate>
@property(nonatomic, assign) RYPanGesture gesture;  //识别的手势 The recognized gesture

@property(nonatomic, assign) NSUInteger maxTouchedNum; //保存曾经最大的touch数目，如果两个手指按下了，因为松手会有前后，如果手势有效，应该还是算两个手指的，两只手指双击的话，这个数字为4.因为一共有四次touch。如果要得到双击的手指数目，那么请用maxFingerNum。 The max number of touch in one gesture cycle. One gesture cycle begins with a touch in the screen and ends with all touches leave the screen. If two fingers touch the screen, and leave one by one, the maxTouchedNum is 2. On double tap situation with two fingers to complete the gesture, the maxTouchedNum is 4. If you want to get the fingers num, please use the property of maxFingerNum.

@property(nonatomic, strong, nonnull) NSMutableSet* customGestureSet;//自定义轻扫手势，只能用1(上)、2(下)、3(左)、4(右)的组合表示.例如上左下右手势，添加的变量为1324.可以使用addCustomGesture:(NSUInteger) customGesture方法添加。 The custom gesture set, you can use the method "addCustomGesture:(NSUInteger) customGesture" to add to this set.

@property(nonatomic, assign) NSUInteger maximumNumberOfTouches;   //最大触点数，默认是3，最好不要超过3，因为4根手指滑动会触发系统的手势 The max touch number with default value 3. You're better not to set the property over 3, since more touches gesture is define by iOS system.

@property(nonatomic, assign) NSUInteger minimumNumberOfTouches;   //最下触点数，默认是1. The minimum number of touch, default vaule is 1.

@property(atomic, assign) NSUInteger maxFingerNum; //本次手势中最大的按下手指数目  //The max number of fingers in the gesture.

@property(nonatomic, assign) NSUInteger gestureEnable; //需要开启的手势，默认是全开启。 The gesture enable flag with default all enable. you can assign the property with NS_OPTION RYGestureEnable.

@property(nonatomic, assign) Boolean shouldDoActionAtTouchBegin;//是否需要在有手指按下的时候响应回调方法。默认是不响应的。如果你需要响应，那么在响应后需要自行在回调方法里面判断这次是不是由手指按下导致的响应，如果是由手指按下导致的响应，recognizer的state的值为UIGestureRecognizerStateBegan  whether call the action at the begin of ecah touch. default is not.


//点击事件
@property(nonatomic, assign) NSUInteger maxNumberOfTapsRequired; //点击能达到的最大的次数。默认是1次。 所以要设置双击，只需要把这个设为2就可以了，此时单击仍可以响应。 The max number of tap can reach, whose default is 1, means that once the tap reach the required num, the action method will be called immediately. If you just double-tap, set the property with 2, and the tap can reach to two. But single tap is also recognized if the time between two tap is too long.

@property(nonatomic, assign) NSUInteger minNumberOfTapsRequired; //点击至少需要的次数，默认是1次。没达到这个次数不会响应，如果需要只响应双击，那么把这个设为2. The min number of taps to call the action. If you set to 2, the single tap will not call the action.

@property(nonatomic, assign) NSUInteger realTapNum; //响应点击事件时候的实际的单击次数 the real number of tap in tap gesture.

@property(nonatomic, assign) double mutilClickedSensitivity;//多次点击时候，每次间隔的时间，默认是0.2.也不能间隔太大，手指全部抬起之后1秒，系统会自动任务手势已经完成，从而调用reset方法。 The max time between taps to recognize to be mutiltap, whose default is 0.2s. The value should not over 1s. Since after all fingers leaves the screen, after anohter 1s, the system will think the touch event is completed.

//旋转手势
@property(nonatomic, assign) double rotation; //旋转手势旋转的角度，手指顺时针旋转为正，单位是弧度 The rotation of rotation gesture, clockwise is positive.

//捏合手势
@property(nonatomic, assign) double scale; //捏合手势的捏合比例，小于1.0为捏合，大于1.0为拉伸 The scale in pinch gesture.

//滑动手势
@property(nonatomic, assign) NSUInteger swipeRecognizeRange;  //滑动手势最小识别长度，默认是5  The min move range to recognize as the swipe gesture.

//长按手势，和系统的长按手势不一样，这个手势一旦判断成功，只会响应一次。响应后按下的手指再移动也没有反应。
@property(nonatomic, assign) Boolean isLongPress; //判断是不是长按  whether is a long press gesture.

@property(nonatomic, assign) CFTimeInterval minimumLongPressDuration; // Default is 0.5. Time in seconds the fingers must be held down for the gesture to be recognized

@property(nonatomic, assign) CGFloat allowableMovementForLongPress;           // Default is 10. Maximum movement in pixels allowed before the gesture fails. Once recognized (after minimumPressDuration) there is no limit on finger movement for the remainder of the touch tracking

- (void) addCustomGesture:(NSUInteger) customGesture; //添加自定义手势，只能用1(上)、2(下)、3(左)、4(右)的组合表示.例如上左下右手势，添加的参数为1324. You can use this method to add your custom swipe gesture. the value is combined by 1(up),2(down),3(left),4(right). For exapmle, an up-left-down-right gesture, you add the 1324 value.
- (void) removeCustomGesture:(NSUInteger)customGesture;

- (UIGestureRecognizerState) recognizerState; //手势类现在的状态，和state基本一致，只有在长按的时候，state为changed，而recognizerState为ended. The recognizer state.

//这些方法可以在回调方法里面调用，会得到当前手指移动的速度和位移。但是得到的是最后移动的一只手指
- (CGPoint) velocityInView:(nullable UIView*) view;//取速度的时候留意手势是否有效 Get the velocity of finger move

- (CGPoint)translationInView:(nullable UIView *)view; //手指距离起始点的移动距离，单位为像素。起始点开始为按下的点，但可以通过setTranslation方法重置 The translation of finger

//设置移动距离，如果设置为CGZeroPoint的话，相当于将起始点设为现在的位置，后面计算的距离都从现在的位置开始算起
- (void)setTranslation:(CGPoint)translation inView:(nullable UIView *)view;



@end
