//
//  SYDBManager.m
//
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "SYDBManager.h"
@interface SYDBManager()

@property (nonatomic, strong) FMDatabaseQueue *databaseQueue;

@end

@implementation SYDBManager

+ (instancetype)manager
{
    static SYDBManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[SYDBManager alloc] init];
    });
    
    return _instance;
}

- (FMDatabaseQueue *)databaseQueue
{
    if (!_databaseQueue) {
        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbFilePath];
    }
    
    return _databaseQueue;
}

- (NSString *)dbFilePath
{
    if (!_dbFilePath) {
        NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        
        docsdir = [docsdir stringByAppendingPathComponent:@"SYDBModel"];
        NSFileManager *filemanage = [NSFileManager defaultManager];
        BOOL isDir;
        BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
        
        if (!exit || !isDir)
        {
            [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        _dbFilePath = [docsdir stringByAppendingPathComponent:@"sydb.sqlite"];
    }
    NSLog(@"[SYDBModel]数据库文件路径:(%@)", _dbFilePath);
    return _dbFilePath;
}


@end
