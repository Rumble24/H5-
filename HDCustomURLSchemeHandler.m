//
//  HDCustomURLSchemeHandler.m
//  yanxishe
//
//  Created by 王景伟 on 2020/11/3.
//  Copyright © 2020 hundun. All rights reserved.
//

#import "HDCustomURLSchemeHandler.h"
#import "NSString+YYAdd.h"
#import "HDCustomURLCache.h"

@interface HDCustomURLSchemeHandler ()

@property (nonatomic, strong) NSMutableDictionary *holderDicM;

@property (nonatomic, strong) NSLock *lock;
@end

@implementation HDCustomURLSchemeHandler

- (instancetype)init {
    self = [super init];
    _lock = [[NSLock alloc] init];
    _holderDicM = [NSMutableDictionary dictionary];
    return self;
}

- (void)webView:(nonnull WKWebView *)webView stopURLSchemeTask:(nonnull id<WKURLSchemeTask>)urlSchemeTask  API_AVAILABLE(ios(11.0)){
    [self.holderDicM setObject:@(NO) forKey:urlSchemeTask.description];

    NSNumber *number = self.holderDicM[urlSchemeTask.description];
    NSLog(@"HDBaseWKWebViewPool stop  %@   %@  %@",urlSchemeTask.description,number.boolValue ? @"1" : @"0",[NSThread currentThread]);
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask  API_AVAILABLE(ios(11.0)){
    [self.holderDicM setObject:@(YES) forKey:urlSchemeTask.description];
    
    NSDictionary *headers = urlSchemeTask.request.allHTTPHeaderFields;
    NSString *accept = headers[@"Accept"];
    NSString *requestUrl = urlSchemeTask.request.URL.absoluteString;

    NSLog(@"HDBaseWKWebViewPool 拦截请求类型： %@   Accept: %@  地址：%@",urlSchemeTask.request.HTTPMethod,accept,requestUrl);

    /// html 不缓存
    if ((accept.length >= @"text".length && [accept rangeOfString:@"text/html"].location != NSNotFound)) {
        [self requestUrlSchemeTask:urlSchemeTask isCache:NO];
    }
    /// js、css 缓存
    else if ([self isMatchingRegularExpressionPattern:@"\\.(js|css)" text:requestUrl]) {
        [self loadLocalFileWithUrlSchemeTask:urlSchemeTask];
    }
    /// image 缓存
    else if (accept.length >= @"image".length && [accept rangeOfString:@"image"].location != NSNotFound) {
        NSString *replacedStr = [requestUrl stringByReplacingOccurrencesOfString:@"customscheme" withString:@"https"];
        [[YYWebImageManager sharedManager] requestImageWithURL:[NSURL URLWithString:replacedStr] options:0 progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
            if (image) {
                NSData *imgData = UIImageJPEGRepresentation(image, 1);
                NSString *mimeType = [self sd_contentTypeForImageData:imgData] ?: @"image/jpeg";
                [self resendRequestWithUrlSchemeTask:urlSchemeTask mimeType:mimeType requestData:imgData];
            } else {
                [self requestUrlSchemeTask:urlSchemeTask isCache:NO];
            }
        }];
    }
    /// 其他网络请求 不缓存
    else {
        [self requestUrlSchemeTask:urlSchemeTask isCache:NO];
    }
}

    
/// 本地加载
- (void)loadLocalFileWithUrlSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask  API_AVAILABLE(ios(11.0)){
    if (!urlSchemeTask) return;
    
    NSString *requestUrl = urlSchemeTask.request.URL.absoluteString;

    if (![[HDCustomURLCache sharedCache] containsObjectForURLString:requestUrl]) {
        [self requestUrlSchemeTask:urlSchemeTask isCache:YES];
    } else {
        NSData *data = [[HDCustomURLCache sharedCache] objectForURLString:requestUrl];
        if ([requestUrl containsString:@"css"]) {
            [self resendRequestWithUrlSchemeTask:urlSchemeTask mimeType:@"text/css" requestData:data];
        }
        else if ([requestUrl containsString:@"js"]) {
            [self resendRequestWithUrlSchemeTask:urlSchemeTask mimeType:@"*/*" requestData:data];
        }
        NSLog(@"HDBaseWKWebViewPool 取缓存：地址：%@",requestUrl);
    }
}



/// 网络请求
- (void)requestUrlSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask isCache:(BOOL)cache API_AVAILABLE(ios(11.0)) {
    NSDictionary *headers = urlSchemeTask.request.allHTTPHeaderFields;
    NSString *accept = headers[@"Accept"];
    
    NSString *requestUrl = urlSchemeTask.request.URL.absoluteString;
    NSString *replacedStr = [requestUrl stringByReplacingOccurrencesOfString:@"customscheme" withString:@"https"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:replacedStr]];
    /// 添加请求头
    if ((accept.length >= @"text".length && [self isTextWith:accept])) {
        [request setAllHTTPHeaderFields:urlSchemeTask.request.allHTTPHeaderFields];
    }
    /// POST 添加请求body
    if ([urlSchemeTask.request.HTTPMethod isEqualToString:@"POST"]) {
        if (urlSchemeTask.request.HTTPBody) {
            [request setHTTPBody:urlSchemeTask.request.HTTPBody];
        }
        if (urlSchemeTask.request.HTTPBodyStream) {
            [request setHTTPBodyStream:urlSchemeTask.request.HTTPBodyStream];
        }
    }
    /// 设置请求方式
    [request setHTTPMethod:urlSchemeTask.request.HTTPMethod];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        [self.lock lock];
        NSNumber *number = self.holderDicM[urlSchemeTask.description];
        if (number.boolValue == NO) return;

        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData:data];
        if (error) {
            [urlSchemeTask didFailWithError:error];
            NSLog(@"HDBaseWKWebViewPool didFailWithError： %@  ",error.description);
        } else {
            [urlSchemeTask didFinish];
            
            /// 缓存到本地
            if (cache) {
                [[HDCustomURLCache sharedCache]setData:data forURLString:requestUrl];
            }
        }
        [self.lock unlock];

    }];
    [dataTask resume];
    [session finishTasksAndInvalidate];
}


///  发送数据到webview
- (void)resendRequestWithUrlSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
                              mimeType:(NSString *)mimeType
                           requestData:(NSData *)requestData  API_AVAILABLE(ios(11.0)) {
    
    if (!urlSchemeTask || !urlSchemeTask.request || !urlSchemeTask.request.URL) {
        return;
    }
    
    NSString *mimeType_local = mimeType ? mimeType : @"text/html";
    NSData *data = requestData ? requestData : [NSData data];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL
                                                        MIMEType:mimeType_local
                                           expectedContentLength:data.length
                                                textEncodingName:nil];
    [urlSchemeTask didReceiveResponse:response];
    [urlSchemeTask didReceiveData:data];
    [urlSchemeTask didFinish];
    
}

- (BOOL)isMatchingRegularExpressionPattern:(NSString *)regex text:(NSString *)text {
    return [text matchesRegex:regex options:NSRegularExpressionCaseInsensitive];
}

- (BOOL)isTextWith:(NSString *)accept {
    if ([accept rangeOfString:@"text/html"].location != NSNotFound ||
        [accept rangeOfString:@"application/json"].location != NSNotFound ||
        [accept rangeOfString:@"text/json"].location != NSNotFound ||
        [accept rangeOfString:@"text/xml"].location != NSNotFound ||
        [accept rangeOfString:@"text/plain"].location != NSNotFound) {
        return YES;
    }
    return NO;
}

//根据路径获取MIMEType
- (NSString *)getMimeTypeWithFilePath:(NSString *)filePath {
    CFStringRef pathExtension = (__bridge_retained CFStringRef)[filePath pathExtension];
    CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
    CFRelease(pathExtension);
    
    //The UTI can be converted to a mime type:
    NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
    if (type != NULL)
        CFRelease(type);
    
    return mimeType;
}

- (NSString *)sd_contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x52:
            // R as RIFF for WEBP
            if ([data length] < 12) {
                return nil;
            }

            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"image/webp";
            }

            return nil;
    }
    return nil;
}
@end
