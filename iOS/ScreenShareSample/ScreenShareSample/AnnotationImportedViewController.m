//
//  ViewController.m
//  ScreenShareSample
//
//  Created by Xi Huang on 4/26/16.
//  Copyright © 2016 Lucas Huang. All rights reserved.
//

#import "AnnotationImportedViewController.h"
#import <ScreenShareKit/ScreenShareKit.h>

@interface AnnotationImportedViewController ()
@property (nonatomic) OTAnnotationScrollView *screenShareView;
@end

@implementation AnnotationImportedViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // screen share view
    UIImage *image = [UIImage imageNamed:@"mvc"];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    
    self.screenShareView = [[OTAnnotationScrollView alloc] initWithFrame:CGRectMake(0,
                                                                                    64.0f,
                                                                                    CGRectGetWidth([UIScreen mainScreen].bounds),
                                                                                    CGRectGetHeight([UIScreen mainScreen].bounds) - 44 - 64)];
    [self.screenShareView addContentView:imageView];
    
    [self.screenShareView initializeToolbarView];
    CGFloat height = self.screenShareView.toolbarView.bounds.size.height;
    self.screenShareView.toolbarView.frame = CGRectMake(0, CGRectGetHeight([UIScreen mainScreen].bounds) - height, self.screenShareView.toolbarView.bounds.size.width, height);
    
//    self.screenShareView.frame = ;
    [self.view addSubview:self.screenShareView];
    [self.view addSubview:self.screenShareView.toolbarView];
}

@end