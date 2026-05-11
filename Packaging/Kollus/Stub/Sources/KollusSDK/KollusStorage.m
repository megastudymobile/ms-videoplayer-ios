// KollusStorage.m
// K2 stub skeleton — regenerate with scripts/generate_kollus_k2_stub.py
// Reference header: KollusStorage.h
// Per ADR-06: no NSException. Pointer return → nil, BOOL → NO, void → debug log.

#import <os/log.h>
#import "KollusStorage.h"

@implementation KollusStorage

- (BOOL)setKollusPath:(NSString *)path {
    return NO;
}
- (BOOL)startStorage:(NSError**)error {
    return NO;
}
- (BOOL)startStorageWithFirst:(BOOL)first error:(NSError**)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)startStorageWithCheck:(NSError**)error {
    return NO;
}
- (BOOL)startStorageWithNewPlayerID:(NSError**)error {
    return NO;
}
- (NSString *)loadContentURL:(NSString *)URL error:(NSError**)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return nil;
}
- (NSString*)checkContentURL:(NSString *)URL error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return nil;
}
- (BOOL)downloadContent:(NSString *)mediaContentKey error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)removeContent:(NSString *)mediaContentKey error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (BOOL)removeCacheWithError:(NSError **)error {
    return NO;
}
- (BOOL)downloadCancelContent:(NSString *)mediaContentKey error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"KollusStub"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];
    }
    return NO;
}
- (void)setNetworkTimeOut:(NSInteger)timeOut retry:(NSInteger)retryCount {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)updateDownloadDRMInfo:(BOOL)bAll {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setCacheSize:(NSInteger)cacheSizeMB {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (void)setBackgroundDownload:(BOOL)bBackground {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
- (NSMutableArray*)contents {
    return nil;
}
- (void)sendStoredLms {
    // K2 stub: simulator no-op
    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);
}
@end
