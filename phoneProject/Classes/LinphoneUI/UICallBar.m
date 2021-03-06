/* UICallBar.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU Library General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */ 

#import "UICallBar.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "Utils.h"
#include "linphone/linphonecore.h"
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>

#import "CAAnimation+Blocks.h"
#import "LPInMeetingParticipatorViewController.h"
#import "LPSystemUser.h"
#import "UIViewController+RDRTipAndAlert.h"

#include "linphone/linphonecore.h"

#import "RDRAddFavRequestModel.h"
#import "RDRAddFavResponseModel.h"

#import "RDRRequest.h"
#import "RDRNetHelper.h"

#import "LPSystemSetting.h"
#import "ShowInviteView.h"
#import "UIDigitButtonLongPlus.h"

// 邀请
#import "RDRInviteRequestModel.h"
#import "RDRInviteResponseModel.h"

// 锁定
#import "RDRLockReqeustModel.h"
#import "RDRLockResponseModel.h"

// 录制相关
#import "RDRReocrdRequestModel.h"
#import "RDRRecordResponseModel.h"

#import "ShowPinView.h"

// 结束
#import "RDRTerminalRequestModel.h"
#import "RDRTerminalResponseModel.h"

// 会议类型请求
#import "RDRMeetingTypeRequestModel.h"
#import "RDRMeetingTypeResponseModel.h"

// 设置布局
#import "RDRMeetingLayoutRequestModel.h"
#import "RDRMeetingLayoutSubRequestModel.h"
#import "RDRMeetingLayoutResponseModel.h"

#import "RDRAllJoinersView.h"

#import "ShowMeetingLayoutView.h"

typedef NS_ENUM(NSInteger, InvityType) {
    InvityTypeSMS,
    InvityTypeEmail,
    InvityTypePhoneCall
};


extern NSString *const kLinphoneInCallCellData;

@interface UICallBar ()
@property (retain, nonatomic) IBOutlet UIView *bottomBgView;        // 底部的背景图，用来控制TabBar与Content的位置,Tag=-1

@property (nonatomic, retain) IBOutlet UIButton *bmMicroButton;
@property (retain, nonatomic) IBOutlet UIButton *bmVideoButton;

@property (retain, nonatomic) IBOutlet UIButton *bottomInviteBtn;
@property (retain, nonatomic) IBOutlet UIButton *bottomJoinerBtn;
@property (retain, nonatomic) IBOutlet UIButton *bottomMoreBtn;

@property (retain, nonatomic) IBOutlet UIButton *collectionBtn;
@property (retain, nonatomic) IBOutlet UIButton *quitBtn;

@property (retain, nonatomic) IBOutlet UIButton *keyboardBtn;

@property (nonatomic, strong) UIView *popControlView;       // 弹出的按钮控件的背景

@property (strong, nonatomic) IBOutlet UIView *keyBgView;
@property (strong, nonatomic) IBOutlet UIDigitButton *oneButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *twoButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *threeButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *fourButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *fiveButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *sixButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *sevenButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *eightButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *nineButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *starButton;
@property (strong, nonatomic) IBOutlet UIDigitButtonLongPlus *zeroButton;
@property (strong, nonatomic) IBOutlet UIDigitButton *sharpButton;

@property (strong, nonatomic) IBOutlet UIView *callTipView;
@property (strong, nonatomic) IBOutlet UILabel *callTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *callSubtitleLabel;

@property (nonatomic, assign) BOOL meetingLockedStatus;     // 会议被锁定?，默认为No
@property (nonatomic, assign) BOOL meetingIsRecording;      // 会议是否正在录制，默认NO

@property (nonatomic, strong) IBOutlet UIImageView *loadingTipImgView;      // 当前关闭摄像头时使用。打开摄像头后，则不显示

@property (nonatomic, assign) MeetingType curMeetingType;

@end

@implementation UICallBar

#pragma mark - Lifecycle Functions

// 在呼叫界面中挂掉电话
- (IBAction)callTipEndCallBtnClicked:(id)sender {
    [self quitMeeting];
}

- (void)dataFillToPreview {
    NSMutableString *addr = [NSMutableString stringWithString:[LPSystemUser sharedUser].curMeetingAddr ?:@""];
    self.callSubtitleLabel.text = [[NSString stringWithString:addr] copy];

    NSString *serverAddr = [LPSystemSetting sharedSetting].sipTmpProxy;
    NSString *serverTempStr = [NSString stringWithFormat:@"@%@", serverAddr];
    
    // 移掉后部
    if ([addr replaceOccurrencesOfString:serverTempStr withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [addr length])] != 0) {
        NSLog(@"remove server address done");
    }else {
        NSLog(@"remove server address failed");
    }
    
    // 移掉前面的sip:
    if ([addr replaceOccurrencesOfString:@"sip:" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [addr length])] != 0) {
        NSLog(@"remove sip done");
    }else {
        NSLog(@"remove sip failed");
    }
    
    self.callTitleLabel.text = [NSString stringWithString:addr];
    
    NSLog(@"test instance :%@", self.callTipView);
    
    // 执行请求会议室类型的请求
    [self requestMeetingType];
}

- (void)requestMeetingType {
    
    RDRMeetingTypeRequestModel *reqModel = [RDRMeetingTypeRequestModel requestModel];
    reqModel.addr = [self curMeetingAddr];
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRMeetingTypeResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  
                  RDRMeetingTypeResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      NSLog(@"会议室类型查询success, model=%@", model);
//                      [self showToastWithMessage:@"收藏会议室成功"];
                      
                      if (model.type == 0) {
                          self.curMeetingType = MeetingTypeLesson;
                      }else {
                          self.curMeetingType = MeetingTypeMeeting;
                      }
                  }else {
                      NSLog(@"会议室类型查询失败, msg=%@", model.msg);
                      NSString *tipStr = [NSString stringWithFormat:@"会议室类型查询失败，msg=%@", model.msg];
                      [self showToastWithMessage:tipStr];
                  }
              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  
                  //请求出错
                  NSLog(@"会议室类型查询失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tipStr = [NSString stringWithFormat:@"会议室类型查询失败，服务器错误"];
                  [self showToastWithMessage:tipStr];
              }];
}

- (void)changeBtn:(UIButton *)btn {
    btn.titleLabel.font = [UIFont systemFontOfSize:11.0];
    
    [btn.titleLabel sizeToFit];
    CGSize titleSize = btn.titleLabel.frame.size;// [btn.titleLabel.text sizeWithFont:btn.titleLabel.font];
    [btn.imageView setContentMode:UIViewContentModeCenter];
    [btn setImageEdgeInsets:UIEdgeInsetsMake(-12.0,
                                             0.0,
                                             0.0,
                                             -titleSize.width)];
    
    [btn.titleLabel setContentMode:UIViewContentModeCenter];
    [btn.titleLabel setBackgroundColor:[UIColor clearColor]];
    [btn.imageView sizeToFit];
    CGSize imgSize = btn.imageView.frame.size;
    [btn setTitleEdgeInsets:UIEdgeInsetsMake(34.0,
                                             -imgSize.width,
                                             0.0,
                                             0.0)];
}

- (void)setAllBtns {
    [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_enable"] forState:UIControlStateNormal];
    [self.bmVideoButton setImage:[UIImage imageNamed:@"m_video_enabled"] forState:UIControlStateNormal];
    [self.bottomInviteBtn setImage:[UIImage imageNamed:@"m_invite"] forState:UIControlStateNormal];
    [self.bottomJoinerBtn setImage:[UIImage imageNamed:@"m_man"] forState:UIControlStateNormal];
    [self.bottomMoreBtn setImage:[UIImage imageNamed:@"m_options"] forState:UIControlStateNormal];
    
    [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_disable"] forState:UIControlStateDisabled];
    [self.bmVideoButton setImage:[UIImage imageNamed:@"m_video_disable"] forState:UIControlStateDisabled];
    [self.bottomInviteBtn setImage:[UIImage imageNamed:@"m_invite_highlight"] forState:UIControlStateHighlighted];
    [self.bottomJoinerBtn setImage:[UIImage imageNamed:@"m_man_highlight"] forState:UIControlStateHighlighted];
    [self.bottomMoreBtn setImage:[UIImage imageNamed:@"m_options_highlight"] forState:UIControlStateHighlighted];
    
    [self.bmMicroButton setTitle:@"声音" forState:UIControlStateNormal];
    [self.bmVideoButton setTitle:@"视频" forState:UIControlStateNormal];
    [self.bottomInviteBtn setTitle:@"邀请" forState:UIControlStateNormal];
    [self.bottomJoinerBtn setTitle:@"与会者" forState:UIControlStateNormal];
    [self.bottomMoreBtn setTitle:@"管理" forState:UIControlStateNormal];
    
    [self.bmMicroButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.bmVideoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.bottomInviteBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.bottomJoinerBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.bottomMoreBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // 调整布局
    [self changeBtn:self.bmMicroButton];
    [self changeBtn:self.bmVideoButton];
    [self changeBtn:self.bottomInviteBtn];
    [self changeBtn:self.bottomJoinerBtn];
    [self changeBtn:self.bottomMoreBtn];
}

- (id)init {
    return [super initWithNibName:@"UICallBar" bundle:[NSBundle mainBundle]];
}

- (void)dealloc {
    [self closeCamera:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (UIView *)popControlView {
    if (_popControlView == nil) {
        _popControlView = [[UIView alloc] initWithFrame:CGRectZero];
        _popControlView.backgroundColor = [UIColor clearColor];
        
        UIView *littleBgView = [[UIView alloc] initWithFrame:CGRectZero];
        littleBgView.backgroundColor = [UIColor grayColor];
        littleBgView.alpha = 0.3;
        [_popControlView addSubview:littleBgView];
        littleBgView.tag = 1000;
        
        [self.view addSubview:_popControlView];
        _popControlView.hidden = YES;
    }
    
    return _popControlView;
}

#pragma mark - ViewController Functions

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bgTapped:)]];
    // 在放大的情况下，该bottomBgView将占据整个屏幕
    [self.bottomBgView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bgTapped:)]];
    
    [self setAllBtns];
    
    self.keyBgView.hidden = YES;
    
    [self.zeroButton setDigit:'0'];
    [self.zeroButton setDtmf:true];
    [self.oneButton    setDigit:'1'];
    [self.oneButton setDtmf:true];
    [self.twoButton    setDigit:'2'];
    [self.twoButton setDtmf:true];
    [self.threeButton  setDigit:'3'];
    [self.threeButton setDtmf:true];
    [self.fourButton   setDigit:'4'];
    [self.fourButton setDtmf:true];
    [self.fiveButton   setDigit:'5'];
    [self.fiveButton setDtmf:true];
    [self.sixButton    setDigit:'6'];
    [self.sixButton setDtmf:true];
    [self.sevenButton  setDigit:'7'];
    [self.sevenButton setDtmf:true];
    [self.eightButton  setDigit:'8'];
    [self.eightButton setDtmf:true];
    [self.nineButton   setDigit:'9'];
    [self.nineButton setDtmf:true];
    [self.starButton   setDigit:'*'];
    [self.starButton setDtmf:true];
    [self.sharpButton  setDigit:'#'];
    [self.sharpButton setDtmf:true];
    
}

- (void)bgTapped:(UITapGestureRecognizer *)tapped {
    [self hideAllBottomBgView];
    self.keyBgView.hidden = YES;
    
    // 这里可以考虑把那些东西进行一显示动画或者隐藏动画
    if (self.bottomBgView.hidden == YES) {
        self.bottomBgView.hidden = NO;
        self.collectionBtn.hidden = NO;
        self.quitBtn.hidden = NO;
        self.keyboardBtn.hidden = NO;
    }else {
        self.bottomBgView.hidden = YES;
        self.collectionBtn.hidden = YES;
        self.quitBtn.hidden = YES;
        self.keyboardBtn.hidden = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(callUpdateEvent:) 
                                                 name:kLinphoneCallUpdate
                                               object:nil];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(autoStartVideo:) name:@"kVedioEnableNotification" object:nil];
    
    // Update on show
    LinphoneCall* call = linphone_core_get_current_call([LinphoneManager getLc]);
    LinphoneCallState state = (call != NULL)?linphone_call_get_state(call): 0;
        
    [self dataFillToPreview];

    [self callUpdate:call state:state];
    
//    [self hideRoutes:FALSE];
//    [self hideOptions:FALSE];
//    [self hidePad:FALSE];
//    [self showSpeaker];
    
    [self hideAllBottomBgView];
    
    self.bottomBgView.hidden = NO;
    self.collectionBtn.hidden = NO;
    self.quitBtn.hidden = NO;
}

//static BOOL onlyOnce = NO;
//
//- (void)autoStartVideo:(NSNotification *)notif {
//    NSLog(@"autoStartVideo called");
//    
//    if (onlyOnce == NO) {
////        [self.bmVideoButton toggle];
//        [self.bmVideoButton startVideoAfterBeActive];
//        onlyOnce = YES;
//        NSLog(@"only run one time.");
//    }
//}

- (void)hideAllBottomBgView {
    if (self.popControlView.hidden == NO) {
        // 隐藏它
        self.popControlView.alpha = 1.0;
        [UIView animateWithDuration:0.3 animations:^{
            self.popControlView.alpha = 0.0;
        } completion:^(BOOL finished) {
            NSMutableArray *subs = [NSMutableArray array];
            for (UIView *subV in self.popControlView.subviews) {
                if (subV.tag != 1000) {
                    [subs addObject:subV];
                }
            }
            
            for (UIView *eachSub in subs) {
                [eachSub removeFromSuperview];
            }
            
            self.popControlView.hidden = YES;
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kLinphoneCallUpdate
                                                  object:nil];
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:@"kVedioEnableNotification"
//                                                  object:nil];
}

#pragma mark popWithButtonMark
- (void)popWithButtons:(NSArray *)btns {
    if (self.keyBgView.hidden == NO) {
        self.keyBgView.hidden = YES;
    }
    
    // 先重置位置
    self.popControlView.frame = self.bottomBgView.frame;
    UIView *theBgView = [self.popControlView viewWithTag:1000];
    theBgView.frame = self.popControlView.bounds;
    
    self.popControlView.ott_bottom = self.bottomBgView.ott_top;
    
    self.popControlView.hidden = NO;
    self.popControlView.alpha = 1.0;
    
    // 移除上面的按钮
    for (UIView *subView in self.popControlView.subviews) {
        if ([subView isKindOfClass:[UIButton class]]) {
            [subView removeFromSuperview];
        }
    }
    
    // 添加按钮
    for (NSInteger i=0; i<btns.count; i++) {
        UIButton *btn = btns[i];
        [self.popControlView addSubview:btn];
        CGFloat eachBtnWidth = self.popControlView.ott_width/btns.count;
        btn.frame = CGRectMake(i*eachBtnWidth, 0, eachBtnWidth, self.popControlView.ott_height);
    }
}

- (IBAction)keyBtnClicked:(id)sender {
    if (self.popControlView.hidden == NO) {
        self.popControlView.hidden = YES;
    }
    
    self.keyBgView.hidden = !(self.keyBgView.hidden);
}

// 底部邀请按钮
- (IBAction)inviteBtnClicked:(id)sender {
    UIButton *mailBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    mailBtn.showsTouchWhenHighlighted = YES;
    [mailBtn addTarget:self action:@selector(sendMailBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [mailBtn setTitle:@"发邮件" forState:UIControlStateNormal];
    
    UIButton *smsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    smsBtn.showsTouchWhenHighlighted = YES;
    [smsBtn addTarget:self action:@selector(sendSMSBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [smsBtn setTitle:@"发短信" forState:UIControlStateNormal];

    UIButton *callPhoneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    callPhoneBtn.showsTouchWhenHighlighted = YES;
    [callPhoneBtn addTarget:self action:@selector(callBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [callPhoneBtn setTitle:@"呼号" forState:UIControlStateNormal];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    copyBtn.showsTouchWhenHighlighted = YES;
    [copyBtn addTarget:self action:@selector(copyAddressBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [copyBtn setTitle:@"复制地址" forState:UIControlStateNormal];
    
    [self popWithButtons:@[mailBtn, smsBtn, callPhoneBtn, copyBtn]];
}

// 底部参与人按钮
- (IBAction)joinerBtnClicked:(id)sender {
    [self hideAllBottomBgView];
    
    [RDRAllJoinersView showTableTitle:@"全部参与人员" withPostBlock:^(NSString *text) {
        [self showToastWithMessage:text];
    }];
}

// 底部更多按钮
- (IBAction)moreBtnClicked:(id)sender {
    UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    lockBtn.showsTouchWhenHighlighted = YES;
    [lockBtn addTarget:self action:@selector(lockMeetingBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [lockBtn setTitle:@"锁定会议室" forState:UIControlStateNormal];
    
    UIButton *unlockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    unlockBtn.showsTouchWhenHighlighted = YES;
    [unlockBtn addTarget:self action:@selector(unlockMeetingBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [unlockBtn setTitle:@"解锁会议室" forState:UIControlStateNormal];
    
    UIButton *startRecordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startRecordBtn.showsTouchWhenHighlighted = YES;
    [startRecordBtn addTarget:self action:@selector(startRecordClicked:) forControlEvents:UIControlEventTouchUpInside];
    [startRecordBtn setTitle:@"录播" forState:UIControlStateNormal];
    
    UIButton *stopRecordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    stopRecordBtn.showsTouchWhenHighlighted = YES;
    [stopRecordBtn addTarget:self action:@selector(stopRecordClicked:) forControlEvents:UIControlEventTouchUpInside];
    [stopRecordBtn setTitle:@"停止录播" forState:UIControlStateNormal];
    
    UIButton *layoutBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    layoutBtn.showsTouchWhenHighlighted = YES;
    [layoutBtn addTarget:self action:@selector(meetingLayoutBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [layoutBtn setTitle:@"布局设置" forState:UIControlStateNormal];
    
    UIButton *endBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    endBtn.showsTouchWhenHighlighted = YES;
    [endBtn addTarget:self action:@selector(endMeetingBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [endBtn setTitle:@"结束会议" forState:UIControlStateNormal];
    
    // 判断当前会议的状态， 是被锁定还是怎么的
    if (self.meetingLockedStatus == YES) {     // 当前是锁定状态
        if (self.meetingIsRecording == YES) {       // 正在录制
            [self popWithButtons:@[layoutBtn, unlockBtn, stopRecordBtn, endBtn]];
        }else {                                     // 没有录制
            [self popWithButtons:@[layoutBtn, unlockBtn, startRecordBtn, endBtn]];
        }
    }else {
        if (self.meetingIsRecording == YES) {       // 正在录制
            [self popWithButtons:@[layoutBtn, lockBtn, stopRecordBtn, endBtn]];
        }else {                                     // 没有录制
            [self popWithButtons:@[layoutBtn, lockBtn, startRecordBtn, endBtn]];
        }
    }
}

// 纯111111, 不是sip:111111@120.138.....
- (NSString *)curMeetingAddr {
    NSMutableString *addr = [NSMutableString stringWithString:[LPSystemUser sharedUser].curMeetingAddr];
    
    NSString *serverAddr = [LPSystemSetting sharedSetting].sipTmpProxy;
    NSString *serverTempStr = [NSString stringWithFormat:@"@%@", serverAddr];
    
    // 移掉后部
    if ([addr replaceOccurrencesOfString:serverTempStr withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [addr length])] != 0) {
        NSLog(@"remove server address done");
    }else {
        NSLog(@"remove server address failed");
    }
    
    // 移掉前面的sip:
    if ([addr replaceOccurrencesOfString:@"sip:" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [addr length])] != 0) {
        NSLog(@"remove sip done");
    }else {
        NSLog(@"remove sip failed");
    }
    
    if (addr.length == 0) {
        [self showToastWithMessage:@"会议室号码错误，请检查"];
        return @"";
    }else {
        return addr;
    }
}

// 收藏按钮
- (IBAction)collectionBtnClicked:(id)sender {
    
    if ( linphone_core_get_default_proxy_config([LinphoneManager getLc]) != NULL ) {
        // 已登录
        [self showToastWithMessage:@"已经登录， 准备收藏"];
        
//        __weak UICallBar *weakSelf = self;
        [self showToastWithMessage:@"收藏会议室中..."];

        RDRAddFavRequestModel *reqModel = [RDRAddFavRequestModel requestModel];
        reqModel.uid = [[LPSystemUser sharedUser].settingsStore stringForKey:@"userid_preference"];;
        reqModel.addr = [self curMeetingAddr];
        
        RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
        
        [RDRNetHelper GET:req responseModelClass:[RDRAddFavResponseModel class]
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                      
                      RDRAddFavResponseModel *model = responseObject;
                      
                      if ([model codeCheckSuccess] == YES) {
                          NSLog(@"收藏会议室success, model=%@", model);
                          [self showToastWithMessage:@"收藏会议室成功"];
                      }else {
                          NSLog(@"请求收藏的会议室列表服务器请求出错, msg=%@", model.msg);
                          NSString *tipStr = [NSString stringWithFormat:@"收藏会议室失败，msg=%@", model.msg];
                          [self showToastWithMessage:tipStr];
                      }
                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      [self hideHudAndIndicatorView];
                      
                      //请求出错
                      NSLog(@"收藏会议室失败, %s, error=%@", __FUNCTION__, error);
                      NSString *tipStr = [NSString stringWithFormat:@"收藏会议室失败，服务器错误"];
                      [self showToastWithMessage:tipStr];
                  }];
    }else {
        // 未登录
        [self showToastWithMessage:@"未登录，请先登录"];
    }
        
    [self hideAllBottomBgView];
}

// 退出按钮
- (IBAction)quitBtnClicked:(id)sender {
    [self quitMeeting];
}

- (void)quitMeeting {
    [self hideAllBottomBgView];
    
    self.callTipView.hidden = NO;
    self.meetingLockedStatus = NO;
    self.meetingIsRecording = NO;
    
    systemOpenCamera = NO;
    self.loadingTipImgView.hidden = YES;
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* currentcall = linphone_core_get_current_call(lc);
    if (linphone_core_is_in_conference(lc) || // In conference
        (linphone_core_get_conference_size(lc) > 0 && [UICallBar callCount:lc] == 0) // Only one conf
        ) {
        linphone_core_terminate_conference(lc);
    } else if(currentcall != NULL) { // In a call
        linphone_core_terminate_call(lc, currentcall);
    } else {
        const MSList* calls = linphone_core_get_calls(lc);
        if (ms_list_size(calls) == 1) { // Only one call
            linphone_core_terminate_call(lc,(LinphoneCall*)(calls->data));
        }
    }
}

// 发邮件
- (IBAction)sendMailBtnClicked:(id)sender {
    [self inviteMenBy:InvityTypeEmail];
    [self hideAllBottomBgView];
}
// 发短信
- (IBAction)sendSMSBtnClicked:(id)sender {
    [self inviteMenBy:InvityTypeSMS];
    [self hideAllBottomBgView];
}
// 呼号
- (IBAction)callBtnClicked:(id)sender {
    [self inviteMenBy:InvityTypePhoneCall];
    [self hideAllBottomBgView];
}

- (void)startRecordClicked:(id)sender {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"录制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self doRecordOperation:0];
    }]];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"直播" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self doRecordOperation:1];
    }]];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"录制+直播" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self doRecordOperation:2];
    }]];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alertVC animated:YES completion:nil];
    
    [self hideAllBottomBgView];
}

- (void)doRecordOperation:(NSInteger)type {
    [ShowPinView showTitle:@"请输入PIN码" withDoneBlock:^(NSString *text) {
        NSString *commandStr = nil;
        NSString *tipStr = nil;
        switch (type) {
            case 0:
                commandStr = @"record";
                tipStr = @"启动录制";
                break;
            case 1:
                commandStr = @"live";
                tipStr = @"启动直播";
                break;
            case 2:
                commandStr = @"both";
                tipStr = @"启动录制和直播";
                break;
            case 3:
                commandStr = @"stop";
                tipStr = @"停止录制或直播";
                break;
            default:
                break;
        }
        
        [self doRecordCommandWithPin:text withCommandStr:commandStr withTipStr:tipStr commandType:type];
    } withCancelBlock:^{
        
    } withNoInput:^{
        [self showToastWithMessage:@"请输入PIN码"];
    }];

}

- (void)stopRecordClicked:(id)sender {
    [self doRecordOperation:3];
}

- (void)doRecordCommandWithPin:(NSString *)pinStr withCommandStr:(NSString *)commandStr withTipStr:(NSString *)tipStr commandType:(NSInteger)type {
    __block UICallBar *weakSelf = self;
    
    [self showToastWithMessage:@"请稍等..."];
    
    RDRReocrdRequestModel *reqModel = [RDRReocrdRequestModel requestModel];
    reqModel.addr = [self curMeetingAddr];
    reqModel.action = commandStr;
    reqModel.pin = pinStr;
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRRecordResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  [weakSelf retain];
                  
                  RDRRecordResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      [weakSelf showToastWithMessage:[NSString stringWithFormat:@"%@成功", tipStr]];
                      
                      switch (type) {
                          case 0:
                              weakSelf.meetingIsRecording = YES;
                              break;
                          case 1:
                              weakSelf.meetingIsRecording = YES;
                              break;
                          case 2:
                              weakSelf.meetingIsRecording = YES;
                              break;
                          case 3:
                              weakSelf.meetingIsRecording = NO;
                              break;
                          default:
                              break;
                      }
                  }else {
                      NSString *tempTipStr = [NSString stringWithFormat:@"%@失败，msg=%@", tipStr, model.msg];
                      [weakSelf showToastWithMessage:tempTipStr];
                  }
                  [weakSelf release];
                  
              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [weakSelf retain];
                  
                  //请求出错
                  NSLog(@"失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tempTipStr = [NSString stringWithFormat:@"%@失败，服务器错误", tipStr];
                  [weakSelf showToastWithMessage:tempTipStr];
                  [weakSelf release];
              }];
}

- (void)inviteMenBy:(InvityType)type {
    // 弹出一个输入框
    [ShowInviteView showWithType:type withDoneBlock:^(NSString *text) {
        [self inviteByType:type withContent:text];
    } withCancelBlock:^{
        NSLog(@"cancel");
    } withNoInput:^{
        [self showToastWithMessage:@"数据为空"];
    }];
}

- (void)inviteByType:(InvityType)type withContent:(NSString *)content {
    __block UICallBar *weakSelf = self;
    
    [self showToastWithMessage:@"邀请中..."];
    
    RDRInviteRequestModel *reqModel = [RDRInviteRequestModel requestModel];
    reqModel.uid = [[LPSystemUser sharedUser].settingsStore stringForKey:@"userid_preference"];;
    reqModel.addr = [self curMeetingAddr];
    reqModel.type = @(type);
    reqModel.to = content;
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRInviteResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  [weakSelf retain];
                  
                  RDRInviteResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      [weakSelf showToastWithMessage:@"邀请成功"];
                  }else {
                      NSString *tipStr = [NSString stringWithFormat:@"邀请失败，msg=%@", model.msg];
                      [weakSelf showToastWithMessage:tipStr];
                  }
                  [weakSelf release];

              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [weakSelf retain];

                  //请求出错
                  NSLog(@"邀请失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tipStr = [NSString stringWithFormat:@"邀请失败，服务器错误"];
                  [weakSelf showToastWithMessage:tipStr];
                  [weakSelf release];

              }];
}

// 复制地址
- (IBAction)copyAddressBtnClicked:(id)sender {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setString:[self curMeetingAddr]];

    [self hideAllBottomBgView];
    
    [self showToastWithMessage:@"复制地址成功"];
}

// 锁定会议，或者解锁
- (IBAction)unlockMeetingBtnClicked:(id)sender {
    [self hideAllBottomBgView];
    
    [ShowPinView showTitle:@"请输入PIN码以解锁会议" withDoneBlock:^(NSString *text) {
        [self doUnlockMeetingWithPin:text];
    } withCancelBlock:^{
        
    } withNoInput:^{
        [self showToastWithMessage:@"请输入PIN码"];
    }];
}

- (void)doUnlockMeetingWithPin:(NSString *)pinStr {
    __block UICallBar *weakSelf = self;
    
    [self showToastWithMessage:@"解锁中..."];
    
    RDRLockReqeustModel *reqModel = [RDRLockReqeustModel requestModel];
    reqModel.addr = [self curMeetingAddr];
    reqModel.lock = @(0);
    reqModel.pin = pinStr;
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRLockResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  [weakSelf retain];

                  RDRLockResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      [weakSelf showToastWithMessage:@"解锁成功"];
                      weakSelf.meetingLockedStatus = NO;
                  }else {
                      NSString *tipStr = [NSString stringWithFormat:@"解锁失败，msg=%@", model.msg];
                      [weakSelf showToastWithMessage:tipStr];
                  }
                  [weakSelf release];

              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [weakSelf retain];

                  //请求出错
                  NSLog(@"解锁失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tipStr = [NSString stringWithFormat:@"解锁失败，服务器错误"];
                  [weakSelf showToastWithMessage:tipStr];
                  [weakSelf release];
              }];
}

// 锁定会议，或者解锁
- (IBAction)lockMeetingBtnClicked:(id)sender {
    [self hideAllBottomBgView];
    
    [ShowPinView showTitle:@"请输入PIN码以锁定会议" withDoneBlock:^(NSString *text) {
        [self doLockMeetingWithPin:text];
    } withCancelBlock:^{
        
    } withNoInput:^{
        [self showToastWithMessage:@"请输入PIN码"];
    }];
}

- (void)doLockMeetingWithPin:(NSString *)pinStr {
    
    [self showToastWithMessage:@"锁定中..."];
    
    __block UICallBar *weakSelf = self;

    RDRLockReqeustModel *reqModel = [RDRLockReqeustModel requestModel];
    reqModel.addr = [self curMeetingAddr];
    reqModel.lock = @(1);
    reqModel.pin = pinStr;
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRLockResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  
                  [weakSelf retain];
                  
                  RDRLockResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      [weakSelf showToastWithMessage:@"锁定成功"];
                      weakSelf.meetingLockedStatus = YES;
                  }else {
                      NSString *tipStr = [NSString stringWithFormat:@"锁定失败，msg=%@", model.msg];
                      [weakSelf showToastWithMessage:tipStr];
                  }
                  [weakSelf release];
              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [weakSelf retain];

                  //请求出错
                  NSLog(@"锁定失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tipStr = [NSString stringWithFormat:@"锁定失败，服务器错误"];
                  [weakSelf showToastWithMessage:tipStr];
                  
                  [weakSelf release];
              }];
}

// 会议布局
- (void)meetingLayoutBtnClicked:(id)sender {
    [self hideAllBottomBgView];

    [ShowMeetingLayoutView showLayoutType:self.curMeetingType
                            withDoneBlock:^(NSDictionary *settingDic) {
        
        NSDictionary *usedDic = [NSDictionary dictionaryWithDictionary:settingDic];
        NSLog(@"mutDic=%@ ,usedDic=%@", settingDic, usedDic);
        
        MeetingType usedType = self.curMeetingType;
        
        // 准备弹出pin界面进行输入密码
        [ShowPinView showTitle:@"请输入PIN码修改布局" withDoneBlock:^(NSString *text) {
            // 根据这里的设置进行操作。
            NSLog(@"ping is %@, usedDIc=%@", text, usedDic);
            
            __block UICallBar *weakSelf = self;
            [weakSelf showToastWithMessage:@"设置布局中"];
            
            RDRRequest *req = nil;
            if (usedType == MeetingTypeLesson) {
                RDRMeetingLayoutRequestModel *reqModel = [RDRMeetingLayoutRequestModel requestModel];
                reqModel.addr = [self curMeetingAddr];
                reqModel.pin = text;
                reqModel.subtitle = ((NSNumber *)(usedDic[@"zimuGround"])).integerValue;
                reqModel.layout = ((NSNumber *)(usedDic[@"zcrGround"])).integerValue;
                reqModel.layout2 = ((NSNumber *)(usedDic[@"jkGround"])).integerValue;
                
                req = [RDRRequest requestWithURLPath:nil model:reqModel];

            }else {
                RDRMeetingLayoutSubRequestModel *subModel = [RDRMeetingLayoutSubRequestModel requestModel];
                subModel.addr = [self curMeetingAddr];
                subModel.pin = text;
                subModel.subtitle = ((NSNumber *)(usedDic[@"zimuGround"])).integerValue;
                subModel.layout = ((NSNumber *)(usedDic[@"zcrGround"])).integerValue;
                
                req = [RDRRequest requestWithURLPath:nil model:subModel];
            }
            
            [RDRNetHelper GET:req responseModelClass:[RDRMeetingLayoutResponseModel class]
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          [weakSelf retain];
                          
                          RDRMeetingLayoutResponseModel *model = responseObject;
                          
                          if ([model codeCheckSuccess] == YES) {
                              [weakSelf showToastWithMessage:@"布局设置成功"];
                          }else {
                              NSString *tipStr = [NSString stringWithFormat:@"布局设置失败，msg=%@", model.msg];
                              [weakSelf showToastWithMessage:tipStr];
                          }
                          [weakSelf release];
                          
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          [weakSelf retain];
                          
                          //请求出错
                          NSLog(@"布局设置失败, %s, error=%@", __FUNCTION__, error);
                          NSString *tipStr = [NSString stringWithFormat:@"布局设置失败，服务器错误"];
                          [weakSelf showToastWithMessage:tipStr];
                          [weakSelf release];
                          
                      }];
            
        } withCancelBlock:^{
            // do nothing
        } withNoInput:^{
            [self showToastWithMessage:@"请输入PIN码"];
        }];
        
    } withCancelBlock:^{
        NSLog(@"界面被取消");
    }];
}

// 结束会议
- (void)endMeetingBtnClicked:(id)sender {
    [self hideAllBottomBgView];
    
    [ShowPinView showTitle:@"请输入PIN码以结束会议" withDoneBlock:^(NSString *text) {
        [self endMeetingByPin:text];
    } withCancelBlock:^{
        
    } withNoInput:^{
        [self showToastWithMessage:@"请输入PIN码"];
    }];
}

- (void)endMeetingByPin:(NSString *)pinStr {
    __block UICallBar *weakSelf = self;
    
    [weakSelf showToastWithMessage:@"结束会议中..."];
    
    RDRTerminalRequestModel *reqModel = [RDRTerminalRequestModel requestModel];
    reqModel.addr = [self curMeetingAddr];
    reqModel.pin = pinStr;
    
    RDRRequest *req = [RDRRequest requestWithURLPath:nil model:reqModel];
    
    [RDRNetHelper GET:req responseModelClass:[RDRTerminalResponseModel class]
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  [weakSelf retain];

                  RDRTerminalResponseModel *model = responseObject;
                  
                  if ([model codeCheckSuccess] == YES) {
                      [weakSelf showToastWithMessage:@"结束会议成功"];
                  }else {
                      NSString *tipStr = [NSString stringWithFormat:@"结束会议失败，msg=%@", model.msg];
                      [weakSelf showToastWithMessage:tipStr];
                  }
                  [weakSelf release];

              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [weakSelf retain];

                  //请求出错
                  NSLog(@"结束会议失败, %s, error=%@", __FUNCTION__, error);
                  NSString *tipStr = [NSString stringWithFormat:@"结束会议失败，服务器错误"];
                  [weakSelf showToastWithMessage:tipStr];
                  [weakSelf release];

              }];
}

+ (int)callCount:(LinphoneCore*) lc {
    int count = 0;
    const MSList* calls = linphone_core_get_calls(lc);
    
    while (calls != 0) {
        if (![UICallBar isInConference:((LinphoneCall*)calls->data)]) {
            count++;
        }
        calls = calls->next;
    }
    return count;
}

+ (bool)isInConference:(LinphoneCall*) call {
    if (!call)
        return false;
    return linphone_call_get_conference(call) != NULL;
}


// 声音按钮点击
- (IBAction)bmSoundClicked:(id)sender {
    [self hideAllBottomBgView];
    
    // 然后执行不同的操作
    if (linphone_core_mic_enabled([LinphoneManager getLc]) == YES) {
        // 当前静音，点击后，则取消静音
        linphone_core_enable_mic([LinphoneManager getLc], false);
        
        [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_enable"] forState:UIControlStateNormal];
        [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_disable"] forState:UIControlStateDisabled];
    }else {
        // 当前没有静音， 点击后，则进行静音
        linphone_core_enable_mic([LinphoneManager getLc], true);
        
        [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_disable"] forState:UIControlStateNormal];
        [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_enable"] forState:UIControlStateDisabled];
    }
}

// 底部视频按钮
- (IBAction)vedioBtnClicked:(id)sender {
    [self hideAllBottomBgView];

    // 点击都弹出选择界面
    UIButton *frontTailBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    frontTailBtn.showsTouchWhenHighlighted = YES;
    [frontTailBtn addTarget:self action:@selector(bmChangeFrontAndTail:) forControlEvents:UIControlEventTouchUpInside];
    [frontTailBtn setTitle:@"前置/后置摄像头" forState:UIControlStateNormal];
    
    UIButton *closeCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeCameraBtn.showsTouchWhenHighlighted = YES;
    [closeCameraBtn addTarget:self action:@selector(closeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [closeCameraBtn setTitle:@"关闭摄像头" forState:UIControlStateNormal];

    UIButton *openCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    openCameraBtn.showsTouchWhenHighlighted = YES;
    [openCameraBtn addTarget:self action:@selector(openCamera:) forControlEvents:UIControlEventTouchUpInside];
    [openCameraBtn setTitle:@"打开摄像头" forState:UIControlStateNormal];
    
    LinphoneCall* currentCall = linphone_core_get_current_call([LinphoneManager getLc]);
    bool video_enabled = linphone_call_params_video_enabled(linphone_call_get_current_params(currentCall));
    
//    if( linphone_core_video_enabled([LinphoneManager getLc])
//       && currentCall
//       && !linphone_call_media_in_progress(currentCall)
//       && linphone_call_get_state(currentCall) == LinphoneCallStreamsRunning) {
//        video_enabled = TRUE;
//    }

    if (video_enabled == YES) {
        // 当前在会议中
        [self popWithButtons:@[frontTailBtn, closeCameraBtn]];
    }else {
        // 当前不在会议中
        [self popWithButtons:@[frontTailBtn, openCameraBtn]];
    }
}

// 点击切换前后摄像头
- (void)bmChangeFrontAndTail:(UIButton *)sender {
    [self hideAllBottomBgView];
    
    const char *currentCamId = (char*)linphone_core_get_video_device([LinphoneManager getLc]);
    const char **cameras=linphone_core_get_video_devices([LinphoneManager getLc]);
    const char *newCamId=NULL;
    int i;
    
    for (i=0;cameras[i]!=NULL;++i){
        if (strcmp(cameras[i],"StaticImage: Static picture")==0) continue;
        if (strcmp(cameras[i],currentCamId)!=0){
            newCamId=cameras[i];
            break;
        }
    }
    if (newCamId){
        LOGI(@"Switching from [%s] to [%s]", currentCamId, newCamId);
        linphone_core_set_video_device([LinphoneManager getLc], newCamId);
        LinphoneCall *call = linphone_core_get_current_call([LinphoneManager getLc]);
        if(call != NULL) {
            linphone_core_update_call([LinphoneManager getLc], call, NULL);
        }
    }
}

// 关闭摄像头
- (void)closeCamera:(UIButton *)sender {
    [self hideAllBottomBgView];
    
    LinphoneCore* lc = [LinphoneManager getLc];
    
    if (!linphone_core_video_enabled(lc))
        return;
    
    LinphoneCall* call = linphone_core_get_current_call([LinphoneManager getLc]);
    if (call) {
        LinphoneCallParams* call_params =  linphone_call_params_copy(linphone_call_get_current_params(call));
        linphone_call_params_enable_video(call_params, FALSE);
        linphone_core_update_call(lc, call, call_params);
        linphone_call_params_destroy(call_params);
        
        [UIView animateWithDuration:0.3 animations:^{
            self.loadingTipImgView.hidden = NO;
        }];

    } else {
        LOGW(@"Cannot close video button, because no current call");
    }
}

// 打开
- (void)openCamera:(UIButton *)sender {
    [self hideAllBottomBgView];
    LinphoneCore* lc = [LinphoneManager getLc];
    
    if (!linphone_core_video_enabled(lc)) {
//        linphone_core_enable_video(lc, true, true);
        
        linphone_core_enable_video_capture(lc, true);
        linphone_core_enable_video_display(lc, true);
    }
    
    LinphoneCall* call = linphone_core_get_current_call([LinphoneManager getLc]);
    if (call) {
        LinphoneCallAppData* callAppData = (LinphoneCallAppData*)linphone_call_get_user_pointer(call);
        callAppData->videoRequested=TRUE; /* will be used later to notify user if video was not activated because of the linphone core*/

        LinphoneCallParams* call_params =  linphone_call_params_copy(linphone_call_get_current_params(call));
        linphone_call_params_enable_video(call_params, TRUE);
        linphone_core_update_call(lc, call, call_params);
        linphone_call_params_destroy(call_params);
        
        [UIView animateWithDuration:0.3 animations:^{
            self.loadingTipImgView.hidden = YES;
        }];
    } else {
        LOGW(@"Cannot open video button, because no current call");
    }
}

#pragma mark - Event Functions

- (void)callUpdateEvent:(NSNotification*)notif {
    LinphoneCall *call = [[notif.userInfo objectForKey: @"call"] pointerValue];
    LinphoneCallState state = [[notif.userInfo objectForKey: @"state"] intValue];
    [self callUpdate:call state:state];
}

#pragma mark - 

static BOOL systemOpenCamera = NO;

- (void)updateVideoBtn {
    if (systemOpenCamera == NO) {
        LinphoneCall* currentCall = linphone_core_get_current_call([LinphoneManager getLc]);
        if( linphone_core_video_enabled([LinphoneManager getLc])
           && currentCall
           && !linphone_call_media_in_progress(currentCall)
           && linphone_call_get_state(currentCall) == LinphoneCallStreamsRunning) {
            
            systemOpenCamera = YES;
            // 打开摄像头
            NSLog(@"____________________start camera");
            [self openCamera:nil];
        }
    }
}

- (void)callUpdate:(LinphoneCall*)call state:(LinphoneCallState)state {
    NSLog(@"callUpdate state =%d", state);
    
    if (state == LinphoneCallOutgoingRinging || state == LinphoneCallStreamsRunning) {
        // 连接建立好了，可以进入
        self.callTipView.hidden = YES;
        
        // 设置当前的静音操作
        if ([LPSystemSetting sharedSetting].defaultSilence == YES) {
            // 要求静音
            linphone_core_enable_mic([LinphoneManager getLc], true);
            
            [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_disable"] forState:UIControlStateNormal];
            [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_enable"] forState:UIControlStateDisabled];
        }else {
            // 要求不静音
            linphone_core_enable_mic([LinphoneManager getLc], false);
            
            [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_enable"] forState:UIControlStateNormal];
            [self.bmMicroButton setImage:[UIImage imageNamed:@"m_mic_disable"] forState:UIControlStateDisabled];
        }
    }
    
    [self updateVideoBtn];
    
//    [self.bmMicroButton update];
//    [self.bmVideoButton update];
    
    switch(state) {
        case LinphoneCallEnd:
        case LinphoneCallError:
        case LinphoneCallIncoming:
        case LinphoneCallOutgoing:
//            [self hidePad:TRUE];
//            [self hideOptions:TRUE];
//            [self hideRoutes:TRUE];
        default:
            break;
    }
}

#pragma mark -

- (void)showAnimation:(NSString*)animationID target:(UIView*)target completion:(void (^)(BOOL finished))completion {
    CGRect frame = [target frame];
    int original_y = frame.origin.y;
    frame.origin.y = [[self view] frame].size.height;
    [target setFrame:frame];
    [target setHidden:FALSE];
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         CGRect frame = [target frame];
                         frame.origin.y = original_y;
                         [target setFrame:frame];
                     }
                     completion:^(BOOL finished){
                         CGRect frame = [target frame];
                         frame.origin.y = original_y;
                         [target setFrame:frame];
                         completion(finished);
                     }];
}

- (void)hideAnimation:(NSString*)animationID target:(UIView*)target completion:(void (^)(BOOL finished))completion {
    CGRect frame = [target frame];
    int original_y = frame.origin.y;
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         CGRect frame = [target frame];
                         frame.origin.y = [[self view] frame].size.height;
                         [target setFrame:frame];
                     }
                     completion:^(BOOL finished){
                         CGRect frame = [target frame];
                         frame.origin.y = original_y;
                         [target setHidden:TRUE];
                         [target setFrame:frame];
                         completion(finished);
                     }];
}

#pragma mark - Action Functions
#pragma mark - TPMultiLayoutViewController Functions

- (NSDictionary*)attributesForView:(UIView*)view {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    [attributes setObject:[NSValue valueWithCGRect:view.frame] forKey:@"frame"];
    [attributes setObject:[NSValue valueWithCGRect:view.bounds] forKey:@"bounds"];
//    if([view isKindOfClass:[UIButton class]]) {
//        UIButton *button = (UIButton *)view;    
//		[LinphoneUtils buttonMultiViewAddAttributes:attributes button:button];
//	} else if (view.tag ==self.leftPadding.tag ||
//               view.tag == self.rightPadding.tag) {
//        if ([view isKindOfClass:[UIImageView class]]) {
//            UIImage* image = [(UIImageView*)view image];
//            if( image ){
//                [attributes setObject:image forKey:@"image"];
//            }
//        }
//    }
    [attributes setObject:[NSNumber numberWithInteger:view.autoresizingMask] forKey:@"autoresizingMask"];

    return attributes;
}

- (void)applyAttributes:(NSDictionary*)attributes toView:(UIView*)view {
    view.frame = [[attributes objectForKey:@"frame"] CGRectValue];
    view.bounds = [[attributes objectForKey:@"bounds"] CGRectValue];
//    if([view isKindOfClass:[UIButton class]]) {
//        UIButton *button = (UIButton *)view;
//        [LinphoneUtils buttonMultiViewApplyAttributes:attributes button:button];
//    } else if (view.tag ==self.leftPadding.tag ||
//               view.tag == self.rightPadding.tag){
//        if ([view isKindOfClass:[UIImageView class]]) {
//            [(UIImageView*)view setImage:[attributes objectForKey:@"image"]];
//        }
//    }
    view.autoresizingMask = [[attributes objectForKey:@"autoresizingMask"] integerValue];
}

@end
