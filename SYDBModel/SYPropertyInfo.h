//
//  SYPropertyInfo.h
//
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//  类的变量的信息

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, SY_BASEDATA_TYPE)
{
    SY_BASEDATA_TYPE_UNKNOWN,
    SY_BASEDATA_TYPE_INT64,
    SY_BASEDATA_TYPE_INT32,
    SY_BASEDATA_TYPE_INT16,
    SY_BASEDATA_TYPE_INT8,
    SY_BASEDATA_TYPE_FLOAT,
    SY_BASEDATA_TYPE_DOUBLE,
    SY_BASEDATA_TYPE_BOOL,
};

typedef NS_ENUM(NSUInteger, SY_AUTHORIZED_STUCT_TYPE)
{
    SY_AUTHORIZED_STUCT_TYPE_CGRECT,
    SY_AUTHORIZED_STUCT_TYPE_CGPOINT,
    SY_AUTHORIZED_STUCT_TYPE_CGSIZE,
};



typedef NS_ENUM(NSUInteger, SY_SQLITE_CACHE_TYPE)
{
    SY_SQLITE_CACHE_TYPE_INTEGER,
    SY_SQLITE_CACHE_TYPE_TEXT,
    SY_SQLITE_CACHE_TYPE_REAL,
    SY_SQLITE_CACHE_TYPE_BLOB,
    SY_SQLITE_CACHE_TYPE_NULL,
};

typedef NS_ENUM(NSUInteger, SY_Variable_TYPE)
{
    SY_Variable_TYPE_UNKNOW,
    SY_Variable_TYPE_OBJECTC,
    SY_Variable_TYPE_BASEDATA,
    SY_Variable_TYPE_BLOCK,
    SY_Variable_TYPE_STUCT,
    SY_Variable_TYPE_ID,
};

@interface SYPropertyInfo : NSObject

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign, getter=isReadOnly) BOOL readOnly;

@property (nonatomic, assign) BOOL isMutable;

@property (nonatomic, assign) Class ocType;

@property (nonatomic, assign) SY_Variable_TYPE variableType;

@property (nonatomic, copy) NSString *attributes;

@property (nonatomic, strong) NSMutableArray *protocolList;

@property (nonatomic, copy) NSString *stuctName;

@property (nonatomic, assign) SY_BASEDATA_TYPE basedataType;

#pragma mark- 数据库扩展
@property (nonatomic, assign) Class associateClass;

@property (nonatomic, assign) BOOL cacheEnable;

@property (nonatomic, assign) SY_SQLITE_CACHE_TYPE sqliteCacheType;

@property (nonatomic, copy) NSString *cacheTypeInSQL;

@end
