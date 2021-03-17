//
//  SYDBManager.h
//  
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//  方便数据库信息管理

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>

@interface SYDBManager : NSObject

@property (nonatomic, strong, readonly) FMDatabaseQueue *databaseQueue;

@property (nonatomic, copy) NSString *dbFilePath;

+ (instancetype)manager;

@end
