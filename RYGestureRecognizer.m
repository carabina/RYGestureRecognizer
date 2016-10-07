//
//  RYUIGestureRecognizer.m
//  
//
//  Created by Ekulelu on 16/9/22.
//  Copyright © 2016年 Ekulelu. All rights reserved.
//

#import "RYGestureRecognizer.h"

//#define NSLog(...)

@interface RYGestureRecognizer() {
    UIGestureRecognizerState _recognizerState; //自定义的状态参数，用来覆盖父类的getter方法。
}


typedef NS_ENUM(NSUInteger, GestureDirection) {
    DIRECTION_UNKNOWN = 0,
    DIRECTION_DOWN = 1,
    DIRECTION_UP = 2,
    DIRECTION_LEFT = 3,
    DIRECTION_RIGHT = 4
};


@property(nonatomic, assign) id actionHandler;
@property(nonatomic, assign) SEL gestureAction;



@property(nonatomic, strong) NSMutableArray* directions; //保存已经移动的方向
@property(nonatomic, assign) NSInteger lastDirection;  //上一次移动的方向
@property(nonatomic, assign) double lastTime; //上一次触点的时间，用来计算速度
@property(nonatomic, assign) double lastLastTime;
@property(nonatomic, assign) Boolean touchRealease; //标记已经有手指离开了，这时候再添加手指将会视为手势无效
@property(nonatomic, assign) Boolean fail; //判断当前的手指是否已经失效，因为失效后还有手指按着，这时候不应该去响应它的滑动事件。
@property(nonatomic, strong) NSMutableArray* touchArray; //保存按下的点
@property(nonatomic, strong) NSMutableSet* gestureSet; //将定义的手势枚举变量转换为Set，方便查询
@property(nonatomic, strong) NSMutableArray* lastPointArray; //保存按下点的上一次的位置。
@property(nonatomic, strong) NSMutableArray* lastLastPointArray; //保存按下点的上一次的位置。
@property(nonatomic, assign) NSUInteger touchIndex; //最后移动触点在touchArray中的索引，取出这个触点来计算速度。
@property(nonatomic, strong) NSMutableArray* changeableTouchBeginPointArray; //可以重置的开始点，用来判断移动的距离
@property(nonatomic, strong) NSMutableArray* staticTouchBeginPointArray; //不可以重置的开始点。用来判断手势滑动的方向
@property(nonatomic, assign, getter=isRotationOrScale) Boolean rotationOrScale;

@property(nonatomic, assign, getter=isMoved) Boolean moved; //判断按下的所有手指是不是移动了。
@property(atomic, assign) __block NSUInteger tapedNum;  //单击次数
@property(nonatomic, assign) int firstTouchedNum; //第一次所以手指释放之后，这次最大的按下手指数，初始值为-1；

@property(nonatomic, strong) NSTimer* longPressTimer;

@end


@implementation RYGestureRecognizer

#pragma mark - 初始化相关
- (instancetype) init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype) initWithTarget:(nullable id)target action:(nullable SEL)action {
    if (self = [super initWithTarget:nil action:nil]) {
        _actionHandler = target;
        _gestureAction = action;
        [self setup];
    }
    return self;
}


- (void) setup {
    self.maximumNumberOfTouches = 3;
    self.minimumNumberOfTouches = 1;
    self.swipeRecognizeRange = 5;
    self.maxNumberOfTapsRequired = 1;
    self.tapedNum = 0;
    self.firstTouchedNum = -1;
    self.delegate = self;
    self.mutilClickedSensitivity = 0.2;
    self.rotationOrScale = false;
    self.minimumLongPressDuration = 0.5;
    self.allowableMovementForLongPress = 10;
    self.isLongPress = false;
    self.gestureEnable = RYGestureEnableAll;
    self.shouldDoActionAtTouchBegin = false;
}


#pragma mark - 手势判断关键方法

//有手指按下的时候回调用，传入的参数是当前刚刚按下的手指
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"touch begin");
    if (self.touchRealease || self.isLongPress) { //有手指松开了  或者 已经响应了长按手势
        NSLog(@"began fail");
        self.fail = true;
        [self reset];
        return;
    }
    
    //将刚刚按下的手指保存起来
    for (UITouch* touch in touches) {
        [self.touchArray addObject:touch];
        [self.lastPointArray addObject:[NSValue valueWithCGPoint:[touch locationInView:self.view]]];
        [self.lastLastPointArray addObject:[NSValue valueWithCGPoint:[touch locationInView:self.view]]];
        [self.changeableTouchBeginPointArray addObject:[NSValue valueWithCGPoint:[touch locationInView:self.view]]];
        [self.staticTouchBeginPointArray addObject:[NSValue valueWithCGPoint:[touch locationInView:self.view]]];
    }
    self.maxTouchedNum += touches.count;
    self.maxFingerNum += touches.count;
    //因为有手指按下，所以清0
    [self.directions removeAllObjects];
    self.lastDirection = DIRECTION_UNKNOWN;
    self.gesture = RYGestureNone;
    
    
    //长按手势
    if (self.longPressTimer != nil) { //定时器不为空，且没响应过长按
        [self.longPressTimer invalidate];
        self.longPressTimer = nil;
    }
    if(!self.isLongPress) { //从这次手势开始没响应过长按
        self.longPressTimer = [NSTimer scheduledTimerWithTimeInterval:self.minimumLongPressDuration target:self selector:@selector(longPressTimerAction:) userInfo:nil repeats:NO];
    }
    
    
    //一旦手势识别开始到结束，手指动了就会调用注册的方法，并且会自动将状态变为UIGestureRecognizerStateChanged，改了也没用。所以打算自己写一个状态量
    [self setRecognizerState:UIGestureRecognizerStateBegan];
    
}

//触点移动的时候会调用这个方法，传入的是移动的触点
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    //    NSLog(@"move");
    if (self.touchRealease || self.isLongPress) { //确保没有按下的手指离开   或者  已经响应是长按手势
        return;
    }
    
    self.moved = true;
    //    NSLog(@"move");
    if (self.fail) {
        return;
    }
    
    if (self.numberOfTouches > self.maximumNumberOfTouches || self.numberOfTouches < self.minimumNumberOfTouches ) { // 多于或少于设置的手指根数不触发
        return;
    }
    
    
    NSUInteger newDirection = DIRECTION_UNKNOWN;
    
    for (UITouch* touch in touches) {
        NSUInteger index = [self.touchArray indexOfObject:touch];
        CGPoint newPoint = [touch locationInView:self.view];
        CGPoint lastPoint = ((NSValue*)[self.lastPointArray objectAtIndex:index]).CGPointValue;
        CGFloat moveRangeX = newPoint.x - lastPoint.x;
        CGFloat moveRangeY = newPoint.y - lastPoint.y;
        
        //        NSLog(@"move x = %f, y = %f dx=%f, dy=%f", newPoint.x, newPoint.y, moveRangeX, moveRangeY);
        //只有移动范围超过了swipeRecognizeRange才认为有效的移动，只要有其中一个手指范围不够就会触发
        if ((fabs(moveRangeY) < self.swipeRecognizeRange && fabs(moveRangeX) < self.swipeRecognizeRange)) {
            [self setRecognizerState:UIGestureRecognizerStateChanged];
            return;
        }
        //更改上次位置记录点
        [self.lastLastPointArray replaceObjectAtIndex:index withObject:[NSValue valueWithCGPoint:lastPoint]];
        [self.lastPointArray replaceObjectAtIndex:index withObject:[NSValue valueWithCGPoint:[touch locationInView:self.view]]];
        double xSuby = fabs(moveRangeX) - fabs(moveRangeY);
        NSInteger tempDirection;
        if (xSuby > 0) {
            tempDirection = moveRangeX > 0 ? DIRECTION_RIGHT : DIRECTION_LEFT;
        } else {
            tempDirection = moveRangeY > 0 ? DIRECTION_UP : DIRECTION_DOWN;
        }
        if (newDirection == DIRECTION_UNKNOWN) {
            newDirection = tempDirection;
        } else if(newDirection != tempDirection){ //多根手指动的方向不一样了，可能是旋转手势或捏合手势
            [self setRecognizerState:UIGestureRecognizerStateChanged];
            return;
        }
        self.touchIndex = index;
    }
    //更新移动时间，和计算速度有关
    self.lastLastTime = self.lastTime;
    self.lastTime = [[NSDate date] timeIntervalSince1970];
    
    if(self.lastDirection != DIRECTION_UNKNOWN && newDirection != self.lastDirection && !(self.numberOfTouches == touches.count)) {//动的手指不等于按下的手指，并且方向有了变化。考虑两只手指按下，一只手指不动，另外一只左右滑动。应该是捏合手势。
        self.rotationOrScale = true;
    }
    //如果移动的方向不一样，添加新的移动方向。并且要手指同时移动
    if (newDirection != DIRECTION_UNKNOWN && newDirection != self.lastDirection && self.numberOfTouches == touches.count && !self.fail) {
        [self.directions addObject:@(newDirection)];
        self.lastDirection = newDirection;
    }
    
    [self setRecognizerState:UIGestureRecognizerStateChanged];
}




//触点抬起的时候会被调用
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //    NSLog(@"end");
    
    //只要有手指抬起就取消长按定时器。如果定时器没有起作用，那么就不是长按。
    [self cancelLongPressTimer];
    
    
    //必须全部手指松开才行，考虑到一种情况：两只手指，松开一只，再按下一只。如果松开第一只手指的时候调用了end。第二只手指按下的时候会认为只有一只手指。
    if(touches.count == self.numberOfTouches){
        //        NSLog(@"手指全松开");
        self.touchRealease = false;  //清空这个标记，因为已经全部手指释放了。
        
        if(self.isLongPress) {//已经响应过长按事件了
            [self setRecognizerState:UIGestureRecognizerStateFailed];
            return;
        }
        
        if (self.fail) {  //手势无效，这种情况出现在：有手指抬起来了，但仍有手指按着，然后有按下了手指
            self.fail = false;
            [self setRecognizerState:UIGestureRecognizerStateFailed];
            return;
        }
        
        if (self.firstTouchedNum <0) {
            self.firstTouchedNum = (int)self.maxTouchedNum;
        }
        if (self.firstTouchedNum < self.minimumNumberOfTouches || self.firstTouchedNum > self.maximumNumberOfTouches) {
            [self setRecognizerState:UIGestureRecognizerStateFailed];
            return;
        }
        
        
        
        if (!self.isMoved) { //说明是点击事件或长按事件
            NSLog(@"没move");
            
            self.gesture = RYTapGesture;
            NSLog(@"tapnum加之前 %ld",self.tapedNum);
            self.tapedNum += 1;
            
            if (self.tapedNum > 1) {
                if (self.maxTouchedNum != self.firstTouchedNum * self.tapedNum) { //点击的次数 乘上 第一次点击的手指数  应该为总共点击的次数，如果不等的话，说明每次点击的手指数目不相同
                    [self setRecognizerState:UIGestureRecognizerStateFailed];
                    NSLog(@"数目不同");
                    return;
                }
                //判断每次点击的位置是否相同，防止这里点一下，那边又马上点一下
                if(![self isInNearRange]) {
                    [self setRecognizerState:UIGestureRecognizerStateFailed];
                    NSLog(@"不同位置");
                    return;
                }
            } else {
                
            }
            
            NSLog(@"tapnum %ld",self.tapedNum);
            if (self.maxNumberOfTapsRequired <= self.tapedNum) {//说明多点击事件这次满足需求了，直接发送
                self.maxFingerNum = self.firstTouchedNum; //对外改变点击的手指数
                self.realTapNum = self.tapedNum;
                NSLog(@"提前点击 %ld, 并且清空tapNum", self.tapedNum);
                [self setRecognizerState:UIGestureRecognizerStateEnded];
                return;
            }
            
            if (self.tapedNum == 1) { //已经点击了一次了，但是不够numberOfTapsRequired，这种情况下要准备延时后判断点击次数
                //这里不能调用reset
                NSLog(@"准备延时方法");
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                __weak typeof (self) weakself = self;
                dispatch_async(queue, ^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.mutilClickedSensitivity * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSLog(@"延时方法执行");
                        
                        if(weakself == nil) {
                            return;
                        }
                        if (weakself.tapedNum == 0 || self.isMoved) {//说明多点击事件已经发送了, 或者说在发送之前第二次手势动了，并不是单击，这种情况下，第一次的单击也不要了
                            return;
                        }
                        if (weakself.maxNumberOfTapsRequired > weakself.tapedNum ) { //规定时间内没有点够次数
                            weakself.gesture = RYTapGesture; //如果刚刚有手指按下，这个方法就调用。因为gesture会被清掉，所以这里重新设置。
                            weakself.realTapNum = weakself.tapedNum;
                            weakself.maxFingerNum = weakself.firstTouchedNum; //对外改变点击的手指数
                            NSLog(@"延时方法点击 %ld", weakself.realTapNum);
                            [weakself setRecognizerState:UIGestureRecognizerStateEnded];
                        }
                    });
                });
                //这里不能调动end，因为上一次的结果仍然保存着。这个时候state为changed
                
            }
        } else { //说明有移动
            NSLog(@"开始识别手势");
            [self recognizeGesture]; //识别手势
            self.maxFingerNum = self.firstTouchedNum; //对外改变点击的手指数，这里情况出现在：单击之后，延时方法执行之前，识别了手势
            NSLog(@"识别的手势为 %d", self.gesture);
            if (self.gesture == RYGestureNone) { //没有识别到有效手势
                [self setRecognizerState:UIGestureRecognizerStateFailed];
                return;
            }
            //识别到了手势，发送消息
            [self setRecognizerState:UIGestureRecognizerStateEnded];
        }
        
        
    } else { //没有全部手指松开
        self.touchRealease = true; //按下的手指中有抬起来了的
        //这里不能去移除touchArray等数组，因为双击的时候要用到
    }
}

//触摸被取消后调用
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self setRecognizerState:UIGestureRecognizerStateCancelled];
    [self reset];
    self.fail = false;
}

//这个方法会在UIGestureRecognizerStateEnded之后被系统自动调用
- (void)reset {
    NSLog(@"reset");
    [self resetSingleTap];
    [self resetMutilTap];
    _recognizerState = UIGestureRecognizerStatePossible;
}


- (void) resetSingleTap {
    self.lastDirection = DIRECTION_UNKNOWN;
    self.gesture = RYGestureNone;
    self.lastTime = 0;
    self.touchIndex = 0;
    
    self.touchRealease = false;
    self.moved = false;
    self.maxFingerNum = 0;
    self.rotationOrScale = false;
    [self cancelLongPressTimer];
    self.isLongPress = false;
}

- (void) resetMutilTap {
    [self.directions removeAllObjects];
    [self.touchArray removeAllObjects];
    [self.changeableTouchBeginPointArray removeAllObjects];
    [self.staticTouchBeginPointArray removeAllObjects];
    [self.lastPointArray removeAllObjects];
    self.maxTouchedNum = 0;
    self.tapedNum = 0;
    self.realTapNum = 0;
    self.firstTouchedNum = -1;
    self.scale = 1;
    self.rotation = 0;
}


- (void) cancelLongPressTimer {
    if (self.longPressTimer != nil) {
        [self.longPressTimer invalidate];
        self.longPressTimer = nil;
    }
}

#pragma mark - 外部调用的方法
- (void) addCustomGesture:(NSUInteger)customGesture {
    [self.customGestureSet addObject:@(customGesture)];
}

- (void) removeCustomGesture:(NSUInteger)customGesture {
    [self.customGestureSet removeObject:@(customGesture)];
}

//计算速度，如果移动的时候不是所有按下的手指同时移动，那么会返回0
- (CGPoint) velocityInView:(nullable UIView*) view {
    //    NSLog(@"vel");
    
    CGPoint lastPoint, lastLastPoint;
    double intervel = [[NSDate date] timeIntervalSince1970] - self.lastLastTime;
    if (self.touchArray.count - 1 < self.touchIndex || self.touchArray.count == 0) { //count是unsign long, 没有负数
        return CGPointZero;
    }
    
    
    
    lastLastPoint = ((NSValue*)[self.lastLastPointArray objectAtIndex:self.touchIndex]).CGPointValue;
    lastPoint = ((NSValue*)[self.lastPointArray objectAtIndex:self.touchIndex]).CGPointValue;
    
    if (self.view != view) {
        lastLastPoint = [self.view convertPoint:lastLastPoint toView:view];
        lastPoint = [self.view convertPoint:lastPoint toView:view];
    }
    
    CGFloat moveRangeX = lastPoint.x - lastLastPoint.x;
    CGFloat moveRangeY = lastPoint.y - lastLastPoint.y;
    
    return CGPointMake(moveRangeX/intervel, moveRangeY/intervel);
}




- (CGPoint)translationInView:(nullable UIView *)view {
    //    NSLog(@"tran");
    if (self.touchArray.count - 1 < self.touchIndex  || self.touchArray.count == 0) { //count是unsign long, 没有负数
        return CGPointZero;
    }
    
    UITouch* touch = [self.touchArray objectAtIndex:self.touchIndex];
    
    CGPoint newPoint = [touch locationInView:self.view];
    CGPoint beginPoint = ((NSValue*)[self.changeableTouchBeginPointArray objectAtIndex:self.touchIndex]).CGPointValue;
    CGPoint distance = [self subCGPointWithCGPoint1:newPoint Point2:beginPoint];
    if (view == nil || view == self.view) {
        return distance;
    } else {
        return [self.view convertPoint:distance toView:view];
    }
}

- (void)setTranslation:(CGPoint)translation inView:(nullable UIView *)view {
    for (int i=0; i < self.touchArray.count; i++) {
        UITouch* touch =  [self.touchArray objectAtIndex:i];
        CGPoint point = [touch locationInView:self.view];
        CGPoint newPoint = [self subCGPointWithCGPoint1:point Point2:translation];
        [self.changeableTouchBeginPointArray replaceObjectAtIndex:i withObject:[NSValue valueWithCGPoint:newPoint]];
    }
}

- (double) rotation{
    if (self.maxTouchedNum < 2) { //按下的手指少于2，返回0
        return 0;
    }
    //只判断前面两只按下的手指
    UITouch* touch1 = [self.touchArray objectAtIndex:0];
    UITouch* touch2 = [self.touchArray objectAtIndex:1];
    CGPoint nowPointA = [touch1 locationInView:self.view];
    CGPoint nowPointB = [touch2 locationInView:self.view];
    CGPoint originPointA = ((NSValue*)[self.staticTouchBeginPointArray objectAtIndex:0]).CGPointValue;
    CGPoint originPointB = ((NSValue*)[self.staticTouchBeginPointArray objectAtIndex:1]).CGPointValue;
    
    CGPoint a = [self subCGPointWithCGPoint1:nowPointA Point2:originPointA];
    CGPoint b = [self subCGPointWithCGPoint1:nowPointB Point2:originPointB];
    if (![self isZeroPoint:a] && ![self isZeroPoint:b] && !self.isRotationOrScale) { //要有两只手指移动了，并且未识别是旋转或捏合
        double vectorAngle = [self anglesWithTwoVector:a vectorB:b];
        if (vectorAngle < M_PI_2) { //两只手指移动的向量夹角小于90度，说明移动方向很接近，不能是旋转或捏合
            NSLog(@"夹角小于90度");
            return 0;
        } else { //两只手指都移动了，并且夹角大于90度，说明是旋转或捏合
            self.rotationOrScale = true;
        }
    }
    
    
    
    CGPoint lastPointA = [touch1 previousLocationInView:self.view];
    CGPoint lastPointB = [touch2 previousLocationInView:self.view];
    CGPoint lastAtoB = [self subCGPointWithCGPoint1:lastPointB Point2:lastPointA];
    CGPoint nowAtoB = [self subCGPointWithCGPoint1:nowPointB Point2:nowPointA];
    
    CGFloat lastAngle = [self anglesBetweenYaxis:lastAtoB];
    CGFloat nowAngle = [self anglesBetweenYaxis:nowAtoB];
    
    CGFloat rotationAngle = nowAngle - lastAngle;
    CGFloat vetorAngle = [self anglesWithTwoVector:nowAtoB vectorB:lastAtoB];
    if (fabs(rotationAngle) > M_PI) { //相差大于pi
        if (nowAngle > lastAngle) {
            rotationAngle = vetorAngle;
        } else {
            rotationAngle = -vetorAngle;
        }
    }
    _rotation -= rotationAngle;//手指顺时针旋转增大
    return _rotation;
    
}


- (double) scale {
    if (self.maxTouchedNum < 2) { //按下的手指少于2，返回1
        return 1;
    }
    //只判断前面两只按下的手指
    UITouch* touch1 = [self.touchArray objectAtIndex:0];
    UITouch* touch2 = [self.touchArray objectAtIndex:1];
    CGPoint nowPointA = [touch1 locationInView:self.view];
    CGPoint nowPointB = [touch2 locationInView:self.view];
    CGPoint originPointA = ((NSValue*)[self.staticTouchBeginPointArray objectAtIndex:0]).CGPointValue;
    CGPoint originPointB = ((NSValue*)[self.staticTouchBeginPointArray objectAtIndex:1]).CGPointValue;
    
    CGPoint a = [self subCGPointWithCGPoint1:nowPointA Point2:originPointA];
    CGPoint b = [self subCGPointWithCGPoint1:nowPointB Point2:originPointB];
    if (![self isZeroPoint:a] && ![self isZeroPoint:b] && !self.isRotationOrScale) { //要有两只手指移动了，并且未识别是旋转或捏合
        double vectorAngle = [self anglesWithTwoVector:a vectorB:b];
        if (vectorAngle < M_PI_2) { //两只手指移动的向量夹角小于90度，说明移动方向很接近，不能是旋转或捏合
            NSLog(@"夹角小于90度");
            return 1;
        } else { //两只手指都移动了，并且夹角大于90度，说明是旋转或捏合
            self.rotationOrScale = true;
        }
    }
    CGFloat originDistance = [self distanceBetweenPoint1:originPointA Point2:originPointB];
    CGFloat nowDistance = [self distanceBetweenPoint1:nowPointA Point2:nowPointB];
    return nowDistance / originDistance;
}


#pragma mark - 内部方法


- (NSMutableSet*) gestureSet {
    if (_gestureSet == nil) {
        _gestureSet = [[NSMutableSet alloc] init];
        [self.gestureSet addObject:@(RYGestureUp)];
        [self.gestureSet addObject:@(RYGestureDown)];
        [self.gestureSet addObject:@(RYGestureLeft)];
        [self.gestureSet addObject:@(RYGestureRight)];
        [self.gestureSet addObject:@(RYGestureUpLeft)];
        [self.gestureSet addObject:@(RYGestureUpDown)];
        [self.gestureSet addObject:@(RYGestureUpRight)];
        [self.gestureSet addObject:@(RYGestureDownUp)];
        [self.gestureSet addObject:@(RYGestureDownLeft)];
        [self.gestureSet addObject:@(RYGestureDownRight)];
        [self.gestureSet addObject:@(RYGestureLeftRight)];
        [self.gestureSet addObject:@(RYGestureLeftUp)];
        [self.gestureSet addObject:@(RYGestureLeftDown)];
        [self.gestureSet addObject:@(RYGestureRightLeft)];
        [self.gestureSet addObject:@(RYGestureRightUp)];
        [self.gestureSet addObject:@(RYGestureRightDown)];
    }
    return _gestureSet;
}


- (NSMutableSet*) customGestureSet {
    if (_customGestureSet == nil) {
        _customGestureSet = [[NSMutableSet alloc] init];
    }
    return _customGestureSet;
}

- (NSMutableArray*) touchArray{
    if(_touchArray == nil) {
        _touchArray = [NSMutableArray array];
    }
    return _touchArray;
}

- (NSMutableArray*) lastPointArray{
    if(_lastPointArray == nil) {
        _lastPointArray = [NSMutableArray array];
    }
    return _lastPointArray;
}

- (NSMutableArray*) lastLastPointArray{
    if(_lastLastPointArray == nil) {
        _lastLastPointArray = [NSMutableArray array];
    }
    return _lastLastPointArray;
}

- (NSMutableArray*) changeableTouchBeginPointArray{
    if(_changeableTouchBeginPointArray == nil) {
        _changeableTouchBeginPointArray = [NSMutableArray array];
    }
    return _changeableTouchBeginPointArray;
}

- (NSMutableArray*) staticTouchBeginPointArray{
    if(_staticTouchBeginPointArray == nil) {
        _staticTouchBeginPointArray = [NSMutableArray array];
    }
    return _staticTouchBeginPointArray;
}

- (NSMutableArray*) directions{
    if(_directions == nil) {
        _directions = [NSMutableArray array];
    }
    return _directions;
}

- (Boolean) isZeroPoint:(CGPoint) point {
    if (point.x == 0 && point.y == 0) {
        return true;
    }
    return false;
}

- (void) setMinNumberOfTapsRequired:(NSUInteger) minNumberOfTapsRequired {
    _minNumberOfTapsRequired = minNumberOfTapsRequired;
    if (_maxNumberOfTapsRequired < minNumberOfTapsRequired) {
        _maxNumberOfTapsRequired = minNumberOfTapsRequired;
    }
}

- (CGPoint) subCGPointWithCGPoint1:(CGPoint)point1 Point2:(CGPoint) point2 {
    CGFloat x = point1.x - point2.x;
    CGFloat y = point1.y - point2.y;
    return CGPointMake(x, y);
}

- (CGPoint) addCGPointWithCGPoint1:(CGPoint)point1 Point2:(CGPoint) point2 {
    CGFloat x = point1.x + point2.x;
    CGFloat y = point1.y + point2.y;
    return CGPointMake(x, y);
}

- (CGFloat) distanceBetweenPoint1:(CGPoint) point1 Point2:(CGPoint) point2 {
    CGFloat x = point1.x - point2.x;
    CGFloat y = point1.y - point2.y;
    return sqrt(x*x+y*y);
}

- (CGFloat) anglesWithTwoVector:(CGPoint)vectorA vectorB:(CGPoint)vectorB {
    CGFloat x = vectorA.x * vectorB.x + vectorA.y * vectorB.y;
    CGFloat y = vectorA.x * vectorB.y - vectorB.x * vectorA.y;
    CGFloat angle = acos(x/sqrt(x*x+y*y));
    return angle;
}

//和Y轴正向的夹角，从顺时针开始计算
- (CGFloat) anglesBetweenYaxis:(CGPoint)vector {
    CGPoint yAxis = CGPointMake(0, 1);
    CGFloat x = vector.x * yAxis.x + vector.y * yAxis.y;
    CGFloat y = vector.x * yAxis.y - yAxis.x * vector.y;
    CGFloat angle = acos(x/sqrt(x*x+y*y));
    if (vector.x < 0) {
        angle = M_PI * 2 - angle;
    }
    return angle;
}


//LongPress定时器方法，进入说明没有手指离开，但是移动范围在这里判断
- (void) longPressTimerAction:(NSTimer*) timer {
    //判断按下时候移动的范围是否超过了限制。
    Boolean belowThreshold = true;
    for (int i=0; i < self.touchArray.count; i++) {
        UITouch* touch = [self.touchArray objectAtIndex:i];
        CGPoint nowPoint = [touch locationInView:self.view];
        CGPoint originPoint = ((NSValue*)[self.staticTouchBeginPointArray objectAtIndex:i]).CGPointValue;
        CGPoint moveRange = [self subCGPointWithCGPoint1:nowPoint Point2:originPoint];
        if (fabs(moveRange.x) > self.allowableMovementForLongPress || fabs(moveRange.y) > self.allowableMovementForLongPress) {
            belowThreshold = false;
            break;
        }
    }
    
    if (belowThreshold) {
        self.isLongPress = true;
        NSLog(@"longPress");
        [self setRecognizerState:UIGestureRecognizerStateChanged]; //已经是longPress响应
    }
}

//将保存到的directions数组转换为手势，如果出现了旋转或捏合的话，那么识别为旋转或捏合手势
- (void) recognizeGesture {
    self.gesture = RYGestureNone;
    NSLog(@"%d",[self directionsToInteger]);
    
    
    if(self.isRotationOrScale) {
        self.gesture = RYRotaionOrScaleGesture;
        return;
    }
    
    int directionsInteger = [self directionsToInteger];
    if ([self.customGestureSet containsObject:@(directionsInteger)]) {
        self.gesture = directionsInteger;
        return;
    }
    if(directionsInteger > 100) { //多过3位不算，斜着的情况容易出现
        self.gesture = RYGestureNone;
        return;
    }
    if ([self.gestureSet containsObject:@(directionsInteger)]) {
        self.gesture = directionsInteger;
    }
}


- (int) directionsToInteger {
    if (self.directions.count == 0) {
        return 0;
    }
    int result = 0;
    NSEnumerator* enmuerator = self.directions.reverseObjectEnumerator;
    int i = 0;
    for (NSNumber* obj in enmuerator) {
        result += obj.intValue * pow(10, i);
        i++;
    }
    return result;
}

#define MutilTapRangeThreshold 50 //两次点击直接的距离阈值，超过了这个阈值就不认为是点在了同一个地方，用在双击和以上
- (Boolean) isInNearRange {
    int groups = (int)self.tapedNum;
    int groupCount = self.firstTouchedNum;
    for (int i=1; i<groups; i++) {
        for (int j=0; j<groupCount; j++) {
            UITouch* t1 = [self.touchArray objectAtIndex:j];
            CGPoint p1 = [t1 locationInView:self.view];
            double distance = MAXFLOAT;
            for (int x= groupCount * i; x<groupCount * (i+1); x++) {
                UITouch* t2 = [self.touchArray objectAtIndex:x];
                CGPoint p2 = [t2 locationInView:self.view];
                int temp = fabs(p1.x - p2.x) + fabs(p1.y - p2.y);
                if (distance > temp) {
                    distance = temp;
                }
            }
            if (distance > MutilTapRangeThreshold) {
                return false;
            }
        }
    }
    
    return true;
}
#pragma mark - 抛弃原来的接口
- (void)addTarget:(id)target action:(SEL)action{
    self.gestureAction = action;
    self.actionHandler = target;
}

- (void)performAction {
    if (self.actionHandler != nil && self.gestureAction != nil) {
        if ([self.actionHandler respondsToSelector:self.gestureAction]) {
            [self.actionHandler performSelector:self.gestureAction withObject:self];
        }
    }
}



- (UIGestureRecognizerState) recognizerState {
    if (_recognizerState == UIGestureRecognizerStateChanged && self.isLongPress) {
        return UIGestureRecognizerStateEnded;
    }
    return _recognizerState;
}



- (void) setRecognizerState:(UIGestureRecognizerState) state{
    
    _recognizerState = state;
    [self setValue:@(state) forKey:@"state"]; //这句不设置的话，其他系统的手势不会再有用
    
    if (state == UIGestureRecognizerStateBegan) {
        if (self.shouldDoActionAtTouchBegin) {
            [self performAction];
        }
        return;
    } else if (state == UIGestureRecognizerStateChanged) {
        if (self.gestureEnable & (RYGestureEnablePinch | RYGestureEnableRotation | RYGestureEnablePan)) { //响应旋转、捏合、拖动
            [self performAction];
            return;
        } else {
            if ((self.gestureEnable & RYGestureEnableLongPress) && self.isLongPress) { //启用了长按，并且识别到长按
                [self performAction];
                return;
            }
        }
    } else if(state == UIGestureRecognizerStateEnded) {
        if (self.gesture == RYTapGesture) { //是点击手势
            if ((self.gestureEnable & RYGestureEnableTap)  && !self.isMoved && self.tapedNum >= self.minNumberOfTapsRequired) { //响应点击事件，并且是点击事件 并且够了最小的点击数目
                [self performAction];
                return;
            } else {
                return;
            }
        }
        
        if (self.gestureEnable & RYGestureEnableSwipe) { //响应轻扫事件
            [self performAction];
            return;
        }
        
    } else if(state == UIGestureRecognizerStateFailed) {
    }
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    
    //    if (touch.view != self.view) { //这里可以更改为只响应设置的view里面的手势。但是系统的不是这样弄的。为了统一，现在只设置为不响应button。
    //        return NO;
    //    }
    if ([touch.view isKindOfClass:[UIButton class]]) {
        return NO;
    }
    return YES;
    
}
@end
