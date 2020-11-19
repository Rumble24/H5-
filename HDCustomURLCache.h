//
//  HDCustomURLCache.h
//  yanxishe
//
//  Created by 王景伟 on 2020/11/19.
//  Copyright © 2020 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HDCustomURLCache : NSObject

+ (instancetype)sharedCache;

- (BOOL)containsObjectForURLString:(NSString *)url;

- (void)setData:(NSData *)data forURLString:(NSString *)url;

- (NSData *)objectForURLString:(NSString *)url;
@end

NS_ASSUME_NONNULL_END
