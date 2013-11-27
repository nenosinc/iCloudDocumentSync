//
//  TLTransitionAnimator.m
//  UIViewController-Transitions-Example
//
//  Created by Ash Furrow on 2013-07-18.
//  Copyright (c) 2013 Teehan+Lax. All rights reserved.
//

#import "TLTransitionAnimator.h"

@implementation TLTransitionAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return 0.5f;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    // Grab the from and to view controllers from the context
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    // Set our ending frame. We'll modify this later if we have to
    CGRect endFrame = CGRectMake(35, 82, 250, toViewController.view.frame.size.height);
    
    if (self.presenting) {
        fromViewController.view.userInteractionEnabled = NO;
        
        [transitionContext.containerView addSubview:fromViewController.view];
        [transitionContext.containerView addSubview:toViewController.view];
        
        CGRect startFrame = endFrame;
        startFrame.origin.x += 320;
        
        toViewController.view.frame = startFrame;
        
        
        [UIView animateWithDuration:0.3 animations:^{
            fromViewController.view.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
            fromViewController.view.alpha = 0.8;
            toViewController.view.layer.cornerRadius = 4.5;
            toViewController.view.layer.shadowOpacity = 0.2;
            toViewController.view.layer.shadowOffset = CGSizeMake(0.0, 0.0);
            toViewController.view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
            toViewController.view.layer.shouldRasterize = YES;
        }];
        
        CGFloat offset = 0.1 * (endFrame.origin.x - startFrame.origin.x);
        [UIView animateWithDuration:0.4 animations:^{
            CGRect frame = toViewController.view.frame;
            frame.origin.x = endFrame.origin.x + offset;
            toViewController.view.frame = frame;
        } completion:^(BOOL finished){
            [UIView animateWithDuration:0.25 animations:^{
                CGRect frame = toViewController.view.frame;
                frame.origin.x = endFrame.origin.x;
                toViewController.view.frame = frame;
            } completion:^(BOOL finished) {
                [transitionContext completeTransition:YES];
            }];
        }];
    } else {
        toViewController.view.userInteractionEnabled = YES;
        
        [transitionContext.containerView addSubview:toViewController.view];
        [transitionContext.containerView addSubview:fromViewController.view];
        
        endFrame.origin.x += 320;
        
        [UIView animateWithDuration:0.3 animations:^{
            toViewController.view.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
            toViewController.view.alpha = 1.0;
            fromViewController.view.frame = endFrame;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    }
}

@end