//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import "RWTweet.h"

#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ReactiveCocoa/RACEXTScope.h>
#import <LinqToObjectiveC/NSArray+LinqExtensions.h>

#import <Accounts/Accounts.h>
#import <Social/Social.h>

typedef NS_ENUM(NSInteger, RWTwitterInstantError) {
    
    RWTwitterInstantErrorAccessDenied,
    RWTwitterInstantErrorNoTwitterAccounts,
    RWTwitterInstantErrorInvalidResponse

};

static NSString * const RWTwitterInstantDomain = @"TwitterInstant";


@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;

@property (strong, nonatomic) ACAccountStore *accountStore;
@property (strong, nonatomic) ACAccountType *twitterAccountType;


@end

@implementation RWSearchFormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Twitter Instant";
    
    [self styleTextField:self.searchText];
    
    self.resultsViewController = self.splitViewController.viewControllers[1];
    
    // ====== social account
    self.accountStore = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    
    // ====== rac
    [self racBlock];
    
}

- (void)racBlock
{
    @weakify(self)
    __typeof(self) __weak weakSelf = self;
    
    RACDisposable *subscription = [[self.searchText.rac_textSignal map:^id(NSString *text) {
        return [weakSelf isValidSearchText:text] ? [UIColor whiteColor]:[UIColor yellowColor];
    }] subscribeNext:^(id x) {
        @strongify(self)
        self.searchText.backgroundColor = x;
    }];
    //    [subscription dispose];
    
    // ===== request rac
//    [[self requestAccessToTwitterSignal]
//     subscribeNext:^(id x) {
//         NSLog(@"access granted");
//     } error:^(NSError *error) {
//         NSLog(@"error : %@",error);
//     }];
    
    // ===== signal-link rac then-block
    // then called when last-signal send complete-sign
    [[[[[[[self requestAccessToTwitterSignal]
      then:^RACSignal *{
          @strongify(self)
          return self.searchText.rac_textSignal;
      }]
     filter:^BOOL(NSString *value) {
         @strongify(self)
         return [self isValidSearchText:value];
     }]
       throttle:0.5]
     flattenMap:^RACStream *(NSString *value) {
         @strongify(self)
         
         return  [self signalForSearchWithText:value]; //search-text-sign转换成请求数据的signal
     }]
      // 将信号传递到主线程上执行subscribe -- 更新UI
     deliverOn:[RACScheduler mainThreadScheduler]]
     
     subscribeNext:^(NSDictionary *data) {
         NSLog(@"seach retdata:%@",data); // 订阅到请求数据data
         NSArray *statuses = data[@"statuses"];
         NSArray *tweets = [statuses linq_select:^id(id item) {
             return [RWTweet tweetWithStatus:item];
         }];// make ui-model datasource
         [self.resultsViewController displayTweets:tweets];//update UI
         
     } error:^(NSError *error) {
         NSLog(@"eror%@",error);
     }];
    
    //====
    
    
}

// 请求Twitter账号权限的signal
- (RACSignal *)requestAccessToTwitterSignal
{
    //error:
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorAccessDenied userInfo:nil];
    
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        [self.accountStore requestAccessToAccountsWithType:self.twitterAccountType options:nil completion:^(BOOL granted, NSError *error) {
            
            if (!granted) {
                [subscriber sendError:accessError];
            } else {
                [subscriber sendNext:nil];
                [subscriber sendCompleted];
            }
        }];
        return nil;
    }];
    
}

// Twitter搜索请求 SLRequest
- (SLRequest *)requestforTwitterSearchWithText:(NSString *)text
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    NSDictionary *params = @{@"q":text};
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
    
    return request;
}

// 基于搜索请求的signal
- (RACSignal *)signalForSearchWithText:(NSString *)text
{
    NSError *noAccountError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorNoTwitterAccounts userInfo:nil];
    NSError *invalidResponseError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorInvalidResponse userInfo:nil];
    
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        
        SLRequest *request = [self requestforTwitterSearchWithText:text];
        
        // 提供Twitter账号
        NSArray *twitterAccounts = [self.accountStore accountsWithAccountType:self.twitterAccountType];
        if (twitterAccounts.count == 0) {
            [subscriber sendError:noAccountError];//
        } else {
            [request setAccount:[twitterAccounts lastObject]];
            
            [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                
                if (urlResponse.statusCode == 200) {
                    
                    NSDictionary *timelineData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
                    [subscriber sendNext:timelineData];
                    [subscriber sendCompleted];
                    
                } else {
                    [subscriber sendError:invalidResponseError];//
                }
            }];
            
        }
        return nil;
    }];
    
}


- (void)styleTextField:(UITextField *)textField {
    CALayer *textFieldLayer = textField.layer;
    textFieldLayer.borderColor = [UIColor grayColor].CGColor;
    textFieldLayer.borderWidth = 2.0f;
    textFieldLayer.cornerRadius = 0.0f;
}


- (BOOL)isValidSearchText:(NSString *)text
{
    return text.length > 2;
}

@end
