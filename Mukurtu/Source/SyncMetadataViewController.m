//
//  SyncMetadataViewController.m
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

#import "SyncMetadataViewController.h"

@interface SyncMetadataViewController ()

@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@end

@implementation SyncMetadataViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

-(void)dealloc {
    //breakpoint here to check for leaks
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) reportSyncFailed
{
    DLog(@"Sync failed, report error");
    
    self.cancelButton.enabled = NO;
    self.cancelButton.hidden = YES;
    
    self.messageLabel.text = @"Sync failed, retry later";
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
}

- (void) reportSyncDone
{
    DLog(@"Sync completed, report success");
    
    self.cancelButton.enabled = NO;
    self.cancelButton.hidden = YES;
    self.messageLabel.text = @"Sync complete!";
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
}

- (IBAction)cancelButtonPressed:(id)sender
{
    DLog(@"Metadata sync cancel button pressed");
    
    self.cancelButton.enabled = NO;
    self.cancelButton.hidden = YES;
    self.messageLabel.text = @"Sync canceled";
    
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    
    if (self.delegate && [self.delegate respondsToSelector:self.cancelSelector])
    {
        DLog(@"Reporting cancel sync request to delegate %@", [self.delegate description]);
        SuppressPerformSelectorLeakWarning([self.delegate performSelector:self.cancelSelector]);
    }
}

@end
