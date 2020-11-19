//
//  HDBaseWKWebViewController.m
//  yanxishe
//
//  Created by 王健鹏 on 2017/6/8.
//  Copyright © 2017年 hundun. All rights reserved.
//

#import "HDBaseWKWebViewController.h"
#import "HDMainPlayLiveController.h"

#import "HDShareInfoResultModel.h"

#import "HDShareView.h"

#import <Photos/Photos.h>

#import "HDEmptyDataSetModel.h"

#import "WKWebView+TYSnapshot.h"
#import "NSString+YYAdd.h"
#import "HDAppSuspendingLayerBindPhonePopView.h"

///2.16.2 新增
#import "HDWanghongLiveNetworkTools.h"

///2.22.0新增
#import "HDRichEditorViewController.h"
#import "HDPracticePreviewController.h"
///2.23.0新增
#import "HDVideoEditorViewController.h"
///4.1.0
#import "HDVoiceReviewView.h"

#import "HDBaseWKWebViewPool.h"

typedef NS_ENUM(NSUInteger, WKWebShareType) {
    //直接分享到微信
    WKWebShareTypeWeiXin,
    //直接分享到朋友圈
    WKWebShareTypeCircle,
    //直接分享到小程序
    WKWebShareTypeMin,
    //弹出分享窗
    WKWebShareTypePopup,
};


@interface HDBaseWKWebRrightMenuModel : NSObject
@property (nonatomic, copy) NSString *menuTitle;
@property (nonatomic, copy) NSString *webUrl;
@property (nonatomic, copy) NSString *pageUrl;
@end

@implementation HDBaseWKWebRrightMenuModel
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{
        @"menuTitle" : @"menuTitle",
        @"webUrl" : @"webUrl",
        @"pageUrl" : @"pageUrl",
    };
}
@end



@interface HDBaseWkWebShareModel : HDBaseResultModel
@property (nonatomic,copy)NSString *url;
@property (nonatomic,copy)NSString *content;
@property (nonatomic,copy)NSString *thumbnail;
@property (nonatomic,copy)NSString *title;
/** h5透传分享id */
@property (nonatomic, copy) NSString *shareActionId;
/** 分享渠道 */
@property (nonatomic, copy) NSString *media;
/** 小程序路径 */
@property (nonatomic, copy) NSString *path;
/** 小程序userName */
@property (nonatomic, copy) NSString *userName;
/** 图片base64 */
@property (nonatomic, copy) NSString *imgBase64;
/** h5回调方法 */
@property (nonatomic, copy) NSString *callback;
@end

@implementation HDBaseWkWebShareModel
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{@"errorNumber" : @"error_no",
             @"errorMsg" : @"error_msg",
             @"url" : @"url",
             @"content" : @"content",
             @"thumbnail" : @[@"thumbUrl",@"thumbnail"],
             @"title" : @"title",
             @"media" : @"media",
             @"path" : @"path",
             @"userName" : @"userName",
             @"imgBase64" : @"imgBase64",
             @"callback" : @"callback",
    };
}
@end




@interface HDBaseWKWebViewController ()<UIGestureRecognizerDelegate,HDEmptyDataSetModelDelegate>
/** 关闭按钮 */
@property (nonatomic, strong) UIButton *closeButton;
/** 容器视图，存在的意义是截屏*/
@property (nonatomic, strong) UIView *webContainerView;
/** WKWebView */
@property (nonatomic, strong, readwrite) WKWebView *webView;
/** 公共方法数组 */
@property (nonatomic, strong) NSMutableArray *publicMethodArray;
/** 内部拼接参数字典 */
@property (nonatomic, strong) NSMutableDictionary *insideParas;
/** 空页面数据 */
@property (nonatomic, strong) HDEmptyDataSetModel *emptyDataSetModel;
/** dns是否解析成功标志 */
@property (nonatomic, assign) BOOL isDNS;
/** dns解析后ip地址 */
@property (nonatomic, strong) NSString *ip;
/** 保存图片的回调，调js方法 */
@property (nonatomic, strong) NSDictionary *saveImageCallBack;

@property (nonatomic, strong) HDBaseWKWebRrightMenuModel *rightMenuModel;

@property (nonatomic, strong) UIButton *rightButton;

@property (nonatomic, assign) NSInteger isHideNavBar;

//*********----------埋点数据----------------**//
///记录开始时间戳
@property (nonatomic, assign) NSTimeInterval decidePolicyDate;
///记录开始加载时间戳
@property (nonatomic, assign) NSTimeInterval didStartDate;
///记录开始获取时间戳
@property (nonatomic, assign) NSTimeInterval didCommitDate;

///记录开始获取时间戳
@property (nonatomic, strong) UIProgressView *progressView;

///记录开始获取时间戳
@property (nonatomic, strong) UILabel *loadTimeLabel;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, assign) CGFloat lastTimer;

@end

@implementation HDBaseWKWebViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        ///默认外部直接传入url然后加载地址。 但是通过请求得到的地址 调用loadRequestWithWebUrl 方法的请设置为NO
        self.autoLoadRequest = YES;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.appChannel = @"";
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.insideParas = [NSMutableDictionary dictionaryWithObjectsAndKeys:STRING_NIL([HDAccountTool account].phone),@"phone", nil];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.isHideNavBar == 1) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    } else if (self.isHideNavBar == 0) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
    [self nativeControlJSWithScript:@"window.onPageBack && window.onPageBack()" andcompletionHandler:^(id response, NSError *error) {
        
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    ///移除前项的练习编辑页
    
    NSInteger index = [self.navigationController.viewControllers indexOfObject:self];
    if (index != NSNotFound && index - 1 > 0) {
        NSMutableArray *controllers = [self.navigationController.viewControllers mutableCopy];
        id obj = [self.navigationController.viewControllers objectAtIndex:index - 1];
        if ([obj isKindOfClass:[HDRichEditorViewController class]] || [obj isKindOfClass:[HDVideoEditorViewController class]]) {
            [controllers removeObject:obj];
            [self.navigationController setViewControllers:controllers animated:NO];
        }else if ([obj isKindOfClass:[HDPracticePreviewController class]]) {
            [controllers removeObject:obj];
            if (index - 2 > 0) {
                id upObj = [self.navigationController.viewControllers objectAtIndex:index - 2];
                if ([upObj isKindOfClass:[HDRichEditorViewController class]] || [upObj  isKindOfClass:[HDVideoEditorViewController class]]) {
                    [controllers removeObject:upObj];
                }
            }
            [self.navigationController setViewControllers:controllers animated:NO];
        }
    }
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self limitInit];
    
    //自定义导航栏
    [self customNavi];
    
    //自定义控件
    [self customSubViews];
}


#pragma mark - 初始化
- (void)limitInit {
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationController.interactivePopGestureRecognizer.delegate = (id)self;
    
    //如果是
    if (self.navigationController.viewControllers.count > 1) {
        UIViewController *vc = self.navigationController.viewControllers[self.navigationController.viewControllers.count - 2];
        NSString *pageId = NSStringFromClass([vc class]);
        [self.insideParas setObject:STRING_NIL(pageId) forKey:@"pageId"];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeHidden:) name:UIWindowDidBecomeHiddenNotification object:nil];
    
    //初始化公共方法数组 v2.15.0添加【getAppVersion cleanCache refreshWeb updateLog】
    self.publicMethodArray = [NSMutableArray arrayWithObjects:@"closeWebsite",@"shareWX",@"ugcShareWX",@"payHDCommon",@"openPayGuide",@"completeRecive",@"saveImage",@"noticeAppBindPhone",@"closePage",@"showRightMenu",@"getAppVersion",@"cleanCache",@"refreshWeb",@"updateLog",@"getAppAudioCaptureAccess",@"getAppBaseInfo", @"openBounces", nil];
    self.publicMethodArray = [NSMutableArray arrayWithObjects:@"closeWebsite",@"shareWX",@"ugcShareWX",@"payHDCommon",@"openPayGuide",@"completeRecive",@"saveImage",@"noticeAppBindPhone",@"closePage",@"showRightMenu",@"getAppVersion",@"cleanCache",@"refreshWeb",@"updateLog",@"getAppAudioCaptureAccess", @"getAppVideoCaptureAccess", @"getAppBaseInfo", @"sessionInvalid",@"openBounces",@"openVoiceComment", nil];
}

#pragma mark - 自定义导航栏
- (void)customNavi {
    if (self.denyNav) {
        return;
    }
    //导航栏title
    self.navigationItem.title = self.titleString;
    
    //关闭按钮
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(0, 0, 40, 40);
    [self.closeButton addTarget:self action:@selector(naviColoseButton_MovieTitle:) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.closeButton.titleLabel.font = HDDefaultFont(17);
    self.closeButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:HDColorTitle forState:UIControlStateNormal];
    
    //判断是否显示关闭回退按钮
    [self changeNaviBackItemsWithBool:[self.webView canGoBack]];
    
    self.rightButton.hidden = YES;
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:self.rightButton];
    self.navigationItem.rightBarButtonItem = item;
}

#pragma mark 判断是否显示关闭回退按钮
- (void)changeNaviBackItemsWithBool:(BOOL)cangoBack {
    if (self.denyNav) {
        return;
    }
    
    UIBarButtonItem * backItem = [UIBarButtonItem hd_itemBackBlackWithTarget:self action:@selector(navBackButton_MovieTitle:)];
    
    UIBarButtonItem * closeItem = [[UIBarButtonItem alloc]initWithCustomView:self.closeButton];
    
    NSArray * array;
    
    if (cangoBack) {
        
        array = @[backItem,closeItem];
        
        /// 检查是不是最顶层，不然在下面的时候会把东西取消掉
        /// 设置forbinRightReturn值，也可以做到在其他页面进来时也拦截左滑功能
        if (self.navigationController.viewControllers.lastObject == self) {
            [self forbiddenSideBack];
        }
        self.forbinRightReturn = YES;
        
    } else {
        
        array = @[backItem];
        
        if (self.navigationController.viewControllers.lastObject == self) {
            [self resetSideBack];
        }
        self.forbinRightReturn = NO;
    }
    
    self.navigationItem.leftBarButtonItems = array;
}

#pragma mark 导航关闭按钮事件
- (void)naviColoseButton_MovieTitle:(UIButton *)button {
    
    if (self.popViewDismissBlock) {
        self.popViewDismissBlock();
        return;
    }
    
    //如果当前栈中,还有其他视图,则返回上一个视图,即使跟视图是present出来的.
    if (self.navigationController.viewControllers.count > 1) {
        if (self.navigationController.viewControllers.lastObject == self) {
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            NSMutableArray *viewControllers = self.navigationController.viewControllers.mutableCopy;
            [viewControllers removeObject:self];
            self.navigationController.viewControllers = viewControllers.copy;
            [self removeFromParentViewController];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - 测滑返回调用的方法
///< 在添加或移除view controller之前被调用 左滑动也会调用的方法  pop  nil为删除
- (void)didMoveToParentViewController:(UIViewController*)parent {
    [super didMoveToParentViewController:parent];
    if (!parent) {
        //清空WKWebView的JS调用标识
        for (NSString *scriptName in self.scriptNames) {
            [self.webView.configuration.userContentController removeScriptMessageHandlerForName:scriptName];
        }
        
        for (NSString *scriptName in self.publicMethodArray) {
            [self.webView.configuration.userContentController removeScriptMessageHandlerForName:scriptName];
        }
    }
}

#pragma mark 导航回退按钮事件
- (void)navBackButton_MovieTitle:(UIButton *)button {
    
    NSString *str = self.webView.backForwardList.backItem.URL.absoluteString;
    if ([self.webView canGoBack] && ![str isEqualToString:@"about:blank"]) {
        [self.webView goBack];
    } else {
        
        //清空WKWebView的JS调用标识
        for (NSString *scriptName in self.scriptNames) {
            
            [self.webView.configuration.userContentController removeScriptMessageHandlerForName:scriptName];
        }
        
        for (NSString *scriptName in self.publicMethodArray) {
            [self.webView.configuration.userContentController removeScriptMessageHandlerForName:scriptName];
        }
        
        //如果当前栈中,还有其他视图,则返回上一个视图,即使跟视图是present出来的.
        if (self.navigationController.viewControllers.count > 1) {
            
            [self.navigationController popViewControllerAnimated:YES];
            
        } else {
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark 监听web视频导航栏隐藏问题
-(void)windowDidBecomeHidden:(NSNotification *)noti{
    
    UIWindow * win = (UIWindow *)noti.object;
    
    if(win){
        
        UIViewController *rootVC = win.rootViewController;
        
        NSArray<__kindof UIViewController *> *vcs = rootVC.childViewControllers;
        
        if([vcs.firstObject isKindOfClass:NSClassFromString(@"AVPlayerViewController")]){
            
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
            
            ///调起视频播放，全屏变收起时
            [self.webView evaluateJavaScript:@"playVideo()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                
            }];
        }
    }
}

#pragma mark - 创建子控件
- (void)customSubViews {
    
    ///仅在创建时候处理
    NSMutableDictionary *parameter = [self.webUrl hd_dictionaryFromUrlParams];
    self.isHideNavBar = [parameter[@"hide_nbar"] integerValue];
    
    self.isDNS = NO;
    self.ip = @"";
    
    self.webView = [[HDBaseWKWebViewPool managerPool] getWKWebView];
    NSArray *selectTure = [self.scriptNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF in %@", self.publicMethodArray]];
    if (selectTure.count) {
#if DEBUG
        //写测试阶段的代码
        [MBProgressHUD showErrorWithMessage:[NSString stringWithFormat:@"与公共方法重复%@",selectTure.yy_modelDescription]];
#else
        //写发布之后的代码
#endif
    }
    
    //注册JS回调OC事件(默认)
    for (NSString *scriptName in self.publicMethodArray) {
        
        //保护判断
        if (![scriptName isKindOfClass:[NSString class]]) continue;
        
        if ([scriptName isEqualToString:@""]) continue;
        
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:scriptName];
    }
    
    //注册JS回调OC事件(外部)
    for (NSString *scriptName in self.scriptNames) {
        
        //保护判断
        if (![scriptName isKindOfClass:[NSString class]]) continue;
        
        if ([scriptName isEqualToString:@""]) continue;
        
        if ([self.publicMethodArray containsObject:scriptName]) continue;
        
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:scriptName];
    }
    
    [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];

    self.webView.scrollView.backgroundColor = [UIColor whiteColor];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.hidden = YES;

    ///4.1.0为适应截图截取webview的父视图的方法
    ///self.view上面可能还有其他的东西，所以添加一层容器视图用于截图
    [self.view addSubview:self.webContainerView];
    [self.webContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.webContainerView addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    self.emptyDataSetModel = [HDEmptyDataSetModel new];
    self.emptyDataSetModel.shouldClick = YES;
    self.emptyDataSetModel.shouldDisplay = NO;
    self.emptyDataSetModel.delegate = self;
    self.emptyDataSetModel.view.hidden = YES;
    self.webView.scrollView.emptyDataSetSource = self.emptyDataSetModel;
    self.webView.scrollView.emptyDataSetDelegate = self.emptyDataSetModel;
    
    ///< 如果隐藏导航栏的话。默认关闭边界回弹
    if (self.isHideNavBar) self.webView.scrollView.bounces = NO;
    
    /// 最后创建加载菊花
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.loadingView];
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.mas_topLayoutGuide).offset(100);
    }];
    
    ///这个地方略有不同，需要先创建数据，填充好后，然后在加载链接的时候对链接做判断
    ///webView上去之后自动就有空占位
    if (self.autoLoadRequest) {
        [self loadRequestWithWebUrl:self.webUrl];
    }
    
    if (@available(iOS 11.0, *)) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    
    [self.view addSubview:self.progressView];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.view);
        make.height.equalTo(@5);
    }];
    
    self.loadTimeLabel = [UILabel hd_labelWithFont:HDDefaultFont(10) color:HDColor.black_40];
    [self.view addSubview:self.loadTimeLabel];
    [self.loadTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.equalTo(self.view);
        make.height.equalTo(@20);
        make.width.equalTo(@50);
    }];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(calculateQuotaTime) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    self.lastTimer = CFAbsoluteTimeGetCurrent();
    self.loadTimeLabel.text = @"0";
}

- (void)calculateQuotaTime {
    CGFloat time = CFAbsoluteTimeGetCurrent() - self.lastTimer;
    self.loadTimeLabel.text = [NSString stringWithFormat:@"%.3f",time];
}

///< 调用给子类使用
- (void)loadingViewStartAnimating {
    [self.loadingView startAnimating];
}

- (void)loadRequestWithWebUrl:(NSString *)webUrl {
    
    HDLog(@"webUrl == %@", webUrl);
    
    webUrl = [webUrl stringByReplacingOccurrencesOfString:@"https" withString:@"customscheme"];
    
    [self.loadingView startAnimating];
    
    ///去掉前后空格回车
    webUrl = [webUrl stringByTrim];
    
    if (!webUrl.length) {
        [MBProgressHUD showErrorWithMessage:@"出错啦"];
        [self showEmptyDataView:YES];
        return;
    }
    
    ///< 解析H5携带的参数
    NSURL *h5Url = [NSURL URLWithString:webUrl];
    if (!h5Url) {
        [self showEmptyDataView:YES];
        [MBProgressHUD showErrorWithMessage:@"地址不合法"];
        return;
    }
    if (self.useOriginUrl) {
        self.webUrl = webUrl;
        NSURL *url = [NSURL URLWithString:webUrl];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    } else {
        //内部参数拼接外部参数,形成整体参数
        [self.insideParas addEntriesFromDictionary:self.params];
        
        //拼接的URL网址(拼接公共参数)
        NSString *webString = [HDSingleMethodTool combineCommonParasWithUrlString:webUrl paras:self.insideParas];
        NSMutableCharacterSet *mutCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [mutCharacterSet addCharactersInString:@"#"];
        [mutCharacterSet addCharactersInString:@"%"];
        webString = [webString stringByAddingPercentEncodingWithAllowedCharacters:mutCharacterSet];
        
        HDLog(@"拼接之后的地址: %@",webString);
        
        self.webUrl = webString;
        NSURL *url = [NSURL URLWithString:webString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    }
}


#pragma mark - 设置webView内边距
- (void)setContentInset:(UIEdgeInsets)contentInset {
    _contentInset = contentInset;
    [self.webView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view).with.insets(contentInset);
    }];
}

#pragma mark 标题Title的监听
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    //加载进度值
    if ([keyPath isEqualToString:@"title"]) {
        self.navigationItem.title = self.webView.title;
        [self changeNaviBackItemsWithBool:[self.webView canGoBack]];
    }
    
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
    }
}

#pragma mark - WKNavigationDelegate --- 网页生命流程和跳转流程拦截
/**
 *  页面开始加载时调用
 *
 *  @param webView    实现该代理的webview
 *  @param navigation 当前navigation
 */
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.didStartDate = [[NSDate date] timeIntervalSince1970];
    HDLog(@"页面开始加载耗时：%f", self.didStartDate - self.decidePolicyDate);
}

/**
 *  当内容开始返回时调用
 *
 *  @param webView    实现该代理的webview
 *  @param navigation 当前navigation
 */
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    self.didCommitDate = [[NSDate date] timeIntervalSince1970];
    HDLog(@"页面内容开始返回耗时：%f", self.didCommitDate - self.decidePolicyDate);
}

/**
 *  页面加载完成之后调用
 *
 *  @param webView    实现该代理的webview
 *  @param navigation 当前navigation
 */
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    [self.loadingView stopAnimating];
    
    HDLog(@"页面加载完成耗时：%f  absoluteString：%@  self.webUrl：%@", [[NSDate date] timeIntervalSince1970] - self.decidePolicyDate,self.webView.URL.absoluteString,self.webUrl);
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    if (currentTime - self.decidePolicyDate > 10) {
        NSDictionary *properties = @{
            @"从开始到加载完成耗时":@(currentTime-self.decidePolicyDate),
            @"从开始到开始加载耗时":@(self.didStartDate-self.decidePolicyDate),
            @"从开始到完成加载耗时":@(self.didStartDate-self.decidePolicyDate),
            @"web_url" : self.currentWebUrl,
            @"is_pop" : @(self.isPop?1:0),
            @"pop_name":STRING_NIL(self.popName)
        };
        [[HDUserActionTools shareUserActionTools] reportErrorLogWithErrorId:HDReportErrorTypeH5Delay properties:properties];
    }
    
    [self showEmptyDataView:NO];
    
    [self.timer invalidate];
}

- (void)showEmptyDataView:(BOOL)show {
    self.webView.hidden = NO;
    [self.loadingView stopAnimating];
    if (show) {
        self.emptyDataSetModel.view.hidden = NO;
        self.emptyDataSetModel.shouldDisplay = YES;
        self.emptyDataSetModel.type = HDEmptyDataSetTypeNoNetwork;
        self.emptyDataSetModel.view.buttonTitle = @"点击刷新";
        if (self.navigationController.viewControllers.count > 1) {
            self.emptyDataSetModel.view.returnTitle = @"返回";
        }
        [self.webView.scrollView reloadEmptyDataSet];
    } else {
        self.emptyDataSetModel.shouldDisplay = NO;
        [self.webView.scrollView reloadEmptyDataSet];
        self.emptyDataSetModel = nil;
    }
}

///< 重新加载
- (void)emptyDataSetViewClickAction {
    ///此处待存疑，用webUrl还是currentWebUrl
    [self loadRequestWithWebUrl:self.webUrl];
}

- (void)emptyDataSetViewClickRetuen {
    [self navBackButton_MovieTitle:nil];
}

/**
 *  加载失败时调用
 *
 *  @param webView    实现该代理的webview
 *  @param navigation 当前navigation
 *  @param error      错误
 */
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
    HDLog(@"加载失败时调用 didFailProvisionalNavigation   %@   %@",error.domain,error.description);

    NSInteger code = [error code];
    /// 1.点击回退的时候，会报这个错误，但是页面加载是成功的  2.重新加载一个新的网络请求的时候
    if (code != NSURLErrorCancelled) {
        [self showEmptyDataView:YES];
        
        [HDUserActionTools reportDataWithActionName:@"日志系统-web加载错误" actionCode:error.code Category:HDLogSystemWebLoadError Properties:error.userInfo];
        
        // 错误预警
        NSDictionary *properties = @{
            @"error_code" : @(error.code),
            @"web_url" : self.currentWebUrl,
            @"is_pop" : @(self.isPop?1:0),
            @"pop_name":STRING_NIL(self.popName),
            @"从开始到加载失败耗时":@([NSDate date].timeIntervalSince1970-self.decidePolicyDate),
        };
        [[HDUserActionTools shareUserActionTools] reportErrorLogWithErrorId:HDReportErrorTypeH5Error properties:properties];
    }
}

/**
 *  当main frame最后下载数据失败时，会回调
 *
 *  @param webView    实现该代理的webview
 *  @param navigation 当前navigation
 *  @param error      错误
 */
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    
    HDLog(@"加载失败时调用  didFailNavigation   %@   %@",error.domain,error.description);
    
    [HDUserActionTools reportDataWithActionName:@"日志系统-web加载错误" actionCode:error.code Category:HDLogSystemWebLoadError Properties:error.userInfo];
    
    // 错误预警
    NSDictionary *properties = @{
        @"error_code" : @(error.code),
        @"web_url" : self.currentWebUrl,
        @"is_pop" : @(self.isPop?1:0),
        @"pop_name":STRING_NIL(self.popName),
        @"从开始到加载失败耗时":@([NSDate date].timeIntervalSince1970-self.decidePolicyDate),
    };
    [[HDUserActionTools shareUserActionTools] reportErrorLogWithErrorId:HDReportErrorTypeH5Error properties:properties];
}

//强制信任 https无效证书
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler{
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        NSURLCredential *card = [[NSURLCredential alloc]initWithTrust:challenge.protectionSpace.serverTrust];
        
        completionHandler(NSURLSessionAuthChallengeUseCredential,card);
        
    }
}

#pragma mark - WKScriptMessageHandler 交互方法
#pragma mark JS回调OC拦截
//当拦截到JS调用OC的时候
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    HDLog(@"JS调用了OC的%@方法。 %@",message.name,[NSThread currentThread]);
    
    NSDictionary * data = message.body;
    
    if ([message.name isEqualToString:@"closeWebsite"]) {
        //关闭WebView页面
        [self naviColoseButton_MovieTitle:self.closeButton];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kCourseListRefresh" object:nil];//2.6.0入学调研迁移过来
        
    }else if ([message.name isEqualToString:@"shareWX"]) {
        
        if (!data.allKeys.count) {
            
            return;
        }
        
        //微信分享
        HDBaseWkWebShareModel *model = [HDBaseWkWebShareModel yy_modelWithJSON:data];
        
        WKWebShareType shareType = WKWebShareTypePopup;
        if ([model.media isEqualToString:@"weixin"]) {
            shareType = WKWebShareTypeWeiXin;
        } else if ([model.media isEqualToString:@"circle"]) {
            shareType = WKWebShareTypeCircle;
        } else if ([model.media isEqualToString:@"min"]) {
            shareType = WKWebShareTypeMin;
        }
        
        HDShareInfoResultModel * shareModel = [HDShareInfoResultModel new];
        
        shareModel.url = model.url;
        shareModel.content = model.content;
        shareModel.title = model.title;
        shareModel.thumbnail = model.thumbnail;
        shareModel.shareId = model.shareActionId;
        shareModel.imgBase64 = model.imgBase64;
        
        HDWXSmallCardModel *cardModel = [[HDWXSmallCardModel alloc] init];
        cardModel.path = model.path;
        cardModel.userName = model.userName;
        shareModel.WXSmallCardModel = cardModel;
        
        if (shareModel.imgBase64.length) {
            [self shareWebWithShareModel:shareModel andImage:nil shareType:shareType callback:model.callback];
            return;
        }
        
        NSString *imageUrl = (shareModel.title.length?shareModel.thumbnail:shareModel.url);
        
        [[YYWebImageManager sharedManager] requestImageWithURL:URL(imageUrl) options:0 progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self shareWebWithShareModel:shareModel andImage:image shareType:shareType callback:model.callback];
            });
        }];
        
    } else if ([message.name isEqualToString:@"ugcShareWX"]) {
        
        NSInteger ssliveId = [[data valueForKey:@"sslive_id"] integerValue];
        NSInteger shareSource = [[data valueForKey:@"share_source"] integerValue];
        
        [self ugcShareWithssliveId:ssliveId shareSource:shareSource];
        
    } else if ([message.name isEqualToString:@"payHDCommon"]){
        //        NSInteger joinType = [data[@"join_type"] integerValue];
        //        NSInteger useYxsMonth = [data[@"use_yxs_month"] integerValue];
        //        if ((joinType != 0 && joinType != 1) || useYxsMonth > 0) {
        //            [MBProgressHUD showAlertWithMessage:@"请分享到微信支付"];
        //            HDShareInfoResultModel * shareModel = [HDShareInfoResultModel new];
        //            shareModel.url = self.webView.URL.absoluteString;
        ////            [self shareWebWithShareModel:shareModel andImage:nil shareType:Popup callback:nil];
        //            return;
        //        }
        
        HDPayIapModel *payIapModel = [HDPayIapModel yy_modelWithJSON:data];
        payIapModel.noJumpH5 = YES;
        payIapModel.otype = kHDPayIapOtypePayJoin;
        payIapModel.gotoPage = YES;
        payIapModel.courseId = self.courseId;
        payIapModel.controller = self;
        
        ///2.23.0改成优先本地appChannel
        if (self.appChannel.length) payIapModel.appChannel = self.appChannel;
        
        [HDUserEntranceTools payWithPayIapModel:payIapModel];
        
    } else if ([message.name isEqualToString:@"openPayGuide"]) {
        NSURL *url = [NSURL URLWithString:@"itms-apps://"];
        // 最好加上   ⭐️判断条件⭐️
        if ([ [UIApplication sharedApplication] canOpenURL:url])
        {   // 看是否 允许跳转
            [[UIApplication sharedApplication] openURL:url];
            
        } else {
            
        }
        return;
    } else if ([message.name isEqualToString:@"completeRecive"]) { //2.6.0入学调研迁移过来
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kCourseListRefresh" object:nil];
        
        
    } else if ([message.name isEqualToString:@"closePage"]) {
        //关闭页面，2.15.0添加。与closeWebsite区别是后者会刷新首页，故需要一个单独关闭的方法
        [self naviColoseButton_MovieTitle:self.closeButton];
    } else if([message.name isEqualToString:@"saveImage"]) {
        ///保存图片
        NSString *imageUrl = data[@"sourse"] ?: data[@"source"];
        NSString *callBack = data[@"callback"];
        [self saveImageWithUrl:imageUrl CallBack:callBack];
    } else if ([message.name isEqualToString:@"showRightMenu"]) {
        //右上角显示样式
        HDBaseWKWebRrightMenuModel *rightMenuModel = [HDBaseWKWebRrightMenuModel yy_modelWithJSON:data];
        self.rightMenuModel = rightMenuModel;
    } else if([message.name isEqualToString:@"noticeAppBindPhone"]) {
        NSString *callBack = data[@"callbackUrl"];
        ///< 1.https开头的会刷新页面吗？
        ///< 2.研习社开头的走路由
        [HDAppSuspendingLayerBindPhonePopView bindPhoneCompletion:^{
            if ([NSString hd_isBlankString:callBack]) return;
            if ([callBack hasPrefix:@"https://"] || [callBack hasPrefix:@"http://"]) {
                ///<公共参数
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithObjectsAndKeys:STRING_NIL([HDAccountTool account].phone),@"phone", nil];
                if (self.navigationController.viewControllers.count > 1) {
                    UIViewController *vc = self.navigationController.viewControllers[self.navigationController.viewControllers.count - 2];
                    NSString *pageId = NSStringFromClass([vc class]);
                    [dic setObject:STRING_NIL(pageId) forKey:@"pageId"];
                }
                
                //拼接的URL网址(拼接公共参数)
                NSString *webString = [HDSingleMethodTool combineCommonParasWithUrlString:callBack paras:dic];
                [self loadRequestWithWebUrl:webString];
            } else {
                [MGJRouter openURL:callBack withUserInfo:@{@"pre_page_id":[HDUserActionTools getPageIdWithController:self]} completion:nil];
            }
        }];
    } else if([message.name isEqualToString:@"getAppVersion"]) {
        //获取App版本号
        NSString *callback = data[@"callback"];
        if (callback.length) {
            [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@')",  callback,[HDAccountTool appVersion]] andcompletionHandler:^(id response, NSError *error) {}];
        }
    } else if([message.name isEqualToString:@"cleanCache"]) {
        //清空本地缓存
        [HDBaseWKWebViewController clearWebCache];
    } else if([message.name isEqualToString:@"refreshWeb"]) {
        //刷新web
        [self.webView reload];
    } else if([message.name isEqualToString:@"updateLog"]) {
        //上传日志
        [HDUserActionTools reportDataWithActionName:@"日志系统-js上报" actionCode:0 Category:HDLogSystemWebLoadError Properties:@{@"scrollView_size":NSStringFromCGSize(self.webView.scrollView.contentSize),@"scrollView_contentOffset":NSStringFromCGPoint(self.webView.scrollView.contentOffset)}];
    } else if ([message.name isEqualToString:@"getAppAudioCaptureAccess"]) {
        // 获取麦克风权限
        // 麦克风权限
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *callback = [NSString stringWithFormat:@"appAudioCaptureAccess(%d)", granted?1:0];
                [self nativeControlJSWithScript:callback andcompletionHandler:^(id response, NSError *error) {
                    
                }];
            });
        }];
    } else if ([message.name isEqualToString:@"getAppVideoCaptureAccess"]) {
        // 获取摄像机权限
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *callback = [NSString stringWithFormat:@"appVideoCaptureAccess(%d)", granted?1:0];
                [self nativeControlJSWithScript:callback andcompletionHandler:^(id response, NSError *error) {
                    
                }];
            });
        }];
    } else if ([message.name isEqualToString:@"getAppBaseInfo"]) {
        // 获取基本参数，保证h5安全性3.2.0添加
        HDUserModel *userModel = [HDAccountTool account];
        NSArray *skuList = [userModel.skuList yy_modelToJSONObject]?:@[];
        NSString *versionName = HDVersion;
        NSString *imei = HDADID;
        
        NSDictionary *info = @{
            @"user_info" : @{
                    @"user_id" : HDUID,
                    @"name" : HDUNAME,
                    @"phone" : STRING_NIL(userModel.phone),
                    @"sku_list" : skuList,
            },
            @"common_params" : @{
                    @"versionName" : STRING_NIL(versionName),
                    @"imei" : STRING_NIL(imei),
                    @"net" : [HDAccountTool net],
            },
            @"session" : @{
                    @"sid" : STRING_NIL([HDAccountTool loginInfo].session.sid),
                    @"token" : STRING_NIL([HDAccountTool loginInfo].session.token),
            },
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingFragmentsAllowed error:nil];
        NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSString *function = [NSString stringWithFormat:@"showAppBaseInfo(%@)", jsonString];
        [self nativeControlJSWithScript:function andcompletionHandler:^(id response, NSError *error) {
            
        }];
    } else if ([message.name isEqualToString:@"openBounces"]) {
        /// 打开或者关闭边界回弹 1 打开 0 关闭
        NSInteger bounces = [[data valueForKey:@"bounces"] integerValue];
        self.webView.scrollView.bounces = bounces;
    }else if([message.name isEqualToString:@"openVoiceComment"]) {
        ///语音评论
        ///语音最大时长
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    ///有麦克风权限
                    NSInteger maxTime = [[data valueForKey:@"max_time"] integerValue];
                    [HDVoiceReviewView showinView:self.webView maxTime:maxTime audioBlock:^(NSString * _Nonnull audioUrl, NSInteger audioDuration) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSDictionary *audioInfo = @{
                                @"audioUrl" : audioUrl,
                                @"duration" : @(audioDuration),
                                
                            };
                            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:audioInfo options:NSJSONWritingFragmentsAllowed error:nil];
                            NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
                            NSString *function = [NSString stringWithFormat:@"showVoiceComment(%@)", jsonString];
                            [self nativeControlJSWithScript:function andcompletionHandler:^(id response, NSError *error) {
                                
                            }];
                        });
                        
                    }];
                } else {
                    [MBProgressHUD showAlertWithMessage:@"请开启麦克风权限"];
                }
               
            });
        }];
       
    } else if ([message.name isEqualToString:@"sessionInvalid"]) {
        ///4.0.4，session不合法
        NSString *errorMsg = data[@"errorMsg"];
        [UIWindow hd_anotherDevice:errorMsg];
    }
}

#pragma mark OC直接调JS方法
//OC直接调用JS的方法
- (void)nativeControlJSWithScript:(NSString *)scriptFunctionName andcompletionHandler:(void (^)(id, NSError *))completionHandler {
    
    //调用WKWebView调用JS方法
    [self.webView evaluateJavaScript:scriptFunctionName completionHandler:completionHandler];
    
    HDLog(@"OC调用了JS的%@方法",scriptFunctionName);
}

#pragma mark - 网页跳转监听代理
/**
 *  H5页面在发送请求之前，决定是否跳转
 *
 *  @param webView          实现该代理的webview
 *  @param navigationAction 当前navigation
 *  @param decisionHandler  是否调转block
 */

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    self.decidePolicyDate = [[NSDate date] timeIntervalSince1970];
    
    NSURL *URL = navigationAction.request.URL;
    NSString *scheme = [URL scheme];
    if ([scheme hasPrefix:@"yanxishe"]) {
        [MGJRouter openURL:URL.absoluteString withUserInfo:@{@"from_course":STRING_NIL(self.fromCourse), @"pre_page_id":[HDUserActionTools getPageIdWithController:self]} completion:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        if ([scheme isEqualToString:@"tel"]) {
            NSString *resourceSpecifier = [URL resourceSpecifier];
            NSString *callPhone = [NSString stringWithFormat:@"telprompt://%@", resourceSpecifier];
            /// 防止iOS 10及其之后，拨打电话系统弹出框延迟出现
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:callPhone]];
            });
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}


#pragma mark - 清空网页缓存
+ (void)clearWebCache {
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 9.0) {
        
        //如果是iOS 9.0以上，直接调用WK清空方法
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
            
            HDLog(@"WKWebView清空缓存成功");
        }];
        
    }else {
        
        //如果iOS 9.0以下，用原始清空方法
        NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        
        NSString *cookiesFolderPath = [libraryPath stringByAppendingString:@"/Cookies"];
        
        NSError *errors;
        
        [[NSFileManager defaultManager] removeItemAtPath:cookiesFolderPath error:&errors];
        
        if (!errors) {
            
            HDLog(@"WKWebView清空缓存成功");
        }
    }
}

#pragma mark - Dealloc
- (void)dealloc {
    
    //    if (self.hadClearCache) [self clearWebCache];//清空缓存
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIWindowDidBecomeHiddenNotification object:nil];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"title"];
    [[HDBaseWKWebViewPool managerPool] reusableWKWebView:self.webView];
    HDLog(@"-----  %@      dealloc" , NSStringFromClass([self class]));
}


#pragma mark -- JS 交互方法

#pragma mark 分享方法
- (void)shareWebWithShareModel:(HDShareInfoResultModel *)model andImage:(UIImage *)image shareType:(WKWebShareType)shareType callback:(NSString *)callback {
    HDShareView *shareView = [[HDShareView alloc] initWithFrame:CGRectMake(0, 0, Screen_W, 100) colorType:HDShareViewColorTypeGreen isShowPoster:NO isShowCancel:NO];
    
    //分享增加url参数
    model.sensorsAnalyticsProperties = @{HDShareParameterWayClick:@{@"url":self.currentWebUrl}};
    
    if (shareType == WKWebShareTypePopup) {
        shareView.shareCallbackWithIndex = ^(HDShareView *shareView, HDShareViewSocialIndex index) {
            
            if (model.imgBase64.length || !model.title.length) {
                [shareView onlyShareImageWithIndex:index imageUrl:model.imgBase64.length ? model.imgBase64 : model.url vc:self result:^(BOOL isSuccess, UMSocialPlatformType platformType) {
                    if (callback.length) {
                        [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%d')",  callback,STRING_NIL(model.shareId),isSuccess] andcompletionHandler:^(id response, NSError *error) {}];
                    }
                } isBase64:model.imgBase64.length];
            } else {
                [shareView shareWithIndex:index shareImage:image isImage:NO shareTitle:model.title shareText:model.content shareUrl:model.url vc:self sensorsAnalyticsProperties:model.sensorsAnalyticsProperties result:^(BOOL isSuccess, UMSocialPlatformType platformType) {
                    if (callback.length) {
                        [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%d')",  callback,STRING_NIL(model.shareId),isSuccess] andcompletionHandler:^(id response, NSError *error) {}];
                    }
                }];
            }
        };
        [shareView shareImageTypeView];
        [shareView popToView:kHDMainWindow type:HDPopupAnimationTypeFromBottom isHaveCoverView:YES isCoverClick:YES];
        
    } else if (shareType == WKWebShareTypeMin) {
        [shareView shareMiniWithIndex:HDShareViewSocialIndexWechatSession Title:model.title desc:model.content thumImage:nil webPageUrl:model.url userName:model.WXSmallCardModel.userName path:model.WXSmallCardModel.path hdImage:image vc:self result:^(BOOL isSuccess, UMSocialPlatformType platformType) {
            if (callback.length) {
                [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%d')",  callback,STRING_NIL(model.shareId),isSuccess] andcompletionHandler:^(id response, NSError *error) {}];
            }
        }];
    } else {  // 直接分享
        
        HDShareViewSocialIndex index = HDShareViewSocialIndexWechatSession;
        if (shareType == WKWebShareTypeWeiXin) {
            index = HDShareViewSocialIndexWechatSession;
        } else if (shareType == WKWebShareTypeCircle) {
            index = HDShareViewSocialIndexWechatTimeLine;
        }
        
        if (model.imgBase64.length || !model.title.length) {
            [shareView onlyShareImageWithIndex:index imageUrl:model.imgBase64.length ? model.imgBase64 : model.url vc:self result:^(BOOL isSuccess, UMSocialPlatformType platformType) {
                if (callback.length) {
                    [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%d')",  callback,STRING_NIL(model.shareId),isSuccess] andcompletionHandler:^(id response, NSError *error) {}];
                }
            } isBase64:model.imgBase64.length];
        } else {
            [shareView shareWithIndex:index shareImage:image isImage:NO shareTitle:model.title shareText:model.content shareUrl:model.url vc:self result:^(BOOL isSuccess, UMSocialPlatformType platformType) {
                if (callback.length) {
                    [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%d')",  callback,STRING_NIL(model.shareId),isSuccess] andcompletionHandler:^(id response, NSError *error) {}];
                }
            }];
        }
    }
}

#pragma mark ugc直播分享方法
- (void)ugcShareWithssliveId:(NSInteger)ssliveId shareSource:(NSInteger)shareSource {
    MBProgressHUD *hud = [MBProgressHUD showLoadingWithMessage:@""];
    hud.userInteractionEnabled = NO;
    
    [[HDWanghongLiveNetworkTools shareNetworkTools] ssliveShareWithSsliveId:ssliveId shareSource:shareSource success:^(id obj) {
        
        HDShareInfoResultModel *resultModel = obj;
        [hud hide:YES];
        NSDictionary *sensorsAnalyticsProperties = @{
            HDShareParameterWayClick : @{
                    @"content_type":@"学员直播",
                    @"content_no":@(ssliveId),
                    @"url":self.currentWebUrl,
            },
            HDShareParameterShareId : STRING_NIL(resultModel.shareId),
            
        };
        resultModel.sensorsAnalyticsProperties = sensorsAnalyticsProperties;
        resultModel.shareSource = shareSource;
        
        [[HDShareView sharedShareView] shareWithModel:resultModel withDetailModel:nil type:HDShareViewTypeFromKnowledge];
        
        
    } failure:^(NSString *errorTip) {
        
        [hud hide:YES];
    }];
}

#pragma mark  保存图片
- (void)saveImageWithUrl:(NSString *)urlString CallBack:(NSString *)callBack {
    
    if (!urlString.length) {
        [MBProgressHUD showErrorWithMessage:@"保存失败"];
        return;
    }
    
    ///保存图片
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                // TODO:...
                HDLog(@"确定之后");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self downloadImageWithUrl:urlString callBack:callBack];
                });
            }else if (status == PHAuthorizationStatusRestricted || status == PHAuthorizationStatusDenied) {
                HDLog(@"拒绝之后");
            }
        }];
    }else if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted || [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *title = [NSString stringWithFormat:@"请在\"设置-隐私-照片\"选项中,允许%@访问您的手机相册",appName];
        
        [HDCommonPopupView showWithTitle:@"提示" message:title sureTitle:@"点击前往" sureBlock:^(){
            //无权限 引导去开启
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
    }else {
        
        [self downloadImageWithUrl:urlString callBack:callBack];
    }
    
    
    
}

#pragma mark 长按保存图片

- (void)longPressed:(UITapGestureRecognizer *)recognizer {
    //只在长按手势开始的时候才去获取图片的url
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [recognizer locationInView:self.webView];
        NSString *js = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", touchPoint.x, touchPoint.y];
        [self.webView evaluateJavaScript:js completionHandler:^(NSString * imageStr, NSError * _Nullable error) {
            HDLog(@"urlToSave === %@",imageStr);
            //成功拿到地址之后
            if (imageStr.length != 0) {
                [self showAlertViewControllerWithImageUrl:imageStr];
            }
        }];
    }
}


- (void)showAlertViewControllerWithImageUrl:(NSString *)url {
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"提示" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"保存图片" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    // TODO:...
                    HDLog(@"确定之后");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self downloadImageWithUrl:url];
                    });
                }else if (status == PHAuthorizationStatusRestricted || status == PHAuthorizationStatusDenied) {
                    HDLog(@"拒绝之后");
                }
            }];
        }else if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted || [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) {
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
            NSString *title = [NSString stringWithFormat:@"请在\"设置-隐私-照片\"选项中,允许%@访问您的手机相册",appName];
            
            [HDCommonPopupView showWithTitle:@"提示" message:title sureTitle:@"点击前往" sureBlock:^(){
                //无权限 引导去开启
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }];
        }else {
            [self downloadImageWithUrl:url];
        }
        
    }];
    [alertView addAction:copyAction];
    UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertView addAction:cancleAction];
    
    //如果存在,兼容ipad
    if (alertView.popoverPresentationController) {
        //如果source传nil,则使用Controller.view
        alertView.popoverPresentationController.sourceView = self.view;
        alertView.popoverPresentationController.sourceRect = CGRectMake(20, Screen_H * 0.5 - 100, Screen_W - 40, 200);
    }
    
    [self presentViewController:alertView animated:YES completion:nil];
}

- (void)downloadImageWithUrl:(NSString *)imageUrl {
    [[YYWebImageManager sharedManager] requestImageWithURL:URL(imageUrl) options:0 progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
            }
        });
    }];
}

- (void)downloadImageWithUrl:(NSString *)imageUrl callBack:(NSString *)callBack {
    
    ///保存图片回调数据
    self.saveImageCallBack =  @{
        @"callBack" : callBack,
        @"imageUrl" : STRING_NIL(imageUrl)
    };
    if ([imageUrl hasPrefix:@"http"]) {
        ///图片地址链接类型
        [[YYWebImageManager sharedManager] requestImageWithURL:URL(imageUrl) options:0 progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void * )self.saveImageCallBack);
                }
            });
        }];
    } else {
        ///base64类型
        
        NSURL *baseImageUrl = [NSURL URLWithString:imageUrl];
        NSData *imageData = [NSData dataWithContentsOfURL:baseImageUrl];
        UIImage *image = [UIImage imageWithData:imageData];
        
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:),(__bridge void * )self.saveImageCallBack);
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    
    ///回调数据
    NSDictionary *callback = (__bridge NSDictionary *)contextInfo;
    NSString *callName = callback[@"callBack"];
    NSString *imageUrl = callback[@"imageUrl"];
    
    
    if (!error) {
        [MBProgressHUD showSuccessWithMessage:@"保存成功"];
        if (callName.length) {
            ///有回调数据，调用js回调
            [self nativeControlJSWithScript:[NSString stringWithFormat:@"%@('%@','%@')",  callName,STRING_NIL(imageUrl),@"true"] andcompletionHandler:^(id response, NSError *error) {}];
            
        }
        
    }
}



- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

///截图
- (void)screenSnapshot:(void(^)(UIImage *snapShotImage))finishBlock; {
    [self.webView screenSnapshot:^(UIImage *snapShotImage) {
        if (finishBlock) {
            finishBlock(snapShotImage);
        }
    }];
}

#pragma mark - 右侧按钮事件
///右侧按钮
- (void)setRightMenuModel:(HDBaseWKWebRrightMenuModel *)rightMenuModel {
    _rightMenuModel = rightMenuModel;
    self.rightButton.hidden = !rightMenuModel.menuTitle.length;
    NSString *menuTitle = rightMenuModel.menuTitle;
    if (menuTitle.length) {
        self.rightButton.hidden = NO;
        [self.rightButton setTitle:menuTitle forState:UIControlStateNormal];
        [self.rightButton sizeToFit];
    } else {
        self.rightButton.hidden = YES;
    }
}

///右侧按钮事件
- (void)rightAction {
    if (!self.rightMenuModel.menuTitle) {
        return;
    }
    NSString *webUrl = self.rightMenuModel.webUrl;
    if (![NSString hd_isBlankString:webUrl]) {
        [self loadRequestWithWebUrl:webUrl];
        return;
    }
    
    NSString *pageUrl = self.rightMenuModel.pageUrl;
    if (pageUrl.length) {
        [MGJRouter openURL:pageUrl withUserInfo:@{@"pre_page_id":[HDUserActionTools getPageIdWithController:self]} completion:nil];
        return;
    }
}

- (UIView *)webContainerView {
    if (!_webContainerView) {
        _webContainerView = [UIView new];
    }
    return _webContainerView;
}

- (UIButton *)rightButton {
    if (!_rightButton) {
        _rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_rightButton addTarget:self action:@selector(rightAction) forControlEvents:UIControlEventTouchUpInside];
        [_rightButton setTitle:@"" forState:UIControlStateNormal];
        [_rightButton setTitleColor:HDColor333333 forState:UIControlStateNormal];
        _rightButton.titleLabel.font = HDDefaultFont(14);
    }
    return _rightButton;
}

///当前页面链接，多用于统计
- (NSString *)currentWebUrl {
    return self.webView.URL.absoluteString?:@"";
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [UIProgressView new];
        _progressView.tintColor = [UIColor redColor];
        _progressView.backgroundColor = [UIColor lightGrayColor];
    }
    return _progressView;
}
/**
 *  接收到服务器跳转请求之后调用
 *
 *  @param webView      实现该代理的webview
 *  @param navigation   当前navigation
 */
/*
 
 - (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
 
 HDLog(@"%s", __FUNCTION__);
 }
 
 */

/**
 *  在收到响应后，决定是否跳转
 *
 *  @param webView            实现该代理的webview
 *  @param navigationResponse 当前navigation
 *  @param decisionHandler    是否跳转block
 */

// - (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
//
//
//     // 如果响应的地址是百度，则允许跳转
//     if ([navigationResponse.response.URL.host.lowercaseString isEqual:@"www.baidu.com"]) {
//
//         // 允许跳转
//         decisionHandler(WKNavigationResponsePolicyAllow);
//         return;
//     }
//     // 不允许跳转
//     decisionHandler(WKNavigationResponsePolicyCancel);
// }
/*
 - (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
 
 // 如果请求的是百度地址，则延迟5s以后跳转
 if ([navigationAction.request.URL.host.lowercaseString isEqual:@"www.baidu.com"]) {
 
 //        // 延迟5s之后跳转
 //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
 //
 //            // 允许跳转
 //            decisionHandler(WKNavigationActionPolicyAllow);
 //        });
 
 // 允许跳转
 decisionHandler(WKNavigationActionPolicyAllow);
 return;
 }
 // 不允许跳转
 decisionHandler(WKNavigationActionPolicyCancel);
 }
 */

#pragma mark - WKUIDelegate --- 界面弹出框拦截和webview创建
// 创建一个新的WebView
/*
 - (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
 
 }
 */

// 界面弹出警告框
/*
 - (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(void (^)())completionHandler {
 
 }
 */

// 界面弹出确认框
/*
 - (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
 
 }
 */

// 界面弹出输入框
/*
 - (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler {
 
 }
 */
@end

