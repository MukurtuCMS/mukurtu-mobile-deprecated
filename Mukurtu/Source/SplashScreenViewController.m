//
//  SplashScreenViewController.m
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

#import "SplashScreenViewController.h"

#define IS_IPHONE5 (([[UIScreen mainScreen] bounds].size.height-568)?NO:YES)

@interface SplashScreenViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *getStartButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *getStartPaddingBottom;

@end

@implementation SplashScreenViewController

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
    [self adjustBackgroundImageOrientation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)getStartButtonPressed:(id)sender
{
    DLog(@"Get start button pressed");
    [self dismissViewControllerAnimated:YES completion:nil];
    
}


-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    DLog(@"Interface orientation change while Splashscreen");
    
    [self adjustBackgroundImageOrientation];
    
}

-(void)adjustBackgroundImageOrientation
{

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        //iPad
        if (self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        {
            //portrait
            [self.imageView setImage:[UIImage imageNamed:@"cover_ipad_portrait.jpg"]];
        }
        else
        {
            //landscape
            [self.imageView setImage:[UIImage imageNamed:@"cover_ipad_landscape.jpg"]];
        }
        
        [self.getStartButton setImage:[UIImage imageNamed:@"Tablet-Getstarted-btn.jpg"] forState:UIControlStateNormal];
        self.getStartPaddingBottom.constant = 20.0;
        [self.view layoutIfNeeded];
    }
    else
    {
        //iPhone
        
        if (IS_IPHONE5)
            [self.imageView setImage:[UIImage imageNamed:@"cover_iphone5_portrait.jpg"]];
        else
            [self.imageView setImage:[UIImage imageNamed:@"cover_iphone4_portrait.jpg"]];
        
        
        [self.getStartButton setImage:[UIImage imageNamed:@"Phone-Getstarted-btn.jpg"] forState:UIControlStateNormal];
        self.getStartPaddingBottom.constant = 15.0;
        [self.view layoutIfNeeded];
    }

    
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
