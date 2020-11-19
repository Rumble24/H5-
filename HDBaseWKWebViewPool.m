//
//  HDBaseWKWebViewPool.m
//  yanxishe
//
//  Created by 王景伟 on 2020/11/3.
//  Copyright © 2020 hundun. All rights reserved.
//

#import "HDBaseWKWebViewPool.h"
#import "HDCustomURLSchemeHandler.h"

@interface HDBaseWKWebViewPool ()
/** 使用当中的数组 */
@property (nonatomic, strong) NSMutableArray *visiableWebViewArr;
/** 准备复用的数组 */
@property (nonatomic, strong) NSMutableArray *reusableWebViewArr;
@end

@implementation HDBaseWKWebViewPool

+ (void)load {
    [HDBaseWKWebViewPool managerPool];
}

+ (instancetype)managerPool {
    static HDBaseWKWebViewPool *tools = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tools = [[HDBaseWKWebViewPool alloc]init];
    });
    return tools;
}

- (instancetype)init {
    self = [super init];
    self.visiableWebViewArr = [NSMutableArray array];
    self.reusableWebViewArr = [NSMutableArray array];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunchingNotification) name:UIApplicationDidFinishLaunchingNotification object:nil];
    return self;
}

- (void)didFinishLaunchingNotification {
    [[HDBaseWKWebViewPool managerPool] prepareWebView];
}

- (WKWebView *)getWKWebView {
    if (self.reusableWebViewArr.count > 0) {
        WKWebView *webview = self.reusableWebViewArr[0];
        [self.reusableWebViewArr removeObjectAtIndex:0];
        [self.visiableWebViewArr addObject:webview];
//        NSLog(@"HDBaseWKWebViewPool 重用了");
        return webview;
    } else {
        WKWebView *webview = [self getInitWebView];
        [self.reusableWebViewArr addObject:webview];
        return webview;
    }
}

- (void)reusableWKWebView:(WKWebView *)webView {
    if ([self.visiableWebViewArr containsObject:webView]) {
        webView.scrollView.delegate = nil;
        [webView stopLoading];
        webView.navigationDelegate = nil;
        
        NSURL *url = [NSURL URLWithString:@"about:blank"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [webView loadRequest:request];
        
        [webView.configuration.userContentController removeAllUserScripts];
        [self.visiableWebViewArr removeObject:webView];
        [self.reusableWebViewArr addObject:webView];
//        NSLog(@"HDBaseWKWebViewPool 重置了");
    }
}

#pragma mark - 预先初始化
- (void)prepareWebView {
    [self.reusableWebViewArr addObject:[self getInitWebView]];
}


- (WKWebView *)getInitWebView {
//    NSLog(@"HDBaseWKWebViewPool 初始化了");
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    
    ///防止视频播放时播放器全屏
    config.allowsInlineMediaPlayback = YES;
    
    ///视频自动播放
    if (@available(iOS 10.0, *)) {
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    if (@available(iOS 11.0, *)) {
        [config setURLSchemeHandler:[HDCustomURLSchemeHandler new] forURLScheme:@"customScheme"];
    } else {
        
    }
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    
    return webView;
}
@end
