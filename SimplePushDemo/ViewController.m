//
//  ViewController.m
//  SimplePushDemo
//

//  Created by mozilla on 2/17/15.
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ViewController.h"
#import "SRWebSocket.h"
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
NSString *endpoint;


SRWebSocket *websocket;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // To get a value from AppDelegate, call this (ick).
    // [(AppDelegate *)[(UIApplication *)[UIApplication sharedApplication] delegate] getSomeValue]
    [[self app] restoreState];
    [self log: @"Starting up..."];
    NSString *host = (NSString *)[[self app] objectForKey:@"host"];
    if (host == nil ) {
        host = @"ws://localhost:8080/";
    }
    self.hostField.text = host;
    endpoint = (NSString*)[[self app] objectForKey:@"endpoint"];
}

- (AppDelegate *) app {
    return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (NSString *)getEndpoint {
    return endpoint;
}

- (void)setEndpoint: (NSString *)ep {
    [[self app] setValue:ep forKey:@"endpoint"];
    endpoint = ep;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Semi-ugly hack to limit the number of messages printed on the screen.
- (void)print:(NSString *)message withPrefix:(NSString *)prefix{
    uint offset = 0;
    NSArray *strings = [self.outputField.text componentsSeparatedByString:@"\n"];
    uint slen = [strings count];
    if (slen > MAX_STRINGS) {
        offset = slen - MAX_STRINGS;
    }
    if ([prefix length] == 0) {
        prefix = @"      ";
    }
    NSRange range = NSMakeRange(offset, MIN(slen, MAX_STRINGS));
    NSLog([NSString stringWithFormat:@"%@%@", prefix, message]);
    self.outputField.text = [NSString stringWithFormat:@"%@\n%@%@",
                             [[strings subarrayWithRange: range]  componentsJoinedByString:@"\n"],
                             prefix,
                             message];
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


- (void)onOpen:(SRWebSocket *)ws withConnect:(NSString *)connect{
    NSLog(@"Connecting...");
}

- (void)fetchEndpoint: (NSString *)url {
    @try {
        [self log: [NSString stringWithFormat: @"Fetching endpoint from %@", url]];
        SRWebSocket *ws = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString: url]];
        // we'll handle the async calls that this requires.
        ws.delegate = self;
        [ws open];
        return;
    }
    @catch (NSException *exception) {
        [self print: [NSString stringWithFormat: @"Crapsticks: something bad happened: %@", exception.reason]
         withPrefix: @"ERROR "];
        return;
    }
    @finally {
    }
    return;
}

- (void) webSocketDidOpen:(SRWebSocket *)ws {
    websocket = ws;
    NSError *error;
    NSString *token = [[self app] getTokenAsString];
    NSDictionary *connect = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"apns", @"type",
                             token, @"token",
                             // the following are optional, but will result in the notification being presented
                             // if the app is not running or in the foreground.
                             //@"A Simplepush Event has appeared!", @"title",
                             //@"I wish that silent notification worked.", @"body",
                             nil];
    NSData *msg = [NSJSONSerialization dataWithJSONObject: [ NSDictionary dictionaryWithObjectsAndKeys:
                                                            @"hello", @"messageType",
                                                            @"", @"uaid",
                                                            @[], @"channelIDs",
                                                            connect, @"connect",
                                                            nil]
                                                  options: NSJSONWritingPrettyPrinted
                                                    error: &error
                   ];
    if (error != nil) {
        [self error: [error description] ];
    }
    [self log: [NSString stringWithFormat: @"Sending: %@", [[NSString alloc] initWithData:msg encoding: NSUTF8StringEncoding ]]];
    [ws send:msg];
    
}

- (void) webSocket:(SRWebSocket *)ws didReceiveMessage:(id)message {
    NSError *error;
    id obj;
    NSDictionary *msg;
    NSString *msgType;
    
    if ([message length] < 2) {
        [self log: @"Got empty websocket message"];
        return;
    }
    [self log: [NSString stringWithFormat:@"Got reply\n%@", (NSString *)message]];
    @try {
        obj = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error: &error ];
        if (error != nil) {
            [self error: error.description];
            return;
        }
        if (![obj isKindOfClass:[NSDictionary class]]) {
            [self error: @"Did not get a dictionary response back."];
            [self log: (NSString *)message];
        }
        msg = (NSDictionary *)obj;
    }
    @catch (NSException *exception) {
        [self error: exception.description];
        return;
    }
    @finally {};
    // handle message
    msgType = (NSString*)[msg objectForKey:@"messageType"];
    if ([msgType isEqualToString: @"hello"]) {
        // Remember kids, ObjectiveC dictionaries are specifed as Value:Key.
        // makes sense Because that.h
        NSData *regmsg = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           @"register", @"messageType",
                                                           [self genGuid], @"channelID",
                                                           nil]
                                                  options: NSJSONWritingPrettyPrinted
                                                    error: &error
                   ];
        [ws send: regmsg];
        return;
    } else if ([msgType isEqualToString: @"register"]) {
        endpoint = (NSString *)[msg objectForKey:@"pushEndpoint"];
        if (endpoint == nil || [endpoint length] == 0) {
            [self error: @"returned endpoint is empty"];
            return;
        }
        // At this point, it's safe to close the websocket handler.
        //[ws close];
    }
    NSLog(@"Got message: %@", msg);
    return;
}

- (void) webSocket:(SRWebSocket *)ws didFailWithError:(NSError *)error {
    // Show error and die
    [self error: [NSString stringWithFormat: @"Websocket failed: %@", error.description]];
}

- (void) webSocket:(SRWebSocket *)ws didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self log: [NSString stringWithFormat: @"Websocket closed: %@", reason]];
    endpoint = @"";
    websocket = nil;
    // shutdown
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
