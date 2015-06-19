//
//  ViewController.m
//  SimplePushDemo
//

//  Created by mozilla on 2/17/15.
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ViewController.h"
// #import "SRWebSocket.h"
#import "AppDelegate.h"

@interface ViewController ()
// NOTE: ctrl + drag from UILabel to 1st widget
// @property (nonatomic, weak) IBOutlet UILabel *messageLabel;
// NOTE: ctrl + drag from UITextField to 1st widget && widget to UITextField!
@property (nonatomic, weak) IBOutlet UITextField *hostField;
@property (nonatomic, weak) IBOutlet UITextView *outputField;
@property(nonatomic, weak) IBOutlet UITextField *dataField;
- (void)log:(NSString *)msg;
@end

@implementation ViewController

int const MAX_STRINGS;

// values from the server
NSString *endpoint;
NSString *sharedSecret;
NSString *channelID;
NSString *uaid;


// SRWebSocket *websocket;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // To get a value from AppDelegate, call this (ick).
    // [(AppDelegate *)[(UIApplication *)[UIApplication sharedApplication] delegate] getSomeValue]
    [[self app] restoreState];
    [self log: @"Starting up..."];
    NSString *host = (NSString *)[[self app] objectForKey:@"host"];
    if (host == nil ) {
        host = @"http://localhost:8082/register";
    }
    self.hostField.text = host;
    endpoint = (NSString*)[[self app] objectForKey:@"endpoint"];
}

- (AppDelegate *) app {
    return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (void)setServerData: (NSDictionary *)sd {
    endpoint = [sd valueForKey: @"endpoint"];
    sharedSecret = [sd valueForKey:@"hash"];
    uaid = [sd valueForKey:@"uaid"];
    channelID = [sd valueForKey:@"channelID"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Semi-ugly hack to limit the number of messages printed on the screen.
- (void)print:(NSString *)message withPrefix:(NSString *)sprefix{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        unsigned long offset = 0;
        NSString *prefix = sprefix;
        NSArray *strings = [self.outputField.text componentsSeparatedByString:@"\n"];
        unsigned long slen = [strings count];
        if (slen > MAX_STRINGS) {
            offset = slen - MAX_STRINGS;
        }
        if ([sprefix length] == 0) {
            prefix = @"      ";
        }
        NSRange range = NSMakeRange(offset, MIN(slen, MAX_STRINGS));
        NSLog([NSString stringWithFormat:@"%@%@", prefix, message]);
        self.outputField.text = [NSString stringWithFormat:@"%@\n%@%@",
                             [[strings subarrayWithRange: range]  componentsJoinedByString:@"\n"],
                             prefix,
                             message];
        }];
}

- (void)error:(NSString *) message {
    [self print: message withPrefix: @"ERROR "];
}

- (void)log:(NSString *) message {
    [self print: message withPrefix: @"      "];
}

- (NSString*)genGuid {
    int const guidLen = 16;
    NSMutableString *hex = [[NSMutableString alloc] init];
    unsigned char *raw = alloca(sizeof(unsigned char) * guidLen);
    SecRandomCopyBytes(kSecRandomDefault, guidLen, raw);
    for (int i=0; i<guidLen; i++) {
        if (i == 4 || i == 6 || i == 8 || i==10) {
            [hex appendString: @"-"];
        }
        int v = raw[i];
        if (i == 6) {
            v = (v & 0x0F) | 0x40;
        }
        [hex appendFormat:@"%02x", v];
    }
    return  (NSString*) hex;
}

- (void)fetchEndpoint: (NSString *)url {
    NSURL *dest = [NSURL URLWithString: url];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    NSString *now = [NSString stringWithFormat:@"%ld", lroundf(CFAbsoluteTimeGetCurrent())];
    NSString *token = [[self app] getTokenAsString];
    NSString  *channelId = [self genGuid];
    NSError *error;
    if (token == nil || [token isEqual: @""]) {
        [self log: @"Token is nil. This will only end in tears. Please check error log and provisioning."];
        return;
    }
    NSDictionary *routerData= [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 token, @"token",
                                                                 nil];
    NSData *msg = [NSJSONSerialization dataWithJSONObject: [ NSDictionary dictionaryWithObjectsAndKeys:
                                                            @"apns", @"type",
                                                            channelId, @"channelID",
                                                            routerData, @"data",
                                                            nil]
                                                  options: NSJSONWritingPrettyPrinted
                                                    error: &error
                   ];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: dest];
    [req setTimeoutInterval: 0];
    [req setHTTPMethod: @"POST"];
    [req setHTTPBody: msg];
    [NSURLConnection
     sendAsynchronousRequest:req
     queue: queue
     completionHandler:^(NSURLResponse *resp,
                         NSData *data,
                         NSError *error) {
         if (error != nil) {
             [self error: [NSString stringWithFormat: @"Could not PUT data: %@", error.description]];
             return;
         }
         long code = [(NSHTTPURLResponse *)resp statusCode];
         if (code < 200 || code > 299) {
             [self error: [NSString stringWithFormat: @"Unexpected status response %ld", code]];
             return;
         }
         // Set the values from the server
         dispatch_async(dispatch_get_main_queue(), ^ {
             /* This may be needlessly complex because of a vague runtime error returned by iOS */
             @synchronized(self) {
                 NSError *lerr;
                 NSDictionary *reply = [NSJSONSerialization JSONObjectWithData: data
                                                                       options: NSJSONReadingMutableContainers
                                                                         error: &lerr];
                 [self setServerData: reply];
                 [self log: [NSString stringWithFormat: @"Got endpoint %@", [reply objectForKey: @"endpoint"]]];
             }
         });
     }];
}

//Connect to the remote host
- (IBAction)SendData:(id)sender {
    NSString *dataString = self.dataField.text;
    NSString *putBody;
    
    if (nil == endpoint) {
        [self log: @"Endpoint not yet set. Aborting"];
        return;
    }
    
    [self log: [NSString stringWithFormat:@"Sending Data to server: %@", dataString]];
    NSURL *dest = [NSURL URLWithString: endpoint];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    NSString *now = [NSString stringWithFormat:@"%ld", lroundf(CFAbsoluteTimeGetCurrent())];
    NSArray *body = @[
        [NSString stringWithFormat:@"%@=%@", @"version", now],
        [NSString stringWithFormat:@"%@=%@", @"data", [dataString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
    ];
    putBody = [body componentsJoinedByString:@"&"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: dest];
    [req setTimeoutInterval: 0];
    [req setHTTPMethod: @"PUT"];
    [req setHTTPBody: [putBody dataUsingEncoding: NSUTF8StringEncoding]];
    [NSURLConnection
     sendAsynchronousRequest:req
     queue: queue
     completionHandler:^(NSURLResponse *resp,
                         NSData *data,
                         NSError *error) {
         if (error != nil) {
             [self error: [NSString stringWithFormat: @"Could not PUT data: %@", error.description]];
             return;
         }
         long code = [(NSHTTPURLResponse *)resp statusCode];
         if (code < 200 || code > 299) {
             [self error: [NSString stringWithFormat: @"Unexpected status response %ld", code]];
         }
     }];
}

- (IBAction)ClearData:(id)sender {
    [self log: @"Clearing data...."];
    self.dataField.text = @"";
    self.outputField.text = @"";
}

- (IBAction)Connect:(id)sender {
    NSString *hostName = self.hostField.text;
    if ([hostName length] == 0) {
        [self log: @"No hostname specified."];
        return;
    }
    [[self app] setValue: hostName forKey: @"host"];
    [self fetchEndpoint: hostName];
}
@end
