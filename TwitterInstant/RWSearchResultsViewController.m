//
//  RWSearchResultsViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 03/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>
#import "RWSearchResultsViewController.h"
#import "RWTableViewCell.h"
#import "RWTweet.h"

@interface RWSearchResultsViewController ()

@property (nonatomic, strong) NSArray *tweets;
@end

@implementation RWSearchResultsViewController {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tweets = [NSArray array];
    
}

- (void)displayTweets:(NSArray *)tweets {
    self.tweets = tweets;
    [self.tableView reloadData];
}

- (RACSignal *)signalForLoadingImage:(NSString *)imageUrl
{
    RACScheduler *scheduler = [RACScheduler schedulerWithPriority:RACSchedulerPriorityBackground];
    
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
        UIImage *img = [UIImage imageWithData:data];
        [subscriber sendNext:img];
        [subscriber sendCompleted];
        
        return nil;
    }] subscribeOn:scheduler];
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tweets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    RWTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    RWTweet *tweet = self.tweets[indexPath.row];
    cell.twitterStatusText.text = tweet.status;
    cell.twitterUsernameText.text = [NSString stringWithFormat:@"@%@",tweet.username];
    
    // async-img-load by rac
    cell.twitterAvatarView.image = nil; //复用时情况之前的图片
    [[[self signalForLoadingImage:tweet.profileImageUrl]
    deliverOn:[RACScheduler mainThreadScheduler]]
    subscribeNext:^(UIImage *img) {
        
        cell.twitterAvatarView.image = img;
    }];
    
    return cell;
}

@end
