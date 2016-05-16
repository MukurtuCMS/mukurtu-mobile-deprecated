//
//  SettingsPrefsViewController.m
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

#import "SettingsPrefsViewController.h"
#import "MukurtuSession.h"
#import "AppDelegate.h"

#import "YouTubeHelper.h"
#import "MainIpadViewController.h"
#import "MainIphoneViewController.h"

@interface SettingsPrefsViewController ()<YouTubeStatusReportDelegate>
{
    
}

@property (weak, nonatomic) IBOutlet UISwitch *unlistedVideoSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *addMukurtuKeywordSwitch;
@property (weak, nonatomic) IBOutlet UILabel *youTubeLoginLabel;

@property (weak, nonatomic) YouTubeHelper *youtubeHelper;

//imageres
@property (weak, nonatomic) IBOutlet UIButton *fullCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *resizeLargeButton;
@property (weak, nonatomic) IBOutlet UIButton *resizeMediumButton;
@property (weak, nonatomic) IBOutlet UIButton *resizeSmallButton;
@property (weak, nonatomic) IBOutlet UIButton *resizeWebButton;
@end

@implementation SettingsPrefsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    MukurtuSession *sharedSession = [MukurtuSession sharedSession];
    _youtubeHelper = sharedSession.youTubeHelper;
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //force popover size to default (youtube login may have changed it)
    UIViewController *rootController = self.navigationController.viewControllers[0];
    CGSize size =  rootController.view.bounds.size; // size of view in popover
    
    self.preferredContentSize = size;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateUI];
    
    //fake wrong preferred size for a moment to force updating popover size with animation
    //http://stackoverflow.com/questions/2752394/popover-with-embedded-navigation-controller-doesnt-respect-size-on-back-nav
    
    UIViewController *rootController = self.navigationController.viewControllers[0];
    CGSize size =  rootController.view.bounds.size; // size of view in popover
    CGSize sizefake =  CGSizeMake(size.width - 1, size.height - 1);
    self.preferredContentSize = sizefake;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)reportLoginError:(NSError *)error
{
    DLog(@"YouTube Login process completed");
    
    if (error)
    {
        DLog(@"YouTube Login returned Auth Error %@", error.description);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"YouTube Login Failed" message:@"Could not login to your YouTube Account.\nPlease try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
    else
    {
        DLog(@"YouTube Login was successfull, updating UI");
    }
    
    [self updateUI];
}

- (IBAction)youtubeLoginButtonPressed:(id)sender
{
    DLog(@"YouTube Login/Logout button pressed");
    
    MukurtuSession *sharedSession = [MukurtuSession sharedSession];
    
    if (!sharedSession.userIsLoggedIn)
    {
        DLog(@"User is not logged in, show alert and force mukurtu login view");
        
        //make sure we have logged out from youtube (redudant)
        [_youtubeHelper signOut];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Mukurtu Login Required" message:@"Please login to your Mukurtu CMS powered site to upload your videos to YouTube." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        appDelegate.forceLoginView = YES;
        
        [self.navigationController popViewControllerAnimated:YES];
    }
    else
    {
        DLog(@"User is logged on mukurtu instance, preparing to youtube login/logout");
        
        if ([_youtubeHelper isAuthValid])
        {
            [_youtubeHelper signOut];
            sharedSession.youTubeStatusReportDelegate = nil;
            
            [self updateUI];
        }
        else
        {
            sharedSession.youTubeSettingsNavigationController = self.navigationController;
            sharedSession.youTubeStatusReportDelegate = self;
            
            [_youtubeHelper authenticate];
        }
    }
}

- (IBAction)unlistedVideoSwitchChanged:(id)sender
{
    NSString *switchKey = kPrefsUnlistedVideoKey;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    UISwitch *aSwitch = (UISwitch *)sender;
    
    [defaults setBool:aSwitch.isOn forKey:switchKey];
    
    [defaults synchronize];
    
    DLog(@"Switch %@ is now %@", switchKey, aSwitch.isOn?@"On":@"Off");
}


- (IBAction)resizeImagesRadioButtonPressed:(id)sender
{
    DLog(@"Resize Radio Button Pressed");
    
    UIButton *touchedRadioButton = (UIButton *)sender;
    
    NSArray *allRadioButtons = @[self.fullCameraButton, self.resizeLargeButton, self.resizeMediumButton, self.resizeSmallButton, self.resizeWebButton];
    NSArray *orderedResizeTags = @[kMukurtuResizedImagePostfixFull, kMukurtuResizedImagePostfixLarge, kMukurtuResizedImagePostfixMedium, kMukurtuResizedImagePostfixSmall, kMukurtuResizedImagePostfixWeb];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //defaults to full res in case of errors
    NSString *resizeFactorTag = kMukurtuResizedImagePostfixFull;
    
    for (UIButton *radioButton in allRadioButtons)
    {
        if (radioButton == touchedRadioButton)
        {
            resizeFactorTag = [orderedResizeTags[[allRadioButtons indexOfObject:radioButton]] copy];
            
            DLog(@"Enabling image resize %@", resizeFactorTag);
        }
    }
    [defaults setValue:resizeFactorTag forKey:kPrefsMukurtuResizeImagesKey];
    [self updateUI];
}


- (IBAction)addMukurtuKeywordSwitchChanged:(id)sender
{
    NSString *switchKey = kPrefsMukurtuKeywordKey;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    UISwitch *aSwitch = (UISwitch *)sender;
    
    [defaults setBool:aSwitch.isOn forKey:switchKey];
    
    [defaults synchronize];
    
    DLog(@"Switch %@ is now %@", switchKey, aSwitch.isOn?@"On":@"Off");
}

- (void)updateUI
{
    DLog(@"updating UI from saved defaults");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL needSynchronize = NO;
    
    //youtube login/logout label
    if (![_youtubeHelper isAuthValid])
    {
        DLog(@"user is not logged to youtube, show login label");
        
        [self.youTubeLoginLabel setText:@"YouTube Login"];
    }
    else
    {
        DLog(@"user is logged to youtube, show logout label");

        NSString *userEmail = _youtubeHelper.getLoggedUserEmail;
        [self.youTubeLoginLabel setText:[NSString stringWithFormat:@"Sign Out\n%@",userEmail]];
    }
    
    //reload table to show invalid pois for having videos and no youtube login
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DLog(@"Taking a weak reference to main view controller for ipad and reload poi table");
        
        MainIpadViewController *mainIpad = (MainIpadViewController *)appDelegate.window.rootViewController;
        
        [mainIpad reloadPoiTable];
    }
    else
    {
        DLog(@"Taking a weak reference to main view controller for iphone and reload poi table");
        
        MainIphoneViewController *mainIphone = (MainIphoneViewController *)appDelegate.window.rootViewController;
        
        [mainIphone reloadPoiTable];
    }
    
    //unlisted videos switch
    if ([defaults objectForKey:kPrefsUnlistedVideoKey])
    {
        [self.unlistedVideoSwitch setOn:[defaults boolForKey:kPrefsUnlistedVideoKey] animated:NO];
    }
    else
    {
        DLog(@"unlisted video switch defaults not found (first run?), using app default status for switch");
        [defaults setBool:YES forKey:kPrefsUnlistedVideoKey];
        needSynchronize = YES;
    }

    //add mukurtu mobile keyword switch
    if ([defaults objectForKey:kPrefsMukurtuKeywordKey])
    {
        [self.addMukurtuKeywordSwitch setOn:[defaults boolForKey:kPrefsMukurtuKeywordKey] animated:NO];
    }
    else
    {
        DLog(@"add mukurtu mobile switch defaults not found (first run?), using app default status for switch");
        [defaults setBool:YES forKey:kPrefsMukurtuKeywordKey];
        needSynchronize = YES;
    }

    NSString *currentResizeImageTag;
    if ([defaults objectForKey:kPrefsMukurtuResizeImagesKey])
    {
        currentResizeImageTag = [defaults objectForKey:kPrefsMukurtuResizeImagesKey];
    }
    else
    {
        DLog(@"mukurtu mobile resize image factor defaults key not found (first run?), using full res as default");
        [defaults setValue:kMukurtuResizedImagePostfixFull forKey:kPrefsMukurtuResizeImagesKey];
        currentResizeImageTag = kMukurtuResizedImagePostfixFull;
        needSynchronize = YES;
    }
    
    //update radio buttons
    DLog(@"Saved resize images factor postfix is %@", currentResizeImageTag);
    NSArray *allRadioButtons = @[self.fullCameraButton, self.resizeLargeButton, self.resizeMediumButton, self.resizeSmallButton, self.resizeWebButton];
    NSArray *orderedResizeTags = @[kMukurtuResizedImagePostfixFull, kMukurtuResizedImagePostfixLarge, kMukurtuResizedImagePostfixMedium, kMukurtuResizedImagePostfixSmall, kMukurtuResizedImagePostfixWeb];
    
    for (NSString *resizeFactorTag in orderedResizeTags)
    {
        UIButton *selectedButton = allRadioButtons[[orderedResizeTags indexOfObject:resizeFactorTag]];
        
        if ([currentResizeImageTag isEqualToString:resizeFactorTag])
        {
            //enable selected button
            [selectedButton setImage:[UIImage imageNamed:@"radio_btn_full.png"] forState:UIControlStateNormal];
        }
        else
        {
            //disable other buttons
            [selectedButton setImage:[UIImage imageNamed:@"radio_btn_empty.png"] forState:UIControlStateNormal];
        }
    }
    
    if (needSynchronize)
    {
        [defaults synchronize];
    }
}

@end
