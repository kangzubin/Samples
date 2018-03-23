//
//  ViewController.m
//  TestOpenURL
//
//  Created by kangzubin on 2018/3/23.
//  Copyright © 2018 KANGZUBIN. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)openWeiXinButtonClick:(UIButton *)sender {
    NSURL *openWXURL = [NSURL URLWithString:@"weixin://"];
    if ([[UIApplication sharedApplication] canOpenURL:openWXURL]) {
        [[UIApplication sharedApplication] openURL:openWXURL];
    }
}

- (IBAction)openWeiboButtonClick:(UIButton *)sender {
    NSURL *openWBURL = [NSURL URLWithString:@"sinaweibo://"];
    [[UIApplication sharedApplication] openURL:openWBURL];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
