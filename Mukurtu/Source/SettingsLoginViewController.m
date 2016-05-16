//
//  SettingsLoginViewController.m
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

#import "SettingsLoginViewController.h"
#import "MukurtuSession.h"
#import "SettingsMenuViewController.h"

@interface SettingsLoginViewController ()<UITextFieldDelegate, UIAlertViewDelegate>
{
    BOOL userLoggedIn;
    BOOL _keyboardVisible;
}

@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UILabel *usernameCaptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *urlCaptionLabel;

@property (weak, nonatomic) IBOutlet UILabel *userLoggedLabel;
@property (weak, nonatomic) IBOutlet UILabel *urlLoggedLabel;

@property (weak, nonatomic) IBOutlet UITableViewCell *loginTopCell;

@property (weak, nonatomic) IBOutlet UIButton *logButton;

@property (weak, nonatomic) IBOutlet UIButton *needHelpLabel;
@end

@implementation SettingsLoginViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Register notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShowNotification:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHideNotification:) name:UIKeyboardDidHideNotification object:nil];
    
    UIView *spacerView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
    [self.usernameTextField setLeftViewMode:UITextFieldViewModeAlways];
    [self.usernameTextField setLeftView:spacerView1];
    
    UIView *spacerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
    [self.passwordTextField setLeftViewMode:UITextFieldViewModeAlways];
    [self.passwordTextField setLeftView:spacerView2];
    
    UIView *spacerView3 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
    [self.urlTextField setLeftViewMode:UITextFieldViewModeAlways];
    [self.urlTextField setLeftView:spacerView3];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    DLog(@"Login view reappeared, resetting text fields");
    
    if ([[MukurtuSession sharedSession] userIsLoggedIn])
    {
        DLog(@"User is logged in, update view");
        userLoggedIn = YES;
        [self enableLogoutView];
    }
    else
    {
        DLog(@"User is not logged in, starting with login cell");
        userLoggedIn = NO;
        [self enableLoginView];
    }
}

- (void) enableLogoutView
{
    DLog(@"Enabling logout view");
    
    MukurtuSession *session = [MukurtuSession sharedSession];
    self.userLoggedLabel.text = [session.storedUsername copy];
    self.urlLoggedLabel.text =  [session.storedBaseUrl copy];

    self.usernameTextField.hidden = YES;
    self.passwordTextField.hidden = YES;
    self.urlTextField.hidden = YES;
    self.needHelpLabel.hidden = YES;
    
    self.usernameCaptionLabel.hidden = NO;
    self.userLoggedLabel.hidden = NO;
    self.urlCaptionLabel.hidden = NO;
    self.urlLoggedLabel.hidden = NO;
    
    [self.logButton setTitle:@"LOG OUT" forState:UIControlStateNormal];
}

- (void) enableLoginView
{
    DLog(@"Enabling login view");
    
    MukurtuSession *session = [MukurtuSession sharedSession];
    self.usernameTextField.text = [session.storedUsername copy];
    self.urlTextField.text =  [session.storedBaseUrl copy];
    self.passwordTextField.text =  [session.storedPassword copy];
    
    DLog(@"user %@", session.storedUsername);
    
    self.usernameTextField.hidden = NO;
    self.passwordTextField.hidden = NO;
    self.urlTextField.hidden = NO;
    self.needHelpLabel.hidden = NO;
    
    self.usernameCaptionLabel.hidden = YES;
    self.userLoggedLabel.hidden = YES;
    self.urlCaptionLabel.hidden = YES;
    self.urlLoggedLabel.hidden = YES;
    
    [self.logButton setTitle:@"LOG IN" forState:UIControlStateNormal];
}

-(void)urlRowTap:(id)sender
{
  
}

- (IBAction)urlTextFieldTouched:(id)sender
{
    DLog(@"Url field tapped");
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad &&
        !(orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) &&
        ((self.tableView.contentSize.height - self.tableView.frame.size.height) < 100))
    {
        CGPoint offset = CGPointMake(0, 40);
        
        [self.tableView setContentOffset:offset animated:YES];
        
        DLog(@"url tapped, scroll more to fit url text field (ipad landscape only)");
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


////Keyboard Notifications
#pragma mark - Keyboard Notifications

- (void)keyboardDidShowNotification:(NSNotification *)notification {
    if (!_keyboardVisible)
    {
        _keyboardVisible = YES;

        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if ( ![[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ||
            !(orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown))
        {
            CGPoint offset = CGPointMake(0, 165);
        
            [self.tableView setContentOffset:offset animated:YES];
            
             DLog(@"keyb up, scroll to fit all text field (iphone all orientation, ipad landscape only)");
        }
    }
}

- (void)keyboardDidHideNotification:(NSNotification *)notification {
    if (_keyboardVisible)
    {
        _keyboardVisible = NO;

        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
            
            DLog(@"keyb down, scroll to bottom (iphone only, all orientations)");
        }
    }
}

////Alert view delegate
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    DLog(@"AlertView: User pressed button %@", buttonTitle);
    
    if ([buttonTitle isEqualToString:kAlertButtonAcceptLogout])
    {
        DLog(@"User confirmed logout, proceding");
        
        MukurtuSession *session = [MukurtuSession sharedSession];
        
        //disable button until login
        self.logButton.enabled = NO;
        [session logoutAndRemovePoisForController:self confirmSelector:@selector(logoutSuccess)];
    }
}

- (IBAction)loginButtonPressed:(id)sender
{
    DLog(@"Login button pressed dd");
    
    MukurtuSession *session = [MukurtuSession sharedSession];
    
    [self.view endEditing:YES];
    
    if (!userLoggedIn)
    {
        if (self.usernameTextField.text.length > 0 &&
            self.passwordTextField.text.length > 0 &&
            self.urlTextField.text.length > 0 )
        {
            session.storedUsername = [self.usernameTextField.text copy];
            session.storedPassword = [self.passwordTextField.text copy];
            session.storedBaseUrl = [self.urlTextField.text copy];
            
            //disable button until login
            self.logButton.enabled = NO;            
            
            [session loginNewSessionForController:self confirmSelector:@selector(loginResult)];
        }
        else
        {
            DLog(@"show invalid credentials alert");
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:kLoginErrorInvalidCredentials
                                                               delegate:self
                                                      cancelButtonTitle:@"Retry"
                                                      otherButtonTitles:nil];
            [alertView show];
        }
    }
    else
    {
        //user is logged in, asking logout
        //show warning
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:kLogoutWarningLostAllPoi
                                                           delegate:self
                                                  cancelButtonTitle:kAlertButtonAcceptLogout
                                                  otherButtonTitles:kAlertButtonCancel, nil];
        [alertView show];

    }
}

- (void) loginResult
{
    MukurtuSession *session = [MukurtuSession sharedSession];
    
    if (session.userIsLoggedIn)
    {
        DLog(@"LOGIN SUCCES: New Mukurtu Session ok");
        
        userLoggedIn = YES;
        [self enableLogoutView];
        self.logButton.enabled = YES;
        
        [self.delegate loginSuccesful];
    }
    else
    {
        //login failure
        DLog(@"Login failure");
        
        userLoggedIn = NO;
        [self enableLoginView];
        self.logButton.enabled = YES;
    }
}


- (void) logoutSuccess
{
    DLog(@"LOGOUT SUCCES: user logged out and poi removed");
    
    userLoggedIn = NO;
    [self enableLoginView];
    self.logButton.enabled = YES;
    
    [self.delegate logoutSuccesful];
}


#pragma mark - Text Delegate methods
- (BOOL)textFieldShouldReturn:(UITextField *)aTextField
{
    //This removes the keyboard input
    [aTextField resignFirstResponder];
    
    return TRUE;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.urlTextField)
    {
        DLog(@"check base url format");
        if (![textField.text hasPrefix:@"http://"] && ![textField.text hasPrefix:@"https://"])
            //add http as default protocol if missing
            textField.text = [NSString stringWithFormat:@"http://%@",textField.text];
        
        if (![textField.text hasSuffix:@"/"])
            //add trailing slash if missing
            textField.text = [NSString stringWithFormat:@"%@/",textField.text];
    }
}

@end
