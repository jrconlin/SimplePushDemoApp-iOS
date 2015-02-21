//
//  ViewController.m
//  SimplePushDemo
//
//  Created by mozilla on 2/17/15.
//  Copyright (c) 2015 mozilla. All rights reserved.
//

#import "ViewController.h"
#import "SRWebSocket.h"

@interface ViewController ()
// NOTE: ctrl + drag from UILabel to 1st widget
// @property (nonatomic, weak) IBOutlet UILabel *messageLabel;
// NOTE: ctrl + drag from UITextField to 1st widget && widget to UITextField!
@property (nonatomic, weak) IBOutlet UITextField *hostField;
@property (nonatomic, weak) IBOutlet UITextView *outputField;
@property(nonatomic, weak) IBOutlet UITextField *dataField;
@end

@implementation ViewController

int const MAX_STRINGS;
NSString *endpoint;

SRWebSocket *websocket;


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
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
    NSString *connect = @"";
    NSError *error;
    NSData *msg = [NSJSONSerialization dataWithJSONObject: [ NSDictionary dictionaryWithObjectsAndKeys:
                                                            @"hello", @"messageType",
                                                            @"", @"uaid",
                                                            @[], @"channelIDs",
                                                            connect, @"connect", nil]
                                                  options: NSJSONWritingPrettyPrinted
                                                    error: &error
                   ];
    if (error != nil) {
        [self error: [error description] ];
    }
    [self log: [NSString stringWithFormat: @"Sending: %@", [[NSString alloc] initWithData:msg encoding: NSUTF8StringEncoding ]]];
    //[ws send:msg];
    
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
    @try {
        obj = [NSJSONSerialization JSONObjectWithData: message options: NSJSONReadingAllowFragments error: &error ];
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
    // Status should be 200
    msgType = [msg objectForKey:@"messageType"];
    if ([msgType isEqualToString: @"hello"]) {
        NSData *msg = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           @"register", @"messageType",
                                                           @"channelID", [self genGuid],
                                                           nil]
                                                  options: NSJSONWritingPrettyPrinted
                                                    error: &error
                   ];
        [ws send: msg];
        return;
    } else if ([msgType isEqualToString: @"register"]) {
        endpoint = (NSString *)[msg objectForKey:@"endpoint"];
        if (endpoint == nil || [endpoint length] == 0) {
            [self error: @"returned endpoint is empty"];
            return;
        }
    }
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
    
    [self log: [NSString stringWithFormat:@"Data: %@", dataString]];
    // TODO PUT to the endpoint
    NSURL *dest = [NSURL URLWithString: endpoint];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    // really?
    NSString *now = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970] *1000];
    NSArray *body = @[
        [NSString stringWithFormat:@"%@=%@", @"version", now],
        [NSString stringWithFormat:@"%@=%@", @"data", [now stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
    ];
    putBody = [body componentsJoinedByString:@"&"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: dest];
    [req setTimeoutInterval: 10.0f];
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
    [self fetchEndpoint: hostName];
}
@end
