//
//  OTScreenSharer.m
//
//  Copyright © 2016 Tokbox, Inc. All rights reserved.
//

#import <OTAcceleratorPackUtil/OTAcceleratorPackUtil.h>
#import <OTKAnalytics/OTKLogger.h>
#import "OTScreenSharer.h"

#import "OTScreenSharer_Private.h"

static NSString * const kLogComponentIdentifier = @"screenSharingAccPack";
static NSString * const KLogClientVersion = @"ios-vsol-1.0.0";
static NSString * const KLogActionInitialize = @"Init";
static NSString * const KLogActionStart = @"Start";
static NSString * const KLogActionEnd = @"End";
static NSString * const KLogActionEnableAudioScreensharing = @"EnableScreensharingAudio";
static NSString * const KLogActionDisableAudioScreensharing = @"DisableScreensharingAudio";
static NSString * const KLogVariationAttempt = @"Attempt";
static NSString * const KLogVariationSuccess = @"Success";
static NSString * const KLogVariationFailure = @"Failure";

@interface SSLoggingWrapper: NSObject
@property (nonatomic) OTKLogger *logger;
@end

@implementation SSLoggingWrapper

+ (instancetype)sharedInstance {
    
    static SSLoggingWrapper *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SSLoggingWrapper alloc] init];
        sharedInstance.logger = [[OTKLogger alloc] initWithClientVersion:KLogClientVersion
                                                                  source:[[NSBundle mainBundle] bundleIdentifier]
                                                             componentId:kLogComponentIdentifier
                                                                    guid:[[NSUUID UUID] UUIDString]];
    });
    return sharedInstance;
}

@end

@interface OTScreenSharer()<OTSessionDelegate, OTPublisherDelegate, OTSubscriberKitDelegate>

@property (nonatomic) BOOL isScreenSharing;

@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) OTAcceleratorSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (strong, nonatomic) ScreenShareBlock handler;

@end

@implementation OTScreenSharer

+ (instancetype)screenSharer {
    return [OTScreenSharer sharedInstance];
}

+ (void)setOpenTokApiKey:(NSString *)apiKey
               sessionId:(NSString *)sessionId
                   token:(NSString *)token; {

    [OTAcceleratorSession setOpenTokApiKey:apiKey sessionId:sessionId token:token];
    
    SSLoggingWrapper *loggingWrapper = [SSLoggingWrapper sharedInstance];
    [loggingWrapper.logger logEventAction:KLogActionInitialize variation:KLogVariationAttempt completion:nil];
    OTScreenSharer *sharedInstance = [OTScreenSharer sharedInstance];
    if (sharedInstance) {
        [loggingWrapper.logger logEventAction:KLogActionInitialize variation:KLogVariationSuccess completion:nil];
    }
    else {
        [loggingWrapper.logger logEventAction:KLogActionInitialize variation:KLogVariationFailure completion:nil];
    }
    
    [OTScreenSharer sharedInstance].session = [OTAcceleratorSession getAcceleratorPackSession];
}

+ (instancetype) sharedInstance {
    
    static OTScreenSharer *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OTScreenSharer alloc] init];
        sharedInstance.session = [OTAcceleratorSession getAcceleratorPackSession];
    });

    return sharedInstance;
}

- (NSError *)connectWithView:(UIView *)view {
    
    SSLoggingWrapper *loggingWrapper = [SSLoggingWrapper sharedInstance];
    self.screenCapture = [[OTScreenCapture alloc] initWithView:view];
    [loggingWrapper.logger logEventAction:KLogActionStart
                    variation:KLogVariationAttempt
                   completion:nil];
    NSError *registerError = [OTAcceleratorSession registerWithAccePack:self];
    if(registerError){
        [loggingWrapper.logger logEventAction:KLogActionStart
                        variation:KLogVariationFailure
                       completion:nil];
    } else {
        [loggingWrapper.logger logEventAction:KLogActionStart
                        variation:KLogVariationSuccess
                       completion:nil];
    }
    
    return registerError;
}

- (void)connectWithView:(UIView *)view
                handler:(ScreenShareBlock)handler {
    
    if (!handler) return;
    
    NSError *error = [self connectWithView:view];
    self.handler = handler;
    if (error) {
        self.handler(ScreenShareSignalSessionDidConnect, error);
    }
}

- (NSError *)disconnect {
    
    SSLoggingWrapper *loggingWrapper = [SSLoggingWrapper sharedInstance];
    [loggingWrapper.logger logEventAction:KLogActionEnd
                                variation:KLogVariationAttempt
                               completion:nil];
    if (self.publisher) {

        OTError *error = nil;
        [self.publisher.view removeFromSuperview];
        [self.session unpublish:self.publisher error:&error];
        return error;
    }

    if (self.subscriber) {

        OTError *error = nil;
        [self.subscriber.view removeFromSuperview];
        [self.session unsubscribe:self.subscriber error:&error];
        return error;
    }

    NSError *disconnectError = [OTAcceleratorSession deregisterWithAccePack:self];
    if (!disconnectError) {
        [loggingWrapper.logger logEventAction:KLogActionEnd
                                    variation:KLogVariationSuccess
                                   completion:nil];
    }
    else {
        [loggingWrapper.logger logEventAction:KLogActionEnd
                                    variation:KLogVariationFailure
                                   completion:nil];
    }
    
    self.isScreenSharing = NO;
    return disconnectError;
}

- (void)updateView:(UIView *)view {
    if (self.isScreenSharing) {
        self.screenCapture.view = view;
    }
}

- (void)notifiyAllWithSignal:(ScreenShareSignal)signal error:(NSError *)error {

    if (self.handler) {
        self.handler(signal, error);
    }

    if (self.delegate) {
        [self.delegate screenShareWithSignal:signal error:error];
    }
}

- (void) sessionDidConnect:(OTSession *)session {
    //Init otkanalytics. Internal use
    [[SSLoggingWrapper sharedInstance].logger setSessionId:session.sessionId connectionId:session.connection.connectionId partnerId:@([self.session.apiKey integerValue])];

    if (!self.publisher) {
        NSString *deviceName = [UIDevice currentDevice].name;
        self.publisher = [[OTPublisher alloc] initWithDelegate:self
                                                          name:deviceName
                                                    audioTrack:YES
                                                    videoTrack:YES];
        [self.publisher setVideoType:OTPublisherKitVideoTypeScreen];
        self.publisher.audioFallbackEnabled = NO;
        [self.publisher setVideoCapture:self.screenCapture];
    }

    OTError *error;
    [self.session publish:self.publisher error:&error];
    if (error) {
        [self notifiyAllWithSignal:ScreenShareSignalSessionDidConnect
                             error:error];
    }
    else {
        self.isScreenSharing = YES;
        [self notifiyAllWithSignal:ScreenShareSignalSessionDidConnect
                             error:nil];
    }
}

- (void) sessionDidDisconnect:(OTSession *)session {
    self.publisher = nil;
    self.subscriber = nil;
    
    [self notifiyAllWithSignal:ScreenShareSignalSessionDidDisconnect
                         error:nil];
}

- (void)session:(OTSession *)session streamCreated:(OTStream *)stream {

    OTError *error;
    self.subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    self.subscriber.viewScaleBehavior = OTVideoViewScaleBehaviorFit;
    [self.session subscribe:self.subscriber error:&error];
    [self notifiyAllWithSignal:ScreenShareSignalSessionStreamCreated
                         error:error];
}

- (void) session:(OTSession *)session streamDestroyed:(OTStream *)stream {

    if (self.subscriber.stream && [self.subscriber.stream.streamId isEqualToString:stream.streamId]) {
        [self.subscriber.view removeFromSuperview];
        self.subscriber = nil;

        [self notifiyAllWithSignal:ScreenShareSignalSessionStreamDestroyed
                             error:nil];
    }
}

- (void)session:(OTSession *)session didFailWithError:(OTError *)error {
    NSLog(@"session did failed with error: (%@)", error);
    [self notifiyAllWithSignal:ScreenShareSignalSessionDidFail
                         error:error];
}

#pragma mark - OTPublisherDelegate

- (void)publisher:(OTPublisherKit *)publisher didFailWithError:(OTError *)error {
    NSLog(@"publisher did failed with error: (%@)", error);
    [self notifiyAllWithSignal:ScreenShareSignalPublisherDidFail
                         error:error];
}

#pragma mark - OTSubscriberKitDelegate
-(void) subscriberDidConnectToStream:(OTSubscriberKit*)subscriber {
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberConnect
                         error:nil];
}

-(void)subscriberVideoDisabled:(OTSubscriber *)subscriber reason:(OTSubscriberVideoEventReason)reason {
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberVideoDisabled
                         error:nil];
}

- (void)subscriberVideoEnabled:(OTSubscriberKit *)subscriber reason:(OTSubscriberVideoEventReason)reason {
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberVideoEnabled
                         error:nil];
}

-(void) subscriberVideoDisableWarning:(OTSubscriber *)subscriber reason:(OTSubscriberVideoEventReason)reason {
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberVideoDisableWarning
                         error:nil];
}

-(void) subscriberVideoDisableWarningLifted:(OTSubscriberKit *)subscriber reason:(OTSubscriberVideoEventReason)reason {
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberVideoDisableWarningLifted
                         error:nil];
}

- (void)subscriber:(OTSubscriberKit *)subscriber didFailWithError:(OTError *)error {
    NSLog(@"subscriber did failed with error: (%@)", error);
    [self notifiyAllWithSignal:ScreenShareSignalSubscriberDidFail
                         error:error];
}

#pragma mark - Setters and Getters
- (UIView *)subscriberView {
    return _subscriber.view;
}

- (UIView *)publisherView {
    return _publisher.view;
}

- (void)setSubscribeToAudio:(BOOL)subscribeToAudio {
    _subscriber.subscribeToAudio = subscribeToAudio;
}

- (BOOL)isSubscribeToAudio {
    return _subscriber.subscribeToAudio;
}

- (void)setSubscribeToVideo:(BOOL)subscribeToVideo {
    _subscriber.subscribeToVideo = subscribeToVideo;
}

- (BOOL)isSubscribeToVideo {
    return _subscriber.subscribeToVideo;
}

- (void)setPublishAudio:(BOOL)publishAudio {
    _publisher.publishAudio = publishAudio;
    if (_publisher.publishAudio){
        [[SSLoggingWrapper sharedInstance].logger logEventAction:KLogActionEnableAudioScreensharing variation:KLogVariationSuccess completion:nil];
    } else {
        [[SSLoggingWrapper sharedInstance].logger logEventAction:KLogActionDisableAudioScreensharing variation:KLogVariationSuccess completion:nil];
    }
}

- (BOOL)isPublishAudio {
    return _publisher.publishAudio;
}

- (void)setPublishVideo:(BOOL)publishVideo {
    _publisher.publishVideo = publishVideo;
}

- (BOOL)isPublishVideo {
    return _publisher.publishVideo;
}

@end
