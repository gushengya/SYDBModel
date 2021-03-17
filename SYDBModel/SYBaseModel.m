//
//  SYBaseModel.m
//  Demo
//
//  Created by 谷胜亚 on 2021/1/27.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import "SYBaseModel.h"
#import "NSObject+SYDBExtension.h"
#import "SYDBManager.h"
#import "SYPropertyInfo.h"
#import <UIKit/UIKit.h>
static NSString *const SY_SQLITE_PRIMARY_KEY = @"SY_SQLITE_PRIMARY_KEY";
static NSString *const SY_SQLITE_SUPERIOR_TABLE_HEADNODE = @"SY_SQLITE_SUPERIOR_TABLE_HEADNODE";
static NSString *const SY_SQLITE_SPLIT_KEY = @"SY_SQLITE_SPLIT_KEY";
static NSMutableArray *instanceClasses;

@interface SYBaseModel ()

@property (nonatomic, assign, readonly) long long primaryKey;

@property (nonatomic, copy, readonly) NSString *superiorHeadNode;

@end

@implementation SYBaseModel

#pragma mark- 数据库操作

- (BOOL)__SY_Insert
{
    __block BOOL result = YES;
    [[SYDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self __SY_InsertWithSuperiorHeadNode:nil database:db rollback:rollback];
    }];
    
    return result;
}

- (BOOL)__SY_InsertWithSuperiorHeadNode:(NSString *)superiorHeadNode database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    if (![self.class __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return NO;
    
    __block BOOL result = YES;
    
    [self __SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:superiorHeadNode completionHandler:^(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues) {
        NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", NSStringFromClass([self class]), cacheEnablePropertyNameSQLiteString, cacheEnablePropertySignSQLiteString];
        
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:cacheEnablePropertyValues];
        if (isSuccess)
        {
            int64_t pkID = db.lastInsertRowId;
            self->_primaryKey = pkID;
            self->_superiorHeadNode = superiorHeadNode;
            [self __SY_HandleNestDataWithRecursionOperation:^(SYPropertyInfo *info, id recursionValue) {
                if ([recursionValue isKindOfClass:[NSDictionary class]])
                {
                    for (id keyOfDic in [recursionValue allKeys])
                    {
                        id valueOfDic = [recursionValue objectForKey:keyOfDic];
                        NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:keyOfDic];
                        [valueOfDic __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                    }
                }
                else if ([recursionValue isKindOfClass:[NSArray class]] || [recursionValue isKindOfClass:[NSSet class]])
                {
                    for (id valueOfArr in recursionValue)
                    {
                        NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:nil];
                        [valueOfArr __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                    }
                }
                else if (recursionValue)
                {
                    NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:nil];
                    [recursionValue __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                }
                else                 {
                }
            }];
        }
        else         {
            NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的非嵌套部分插入数据失败:(%@)", NSStringFromClass([self class]), sqlString];
            NSLog(@"%@", logKey);
            *rollback = YES;
            result = NO;
        }
        
        if (!result)
        {
            self->_primaryKey = 0;
        }
    }];
    
    return result;
}

- (BOOL)__SY_Delete
{
    if (self.primaryKey <= 0) return NO;
    __block BOOL result = YES;
    [[SYDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *str = [self.class __SY_GetTheStringAfterTheTableNameWithCondition:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %lld;", NSStringFromClass(self.class), SY_SQLITE_PRIMARY_KEY, self.primaryKey]];
        result = [self.class __SY_DeleteWithCondition:str fromTableClass:self.class database:db rollback:rollback];
    }];
    return result;
}

+ (BOOL)__SY_DeleteWithCondition:(NSString * __nullable)condition
{
    __block BOOL result = YES;
    [[SYDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        NSString *str = [self __SY_GetTheStringAfterTheTableNameWithCondition:condition];
        result = [self __SY_DeleteWithCondition:str fromTableClass:self database:db rollback:rollback];
    }];
    
    return result;
}

+ (BOOL)__SY_DeleteWithWillDeletedModel:(SYBaseModel *)willDeletedModel database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    if (willDeletedModel.primaryKey <= 0) return NO;
    
    BOOL result = YES;
    NSDictionary *nestPropertyList = [willDeletedModel.class __SY_NestPropertyInfo];
    for (NSString *propertyName in nestPropertyList.allKeys)
    {
        SYPropertyInfo *info = [nestPropertyList objectForKey:propertyName];
        
        id value = [willDeletedModel valueForKey:propertyName];
        
        if (!value || [value isKindOfClass:[NSNull class]]) continue;
        if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSSet class]])
        {
            for (SYBaseModel *modelOfArr in value)
            {
                if (![self __SY_DeleteWithWillDeletedModel:modelOfArr database:db rollback:rollback]) result = NO;
            }
        }
        else if ([info.ocType isSubclassOfClass:[NSDictionary class]])
        {
            for (SYBaseModel *modelOfDic in [value allValues])
            {
                if (![self __SY_DeleteWithWillDeletedModel:modelOfDic database:db rollback:rollback]) result = NO;
            }
        }
        else
        {
            if (![self __SY_DeleteWithWillDeletedModel:value database:db rollback:rollback]) result = NO;
        }
    }
    
    if (!result)
    {
        *rollback = YES;
        return NO;
    }
    
    NSString *deleteString = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %lld;", NSStringFromClass(willDeletedModel.class), SY_SQLITE_PRIMARY_KEY, willDeletedModel.primaryKey];
    
    BOOL isSuccess = [db executeUpdate:deleteString];
    if (!isSuccess)
    {
        NSAssert(NO, @"执行该删除语句出现错误:%@", deleteString);
        result = NO;
        *rollback = YES;
    }
    
    return result;
}

+ (BOOL)__SY_DeleteWithCondition:(NSString *)condition fromTableClass:(Class)tableClass database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    if (![tableClass __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return NO;
    
    BOOL result = YES;
    
    NSString *selectString = [NSString stringWithFormat:@"SELECT * FROM %@ %@", NSStringFromClass(tableClass), condition];
    
    NSArray *resultArray = [tableClass __SY_SelectWithCondition:selectString database:db rollback:rollback];
    
    for (SYBaseModel *model in resultArray)
    {
        result = [self __SY_DeleteWithWillDeletedModel:model database:db rollback:rollback];
    }
    
    return result;
}

- (BOOL)__SY_Update
{
    if (self.primaryKey <= 0) return NO;
    __block BOOL result = YES;
    __weak typeof(self) weakSelf = self;
    [[SYDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        NSArray *data = [weakSelf.class __SY_SelectWithCondition:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = %lld;", NSStringFromClass([weakSelf class]), SY_SQLITE_PRIMARY_KEY, weakSelf.primaryKey] database:db rollback:rollback];
        
        if (data.count > 0)
        {
            if (![self.class __SY_UpdateModel:data.firstObject toModel:weakSelf WithDatabase:db rollback:rollback]) result = NO;
        }
        else result = NO;
    }];
    
    return result;
}

+ (BOOL)__SY_UpdateModel:(SYBaseModel *)model toModel:(SYBaseModel *)toModel WithDatabase:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    __block BOOL result = YES;
    if (model.primaryKey <= 0) return NO;
    
    [toModel __SY_HandleNestDataWithRecursionOperation:^(SYPropertyInfo *info, id recursionValue) {
        
        id valueOfModel = [model valueForKey:info.name];
        
        if ([info.ocType isSubclassOfClass:[NSDictionary class]])
        {
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                NSDictionary *dicOfNest = valueOfModel;
                for (SYBaseModel *valueOfDic in dicOfNest.allValues)
                {
                    if (![valueOfDic isKindOfClass:info.associateClass]) continue;
                    
                    if (![self __SY_DeleteWithWillDeletedModel:valueOfDic database:db rollback:rollback]) result = NO;
                }
                
                [model setValue:nil forKey:info.name];
            }
            else
            {
                for (id keyOfDic in recursionValue)
                {
                    id valueOfDic = [recursionValue objectForKey:keyOfDic];
                    
                    if ([[valueOfModel allKeys] containsObject:keyOfDic])
                    {
                        id valueOfDicInModel = [valueOfModel objectForKey:keyOfDic];
                        if (![self __SY_UpdateModel:valueOfDicInModel toModel:valueOfDic WithDatabase:db rollback:rollback]) result = NO;
                    }
                    else
                    {
                        NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:keyOfDic];
                        if (![valueOfDic __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
                    }
                }
                
                NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", [recursionValue allKeys]];
                NSArray *needDeleteKeys = [[valueOfModel allKeys] filteredArrayUsingPredicate:filterPredicate];
                
                for (id keyOfNeedDeleteKeys in needDeleteKeys)
                {
                    id tmpValue = [valueOfModel objectForKey:keyOfNeedDeleteKeys];
                    if (![self __SY_DeleteWithWillDeletedModel:tmpValue database:db rollback:rollback]) result = NO;
                }
                
            }
        }
        else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSSet class]])
        {
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                NSArray *arrOfNest = valueOfModel;
                for (SYBaseModel *valueOfDic in arrOfNest)
                {
                    if (![valueOfDic isKindOfClass:info.associateClass]) continue;
                    
                    if (![self __SY_DeleteWithWillDeletedModel:valueOfDic database:db rollback:rollback]) result = NO;
                }
                
                [model setValue:nil forKey:info.name];
            }
            else
            {
                for (int i = 0; i < [recursionValue count]; i++)
                {
                    SYBaseModel *itemOfNewArr = [recursionValue objectAtIndex:i];
                    
                    if (i < [valueOfModel count])
                    {
                        SYBaseModel *itemOfOldArr = [valueOfModel objectAtIndex:i];
                        if (![self __SY_UpdateModel:itemOfOldArr toModel:itemOfNewArr WithDatabase:db rollback:rollback]) result = NO;
                    }
                    else
                    {
                        NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:nil];
                        if (![itemOfNewArr __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
                    }
                }
                
                if ([valueOfModel count] > [recursionValue count])
                {
                    for (NSUInteger i = [valueOfModel count] - 1; i >= [recursionValue count]; i--)
                    {
                        SYBaseModel *itemOfNewArr = [valueOfModel objectAtIndex:i];
                        if (![self __SY_DeleteWithWillDeletedModel:itemOfNewArr database:db rollback:rollback]) result = NO;
                    }
                }
                
                
            }
        }
        else
        {
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                SYBaseModel *modelOfNest = valueOfModel;
                
                if (modelOfNest)
                {
                    if (![self __SY_DeleteWithWillDeletedModel:modelOfNest database:db rollback:rollback]) result = NO;
                }
                
                [model setValue:nil forKey:info.name];
            }
            else if (!valueOfModel || [valueOfModel isKindOfClass:[NSNull class]])
            {
                NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:nil];
                if (![recursionValue __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
            }
            else
            {
                if (![self __SY_UpdateModel:valueOfModel toModel:recursionValue WithDatabase:db rollback:rollback]) result = NO;
            }
        }
    }];
    
    if (!result) return NO;
    
    [toModel __SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:model.superiorHeadNode completionHandler:^(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues) {
        
        NSString *sqlString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = %lld;", NSStringFromClass([model class]), cacheEnablePropertyNameAndSign, SY_SQLITE_PRIMARY_KEY, model.primaryKey];
        
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:cacheEnablePropertyValues];
        if (!isSuccess)
        {
            NSLog(@"更新语句发生错误:%@", sqlString);
            *rollback = YES;
            result = NO;
        }
    }];
    
    return result;
}

+ (NSArray *)__SY_SelectAll
{
    NSString *selectStr = [NSString stringWithFormat:@"SELECT * FROM %@;", NSStringFromClass(self)];
    return [self __SY_SelectWithCondition:selectStr];
}

+ (NSArray *)__SY_SelectWithCondition:(NSString * __nullable)condition
{
    __block NSArray *result = nil;
    [[SYDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *str = condition;
        
        str = [self __SY_GetTheStringAfterTheTableNameWithCondition:str];
        
        str = [NSString stringWithFormat:@"SELECT * FROM %@ %@", NSStringFromClass(self), str];
        
        result = [self __SY_SelectWithCondition:str database:db rollback:rollback];
    }];
    
    return result;
}

+ (NSArray *)__SY_SelectWithCondition:(NSString *)condition database:(FMDatabase *_Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    NSMutableArray *resultList = [NSMutableArray array];
    if (![self __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return resultList;
    FMResultSet *resultSet = [db executeQuery:condition];
    
    if (resultSet == nil) return resultList;
    
    NSDictionary *cacheDic = [self __SY_CacheEnablePropertyInfo];
    
    while ([resultSet next])     {
        NSDictionary *dic = [resultSet resultDictionary];
        
        SYBaseModel *model = [[self alloc] init];
        
        long long primaryKey = [[dic valueForKey:SY_SQLITE_PRIMARY_KEY] longLongValue];
        
        NSString *superiorHeadNode = [dic valueForKey:SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
        if ([superiorHeadNode isKindOfClass:[NSNull class]]) superiorHeadNode = nil;
        
        for (id key in dic.allKeys)
        {
            id value = dic[key];
            SYPropertyInfo *info = cacheDic[key];
            
            if (info.variableType == SY_Variable_TYPE_UNKNOW)
            {
            }
            else if (info.variableType == SY_Variable_TYPE_OBJECTC)
            {
                if (info.associateClass)                 {
                    if ([info.ocType isSubclassOfClass:[NSDictionary class]])                     {
                        if (!value || [value isKindOfClass:[NSNull class]]) continue;
                        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                        NSError *error;
                        NSArray *nestArray = nil;
                        @try {
                            nestArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                            if (!error)
                            {
                                NSMutableDictionary *mulDic = [NSMutableDictionary dictionary];
                                for (id key in nestArray)
                                {
                                    NSString *nextSelectStr = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@';", info.associateClass, SY_SQLITE_SUPERIOR_TABLE_HEADNODE, [self __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:primaryKey keyOfDict:key]];
                                    
                                    NSArray *nestArrResult = [info.associateClass __SY_SelectWithCondition:nextSelectStr database:db rollback:rollback];
                                    if (nestArrResult.count > 0)
                                    {
                                        [mulDic setObject:nestArrResult.firstObject forKey:key];
                                    }
                                }
                                if (mulDic.allKeys.count > 0)
                                {
                                    [model setValue:mulDic forKey:info.name];
                                }
                            }
                        } @catch (NSException *exception) {
                            
                        } @finally {
                            
                        }
                    }
                    else
                    {
                        NSString *nextSelectStr = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@';", info.associateClass, SY_SQLITE_SUPERIOR_TABLE_HEADNODE, [self __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:primaryKey keyOfDict:nil]];
                        
                        NSArray *nestArrResult = [info.associateClass __SY_SelectWithCondition:nextSelectStr database:db rollback:rollback];
                        if (nestArrResult.count > 0)
                        {
                            if ([info.ocType isSubclassOfClass:[NSArray class]])                             {
                                [model setValue:nestArrResult forKey:info.name];
                            }
                            else if ([info.ocType isSubclassOfClass:[NSSet class]])
                            {
                                [model setValue:[NSSet setWithArray:nestArrResult] forKey:info.name];
                            }
                            else
                            {
                                [model setValue:nestArrResult.firstObject forKey:info.name];
                            }
                        }
                    }
                }
                else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSDictionary class]] || [info.ocType isSubclassOfClass:[NSSet class]])                 {
                    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *error;
                    id objc = nil;
                    @try {
                        objc = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                        if (!error)
                        {
                            [model setValue:objc forKey:info.name];
                        }
                    } @catch (NSException *exception) {
                        
                    } @finally {
                        
                    }
                }
                else if ([info.ocType isSubclassOfClass:[NSDate class]])                 {
                    if (![value isKindOfClass:[NSNumber class]]) continue;
                    NSTimeInterval interval = [value doubleValue];
                    if (interval <= 0) continue;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
                    if (date) [model setValue:date forKey:info.name];
                }
                else if ([info.ocType isSubclassOfClass:[NSData class]])
                {
                    if (![value isKindOfClass:[NSData class]]) continue;
                    [model setValue:value forKey:info.name];
                }
                else                 {
                    [model setValue:value forKey:info.name];
                }
            }
            else if (info.variableType == SY_Variable_TYPE_BASEDATA)
            {
                [model setValue:value forKey:info.name];
            }
            else if (info.variableType == SY_Variable_TYPE_BLOCK)
            {
            }
            else if (info.variableType == SY_Variable_TYPE_STUCT)
            {
                NSValue *stuctValue = nil;
                if ([info.stuctName isEqualToString:@"CGRect"])
                {
                    stuctValue = [NSValue valueWithCGRect:CGRectFromString(value)];
                }
                else if ([info.stuctName isEqualToString:@"CGSize"])
                {
                    stuctValue = [NSValue valueWithCGSize:CGSizeFromString(value)];
                }
                else if ([info.stuctName isEqualToString:@"CGPoint"])
                {
                    stuctValue = [NSValue valueWithCGPoint:CGPointFromString(value)];
                }
                if (stuctValue)
                {
                    [model setValue:stuctValue forKey:info.name];
                }
            }
            else if (info.variableType == SY_Variable_TYPE_ID)
            {
                [model setValue:value forKey:info.name];
            }
        }
        
        model->_primaryKey = primaryKey;
        model->_superiorHeadNode = superiorHeadNode;
        [resultList addObject:model];
    }
    
    return resultList;
}

#pragma mark- 类方法
+ (BOOL)__SY_ConfigSQLiteTableWithDB:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    BOOL result = YES;
    if ([instanceClasses containsObject:NSStringFromClass(self)]) return result;
    instanceClasses = [NSMutableArray arrayWithArray:instanceClasses];
    [instanceClasses addObject:NSStringFromClass(self)];
    
    BOOL isExist = [db tableExists:NSStringFromClass(self)];

    if (isExist)
    {
        NSLog(@"[%@]表已存在无需创建", NSStringFromClass([self class]));
        NSMutableArray *columnNames = [NSMutableArray array];

        FMResultSet *resultSet = [db getTableSchema:NSStringFromClass(self)];
        while ([resultSet next]) {
            NSString *columnName = [resultSet stringForColumn:@"name"];
            [columnNames addObject:columnName];
        }

        NSDictionary *storeDic = [self __SY_CacheEnablePropertyInfo];
        NSArray *propertyNameList = storeDic.allKeys;

        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
        NSArray *needSavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];

        if (!needSavedProperties || needSavedProperties.count == 0) return result;

        for (NSString *columnName in needSavedProperties)
        {
            SYPropertyInfo *p = storeDic[columnName];

            NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", NSStringFromClass(self), columnName, p.cacheTypeInSQL];
            BOOL success = [db executeUpdate:sqlString];
            if (success)
            {
                NSLog(@"[%@]表增加字段成功语句为:(%@)", NSStringFromClass(self), sqlString);
            }
            else
            {
                NSLog(@"[%@]表增加字段失败语句为:(%@)", NSStringFromClass(self), sqlString);
                *rollback = YES; return NO;
            }
        }
    }
    else
    {
        NSString *propertySQLString = [self __SY_GetPropertyNameAndSQLiteTypeStringWhileCreateTable];

        if ([propertySQLString isEqualToString:@""])
        {
            NSAssert(NO, @"未添加任何需保存的属性");
            *rollback = YES; return NO;
        }

        NSString *associatedColumn = [NSString stringWithFormat:@"%@ %@", SY_SQLITE_SUPERIOR_TABLE_HEADNODE, @"TEXT"];

        NSString *primaryKey = [NSString stringWithFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT", SY_SQLITE_PRIMARY_KEY];

        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@,%@,%@);", NSStringFromClass(self), primaryKey, associatedColumn, propertySQLString];

        BOOL isSuccess = [db executeUpdate:sql];
        if (!isSuccess)
        {
            NSLog(@"[%@]表创建失败语句为:(%@)", NSStringFromClass(self), sql);
            *rollback = YES; return NO;
        }
        else
        {
            NSLog(@"[%@]表创建成功语句为:(%@)", NSStringFromClass(self), sql);
        }
    }
    return result;
}

+ (NSString *)__SY_GetPropertyNameAndSQLiteTypeStringWhileCreateTable
{
    NSMutableString *str = [NSMutableString string];
    NSDictionary *dic = [self __SY_CacheEnablePropertyInfo];
    
    for (SYPropertyInfo *p in dic.allValues)
    {
        [str appendFormat:@"%@ %@,", p.name, p.cacheTypeInSQL];
    }
    
    if ([str hasSuffix:@","])
    {
        [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
    }
    
    return str.copy;
}

+ (NSString *)__SY_GetTheStringAfterTheTableNameWithCondition:(NSString *)condition
{
    if (!condition || ![condition isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@" WHERE %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    condition = [condition stringByReplacingOccurrencesOfString:@";" withString:@""];
    
    NSRange range = [[[@" " stringByAppendingString:condition] lowercaseString] rangeOfString:@" where "];
    
    if (range.location == NSNotFound) return [NSString stringWithFormat:@" WHERE %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    condition = [condition substringFromIndex:range.location];
    
    NSRange headNodeRange = [[[@" " stringByAppendingString:condition] lowercaseString] rangeOfString:[[NSString stringWithFormat:@" %@ ", SY_SQLITE_SUPERIOR_TABLE_HEADNODE] lowercaseString]];
    
    if (headNodeRange.location == NSNotFound) return [condition stringByAppendingString:[NSString stringWithFormat:@" AND %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE]];
    
    return [[condition stringByReplacingOccurrencesOfString:@";" withString:@""] stringByAppendingString:@";"];
}

+ (NSString *)__SY_SQLiteStringBeforeAppendWildcardOfString:(NSString *)string
{
    NSString *right = [string lowercaseString];
    NSRange range = [right rangeOfString:@" like "];
    if (range.location == NSNotFound) return string;
    
    NSString *left = [string substringToIndex:range.location];
    right = [string substringFromIndex:range.location];
    
    right = [right stringByReplacingOccurrencesOfString:@"[" withString:@"[[]"];
    right = [right stringByReplacingOccurrencesOfString:@"_" withString:@"[_]"];
    right = [right stringByReplacingOccurrencesOfString:@"%" withString:@"[%]"];
    
    return [left stringByAppendingString:right];
}

+ (NSString *)__SY_GetSuperiorHeadNodeWithPropertyName:(NSString *)name primaryKey:(long long)primaryKey keyOfDict:(id)key
{
    NSString *result = [NSString stringWithFormat:@"%@%@%@%@%lld", NSStringFromClass(self), SY_SQLITE_SPLIT_KEY, name, SY_SQLITE_SPLIT_KEY, primaryKey];
    if (key && ![key isKindOfClass:[NSNull class]]) {
        Class keyClass = [key class];
        Class baseClass = keyClass;
        while (keyClass != [NSObject class]) {
            baseClass = keyClass;
            keyClass = [keyClass superclass];
        }
        result = [result stringByAppendingFormat:@"%@%@%@%@", SY_SQLITE_SPLIT_KEY, NSStringFromClass(baseClass),SY_SQLITE_SPLIT_KEY, key];
    }
    return result;
}

#pragma mark- 实例方法

- (id)__SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:(SYPropertyInfo *)info
{
    id valueOfProperty = [self valueForKey:info.name];
    
    if (!info.cacheEnable || !info.associateClass) return nil;
    
    if (!valueOfProperty || [valueOfProperty isKindOfClass:[NSNull class]]) return nil;
    
    if ([info.ocType isSubclassOfClass:[NSDictionary class]])     {
        if (![valueOfProperty isKindOfClass:[NSDictionary class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        NSMutableDictionary *mul = [NSMutableDictionary dictionary];
        for (id keyOfDic in [valueOfProperty allKeys])
        {
            if (![keyOfDic __SY_RemoveCannotSerializationPart]) continue;
            id valueOfDic = [valueOfProperty objectForKey:keyOfDic];
            if (![valueOfDic isKindOfClass:info.associateClass]) continue;
            [mul setObject:valueOfDic forKey:keyOfDic];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:[NSArray class]])     {
        if (![valueOfProperty isKindOfClass:[NSArray class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        NSMutableArray *mul = [NSMutableArray array];
        for (id valueOfArr in valueOfProperty)
        {
            if (![valueOfArr isKindOfClass:info.associateClass]) continue;
            [mul addObject:valueOfArr];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:[NSSet class]])     {
        if (![valueOfProperty isKindOfClass:[NSSet class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        NSMutableSet *mul = [NSMutableSet set];
        for (id valueOfArr in valueOfProperty)
        {
            if (![valueOfArr isKindOfClass:info.associateClass]) continue;
            [mul addObject:valueOfArr];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:info.associateClass])     {
        if (![valueOfProperty isKindOfClass:info.associateClass])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        return valueOfProperty;
    }
    
    return nil;
}

- (void)__SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:(NSString *)superiorHeadNode completionHandler:(void(^)(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues))completionHandler
{
    NSDictionary *cacheDic = [[self class] __SY_CacheEnablePropertyInfo];
    
    NSMutableString *cacheEnablePropertyNameSQLiteString = [NSMutableString string];
    
    NSMutableString *cacheEnablePropertySignSQLiteString = [NSMutableString string];
    
    NSMutableArray *cacheEnablePropertyValues = [NSMutableArray array];
    
    NSMutableString *cacheEnablePropertyNameAndSign = [NSMutableString string];
    
    [cacheEnablePropertyNameSQLiteString appendFormat:@"%@,", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    if (superiorHeadNode)
    {
        [cacheEnablePropertySignSQLiteString appendFormat:@"?,"];
        [cacheEnablePropertyValues addObject:superiorHeadNode];
    }
    else
    {
        [cacheEnablePropertySignSQLiteString appendFormat:@"null,"];
    }
    
    [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@,", SY_SQLITE_SUPERIOR_TABLE_HEADNODE, superiorHeadNode ? @"?" : @"null"];
    
    for (SYPropertyInfo *info in cacheDic.allValues)
    {
        id value = [self valueForKey:info.name];
        [cacheEnablePropertyNameSQLiteString appendFormat:@"%@,", info.name];
        if (!value || [value isKindOfClass:[NSNull class]])
        {
            [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@,", info.name, @"null"];
            [cacheEnablePropertySignSQLiteString appendString:@"null,"];continue;
        }
        
        NSString *sign = @"null,";
        
        if (info.variableType == SY_Variable_TYPE_UNKNOW)         {
        }
        else if (info.variableType == SY_Variable_TYPE_OBJECTC)         {
            if (info.associateClass)
            {
                if ([info.ocType isSubclassOfClass:[NSDictionary class]])
                {
                    if ([value isKindOfClass:[NSDictionary class]])
                    {
                        NSDictionary *mul = [self __SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:info];
                        NSArray *allKeys = [mul allKeys];
                        NSError *error = nil; NSData *data = nil;
                        @try {                             data = [NSJSONSerialization dataWithJSONObject:allKeys options:NSJSONWritingPrettyPrinted error:&error];
                            if (!error) {
                                NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                sign = @"?,";
                                [cacheEnablePropertyValues addObject:jsonStr];
                            }
                        } @catch (NSException *e) {}
                    }
                }
            }
            else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSDictionary class]] || [info.ocType isSubclassOfClass:[NSSet class]])
            {
                value = [value __SY_RemoveCannotSerializationPart];
                
                NSError *error = nil; NSData *data = nil;
                @try {                     data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                    if (!error) {
                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        sign = @"?,";
                        [cacheEnablePropertyValues addObject:jsonStr];
                    }
                } @catch (NSException *e) {}
            }
            else if ([info.ocType isSubclassOfClass:[NSDate class]])             {
                if ([value isKindOfClass:[NSDate class]])
                {
                    NSTimeInterval interval = [value timeIntervalSince1970];
                    
                    [cacheEnablePropertyValues addObject:[NSNumber numberWithDouble:interval]];
                    sign = @"?,";
                }
            }
            else if ([info.ocType isSubclassOfClass:[NSNumber class]])
            {
                if ([value isKindOfClass:[NSNumber class]])
                {
                    [cacheEnablePropertyValues addObject:value];
                    sign = @"?,";
                }
            }
            else if ([info.ocType isSubclassOfClass:[NSData class]])
            {
                if ([value isKindOfClass:[NSData class]])
                {
                    [cacheEnablePropertyValues addObject:value];
                    sign = @"?,";
                }
            }
            else
            {
            }
        }
        else if (info.variableType == SY_Variable_TYPE_BASEDATA)
        {
            [cacheEnablePropertyValues addObject:value];
            sign = @"?,";
        }
        else if (info.variableType == SY_Variable_TYPE_BLOCK)
        {
            
        }
        else if (info.variableType == SY_Variable_TYPE_STUCT)
        {
            NSString *sel = [info.stuctName stringByAppendingString:@"Value"];
            if ([value respondsToSelector:NSSelectorFromString(sel)])
            {
                NSString *stuctToString = nil;
                if ([info.stuctName isEqualToString:@"CGRect"])
                {
                    stuctToString = NSStringFromCGRect([value CGRectValue]);
                }
                else if ([info.stuctName isEqualToString:@"CGPoint"])
                {
                    stuctToString = NSStringFromCGPoint([value CGPointValue]);
                }
                else if ([info.stuctName isEqualToString:@"CGSize"])
                {
                    stuctToString = NSStringFromCGSize([value CGSizeValue]);
                }
                if (stuctToString)
                {
                    [cacheEnablePropertyValues addObject:stuctToString];
                    sign = @"?,";
                }
            }
            else
            {
                
            }
        }
        else if (info.variableType == SY_Variable_TYPE_ID)
        {
        }

        [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@", info.name, sign];
        [cacheEnablePropertySignSQLiteString appendString:sign];
    }
            
    if (cacheEnablePropertyNameSQLiteString.length > 0)
    {
        [cacheEnablePropertyNameSQLiteString deleteCharactersInRange:NSMakeRange(cacheEnablePropertyNameSQLiteString.length - 1, 1)];
    }
    if (cacheEnablePropertySignSQLiteString.length > 0)
    {
        [cacheEnablePropertySignSQLiteString deleteCharactersInRange:NSMakeRange(cacheEnablePropertySignSQLiteString.length - 1, 1)];
    }
    if (cacheEnablePropertyNameAndSign.length > 0)
    {
        [cacheEnablePropertyNameAndSign deleteCharactersInRange:NSMakeRange(cacheEnablePropertyNameAndSign.length - 1, 1)];
    }
    
    if (completionHandler) {
        completionHandler(cacheEnablePropertyNameSQLiteString, cacheEnablePropertySignSQLiteString, cacheEnablePropertyNameAndSign, cacheEnablePropertyValues);
    }
}

- (void)__SY_HandleNestDataWithRecursionOperation:(void(^)(SYPropertyInfo *info, id recursionValue))operation
{
    NSDictionary *nestDic = [self.class __SY_NestPropertyInfo];
    
    for (SYPropertyInfo *info in nestDic.allValues)
    {
        if (!info.cacheEnable) continue;
        
        id recursionValue = [self __SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:info];
        
        if (operation) operation(info, recursionValue);
    }
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self;
}

- (void)dealloc
{
    NSLog(@"%@已销毁", NSStringFromClass([self class]));
}

@end
