//
// Created by Jeff Roberts on 1/23/15.
// Copyright (c) 2015 nimbleNoggin.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Typhoon/TyphoonAssembly.h>

@class NIOLoLApiRequestOperationManager;
@class GetRealmTask;
@class NIODataDragonSyncService;
@protocol NIOContentProvider;
@class NIOCoreComponents;
@class NIODataDragonContentProvider;

@interface NIODataDragonComponents : TyphoonAssembly
@property (nonatomic, strong, readonly) NIOCoreComponents *coreComponents;

-(GetRealmTask *)getRealmTask;
-(NIODataDragonContentProvider *)dataDragonContentProvider;
-(NIODataDragonSyncService *)dataDragonSyncService;
-(NIOLoLApiRequestOperationManager *)lolStaticDataApiRequestOperationManager;
@end