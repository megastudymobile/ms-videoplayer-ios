// LogUtil.m
// K2 stub skeleton — regenerate with scripts/generate_kollus_k2_stub.py
// Reference header: LogUtil.h
// Per ADR-06: no NSException. Pointer return → nil, BOOL → NO, void → debug log.

#import <os/log.h>
#import "LogUtil.h"

@implementation LogUtil

+ (instancetype)sharedUtil {
    static LogUtil *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [LogUtil new];
    });
    return sharedInstance;
}
+ (void)utilLog:(NSString *)logContent, ... {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
@end
