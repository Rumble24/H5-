//
//  HDBaseWKWebViewPool.h
//  yanxishe
//
//  Created by 王景伟 on 2020/11/3.
//  Copyright © 2020 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HDBaseWKWebViewPool : NSObject

+ (instancetype)managerPool;

- (WKWebView *)getWKWebView;

- (void)reusableWKWebView:(WKWebView *)webView;
@end

NS_ASSUME_NONNULL_END
