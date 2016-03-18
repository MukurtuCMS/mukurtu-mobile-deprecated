//
//  UploadProgressViewController.m
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

#import "UploadProgressViewController.h"

@interface UploadProgressViewController ()
{
    BOOL _cancelingUpload;
}
@property (weak, nonatomic) IBOutlet UILabel *uploadLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIView *backgroundView;

@property (weak, nonatomic) IBOutlet UILabel *progressStatusLabel;

@end

@implementation UploadProgressViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    _poiToUpload = 0;
    _poiUploaded = 0;
    _cancelingUpload = NO;
    
    [self updateProgressLabel];
    
    if (self.delegate && [self.delegate respondsToSelector:self.uploadDidLoadDelegate])
    {
        [self.delegate performSelector:self.uploadDidLoadDelegate withObject:nil afterDelay:1.0];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) updateProgressStatus:(NSString *)newStatus
{
    [self.progressStatusLabel setText:newStatus];
}

- (void) updateProgressLabel
{
    DLog(@"updating progress label");
    
    //Update label
    if (_cancelingUpload)
    {
        DLog(@"Canceling upload, confirm cancel in progress label");
        self.uploadLabel.text = @"Upload canceled";
        [self updateProgressStatus:@""];
    }
    
    if (_poiUploaded < _poiToUpload)
    {
        DLog(@"No poi uploaded yet or all uploaded, ignoring prgress label update");
        self.uploadLabel.text = [NSString stringWithFormat:@"Uploading story %d of %d", (int) _poiUploaded + 1, (int) _poiToUpload];
    }
    
}


- (void) updateProgressBar
{
    float progressValue;
    
    //FIX 2.5: fixed initial progess value special case
    if (self.poiToUpload == 0 && self.poiUploaded == 0)
    {
        progressValue = 0.0;
    }
    else
    {
        //progressValue = (float)self.poiUploaded / (float)self.poiToUpload;
        progressValue = (float)self.poiUploaded / (float)self.poiToUpload;
    }
    DLog(@"progress value %f", progressValue);
    
    self.progressBar.progress = progressValue;

    [self updateProgressLabel];
    
#warning DON'T MAKE PROGRESS BAR CONTROL WHEN UPLOAD IS COMPLETE!! IT'S HORRIBLE!
    if (!_cancelingUpload && _poiToUpload == _poiUploaded)
    {
        //all poi uploaded or with errors
        self.uploadLabel.text = @"Upload complete";
        [self updateProgressStatus:@""];
        [self successConfirmed];
    }
}

- (IBAction)cancelButtonPressed:(id)sender
{
    DLog(@"Cancel button pressed");
    
    //self.uploadLabel.text = @"Upload canceled";
    [self updateProgressLabel];
    
    self.cancelButton.hidden = YES;
    self.progressBar.hidden = YES;
    _cancelingUpload = YES;
    
    [self.delegate performSelector:self.uploadCancelDelegate withObject:nil afterDelay:1.0];
    
}

- (void)cancelConfirmed
{
    DLog(@"Cancel confirmed");
}


- (void)destroyUpload
{
    DLog(@"Destroy upload ");
}

- (void)successConfirmed
{
    
    DLog(@"Success confirmed ");
    
    if (_cancelingUpload)
        return;
    
    self.uploadLabel.text = @"Upload complete";
    [self updateProgressStatus:@""];
    
    self.cancelButton.hidden = YES;
    [self.progressBar setProgress:1.0 animated:YES];
    
    [self.delegate performSelector:self.uploadSuccessDelegate withObject:nil afterDelay:1.0];
    
}

@end
