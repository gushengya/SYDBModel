//
//  NSObject+SYDBExtension.m
//  
//
//  Created by 谷胜亚 on 2018/6/22.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "NSObject+SYDBExtension.h"

@implementation NSObject (SYPublic)

- (id)__SY_RemoveCannotSerializationPart
{
    if ([self isKindOfClass:[NSArray class]])
    {
        NSArray *tmpArr = (NSArray *)self;
        NSMutableArray *mul = [NSMutableArray array];
        for (id key in tmpArr)
        {
            if (![key __SY_RemoveCannotSerializationPart]) continue;
            [mul addObject:key];
        }
        return mul.count > 0 ? mul : nil;
    }
    else if ([self isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *tmpDic = (NSDictionary *)self;
        NSMutableDictionary *mul = [NSMutableDictionary dictionary];
        
        for (id key in tmpDic.allKeys)
        {
            id value = [tmpDic objectForKey:key];
            if (![key __SY_RemoveCannotSerializationPart]) continue;
            if (![value __SY_RemoveCannotSerializationPart]) continue;
            [mul setObject:value forKey:key];
        }
        return mul.allKeys.count > 0 ? mul : nil;
    }
    else if ([self isKindOfClass:[NSSet class]])
    {
        NSSet *tmpSet = (NSSet *)self;
        NSMutableSet *mul = [NSMutableSet set];
        for (id key in tmpSet)
        {
            if (![key __SY_RemoveCannotSerializationPart]) continue;
            [mul addObject:key];
        }
        return mul.count > 0 ? mul : nil;
    }
    else
    {
        NSError *error = nil; NSData *data = nil;
        NSArray *tmp = @[self];
        @try {             data = [NSJSONSerialization dataWithJSONObject:tmp options:NSJSONWritingPrettyPrinted error:&error];
            if (!error)
            {
                return self;
            }
        }
        @catch (NSException *e) {
            
        }
    }
    NSLog(@"%@", [NSString stringWithFormat:@"[%@]内存地址:%p,不能被序列化", [self class], self]);
    return nil;
}

@end




#import <objc/runtime.h>
#import "SYPropertyInfo.h"
#import "SYDBManager.h"
#import <UIKit/UIKit.h>

#pragma mark- NSObject自有属性信息的扩展
static const char SY_ALL_PROPERTY_INFO_DICTIONARY;
@implementation NSObject (SYPropertyInfo)

+ (NSDictionary *)__SY_AllPropertyInfo
{
    NSDictionary *dic = objc_getAssociatedObject(self, &SY_ALL_PROPERTY_INFO_DICTIONARY);
    if (!dic) {
        [self __SY_ConfigPropertyInfos];
    }
    return objc_getAssociatedObject(self, &SY_ALL_PROPERTY_INFO_DICTIONARY);
}

+ (void)__SY_ConfigPropertyInfos
{
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    
    NSScanner *scanner = nil; NSString *type = nil; Class class = self;
    
    while (class != NSObject.class)
    {
        unsigned int count;
        objc_property_t *list = class_copyPropertyList(class, &count);
        
        for (unsigned int i = 0; i < count; i++)
        {
            SYPropertyInfo *des = [[SYPropertyInfo alloc] init];
            
            objc_property_t property = list[i];
            
            NSString *name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            des.name = name;
            
            NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
            NSArray *keywords = [attributes componentsSeparatedByString:@","];
            des.attributes = attributes;
            
            if ([keywords containsObject:@"R"]) des.readOnly = YES;
            
            scanner = [NSScanner scannerWithString:attributes];
            [scanner scanUpToString:@"T" intoString:nil];
            [scanner scanString:@"T" intoString:nil];
            
            if ([scanner scanString:@"@\"" intoString:&type])             {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&type];
                
                des.variableType = SY_Variable_TYPE_OBJECTC;
                
                if ([type isEqualToString:@""])
                {
                    des.variableType = SY_Variable_TYPE_UNKNOW;                 }
                else
                {
                    des.ocType = NSClassFromString(type);
                    des.isMutable = ([type rangeOfString:@"Mutable"].location != NSNotFound);
                }
                
                NSString *protocolName = nil;
                while ([scanner scanString:@"<" intoString:nil])
                {
                    [scanner scanUpToString:@">" intoString:&protocolName];
                    
                    if (des.protocolList != nil)
                    {
                        [des.protocolList addObject:NSProtocolFromString(protocolName)];
                    }
                    else
                    {
                        des.protocolList = [NSMutableArray arrayWithObject:NSProtocolFromString(protocolName)];
                    }
                    
                    [scanner scanString:@">" intoString:nil];
                }
            }
            else if ([scanner scanString:@"@?" intoString:nil])
            {
                des.variableType = SY_Variable_TYPE_BLOCK;
            }
            else if ([scanner scanString:@"@" intoString:nil])
            {
                des.variableType = SY_Variable_TYPE_ID;
            }
            else if ([scanner scanString:@"{" intoString:&type])
            {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"="] intoString:&type];
                des.variableType = SY_Variable_TYPE_STUCT;
                des.stuctName = type;
            }
            else
            {
                [scanner scanUpToString:@"," intoString:&type];
                [self __SY_ConvertToBaseDataFromSign:type WithPropertyInfo:des];
                des.variableType = SY_Variable_TYPE_BASEDATA;
            }
            
            if (des && ![all objectForKey:des.name]) [all setValue:des forKey:des.name];
        }
        
        free(list);
        class = [class superclass];
    }
    
    objc_setAssociatedObject(self, &SY_ALL_PROPERTY_INFO_DICTIONARY, all, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (void)__SY_ConvertToBaseDataFromSign:(NSString *)type WithPropertyInfo:(SYPropertyInfo *)info
{
    if ([type isEqualToString:@"q"])     {
        info.basedataType = SY_BASEDATA_TYPE_INT64;
    }
    else if ([type isEqualToString:@"i"])     {
        info.basedataType = SY_BASEDATA_TYPE_INT32;
    }
    else if ([type isEqualToString:@"s"])     {
        info.basedataType = SY_BASEDATA_TYPE_INT16;
    }
    else if ([type isEqualToString:@"c"])     {
        info.basedataType = SY_BASEDATA_TYPE_INT8;
    }
    else if ([type isEqualToString:@"f"])     {
        info.basedataType = SY_BASEDATA_TYPE_FLOAT;
    }
    else if ([type isEqualToString:@"d"])     {
        info.basedataType = SY_BASEDATA_TYPE_DOUBLE;
    }
    else if ([type isEqualToString:@"B"])     {
        info.basedataType = SY_BASEDATA_TYPE_BOOL;
    }
    else {         info.basedataType = SY_BASEDATA_TYPE_UNKNOWN;//@"int";
    }
}

@end


#pragma mark- SQLite存储方向的扩展

static const char SY_NEST_PROPERTY_INFO_DICTIONARY;
static const char SY_CACHE_ENABLE_PROPERTY_INFO_DICTIONARY;

@implementation NSObject (SQLiteCache)

+ (NSDictionary *)__SY_NestPropertyInfo
{
    if (!objc_getAssociatedObject(self, &SY_NEST_PROPERTY_INFO_DICTIONARY)) {
        [self __SY_DataBaseConfigProperties];
    }
    return objc_getAssociatedObject(self, &SY_NEST_PROPERTY_INFO_DICTIONARY);
}

+ (NSDictionary *)__SY_CacheEnablePropertyInfo
{
    if (!objc_getAssociatedObject(self, &SY_CACHE_ENABLE_PROPERTY_INFO_DICTIONARY)) {
        [self __SY_DataBaseConfigProperties];
    }
    return objc_getAssociatedObject(self, &SY_CACHE_ENABLE_PROPERTY_INFO_DICTIONARY);
}

+ (void)__SY_DataBaseConfigProperties
{
    NSDictionary *tmpDic = [self __SY_AllPropertyInfo];
    NSMutableDictionary *allPropertyDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *nestPropertyDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *cachePropertyDic = [NSMutableDictionary dictionary];
    
    NSMutableDictionary *nestMapDic = [NSMutableDictionary dictionary];
    Class class = self;
    while (class != NSObject.class)
    {
        NSDictionary *tmp = [class __SY_NestClassMap];
        [nestMapDic addEntriesFromDictionary:tmp];
        class = [class superclass];
    }
    
    for (int i = 0; i < tmpDic.allKeys.count; i++)
    {
        NSString *name = tmpDic.allKeys[i];
        SYPropertyInfo *info = [tmpDic objectForKey:name];
        if ([self respondsToSelector:@selector(__SY_CacheEnableOfPropertyName:)])
        {
            info.cacheEnable = [self __SY_CacheEnableOfPropertyName:NSSelectorFromString(info.name)];
        }
        
        if ([info.protocolList containsObject:@protocol(SYPropertyCache)]) info.cacheEnable = YES;
        
        if (info.isReadOnly) info.cacheEnable = NO;
        
        info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_BLOB;// 二进制方式存储
        if (info.variableType == SY_Variable_TYPE_UNKNOW)
        {
            info.cacheEnable = NO;
        }
        else if (info.variableType == SY_Variable_TYPE_OBJECTC)
        {
            if ([info.ocType isSubclassOfClass:[NSString class]])
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_TEXT;// 字符串类型以text方式存储在sql中
            }
            else if ([info.ocType isSubclassOfClass:[NSNumber class]])
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_REAL;
            }
            else if ([info.ocType isSubclassOfClass:[NSDate class]])
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_REAL;
            }
            else if ([info.ocType isSubclassOfClass:[NSData class]])
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_BLOB;
            }
            else
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_BLOB;// 二进制方式存储
            }
        }
        else if (info.variableType == SY_Variable_TYPE_BASEDATA)
        {
            if (info.basedataType == SY_BASEDATA_TYPE_FLOAT || info.basedataType == SY_BASEDATA_TYPE_DOUBLE)
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_REAL;
            }
            else
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_INTEGER;
            }
        }
        else if (info.variableType == SY_Variable_TYPE_BLOCK)
        {
            info.cacheEnable = NO;
        }
        else if (info.variableType == SY_Variable_TYPE_STUCT)
        {
            if (![self __SY_SupportStuctOfType:info.stuctName])
            {
                info.cacheEnable = NO;
            }
            else
            {
                info.sqliteCacheType = SY_SQLITE_CACHE_TYPE_TEXT;
            }
        }
        else if (info.variableType == SY_Variable_TYPE_ID)
        {
            
        }
        
        info.cacheTypeInSQL = [self __SY_SQLiteColumnTypeOfCacheType:info.sqliteCacheType];
        
        if ([nestMapDic.allKeys containsObject:info.name])
        {
            Class nestClass = [nestMapDic objectForKey:info.name];
            
            if (nestClass && [nestClass respondsToSelector:@selector(__SY_DataBaseConfigProperties)])
            {
                info.associateClass = nestClass;
            }
            else
            {
                NSString *log = [NSString stringWithFormat:@"[%@]类对应的属性%@嵌套类发生错误", NSStringFromClass(class), info.name];
                NSAssert(NO, log);
            }
        }
        
        [allPropertyDic setObject:info forKey:info.name];
        if (info.cacheEnable) {
            [cachePropertyDic setObject:info forKey:info.name];
        }
        if (info.associateClass) {
            [nestPropertyDic setObject:info forKey:info.name];
        }
    }
    
    objc_setAssociatedObject(self, &SY_ALL_PROPERTY_INFO_DICTIONARY, allPropertyDic, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &SY_CACHE_ENABLE_PROPERTY_INFO_DICTIONARY, cachePropertyDic, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &SY_NEST_PROPERTY_INFO_DICTIONARY, nestPropertyDic, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (BOOL)__SY_SupportStuctOfType:(NSString *)type
{
    static NSArray *supportStuctList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportStuctList = @[@"CGRect", @"CGPoint", @"CGSize"];
    });
    return [supportStuctList containsObject:type];
}

+ (NSString *)__SY_SQLiteColumnTypeOfCacheType:(SY_SQLITE_CACHE_TYPE)type
{
    switch (type) {
        case SY_SQLITE_CACHE_TYPE_BLOB: return @"BLOB";
        case SY_SQLITE_CACHE_TYPE_NULL: return @"NULL";
        case SY_SQLITE_CACHE_TYPE_REAL: return @"REAL";
        case SY_SQLITE_CACHE_TYPE_TEXT: return @"TEXT";
        case SY_SQLITE_CACHE_TYPE_INTEGER: return @"INTEGER";
        default: return @"BLOB";
    }
}

#pragma mark- 遵循的协议内容
+ (NSDictionary *)__SY_NestClassMap
{
    return nil;
}

+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    return NO;
}

@end

