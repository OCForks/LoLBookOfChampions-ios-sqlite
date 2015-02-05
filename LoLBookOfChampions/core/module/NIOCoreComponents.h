//
// Created by Jeff Roberts on 2/4/15.
// Copyright (c) 2015 io.nimblenoggin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Typhoon/TyphoonAssembly.h>

@class NIOContentResolver;


@interface NIOCoreComponents : TyphoonAssembly
-(NIOContentResolver *)contentResolver;
-(NSBundle *)mainBundle;

@end