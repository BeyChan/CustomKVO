//
//  ViewController.m
//  CustomKVO
//
//  Created by Melody Chan on 16/10/29.
//  Copyright © 2016年 canlife. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVOHelp.h"
@interface Message : NSObject

@property (nonatomic, copy) NSString *text;

@end

@implementation Message

@end

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (nonatomic, strong) Message *message;

- (IBAction)changeText:(id)sender;

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.message = [[Message alloc] init];
    [self.message CMY_addObserver:self
                           forKey:NSStringFromSelector(@selector(text))
                        withBlock:^(id observedObject, NSString *observedKey, id oldValue,
                                    id newValue) {
        NSLog(@"observedObject ＝%@observedKey＝%@ newValue＝ %@", observedObject, observedKey, newValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.label.text = newValue;
        });

    }];
    [self changeText:nil];
    // Do any additional setup after loading the view, typically from a nib.
}



- (IBAction)changeText:(id)sender {
    NSArray *msgs = @[@"刘德华", @"周杰伦", @"周星驰", @"周润发", @"张学友", @"任贤齐", @"古天乐"];
    NSUInteger index = arc4random_uniform((u_int32_t)msgs.count);
    self.message.text = msgs[index];

}
@end
