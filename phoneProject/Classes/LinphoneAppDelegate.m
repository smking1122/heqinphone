/* LinphoneAppDelegate.m
 *
 * Copyright (C) 2009  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */                                                                           

#import "PhoneMainView.h"
#import "linphoneAppDelegate.h"
#import "AddressBook/ABPerson.h"

#import "CoreTelephony/CTCallCenter.h"
#import "CoreTelephony/CTCall.h"

#import "LinphoneCoreSettingsStore.h"

#include "LinphoneManager.h"
#include "linphone/linphonecore.h"

#import "RDRRequest.h"
#import "RDRSystemConfigRequestModel.h"
#import "RDRSystemConfigResponseModel.h"
#import "RDRNetHelper.h"
#import "LPSystemSetting.h"
#import "LPSystemUser.h"

@interface LinphoneAppDelegate () {
    UIAlertView *_updateAlertView;
}

@end

@implementation LinphoneAppDelegate

@synthesize configURL;
@synthesize window;

#pragma mark - Lifecycle Functions

- (id)init {
    self = [super init];
    if(self != nil) {
        self->startedInBackground = FALSE;
    }
    return self;
}

- (void)dealloc {
	[super dealloc];
}


#pragma mark - 



- (void)applicationDidEnterBackground:(UIApplication *)application{
	LOGI(@"%@", NSStringFromSelector(_cmd));
	[[LinphoneManager instance] enterBackgroundMode];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    LOGI(@"%@", NSStringFromSelector(_cmd));
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
	
    if (call){
		/* save call context */
		LinphoneManager* instance = [LinphoneManager instance];
		instance->currentCallContextBeforeGoingBackground.call = call;
		instance->currentCallContextBeforeGoingBackground.cameraIsEnabled = linphone_call_camera_enabled(call);
    
		const LinphoneCallParams* params = linphone_call_get_current_params(call);
		if (linphone_call_params_video_enabled(params)) {
			linphone_call_enable_camera(call, false);
		}
	}
    
    if (![[LinphoneManager instance] resignActive]) {

    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if(_updateAlertView == nil){
//        [self checkLatestVersion];
    }
    
    LOGI(@"%@", NSStringFromSelector(_cmd));

    if( startedInBackground ){
        startedInBackground = FALSE;
        [[PhoneMainView instance] startUp];
        [[PhoneMainView instance] updateStatusBar:nil];
    }
    LinphoneManager* instance = [LinphoneManager instance];
    
    [instance becomeActive];
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
    
    if (call){
        if (call == instance->currentCallContextBeforeGoingBackground.call) {
            const LinphoneCallParams* params = linphone_call_get_current_params(call);
            if (linphone_call_params_video_enabled(params)) {
                linphone_call_enable_camera(
                                            call,
                                            instance->currentCallContextBeforeGoingBackground.cameraIsEnabled);
            }
            instance->currentCallContextBeforeGoingBackground.call = 0;
        } else if ( linphone_call_get_state(call) == LinphoneCallIncomingReceived ) {
            [[PhoneMainView  instance ] displayIncomingCall:call];
            // in this case, the ringing sound comes from the notification.
            // To stop it we have to do the iOS7 ring fix...
            [self fixRing];
        }
    }
}

- (UIUserNotificationCategory*)getMessageNotificationCategory {
    
    UIMutableUserNotificationAction* reply = [[[UIMutableUserNotificationAction alloc] init] autorelease];
    reply.identifier = @"reply";
    reply.title = NSLocalizedString(@"Reply", nil);
    reply.activationMode = UIUserNotificationActivationModeForeground;
    reply.destructive = NO;
    reply.authenticationRequired = YES;
    
    UIMutableUserNotificationAction* mark_read = [[[UIMutableUserNotificationAction alloc] init] autorelease];
    mark_read.identifier = @"mark_read";
    mark_read.title = NSLocalizedString(@"Mark Read", nil);
    mark_read.activationMode = UIUserNotificationActivationModeBackground;
    mark_read.destructive = NO;
    mark_read.authenticationRequired = NO;
    
    NSArray* localRingActions = @[mark_read, reply];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[[UIMutableUserNotificationCategory alloc] init] autorelease];
    localRingNotifAction.identifier = @"incoming_msg";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];

    return localRingNotifAction;
}

- (UIUserNotificationCategory*)getCallNotificationCategory {
    UIMutableUserNotificationAction* answer = [[[UIMutableUserNotificationAction alloc] init] autorelease];
    answer.identifier = @"answer";
    answer.title = NSLocalizedString(@"Answer", nil);
    answer.activationMode = UIUserNotificationActivationModeForeground;
    answer.destructive = NO;
    answer.authenticationRequired = YES;
    
    UIMutableUserNotificationAction* decline = [[[UIMutableUserNotificationAction alloc] init] autorelease];
    decline.identifier = @"decline";
    decline.title = NSLocalizedString(@"Decline", nil);
    decline.activationMode = UIUserNotificationActivationModeBackground;
    decline.destructive = YES;
    decline.authenticationRequired = NO;
    
    
    NSArray* localRingActions = @[decline, answer];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[[UIMutableUserNotificationCategory alloc] init] autorelease];
    localRingNotifAction.identifier = @"incoming_call";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];

    return localRingNotifAction;
}



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    UIApplication* app= [UIApplication sharedApplication];
    UIApplicationState state = app.applicationState;

	LinphoneManager* instance = [LinphoneManager instance];
    BOOL background_mode = [instance lpConfigBoolForKey:@"backgroundmode_preference"];
    BOOL start_at_boot   = [instance lpConfigBoolForKey:@"start_at_boot_preference"];
    
    if( !instance.isTesting ){
        if( [app respondsToSelector:@selector(registerUserNotificationSettings:)] ){
            /* iOS8 notifications can be actioned! Awesome: */
            UIUserNotificationType notifTypes = UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert;
            
            NSSet* categories = [NSSet setWithObjects:[self getCallNotificationCategory], [self getMessageNotificationCategory], nil];
            UIUserNotificationSettings* userSettings = [UIUserNotificationSettings settingsForTypes:notifTypes categories:categories];
            [app registerUserNotificationSettings:userSettings];
            [app registerForRemoteNotifications];
        } else {
            NSUInteger notifTypes = UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeNewsstandContentAvailability;
            [app registerForRemoteNotificationTypes:notifTypes];
        }
    } else {
        NSLog(@"No remote push for testing");
    }

    if (state == UIApplicationStateBackground)
    {
        // we've been woken up directly to background;
        if( !start_at_boot || !background_mode ) {
            // autoboot disabled or no background, and no push: do nothing and wait for a real launch
			/*output a log with NSLog, because the ortp logging system isn't activated yet at this time*/
			NSLog(@"Linphone launch doing nothing because start_at_boot or background_mode are not activated.", NULL);
            return YES;
        }
    }
    
	bgStartId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        LOGW(@"Background task for application launching expired.");
		[[UIApplication sharedApplication] endBackgroundTask:bgStartId];
	}];

    [LinphoneManager.instance startLinphoneCore];
    
    // initialize UI
    [self.window makeKeyAndVisible];
    [RootViewManager setupWithPortrait:(PhoneMainView*)self.window.rootViewController];
    [[PhoneMainView instance] startUp];
    [[PhoneMainView instance] updateStatusBar:nil];


	NSDictionary *remoteNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif){
        LOGI(@"PushNotification from launch received.");
		[self processRemoteNotification:remoteNotif];
	}
    if (bgStartId!=UIBackgroundTaskInvalid) [[UIApplication sharedApplication] endBackgroundTask:bgStartId];
    
    // 先取当前系统的sip地址
    [self askForSystemConfig];

    NSString *verStr = [NSString stringWithFormat:@"%@ Core %s", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"], linphone_core_get_version()];
    NSLog(@"verStr=%@", verStr);
    
    return YES;
}

#define kFirAppID @"56ea45f200fc74207f000042"
#define kFirApiToken @"64cf65b0ce3e7db98a72307d69d98a65"

- (void)checkLatestVersion{
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://api.fir.im/apps/latest/%@?api_token=%@",kFirAppID, kFirApiToken]]]
                                       queue:[NSOperationQueue currentQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (data) {
            @try {
                NSDictionary *result= [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                //对比版本
                NSString * version=result[@"version"]; //对应 CFBundleVersion, 对应Xcode项目配置"General"中的 Build
                NSString * versionShort=result[@"versionShort"]; //对应 CFBundleShortVersionString, 对应Xcode项目配置"General"中的 Version
                
                NSString * localVersion=[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
                NSString * localVersionShort=[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
                
                NSString *url=result[@"update_url"]; //如果有更新 需要用Safari打开的地址
                NSString *changelog=result[@"changelog"]; //如果有更新 需要用Safari打开的地址
                
                //这里放对比版本的逻辑  每个 app 对版本更新的理解都不同
                //有的对比 version, 有的对比 build
                NSComparisonResult verResult=[localVersionShort compare:versionShort options:NSNumericSearch];
                NSComparisonResult buildResult=[localVersion compare:version options:NSNumericSearch];
                
                if ( buildResult == NSOrderedAscending || verResult == NSOrderedAscending) {
                    
                    NSString *tString=[NSString stringWithFormat:@"发现新版本 %@ ( %@ )",versionShort,version];
                    
                    if (_updateAlertView != nil) {
                        [_updateAlertView dismissWithClickedButtonIndex:_updateAlertView.cancelButtonIndex animated:NO];
                    }
                    _updateAlertView=[[UIAlertView alloc] initWithTitle:tString message:changelog delegate:self cancelButtonTitle:@"暂不更新" otherButtonTitles:@"去更新", nil];
                    _updateAlertView.rd_userInfo = @{@"url":url};
                    [_updateAlertView show];
                }
            }
            @catch (NSException *exception) {
                //返回格式错误 忽略掉
                NSLog(@"version detect exception=%@", exception);
            }
        }else {
            NSLog(@"version detected error, data is nil");
        }
    }];
}

- (void)askForSystemConfig {
    // 判断本地是否有存储
    LPSystemSetting *systemSetting = [LPSystemSetting sharedSetting];
//    if (systemSetting.sipDomainStr.length == 0) {
        // 从网络请求
    NSLog(@"start ask for system config");
        RDRSystemConfigRequestModel *reqModel = [RDRSystemConfigRequestModel requestModel];
        RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
        
        [RDRNetHelper POST:req responseModelClass:[RDRSystemConfigResponseModel class]
                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                       
                       RDRSystemConfigResponseModel *model = responseObject;
                       
//                       [self showWithDomainValue:model];

                       if ([model codeCheckSuccess] == YES) {
                           NSString *domainStr = model.domainStr;
                           NSLog(@"请求sipDoamin returned system setting domainStr=%@", domainStr);
                           
                           // 进行存储
                           systemSetting.sipDomainStr = domainStr;
                           [systemSetting saveSystem];
                       }else {
                           NSLog(@"请求sipDoamin 服务器请求出错, model=%@", model);
                       }
                   } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                       //请求出错
                       NSLog(@"请求sipDoamin出错, %s, error=%@", __FUNCTION__, error);
                   }];
//    }else {
//        // 本地已经有了，不需重新请求
//        NSLog(@"local sip str = %@", systemSetting.sipDomainStr);
//    }
}

- (void)showWithDomainValue:(RDRSystemConfigResponseModel *)model {
    UIWindow *curWindow = [UIApplication sharedApplication].keyWindow;
    
    UILabel *tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 100, 300, 100)];
    tipLabel.numberOfLines = 0;
    tipLabel.text = model.description;
    [curWindow addSubview:tipLabel];
    tipLabel.backgroundColor = [UIColor redColor];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    LOGI(@"%@", NSStringFromSelector(_cmd));
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    NSString *scheme = [[url scheme] lowercaseString];
    if ([scheme isEqualToString:@"linphone-config"] || [scheme isEqualToString:@"linphone-config"]) {
        NSString* encodedURL = [[url absoluteString] stringByReplacingOccurrencesOfString:@"linphone-config://" withString:@""];
        self.configURL = [encodedURL stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        UIAlertView* confirmation = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Remote configuration",nil)
                                                        message:NSLocalizedString(@"This operation will load a remote configuration. Continue ?",nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"No",nil)
                                              otherButtonTitles:NSLocalizedString(@"Yes",nil),nil];
        confirmation.tag = 1;
        [confirmation show];
        [confirmation release];
    } else {
        if([[url scheme] isEqualToString:@"sip"]) {
			// remove "sip://" from the URI, and do it correctly by taking resourceSpecifier and removing leading and trailing "/"
			NSString* sipUri = [[url resourceSpecifier] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];

			DialerViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]], DialerViewController);
            if(controller != nil) {
                [controller setAddress:sipUri];
            }
        }
    }
	return YES;
}

- (void)fixRing{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        // iOS7 fix for notification sound not stopping.
        // see http://stackoverflow.com/questions/19124882/stopping-ios-7-remote-notification-sound
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
    }
}

- (void)processRemoteNotification:(NSDictionary*)userInfo{

	NSDictionary *aps = [userInfo objectForKey:@"aps"];
	
    if(aps != nil) {
        NSDictionary *alert = [aps objectForKey:@"alert"];
        if(alert != nil) {
            NSString *loc_key = [alert objectForKey:@"loc-key"];
			/*if we receive a remote notification, it is probably because our TCP background socket was no more working.
			 As a result, break it and refresh registers in order to make sure to receive incoming INVITE or MESSAGE*/
			LinphoneCore *lc = [LinphoneManager getLc];
			if (linphone_core_get_calls(lc)==NULL){ //if there are calls, obviously our TCP socket shall be working
				linphone_core_set_network_reachable(lc, FALSE);
				[LinphoneManager instance].connectivity=none; /*force connectivity to be discovered again*/
                [[LinphoneManager instance] refreshRegisters];
				if(loc_key != nil) {

					NSString* callId = [userInfo objectForKey:@"call-id"];
					if( callId != nil ){
						[[LinphoneManager instance] addPushCallId:callId];
					} else {
                        LOGE(@"PushNotification: does not have call-id yet, fix it !");
					}

					if( [loc_key isEqualToString:@"IM_MSG"] ) {

						[[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];

					} else if( [loc_key isEqualToString:@"IC_MSG"] ) {

						[self fixRing];

					}
				}
			}
        }
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    LOGI(@"%@ : %@", NSStringFromSelector(_cmd), userInfo);

	[self processRemoteNotification:userInfo];
}

- (LinphoneChatRoom*)findChatRoomForContact:(NSString*)contact {
    MSList* rooms = linphone_core_get_chat_rooms([LinphoneManager getLc]);
    const char* from = [contact UTF8String];
    while (rooms) {
        const LinphoneAddress* room_from_address = linphone_chat_room_get_peer_address((LinphoneChatRoom*)rooms->data);
        char* room_from = linphone_address_as_string_uri_only(room_from_address);
        if( room_from && strcmp(from, room_from)== 0){
            return rooms->data;
        }
        rooms = rooms->next;
    }
    return NULL;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    LOGI(@"%@ - state = %ld", NSStringFromSelector(_cmd), (long)application.applicationState);

    [self fixRing];

    if([notification.userInfo objectForKey:@"callId"] != nil) {
        BOOL auto_answer = TRUE;

        // some local notifications have an internal timer to relaunch themselves at specified intervals
        if( [[notification.userInfo objectForKey:@"timer"] intValue] == 1 ){
            [[LinphoneManager instance] cancelLocalNotifTimerForCallId:[notification.userInfo objectForKey:@"callId"]];
            auto_answer = [[LinphoneManager instance] lpConfigBoolForKey:@"autoanswer_notif_preference"];
        }
        if(auto_answer)
        {
            [[LinphoneManager instance] acceptCallForCallId:[notification.userInfo objectForKey:@"callId"]];
        }
    } else if([notification.userInfo objectForKey:@"from_addr"] != nil) {
        NSString *remoteContact = (NSString*)[notification.userInfo objectForKey:@"from_addr"];
        // Go to ChatRoom view
        [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
		LinphoneChatRoom*room = [self findChatRoomForContact:remoteContact];
        ChatRoomViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ChatRoomViewController compositeViewDescription] push:TRUE], ChatRoomViewController);
        if(controller != nil && room != nil) {
            [controller setChatRoom:room];
        }
    } else if([notification.userInfo objectForKey:@"callLog"] != nil) {
        NSString *callLog = (NSString*)[notification.userInfo objectForKey:@"callLog"];
        // Go to HistoryDetails view
        [[PhoneMainView instance] changeCurrentView:[HistoryViewController compositeViewDescription]];
        HistoryDetailsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[HistoryDetailsViewController compositeViewDescription] push:TRUE], HistoryDetailsViewController);
        if(controller != nil) {
            [controller setCallLogId:callLog];
        }
    }
}

// this method is implemented for iOS7. It is invoked when receiving a push notification for a call and it has "content-available" in the aps section.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    LOGI(@"%@ : %@", NSStringFromSelector(_cmd), userInfo);
    LinphoneManager* lm = [LinphoneManager instance];

    // save the completion handler for later execution.
    // 2 outcomes:
    // - if a new call/message is received, the completion handler will be called with "NEWDATA"
    // - if nothing happens for 15 seconds, the completion handler will be called with "NODATA"
    lm.silentPushCompletion = completionHandler;
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:lm selector:@selector(silentPushFailed:) userInfo:nil repeats:FALSE];

	LinphoneCore *lc=[LinphoneManager getLc];
	// If no call is yet received at this time, then force Linphone to drop the current socket and make new one to register, so that we get
	// a better chance to receive the INVITE.
	if (linphone_core_get_calls(lc)==NULL){
		linphone_core_set_network_reachable(lc, FALSE);
		lm.connectivity=none; /*force connectivity to be discovered again*/
		[lm refreshRegisters];
	}
}


#pragma mark - PushNotification Functions

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    LOGI(@"%@ : %@", NSStringFromSelector(_cmd), deviceToken);
    [[LinphoneManager instance] setPushNotificationToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    LOGI(@"%@ : %@", NSStringFromSelector(_cmd), [error localizedDescription]);
    [[LinphoneManager instance] setPushNotificationToken:nil];
}

#pragma mark - User notifications

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    LOGI(@"%@", NSStringFromSelector(_cmd));
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler {
    LOGI(@"%@", NSStringFromSelector(_cmd));
    if( [[UIDevice currentDevice].systemVersion floatValue] >= 8){

        LinphoneCore* lc = [LinphoneManager getLc];
        LOGI(@"%@", NSStringFromSelector(_cmd));
        
        if( [notification.category isEqualToString:@"incoming_call"]) {
            if( [identifier isEqualToString:@"answer"] ){
                // use the standard handler
                [self application:application didReceiveLocalNotification:notification];
            } else if( [identifier isEqualToString:@"decline"] ){
                LinphoneCall* call = linphone_core_get_current_call(lc);
                if( call ) linphone_core_decline_call(lc, call, LinphoneReasonDeclined);
            }
        } else if( [notification.category isEqualToString:@"incoming_msg"] ){
            if( [identifier isEqualToString:@"reply"] ){
                // use the standard handler
                [self application:application didReceiveLocalNotification:notification];
            } else if( [identifier isEqualToString:@"mark_read"] ){
                NSString* from = [notification.userInfo objectForKey:@"from_addr"];
//                LinphoneChatRoom* room = linphone_core_get_or_create_chat_room(lc, [from UTF8String]);
                LinphoneChatRoom *room = linphone_core_get_chat_room_from_uri(LC, [from UTF8String]);

                if( room ){
                    linphone_chat_room_mark_as_read(room);
                    [[PhoneMainView instance] updateApplicationBadgeNumber];
                }
            }
        }
    }
    completionHandler();
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
    LOGI(@"%@", NSStringFromSelector(_cmd));
    completionHandler();
}

#pragma mark - Remote configuration Functions (URL Handler)


- (void)ConfigurationStateUpdateEvent: (NSNotification*) notif {
    LinphoneConfiguringState state = [[notif.userInfo objectForKey: @"state"] intValue];
       if (state == LinphoneConfiguringSuccessful) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLinphoneConfiguringStateUpdate
                                                  object:nil];
        [_waitingIndicator dismissWithClickedButtonIndex:0 animated:true];

        UIAlertView* error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Success",nil)
                                                        message:NSLocalizedString(@"Remote configuration successfully fetched and applied.",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
        [[PhoneMainView instance] startUp];
    }
    if (state == LinphoneConfiguringFailed) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLinphoneConfiguringStateUpdate
                                                  object:nil];
        [_waitingIndicator dismissWithClickedButtonIndex:0 animated:true];
        UIAlertView* error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure",nil)
                                                        message:NSLocalizedString(@"Failed configuring from the specified URL." ,nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
    }
}


- (void) showWaitingIndicator {
    _waitingIndicator = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Fetching remote configuration...",nil) message:@"" delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    UIActivityIndicatorView *progress= [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(125, 60, 30, 30)];
    progress.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
        [_waitingIndicator setValue:progress forKey:@"accessoryView"];
        [progress setColor:[UIColor blackColor]];
    } else {
        [_waitingIndicator addSubview:progress];
    }
    [progress startAnimating];
    [progress release];
    [_waitingIndicator show];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ((alertView.tag == 1) && (buttonIndex==1))  {
        [self showWaitingIndicator];
        [self attemptRemoteConfiguration];
        
    }else if (alertView == _updateAlertView) {
        
        if (buttonIndex!=[alertView cancelButtonIndex]) {
            NSString *urlString=[alertView.rd_userInfo objectForKey:@"url"];
            
            if (urlString) {
                NSURL *url=[NSURL URLWithString:urlString];
                [[UIApplication sharedApplication] openURL:url];
            }
            
        }
        
        _updateAlertView=nil;
    }
}

- (void)attemptRemoteConfiguration {

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(ConfigurationStateUpdateEvent:)
                                               name:kLinphoneConfiguringStateUpdate
                                             object:nil];
    linphone_core_set_provisioning_uri(LC, [configURL UTF8String]);
    [LinphoneManager.instance destroyLinphoneCore];
    [LinphoneManager.instance startLinphoneCore];

}


@end
