// AFNetworkActivityIndicatorManager.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFRKNetworkActivityIndicatorManager.h"

#import "AFRKHTTPRequestOperation.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
static NSTimeInterval const kAFRKNetworkActivityIndicatorInvisibilityDelay = 0.17;

@interface AFRKNetworkActivityIndicatorManager ()
@property (readwrite, nonatomic, assign) NSInteger activityCount;
@property (readwrite, nonatomic, strong) NSTimer *activityIndicatorVisibilityTimer;
@property (readonly, nonatomic, getter = isNetworkActivityIndicatorVisible) BOOL networkActivityIndicatorVisible;

- (void)updateNetworkActivityIndicatorVisibility;
- (void)updateNetworkActivityIndicatorVisibilityDelayed;
@end

@implementation AFRKNetworkActivityIndicatorManager
@synthesize activityCount = _activityCount;
@synthesize activityIndicatorVisibilityTimer = _activityIndicatorVisibilityTimer;
@synthesize enabled = _enabled;
@dynamic networkActivityIndicatorVisible;

+ (instancetype)sharedManager {
    static AFRKNetworkActivityIndicatorManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });

    return _sharedManager;
}

+ (NSSet *)keyPathsForValuesAffectingIsNetworkActivityIndicatorVisible {
    return [NSSet setWithObject:@"activityCount"];
}

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkingOperationDidStart:) name:AFRKNetworkingOperationDidStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkingOperationDidFinish:) name:AFRKNetworkingOperationDidFinishNotification object:nil];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_activityIndicatorVisibilityTimer invalidate];

}

- (void)updateNetworkActivityIndicatorVisibilityDelayed {
    if (self.enabled) {
        // Delay hiding of activity indicator for a short interval, to avoid flickering
        if (![self isNetworkActivityIndicatorVisible]) {
            [self.activityIndicatorVisibilityTimer invalidate];
            self.activityIndicatorVisibilityTimer = [NSTimer timerWithTimeInterval:kAFRKNetworkActivityIndicatorInvisibilityDelay target:self selector:@selector(updateNetworkActivityIndicatorVisibility) userInfo:nil repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:self.activityIndicatorVisibilityTimer forMode:NSRunLoopCommonModes];
        } else {
            [self performSelectorOnMainThread:@selector(updateNetworkActivityIndicatorVisibility) withObject:nil waitUntilDone:NO modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
        }
    }
}

- (BOOL)isNetworkActivityIndicatorVisible {
    return _activityCount > 0;
}

- (void)updateNetworkActivityIndicatorVisibility {
#ifndef APP_EXTENSION
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:[self isNetworkActivityIndicatorVisible]];
#endif
}

// Not exposed, but used if activityCount is set via KVC.
- (NSInteger)activityCount {
	return _activityCount;
}

- (void)setActivityCount:(NSInteger)activityCount {
	@synchronized(self) {
		_activityCount = activityCount;
	}
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateNetworkActivityIndicatorVisibilityDelayed];
    });
}

- (void)incrementActivityCount {
    [self willChangeValueForKey:@"activfityCount"];
	@synchronized(self) {
		_activityCount++;
	}
    [self didChangeValueForKey:@"activityCount"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateNetworkActivityIndicatorVisibilityDelayed];
    });
}

- (void)decrementActivityCount {
    [self willChangeValueForKey:@"activityCount"];
	@synchronized(self) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
		_activityCount = MAX(_activityCount - 1, 0);
#pragma clang diagnostic pop
	}
    [self didChangeValueForKey:@"activityCount"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateNetworkActivityIndicatorVisibilityDelayed];
    });
}

- (void)networkingOperationDidStart:(NSNotification *)notification {
    AFRKURLConnectionOperation *connectionOperation = [notification object];
    if (connectionOperation.request.URL) {
        [self incrementActivityCount];
    }
}

- (void)networkingOperationDidFinish:(NSNotification *)notification {
    AFRKURLConnectionOperation *connectionOperation = [notification object];
    if (connectionOperation.request.URL) {
        [self decrementActivityCount];
    }
}

@end

#endif
