// KollusPlayerView.m
// K2 stub skeleton — regenerate with scripts/generate_kollus_k2_stub.py
// Reference header: KollusPlayerView.h
// Per ADR-06: no NSException. Pointer return → nil, BOOL → NO, void → debug log.

#import <os/log.h>
#import "KollusPlayerView.h"

@implementation KollusPlayerView

- (id)initWithContentURL:(NSString*)url {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.contentURL = url;
    }
    return self;
}
- (id)initWithMediaContentKey:(NSString*)mck {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.mediaContentKey = mck;
    }
    return self;
}
- (BOOL)prepareToPlayWithMode:(KollusPlayerType)type error:(NSError**)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)playWithError:(NSError **)error {
    return NO;
}
- (BOOL)pauseWithError:(NSError **)error {
    return NO;
}
- (BOOL)stopWithError:(NSError **)error {
    return NO;
}
- (BOOL)scroll:(CGPoint)distance error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)scrollStopWithError:(NSError **)error {
    return NO;
}
- (BOOL)zoom:(UIPinchGestureRecognizer*)recognizer error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)addBookmark:(NSTimeInterval)position value:(NSString*)value error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)removeBookmark:(NSTimeInterval)position error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (void)setNetworkTimeOut:(NSInteger)timeOut {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setBufferingRatio:(NSInteger)bufferingRatio {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (BOOL)isOpened {
    return NO;
}
- (BOOL)setSkipPlay {
    return NO;
}
- (void)changeBandWidth:(int)bandWidth {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (bool)setSubTitlePath:(char*)path {
    return false;
}
- (bool)setSubTitleSubPath:(char*)path {
    return false;
}
- (CGRect)getVideoPosition {
    return (CGRect){0};
}
- (CGFloat)getZoomValue {
    return 0;
}
- (void)setPauseOnForeground:(BOOL)bPause {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setDisableZoomOut:(BOOL)bDisable {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setDecoder:(bool)bHW {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setAIRate:(bool)bAIRate {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
@end
