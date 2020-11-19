/**
 * @file HDBaseViewController
 * @author 王健鹏
 * @date 2017-06-09
 */

#import "HDBaseViewController.h"
#import <WebKit/WebKit.h>
#import "HDRusheResultModel.h"

/**
 * @class HDBaseWKWebViewController
 * @brief 基本WKWebView控制器
 * @author 王健鹏
 * @date 2017-06-09
 */

/**
 * 使用方法说明
 *
 * 1.继承此类，则已经成为WKWebView的代理，直接在子类中实现即可(代理详情见.m文件)
 *
 * 2.若有JS调用OC需求，则必须将JS调用OC的方法名数组赋值，也就是本类属性scriptNames
 *
 * 3.若有OC调用JS需求，则直接调用本类方法，传入JS方法名和参数
 *
 */

@interface HDBaseWKWebViewController : HDBaseViewController <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>
/** WKWebView */
@property (nonatomic, strong, readonly) WKWebView *webView;
/** 加载菊花 */
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
/** 课程id */
@property (nonatomic ,  copy) NSString *courseId;
/** 标题 */
@property (nonatomic ,  copy) NSString *titleString;
/** 网络请求地址 (不需要拼接公共参数,内部会自动拼接公共参数) */
@property (nonatomic ,  copy) NSString *webUrl;
/** 默认外部直接传入url然后加载地址。 但是通过请求得到的地址 调用loadRequestWithWebUrl 方法的请设置为NO */
@property (nonatomic, assign) BOOL autoLoadRequest;
/** 需要拼接的参数 */
@property (nonatomic ,strong) NSDictionary *params;
/** webView内边距 (用来调整webView的位置的) */
@property (nonatomic ,assign) UIEdgeInsets contentInset;
/** 是否使用不拼接参数的原始url */
@property (nonatomic, assign) BOOL useOriginUrl;
#pragma mark - H5交互
/** JS调OC标识数组 (若有交互，必须要传) */
@property (nonatomic ,strong) NSArray <NSString *> *scriptNames;
/// 支付数据
@property (strong, nonatomic) HDRusheResultModel *rusheModel;
/// 支付渠道，2.8.0添加，用于透传数据统计
@property (nonatomic,   copy) NSString *appChannel;
@property (nonatomic,   copy) NSString *fromCourse;
@property (nonatomic,   copy) void (^popViewDismissBlock)();
/// 是否是弹窗，用于埋点
@property (nonatomic, assign) BOOL isPop;
/// 弹窗名字，用于埋点
@property (nonatomic,   copy) NSString *popName;
/// 不允许操作导航栏
@property (nonatomic, assign) BOOL denyNav;


/// 截图
- (void)screenSnapshot:(void(^)(UIImage *snapShotImage))finishBlock;
/// 外部加载网页
- (void)loadRequestWithWebUrl:(NSString *)webUrl;
/// 当前页面链接，多用于统计
- (NSString *)currentWebUrl;
/// 清空缓存
+ (void)clearWebCache;


@end
