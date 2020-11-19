//
//  HDCustomURLCache.m
//  yanxishe
//
//  Created by 王景伟 on 2020/11/19.
//  Copyright © 2020 hundun. All rights reserved.
//

#import "HDCustomURLCache.h"
#import "YYCache.h"
#import "NSString+YYAdd.h"

@interface HDCustomURLCache ()
@property (strong, nonatomic) YYCache *cache;
@end

@implementation HDCustomURLCache

+ (instancetype)sharedCache {
    static HDCustomURLCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                   NSUserDomainMask, YES) firstObject];
        cachePath = [cachePath stringByAppendingPathComponent:@"com.hundu"];
        cachePath = [cachePath stringByAppendingPathComponent:@"jscss"];
        cache = [[self alloc] initWithPath:cachePath];
    });
    return cache;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    self.cache = [YYCache cacheWithPath:path];
    return self;
}

- (BOOL)containsObjectForURLString:(NSString *)url {
    return [self.cache containsObjectForKey:url.md5String];
}

- (void)setData:(NSData *)data forURLString:(NSString *)url {
    [self.cache setObject:data forKey:url.md5String];
    NSLog(@"HDBaseWKWebViewPool 存储： %@  ",url.md5String);
}

- (NSData *)objectForURLString:(NSString *)url {
    return (id)[self.cache objectForKey:url.md5String];
}




@end
