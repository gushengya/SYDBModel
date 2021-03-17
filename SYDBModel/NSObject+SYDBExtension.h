//
//  NSObject+SYDBExtension.h
//  
//
//  Created by 谷胜亚 on 2018/6/22.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SYDefineFile.h"

#pragma mark- 公用方法
@interface NSObject (SYPublic)

- (id)__SY_RemoveCannotSerializationPart;

@end

#pragma mark- NSObject自有变量的扩展
@interface NSObject (SYPropertyInfo)

+ (NSDictionary *)__SY_AllPropertyInfo;

@end

@interface NSObject (SQLiteCache)<SYClassCache>

+ (NSDictionary *)__SY_NestPropertyInfo;

+ (NSDictionary *)__SY_CacheEnablePropertyInfo;

@end

