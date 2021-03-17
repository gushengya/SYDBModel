//
//  SYDefineFile.h
//  Demo
//
//  Created by 谷胜亚 on 2021/2/2.
//  Copyright © 2021 gushengya. All rights reserved.
//

@protocol SYClassCache
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector;
+ (NSDictionary *)__SY_NestClassMap;;
@end
@protocol SYPropertyCache
@end

