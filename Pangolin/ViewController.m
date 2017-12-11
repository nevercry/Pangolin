//
//  ViewController.m
//  Pangolin
//
//  Created by yangshengfu on 05/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "ViewController.h"
@import NetworkExtension;


@interface ViewController ()

@property (nonatomic ,strong) NETunnelProviderManager *manager;
@property (weak, nonatomic) IBOutlet UISwitch *vpnSwitch;
@property (weak, nonatomic) IBOutlet UILabel *vpnStatusLabel;

@end

@implementation ViewController

#pragma mark - View LifeCycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self resetupManager];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NEVPNStatusDidChangeNotification object:self.manager.connection];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://www.baidu.com"]] resume];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)toggleVPN:(UISwitch *)sender {
    NETunnelProviderSession *session = (NETunnelProviderSession *)self.manager.connection;
    if (sender.isOn) {
        // 打开VPN
        NSError *err;
        [session startVPNTunnelAndReturnError:&err];
        
        if (err) {
            NSLog(@"");
        }
        
    } else {
        // 关闭VPN
        [session stopVPNTunnel];
    }
}

#pragma mark - Custom Methods

- (void)resetupManager {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"loadAllFromPreferences error %@",error);
        } else {
            [self stopObservingStatus];
            
            if (managers.lastObject) {
                self.manager = managers.lastObject;
                [self sendAmessageToProvider];
            } else {
                // 新建立一个默认VPN配置
                NETunnelProviderManager *manager = [[NETunnelProviderManager alloc] init];
                NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
                NEProxySettings *settings = [[NEProxySettings alloc] init];
                
//                protocol.serverAddress = @"192.168.2.157:8999";        // VPN server address
                protocol.serverAddress = @"192.168.190.37:8999";
                protocol.proxySettings = settings; // HTTP proxy
                manager.protocolConfiguration = protocol;
                
                [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"save to Preferences error %@",error);
                    }
                }];
                self.manager = manager;
                [self sendAmessageToProvider];
            }
            
            [self observeStatus];
            
            [self updateVPNStatus];
            
            
        }
    }];
}

- (void)sendAmessageToProvider {
    // Send a simple IPC message to the privider
    NETunnelProviderSession *session = (NETunnelProviderSession *)self.manager.connection;
    session = [[NETunnelProviderSession alloc] init];
    
    
    NSData *messageData = [[NSString stringWithFormat:@"Hello Provider"] dataUsingEncoding:NSUTF8StringEncoding];
    if (session) {
        NSError *error;
        
        [session sendProviderMessage:messageData returnError:&error responseHandler:^(NSData * _Nullable responseData) {
            if (responseData) {
                NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                NSLog(@"Received response from the provider : %@",responseString);
            } else {
                NSLog(@"Got a nil response from the provider");
            }
        }];
        
        if (error) {
            NSLog(@"failed to send a message to the provider");
        }
    }
}


- (void)stopObservingStatus {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NEVPNStatusDidChangeNotification object:self.manager.connection];
}

- (void)observeStatus {
    [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification object:self.manager.connection queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
        [self updateVPNStatus];
    }];
}

- (void)updateVPNStatus {
    NEVPNStatus vpnStatus = self.manager.connection.status;
    
    switch (vpnStatus) {
        case NEVPNStatusConnecting:
        case NEVPNStatusConnected:
        {
            [self.vpnSwitch setOn:YES];
            [self.vpnSwitch setEnabled:YES];
            
            self.vpnStatusLabel.text = (vpnStatus == NEVPNStatusConnecting) ? @"正在连接..." : @"已连上";
        }
            break;
        case NEVPNStatusDisconnected:
        case NEVPNStatusDisconnecting:
        {
            [self.vpnSwitch setOn:NO];
            [self.vpnSwitch setEnabled:YES];
            
            self.vpnStatusLabel.text = (vpnStatus == NEVPNStatusDisconnecting) ? @"正在断开" : @"已断开";
        }
            break;
        case NEVPNStatusInvalid: {
            [self.vpnSwitch setEnabled:NO];
            
            self.vpnStatusLabel.text = @"vpn配置无效";
        }
            break;
        case NEVPNStatusReasserting: {
            [self.vpnSwitch setOn:YES];
            [self.vpnSwitch setEnabled:YES];
            
            self.vpnStatusLabel.text = @"正在重新连接";
        }
            break;
            
    }
    
    
    
}







@end
