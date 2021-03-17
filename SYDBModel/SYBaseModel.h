//
//  SYBaseModel.h
//  Demo
//
//  Created by 谷胜亚 on 2021/1/27.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SYDefineFile.h"
NS_ASSUME_NONNULL_BEGIN

@interface SYBaseModel : NSObject<SYClassCache, NSCopying>

- (BOOL)__SY_Insert;

- (BOOL)__SY_Delete;

+ (BOOL)__SY_DeleteWithCondition:(NSString * __nullable)condition;

- (BOOL)__SY_Update;

+ (NSArray *)__SY_SelectAll;

+ (NSArray *)__SY_SelectWithCondition:(NSString * __nullable)condition;
@end

NS_ASSUME_NONNULL_END
