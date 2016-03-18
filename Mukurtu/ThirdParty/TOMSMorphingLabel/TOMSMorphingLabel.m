//
//  TOMSMorphingLabel.m
//  TOMSMorphingLabelExample
//
//  Created by Tom König on 13/06/14.
//  Copyright (c) 2014 TomKnig. All rights reserved.
//

#import "TOMSMorphingLabel.h"

#define kTOMSKernFactorAttributeName @"kTOMSKernFactorAttributeName"

@interface TOMSMorphingLabel ()

@property (readonly, nonatomic, assign) NSUInteger numberOfAttributionStages;
@property (readonly, nonatomic, strong) NSArray *attributionStages;
@property (atomic, assign, getter=isAnimating) BOOL animating;

@property (atomic, assign) NSInteger attributionStage;
@property (atomic, strong) NSArray *deletionRanges;
@property (atomic, strong) NSArray *additionRanges;
@property (atomic, strong) NSString *nextText;
@property (readwrite, atomic, strong) NSString *targetText;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval displayLinkDuration;

@end

@implementation TOMSMorphingLabel
@synthesize attributionStages = _attributionStages;
@synthesize attributionStage = _attributionStage;
@synthesize deletionRanges = _deletionRanges;
@synthesize additionRanges = _additionRanges;

#pragma mark - Initialization

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        [self designatedInitialization];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self designatedInitialization];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self designatedInitialization];
    }
    
    return self;
}

- (void)designatedInitialization
{
    _displayLinkDuration = -1;
    self.animating = NO;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(tickInitial)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSRunLoopCommonModes];
    
    self.animationDuration = 0.37;
    self.characterAnimationOffset = 0.25;
    self.characterShrinkFactor = 4;
}

#pragma mark - Setters

- (void)numberOfAttributionStagesShouldChange
{
    if (self.displayLinkDuration > 0) {
        _numberOfAttributionStages = (NSInteger) ((1.f / self.displayLinkDuration) * _animationDuration);
        _attributionStages = nil;
        if (self.nextText) {
            [self beginMorphing];
        }
    }
}

- (void)setDisplayLinkDuration:(CFTimeInterval)displayLinkDuration
{
    _displayLinkDuration = displayLinkDuration;
    [self numberOfAttributionStagesShouldChange];
}

- (void)setAnimationDuration:(CGFloat)animationDuration
{
    if (!self.isAnimating) {
        _animationDuration = animationDuration;
        [self numberOfAttributionStagesShouldChange];
    }
}

- (void)tickInitial
{
    if (self.displayLinkDuration <= 0) {
        self.displayLink.paused = YES;
        CFTimeInterval duration = self.displayLink.duration;
        
        self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                           selector:@selector(tickMorphing)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSRunLoopCommonModes];
        self.displayLink.paused = YES;
        
        self.displayLinkDuration = duration;
    }
}

#pragma mark - Getters

- (CGFloat)easedValue:(CGFloat)p
{
    if (p < 0.5f) {
        return 2.f * p * p;
    }
    return (-2.f * p * p) + (4.f * p) - 1.f;
}

- (UIColor *)textColorWithAlpha:(CGFloat)alpha
{
    return [self.textColor colorWithAlphaComponent:alpha];
}

- (UIFont *)fontForScale:(CGFloat)scale
{
    return [UIFont fontWithName:self.font.fontName size:(self.font.pointSize * scale)];
}

- (NSArray *)attributionStages
{
    if (!_attributionStages) {
        NSMutableArray *attributionStages = [[NSMutableArray alloc] initWithCapacity:self.numberOfAttributionStages];
        
        CGFloat minFontSize = self.font.pointSize / self.characterShrinkFactor;
        CGFloat fontRatio = minFontSize / self.font.pointSize;
        CGFloat fontPadding = 1 - fontRatio;
        
        CGFloat progress, fontScale;
        UIColor *color;
        
        for (int i = 0; i < self.numberOfAttributionStages; i++) {
            NSMutableDictionary *attributionStage = [[NSMutableDictionary alloc] init];
            
            progress = [self easedValue:((CGFloat)i / (CGFloat)(self.numberOfAttributionStages - 1))];
            color = [self textColorWithAlpha:progress];
            attributionStage[NSForegroundColorAttributeName] = color;
            
            fontScale = fontRatio + progress * fontPadding;
            attributionStage[NSFontAttributeName] = [self fontForScale:fontScale];
            
            attributionStage[kTOMSKernFactorAttributeName] = [NSNumber numberWithFloat:1 - progress];
            
            [attributionStages addObject:attributionStage];
        }
        
        _attributionStages = attributionStages;
    }
    return _attributionStages;
}

#pragma mark - Morphing: Helpers

- (NSArray *)scalarRangesInArrayOfRanges:(NSArray *)ranges
{
    NSMutableArray *scalarRanges = [[NSMutableArray alloc] init];
    
    for (NSValue *value in ranges) {
        NSRange range = [value rangeValue];
        if (range.length > 1) {
            for (int i = 0; i < range.length; ++i) {
                [scalarRanges addObject:[NSValue valueWithRange:NSMakeRange(range.location + i, 1)]];
            }
        } else {
            [scalarRanges addObject:value];
        }
    }
    
    return scalarRanges;
}

#pragma mark - Morphing: Atomic Getters

- (NSInteger)attributionStage
{
    @synchronized (self) {
        return _attributionStage;
    }
}

- (NSArray *)additionRanges
{
    @synchronized (self) {
        return _additionRanges;
    }
}

- (NSArray *)deletionRanges
{
    @synchronized (self) {
        return _deletionRanges;
    }
}

#pragma mark - Morphing: Atomic Getters

- (void)setText:(NSString *)text
{
    self.nextText = text;
    if (self.displayLinkDuration > 0) {
        [self beginMorphing];
    }
}

- (void)setAttributionStage:(NSInteger)attributionStage
{
    @synchronized (self) {
        _attributionStage = attributionStage;
        [self applyAttributionStage:_attributionStage toString:self.text];
    }
}

- (void)setAdditionRanges:(NSArray *)additionRanges
{
    @synchronized (self) {
        _additionRanges = [self scalarRangesInArrayOfRanges:additionRanges];
    }
}

- (void)setDeletionRanges:(NSArray *)deletionRanges
{
    @synchronized (self) {
        _deletionRanges = [self scalarRangesInArrayOfRanges:deletionRanges];
    }
}

#pragma mark - Morphing: Animation

- (NSString *)prepareMorphing
{
    if (self.nextText) {
        NSString *newText;
        
        if (self.text) {
            NSDictionary *mergeResult = [self.nextText toms_mergeIntoString:self.text];
            
            newText = mergeResult[kTOMSDictionaryKeyMergedString];
            self.additionRanges = mergeResult[kTOMSDictionaryKeyAdditionRanges];
            self.deletionRanges = mergeResult[kTOMSDictionaryKeyDeletionRanges];
        } else {
            newText = self.nextText;
            self.additionRanges = @[[NSValue valueWithRange:NSMakeRange(0, newText.length)]];
            self.deletionRanges = @[];
        }
        
        self.targetText = self.nextText;
        self.nextText = nil;
        return newText;
    }
    return @"";
}

- (void)applyAttributionStage:(NSInteger)stage toString:(NSString *)aString
{
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:aString];
    NSInteger middleOfString = (NSInteger)(aString.length / 2);
    
    CGFloat(^entryPointForLocation)(NSInteger location) = ^(NSInteger location){
        if (location >= middleOfString) {
            return (CGFloat)(location - middleOfString) / (CGFloat)middleOfString;
        } else {
            return 1.f - (CGFloat)location / (CGFloat)middleOfString;
        }
    };
    
    void(^applyMutations)(NSArray *ranges, NSInteger offset) = ^(NSArray *ranges, NSInteger offset){
        for (NSValue *value in ranges) {
            NSRange range = [value rangeValue];
            CGFloat entryPoint = entryPointForLocation(range.location) * self.characterAnimationOffset * (CGFloat)self.numberOfAttributionStages;
            
            NSInteger attributionIndex = (NSInteger)(offset - entryPoint);
            attributionIndex = MIN(self.numberOfAttributionStages - 1, MAX(0, attributionIndex));
            
            NSMutableDictionary *attributionStage = self.attributionStages[attributionIndex];
            CGFloat kernFactor = [attributionStage[kTOMSKernFactorAttributeName] floatValue];
            NSString *character = [aString substringWithRange:range];
            CGSize characterSize = [character sizeWithAttributes:@{NSFontAttributeName: attributionStage[NSFontAttributeName]}];
            attributionStage[NSKernAttributeName] = [NSNumber numberWithFloat:(-kernFactor * characterSize.width)];
            
            [attributedText setAttributes:attributionStage
                                    range:range];
        }
    };
    
    applyMutations(self.additionRanges, stage * (1 + self.characterAnimationOffset));
    applyMutations(self.deletionRanges, self.numberOfAttributionStages - stage);
    
    self.attributedText = attributedText;
}

- (void)beginMorphing
{
    @synchronized (self) {
        if (!self.isAnimating) {
            NSString *newText = [self prepareMorphing];
            self.animating = YES;
            _attributionStage = 0;
            [self applyAttributionStage:self.attributionStage toString:newText];
            self.displayLink.paused = NO;
        }
    }
}

- (void)endMorphing
{
    self.displayLink.paused = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized (self) {
                self.attributedText = [[NSAttributedString alloc] initWithString:self.targetText];
                self.animating = NO;
                if (self.nextText) {
                    [self beginMorphing];
                }
            }
        });
    });
}

- (void)tickMorphing
{
    @synchronized (self) {
        if (self.isAnimating) {
            if (self.attributionStage < self.numberOfAttributionStages) {
                [self applyAttributionStage:self.attributionStage++ toString:self.text];
            } else {
                [self endMorphing];
            }
        }
    }
}

@end
