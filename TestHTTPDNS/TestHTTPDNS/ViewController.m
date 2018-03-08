//
//  ViewController.m
//  TestHTTPDNS
//
//  Created by kangzubin on 2018/3/7.
//  Copyright © 2018 KANGZUBIN. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *tempDNS;
@property (nonatomic, copy) NSString *testHost;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.testHost = @"kangzubin.com";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)testButtonClick:(UIButton *)sender {
    NSString *hostIP = self.tempDNS[self.testHost];
    if (!hostIP) {
        [self getDomainNameIP];
    } else {
        [self sendRequestByIP];
    }
}

- (void)sendRequestByIP {
    NSString *hostIP = self.tempDNS[self.testHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/test/httpdns/", hostIP]];
    // 这里请求的 url 原本应该为：https://kangzubin.com/test/httpdns/
    // 采用 HTTPDNS 替换后，此时为：https://123.206.23.22/test/httpdns/
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    // 由于请求的 url 中的域名已经被替换为 IP 了，
    // 这里需要手动设置请求 Host 字段为相应的域名，便于服务端解析，
    // 参见：https://help.aliyun.com/knowledge_detail/58683.html?spm=a2c4g.11186631.2.20.EhRKt7
    [request setValue:self.testHost forHTTPHeaderField:@"Host"];
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"The test result is:\n%@", result);
        } else {
            NSLog(@"%@", error);
        }
    }];
    [dataTask resume];
}

// 根据域名向 HTTPDNS 服务器请求其对应的服务器 IP 地址，
// 这里采用腾讯云提供的免费 HTTPDNS 服务作为测试，详见：https://cloud.tencent.com/document/product/379/3524
// 一般这些云服务商都会提供封装好的 SDK 供我们使用。
- (void)getDomainNameIP {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://119.29.29.29/d?dn=%@", self.testHost]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!error) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (result.length > 0) {
                strongSelf.tempDNS[self.testHost] = result;
                NSLog(@"The IP for Domain Name: `%@` is: `%@`", self.testHost, result);
                // 测试用 IP 发起请求
                [strongSelf sendRequestByIP];
            }
        }
    }];
    [dataTask resume];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;
    
    // 证书验证前置处理
    NSString *domain = challenge.protectionSpace.host; // 获取当前请求的 host（域名或者 IP），此时为：123.206.23.22
    NSString *testHostIP = self.tempDNS[self.testHost];
    // 此时服务端返回的证书里的 CN 字段（即证书颁发的域名）与上述 host 可能不一致，
    // 因为上述 host 在发请求前已经被我们替换为 IP，所以校验证书时会发现域名不一致而无法通过，导致请求被取消掉，
    // 所以，这里在校验证书前做一下替换处理。
    if ([domain isEqualToString:testHostIP]) {
        domain = self.testHost; // 替换为：kangzubin.com
    }
    
    // 以下逻辑与 AFNetworking -> AFURLSessionManager.m 里的代码一致
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:domain]) {
            // 上述 `evaluateServerTrust:forDomain:` 方法用于验证 SSL 握手过程中服务端返回的证书是否可信任，
            // 以及请求的 URL 中的域名与证书里声明的的 CN 字段是否一致。
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            if (credential) {
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

// 以下逻辑取自 AFNetworking -> AFSecurityPolicy 的 `evaluateServerTrust:forDomain:`
// 方法中 SSLPinningMode 为 AFSSLPinningModeNone 的情况
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
    // 创建证书校验策略
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        // 需要验证请求的域名与证书中声明的 CN 字段是否一致
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
    
    // 绑定校验策略到服务端返回的证书（serverTrust）上
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
    
    // 评估当前 serverTrust 是否可信任，
    // 根据苹果文档：https://developer.apple.com/library/ios/technotes/tn2232/_index.html
    // 当 result 为 kSecTrustResultUnspecified 或 kSecTrustResultProceed 的情况下，serverTrust 可以被验证通过。
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);
    return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
}

#pragma mark - Getter

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:operationQueue];
    }
    return _session;
}

- (NSMutableDictionary *)tempDNS {
    if (!_tempDNS) {
        _tempDNS = [NSMutableDictionary dictionary];
    }
    return _tempDNS;
}

@end
