//
//  SlideLeftSegue.m
//
//MukurtuMobile
//Mukurtu Mobile is a mobile authoring tool for Mukurtu CMS, a digital
//heritage management system designed with the needs of indigenous
//communities in mind.
//http://mukurtumobile.org/
//Copyright (C) 2012-2016  CoDA https://codifi.org
//
//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "SlideLeftSegue.h"
#import <QuartzCore/QuartzCore.h>

@implementation SlideLeftSegue

- (id) initWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination
{
	self = [super initWithIdentifier:identifier source:source destination:destination];
	if (self) {
		_unwinding = NO;
	}
	return self;
}
- (void)perform{
    UIViewController *srcViewController = (UIViewController *) self.sourceViewController;
    UIViewController *destViewController = (UIViewController *) self.destinationViewController;
    
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionPush;
    
    if (!_unwinding)
        transition.subtype = kCATransitionFromRight;
    else
    {
        //reverse animation
        transition.subtype = kCATransitionFromLeft;
    }
    
    [srcViewController.view.window.layer addAnimation:transition forKey:nil];
    
    
    if (self.unwinding) {
        [self.destinationViewController dismissViewControllerAnimated:NO completion:nil];
    } else {
            [srcViewController presentViewController:destViewController animated:NO completion:nil];
    }

    
}


@end
