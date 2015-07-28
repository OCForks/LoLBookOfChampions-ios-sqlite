//
// NIODataDragonSyncService / LoLBookOfChampions
//
// Created by Jeff Roberts on 1/24/15.
// Copyright (c) 2015 Riot Games. All rights reserved.
//

#import <Bolts/Bolts.h>
#import "NIODataDragonSyncService.h"
#import "NIOGetRealmTask.h"
#import "NIOContentProvider.h"
#import "NIOContentResolver.h"
#import "NIODataDragonContract.h"
#import "NIOTaskFactory.h"
#import "NIOClearLocalDataDragonDataTask.h"
#import "NIOInsertDataDragonRealmTask.h"
#import "NIOGetChampionStaticDataTask.h"
#import "NIOInsertDataDragonChampionDataTask.h"
#import "NIOCacheChampionImagesTask.h"
#import "NIOCursor.h"

@interface NIODataDragonSyncService ()
@property (strong, nonatomic) NSString *dataDragonCDN;
@property (strong, nonatomic) NIOContentResolver *contentResolver;
@property (strong, nonatomic) id<NIOTask> currentTask;
@property (strong, nonatomic) NSString *localDataDragonVersion;
@property (retain, nonatomic) dispatch_queue_t taskExecutionQueue;
@property (strong, nonatomic) BFExecutor *taskExecutor;
@property (strong, nonatomic) id<NIOTaskFactory> taskFactory;
@end

@implementation NIODataDragonSyncService
-(instancetype)initWithContentResolver:(NIOContentResolver *)contentResolver
					   withTaskFactory:(id<NIOTaskFactory>)taskFactory {
	self = [super init];
	if ( self ) {
		self.contentResolver = contentResolver;
		self.taskFactory = taskFactory;
		self.taskExecutionQueue = dispatch_queue_create(object_getClassName(self), DISPATCH_QUEUE_SERIAL);
		self.taskExecutor = [BFExecutor executorWithDispatchQueue:self.taskExecutionQueue];
	}

	return self;
}

-(BFTask *)cacheChampionImagesWithImageURLs:(NSArray *)cacheableImageURLs {
	NIOCacheChampionImagesTask *cacheTask = [self.taskFactory createTaskWithType:[NIOCacheChampionImagesTask class]];
	cacheTask.cacheableImageURLs = cacheableImageURLs;
    self.currentTask = cacheTask;
	return [cacheTask run];
}

-(BFTask *)getChampionStaticData {
    self.currentTask = [self.taskFactory createTaskWithType:[NIOGetChampionStaticDataTask class]];
    return [self.currentTask run];
}

-(NSString *)getLocalDataDragonVersion:(id<NIOCursor>)cursor {
	NSString *localDataDragonVersion;
	if ( [cursor next] ) {
		localDataDragonVersion = [cursor stringForColumn:[RealmColumns COL_REALM_VERSION]];
	} else {
		LOLLogInfo(@"No local Data Dragon version found");
		localDataDragonVersion = [@(NSNotFound) stringValue];
	}

	[cursor close];

	return localDataDragonVersion;
}

-(BFTask *)insertChampionStaticDataWithRemoteChampionData:(NSDictionary *)championResponse {
	NIOInsertDataDragonChampionDataTask *insertChampionDataTask = [self.taskFactory createTaskWithType:[NIOInsertDataDragonChampionDataTask class]];
    self.currentTask = insertChampionDataTask;
	insertChampionDataTask.remoteDataDragonChampionData = championResponse;
	insertChampionDataTask.dataDragonCDN = [NSURL URLWithString:self.dataDragonCDN];
	insertChampionDataTask.dataDragonRealmVersion = self.localDataDragonVersion;

	return [insertChampionDataTask run];
}

-(BFTask *)insertRealmWithRemoteRealmData:(NSDictionary *)realmResponse {
	NSString *remoteDataDragonVersion = realmResponse[@"v"];
	LOLLogInfo(@"Found remote data dragon version %@", remoteDataDragonVersion);
	self.localDataDragonVersion = remoteDataDragonVersion;
	self.dataDragonCDN = realmResponse[@"cdn"];

	NIOInsertDataDragonRealmTask *insertDataDragonRealmTask = [self.taskFactory createTaskWithType:[NIOInsertDataDragonRealmTask class]];
    self.currentTask = insertDataDragonRealmTask;
	insertDataDragonRealmTask.remoteDataDragonRealmData = realmResponse;
	return [insertDataDragonRealmTask run];
}

-(void)resync {
	LOLLogInfo(@"Resyncing remote data dragon data with local database");

	[[[[[[[BFTask taskFromExecutor:self.taskExecutor withBlock:^id {
		return [[self.taskFactory createTaskWithType:[NIOClearLocalDataDragonDataTask class]] run];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		if ( task.error ) {
			LOLLogError(@"An error occurred attempting to delete the local data dragon data: %@", task.error);
            self.currentTask = nil;
			return nil;
		}

		return [[self.taskFactory createTaskWithType:[NIOGetRealmTask class]] run];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		if ( task.error ) {
			LOLLogError(@"An error occurred attempting to retrieve the remote data dragon realm: %@", task.error);
            self.currentTask = nil;
			return nil;
		}

		return [self insertRealmWithRemoteRealmData:task.result];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		return [self getChampionStaticData];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		return task.error ? task : [self insertChampionStaticDataWithRemoteChampionData:task.result];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		if ( task.error || task.exception ) {
            self.currentTask = nil;
			return task;
		}
		[self.contentResolver notifyChange:[Champion URI]];

		return [self cacheChampionImagesWithImageURLs:task.result];
	}] continueWithExecutor:self.taskExecutor withBlock:^id(BFTask *task) {
		if ( task.error || task.exception ) {
			LOLLogError(@"An error occurred attempting to resync the remote data dragon data with the local database: %@", task.error ? task.error : task.exception);
		} else {
			LOLLogInfo(@"Resync of remote data dragon data with the local database has completed successfully");
		}
        self.currentTask = nil;
		return nil;
	}];
}

-(void)sync {
	self.localDataDragonVersion = nil;
    __block __weak NIODataDragonSyncService *weakSelf = self;
	[BFTask taskFromExecutor:self.taskExecutor withBlock:^id {
        NSError *error;
		id<NIOCursor> cursor = [weakSelf.contentResolver queryWithURI:[Realm URI]
                                                       withProjection:@[[RealmColumns COL_REALM_VERSION]]
                                                        withSelection:nil
                                                    withSelectionArgs:nil
                                                          withGroupBy:nil
                                                           withHaving:nil
                                                             withSort:nil
                                                            withError:&error];
                                  
        if (error) {
            LOLLogError(@"An error occurred retrieving the local data dragon realm info: %@", error);
            return nil;
        }
        
        __block NSString *localDataDragonVersion = [weakSelf getLocalDataDragonVersion:cursor];
        LOLLogInfo(@"Found local data dragon version %@", localDataDragonVersion);
        
        if ( [[@(NSNotFound) stringValue] isEqualToString:localDataDragonVersion] ) {
            [weakSelf resync];
            
            weakSelf.localDataDragonVersion = localDataDragonVersion;
        } else {
            [[[weakSelf.taskFactory createTaskWithType:[NIOGetRealmTask class]] run]
                continueWithExecutor:weakSelf.taskExecutor withSuccessBlock:^id(BFTask *task) {
					NSDictionary *remoteDataDragonRealmData = task.result;
					NSString *remoteDataDragonVersion = remoteDataDragonRealmData[@"v"];
					LOLLogInfo(@"Found remote data dragon version %@", remoteDataDragonVersion);

					if ( [localDataDragonVersion isEqualToString:remoteDataDragonVersion] ) {
						LOLLogInfo(@"Local data dragon version is the latest available");
					} else {
						[weakSelf resync];
					}
                    
                    return nil;
				}];
        }
        
        return nil;
    }];
}

@end