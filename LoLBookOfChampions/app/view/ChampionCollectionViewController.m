//
//  ChampionCollectionViewController.m
//  LoLBookOfChampions
//
//  Created by Jeff Roberts on 1/19/15.
//  Copyright (c) 2015 nimbleNoggin.io. All rights reserved.
//

#import <Bolts/BFTask.h>
#import "ChampionCollectionViewController.h"
#import "NIOContentResolver.h"
#import "NIODataDragonContract.h"
#import "NIOChampionCollectionViewCell.h"
#import <AFNetworking/UIImageView+AFNetworking.h>
#import "NIOCursor.h"

@interface ChampionCollectionViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UICollectionView *championCollectionView;
@property (strong, nonatomic) id<NIOCursor> cursor;
@end

@implementation ChampionCollectionViewController

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"League of Legends Champion Browser";
	[self queryChampions];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSArray *)buildProjection {
	return @[[ChampionColumns COL_NAME], [ChampionColumns COL_IMAGE_URL], [ChampionColumns COL_TITLE]];
}

-(void)queryChampions {
	[self.activityIndicatorView setHidden:NO];
	[self.activityIndicatorView startAnimating];
	__weak ChampionCollectionViewController *weakSelf = self;
	[[self.contentResolver queryWithURL:[Champion URI]
						 withProjection:[self buildProjection]
						  withSelection:nil
					  withSelectionArgs:nil
							withGroupBy:nil
							 withHaving:nil
							   withSort:[ChampionColumns COL_NAME]]
			continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
		if ( weakSelf ) [weakSelf.activityIndicatorView stopAnimating];

		if ( task.error || task.exception ) {
			DDLogError(@"An error occurred querying champions: %@", task.error ? task.error : task.exception);
		} else {
			if ( weakSelf ) {
				weakSelf.cursor = task.result;
				[weakSelf.championCollectionView reloadData];
			}

		}
		return nil;
	}];
}

#pragma mark UICollectionViewDataSource

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
				 cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	__block NIOChampionCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"championCell"
																					forIndexPath:indexPath];
	[self.cursor moveToPosition:(uint)indexPath.row];
	cell.championNameLabel.text = [self.cursor stringForColumn:[ChampionColumns COL_NAME]];

	NSURL *imageURL = [NSURL URLWithString:[self.cursor stringForColumn:[ChampionColumns COL_IMAGE_URL]]];
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:imageURL];

	[cell.championImageView setImageWithURLRequest:urlRequest
								  placeholderImage:nil
										   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
											   cell.championImageView.image = image;
											   [cell.championImageView.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5f] CGColor]];
											   [cell.championImageView.layer setBorderWidth:1.0f];
											   [cell setNeedsDisplay];
										   }
										   failure:nil];
	return cell;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return self.cursor ? self.cursor.rowCount : 0;
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return self.cursor ? 1 : 0;
}


#pragma mark UICollectionViewDelegate

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	[self.cursor moveToPosition:indexPath.row];
	DDLogInfo(@"I just tapped %@", [self.cursor stringForColumn:[ChampionColumns COL_NAME]]);
}


@end