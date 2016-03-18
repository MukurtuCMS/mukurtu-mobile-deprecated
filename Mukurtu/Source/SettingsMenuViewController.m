//
//  SettingsMenuViewController.m
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

#import "SettingsMenuViewController.h"
#import "AppDelegate.h"

#import "SettingsLoginViewController.h"
#import "MainIpadViewController.h"
#import "MainIphoneViewController.h"


@interface SettingsMenuViewController ()
{
    BOOL _forceSettingsViewUntilLogin;
}
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationBar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeButton;

@end

@implementation SettingsMenuViewController
@synthesize forceSettingsViewUntilLogin = _forceSettingsViewUntilLogin;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        //self.navigationBar.backBarButtonItem.title = @"";
        
            }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
#warning should be implemented better (global value for ipad/iphone check?)
   if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
   {
       self.closeButton.enabled = NO;
       self.closeButton.image = nil;
   }

}


- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    if (appDelegate.forceLoginView)
    {
        DLog(@"Forcing login menu item in settings");
        
        //disabling app force login flag and setting internal controller flag to stick to settings view, help, etc.
        appDelegate.forceLoginView = NO;
        
        //make sure we don't force both login and youtube login view! (may be redundant)
        appDelegate.forceYouTubeLoginView = NO;
        
        _forceSettingsViewUntilLogin = YES;
        
        [self performSegueWithIdentifier:@"SettingsMenuToLoginSegue" sender:self];
    }
    
    if (_forceSettingsViewUntilLogin)
    {
        DLog(@"hiding close button if present");
        
        self.closeButton.enabled = NO;
    }
    
    if (appDelegate.forceYouTubeLoginView)
    {
        DLog(@"Forcing preferences item in settings");
        
        //disabling app force prefs flag
        appDelegate.forceYouTubeLoginView = NO;
        
        [self performSegueWithIdentifier:@"SettingsMenuToPrefsSegue" sender:self];
    }
    
    //CGSize size =  CGSizeMake(320, 300);// size of view in popover
    //CGSize sizef =  CGSizeMake(320, 301);
    //self.preferredContentSize = sizef;
    //self.preferredContentSize = size;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    
    //CGSize size =  CGSizeMake(320, 500);// size of view in popover
    //CGSize sizef =  CGSizeMake(320, 501);
    //self.preferredContentSize = sizef;
    //self.preferredContentSize = size;

}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"SettingsMenuToLoginSegue"])
    {
        SettingsLoginViewController *loginController =  segue.destinationViewController;
        loginController.delegate = self;
    }
    
}

- (void) loginSuccesful
{
    DLog(@"Login was successful");
    _forceSettingsViewUntilLogin = NO;
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        MainIpadViewController *ipadMainController = (MainIpadViewController *)[[[[UIApplication sharedApplication] delegate] window]rootViewController];
    
        [ipadMainController.settingsPopoverController dismissPopoverAnimated:YES];
        [ipadMainController syncButtonPressed:nil];
    }
    else
    {
        
        [self dismissViewControllerAnimated:NO completion:nil];
        
        MainIphoneViewController *iphoneMainController = (MainIphoneViewController *)[[[[UIApplication sharedApplication] delegate] window]rootViewController];
        
        [iphoneMainController syncButtonPressed:nil];

        
    }
}

- (void) logoutSuccesful
{
    DLog(@"Logout was successful");
    _forceSettingsViewUntilLogin = YES;
    
    //ask reload of poi table on ipad only
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        
        MainIpadViewController *ipadMainController = (MainIpadViewController *) [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        
        DLog(@"IPad only: ask reload of poi table to root controller %@", [ipadMainController description]);
        [ipadMainController reloadPoiTable];
        
    }
    
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)menuButtonPressed:(id)sender
{
    UIView *contentView = [sender superview];
    contentView.backgroundColor = kUIColorMediumGrayBackground;
}

- (IBAction)menuButtonUp:(id)sender
{
    UIView *contentView = [sender superview];
    contentView.backgroundColor = kUIColorDarkGrayBackground;

}
- (IBAction)closeSettingsButtonPressed:(id)sender
{
    
    if (!self.forceSettingsViewUntilLogin)
        [self dismissViewControllerAnimated:YES completion:nil];
    
}
@end
