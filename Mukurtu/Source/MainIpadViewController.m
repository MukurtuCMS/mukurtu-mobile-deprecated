//
//  MainIpadViewController.m
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

#import "MainIpadViewController.h"
#import "IpadRightViewController.h"
#import "PoiTableViewController.h"

#import "Poi.h"
#import "AppDelegate.h"
#import "SettingsMenuViewController.h"
#import "MukurtuSession.h"
#import "SyncMetadataViewController.h"
#import "UploadProgressViewController.h"
#import "ImageSaver.h"
#import "SplashScreenViewController.h"


#define kMukurtuActionSheetSyncMetadata 1

#define kYouTubeNeededAlert 42

@interface MainIpadViewController() <UIPopoverControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate>


@property (weak, nonatomic) IBOutlet UIButton *settingsBarButton;

@property (weak, nonatomic) IBOutlet UIButton *createButton;
@property (weak, nonatomic) IBOutlet UIButton *editPoiTableButton;
@property (weak, nonatomic) IBOutlet UIButton *syncMetadataButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadPoisButton;
@property (weak, nonatomic) IBOutlet UIButton *openWebViewButton;

@property (weak, nonatomic) IBOutlet UIView *editButtonBgView;
@property (weak, nonatomic) IBOutlet UILabel *editButtonLabel;

@property (weak, nonatomic) IBOutlet UIView *viewToolbar;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *rightViewControllerWidth;

@property (weak, nonatomic) IpadRightViewController *rightViewController;
@property (weak, nonatomic) PoiTableViewController *leftViewController;


@property (weak, nonatomic) SettingsMenuViewController *settingsMenuViewController;

@property (strong,nonatomic) UIPopoverController *syncPopoverController;
@property (weak, nonatomic) SyncMetadataViewController *syncViewController;
    
@property (strong,nonatomic) UIPopoverController *uploadPopoverController;
@property (weak, nonatomic) UploadProgressViewController *uploadViewController;
@property (strong, nonatomic) SplashScreenViewController *splashScreenViewController;


@end

@implementation MainIpadViewController

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
    
    DLog(@"Main view did load");

    //TODO: reachability is not reliable and have been disabled as now
    //DLog(@"If we have a base url, reset http client to start reachability test");
    //[[MukurtuSession sharedSession] resetClientReachabilityTest];
    
    [self checkSplashScreen];

}

- (void) checkSplashScreen
{
    self.splashScreenViewController = nil;
    
    //check first launch here
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *lockfile = [[directories firstObject] stringByAppendingString:@"/launchlock.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:lockfile])
    {
        DLog(@"App first launch after install or reinstall (updates are ignored)");
        
        if ([[NSString stringWithFormat:@"LOCK"] writeToFile:lockfile atomically:YES encoding:NSUTF8StringEncoding error:nil])
        {
            DLog(@"Created Launchlock.plist > %@", lockfile);
            //show splascreen only if writing lockfile succeded,
            //this avoid presenting splashcreen everytime if writing lockfile fails
            
            UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
            SplashScreenViewController *splashScreenController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"SplashScreenViewController"];
            
            [splashScreenController setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];

            self.splashScreenViewController = splashScreenController;
            
            [self.view setHidden:YES];
        }
    }
    else
    {
        DLog(@"Lockfile exists, skipping splashscreen");
        
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewDidAppear:(BOOL)animated
{
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    if (self.splashScreenViewController != nil)
    {
        DLog(@"Showing splash screen");
        [self presentViewController:self.splashScreenViewController animated:YES completion:nil];
        self.splashScreenViewController = nil;
        [self.view setHidden:NO];
        
    }
    else
    {
        [self.rightViewController authorizeLocationServices];
        
        if (appDelegate.forceLoginView)
        {
            DLog(@"Forcing login view");
            [self showSettingsPopover:nil];
        }
    }
    
    [super viewDidAppear:animated];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"RightViewController"])
    {
        self.rightViewController = segue.destinationViewController;
        self.rightViewController.mainViewController = self;
    }
    else
    if ([segue.identifier isEqualToString:@"LeftViewController"])
    {
        self.leftViewController = segue.destinationViewController;
        self.leftViewController.mainViewController = self;
    }
}


//Handle Orientation
-(void)updateViewConstraints
{
    [super updateViewConstraints];
    
    DLog(@"screen size w:%f x h: %f", self.view.bounds.size.width, self.view.bounds.size.height);
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        self.rightViewControllerWidth.constant = self.view.bounds.size.width;
    }
    else
    {
#warning customize right view controller width for different screen aspect ratio
        self.rightViewControllerWidth.constant = self.view.bounds.size.width * 0.6875   ;
    }
    
}

 
-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.settingsPopoverController.popoverVisible)
    {
        [self.settingsPopoverController dismissPopoverAnimated:NO];
        CGRect arrowRect = self.settingsBarButton.frame;
        arrowRect.size.height = arrowRect.size.height * 1.5;
        
        [self.settingsPopoverController presentPopoverFromRect:arrowRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    }
    
}


- (void)editPoi:(Poi *)poi
{
    DLog(@"Table controller want to edit poi %@", poi.title);
    [self.rightViewController showCreatePoiPopoverForPoi:poi];
}

- (void)updateMainMap
{
    DLog(@"Updating main map, zoom to fit all annotations");
    
    [self.rightViewController resetMainMapAnnotations];
}


- (void) enterEditMode
{
    DLog(@"Entering edit mode");
    
    [self.leftViewController setEditing:YES animated:YES];
    
    self.createButton.enabled = NO;
    self.syncMetadataButton.enabled = NO;
    self.uploadPoisButton.enabled = NO;
    self.settingsBarButton.enabled = NO;
    self.openWebViewButton.enabled = NO;
    self.rightViewController.view.userInteractionEnabled = NO;
    
    [self.editPoiTableButton setImage:[UIImage imageNamed:@"icon_edit_DONE"] forState:UIControlStateNormal];
    [self.editButtonBgView setBackgroundColor:kUIColorOrange];
    [self.editButtonLabel setText:@"Done"];
    
    
    [self updateMainMap];
}


- (void) leaveEditMode
{
    DLog(@"Leaving edit mode");
    
    [self.leftViewController setEditing:NO animated:YES];
    
    self.createButton.enabled = YES;
    self.syncMetadataButton.enabled = YES;
    self.uploadPoisButton.enabled = YES;
    self.settingsBarButton.enabled = YES;
    self.openWebViewButton.enabled = YES;
    self.rightViewController.view.userInteractionEnabled = YES;
    
    [self.editPoiTableButton setImage:[UIImage imageNamed:@"icon_edit"] forState:UIControlStateNormal];
    [self.editButtonBgView setBackgroundColor:kUIColorDarkBarBackground];
    [self.editButtonLabel setText:@"Edit"];

}


- (void)dismissSettingsPopover
{
    DLog(@"Dismissing settings popover");
    
    [self.settingsPopoverController dismissPopoverAnimated:YES];
}

////Actions
#pragma mark - actions
- (IBAction)openWebViewPressed:(id)sender
{
    DLog(@"Open WebView button pressed, presenting modal webview");
    
    if ([[MukurtuSession sharedSession] isBaseUrlReachable])
    {
        DLog(@"Base URL is reachable, launch web view");

        UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    
        UIViewController *webViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"WebSiteViewController"];
        webViewController.view.frame = self.view.frame;
    
        [self presentViewController:webViewController animated:YES completion:nil];
    }
    else
    {
        DLog(@"Base URL is not reachable");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                        message:@"This Mukurtu site is not reachable now. Check the URL you provided and your Internet connection and retry"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
    }
}

- (IBAction)showSettingsPopover:(id)sender
{
#warning should put sharedStoryboard in commander singleton
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    UINavigationController *settingsViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"SettingsMainMenu"];
    self.settingsMenuViewController = [settingsViewController.viewControllers firstObject];
    
    UIPopoverController *settingsPopover = [[UIPopoverController alloc] initWithContentViewController:settingsViewController];
    
    settingsPopover.delegate = self;
    
    
    self.settingsPopoverController = settingsPopover;
    self.settingsPopoverController.popoverLayoutMargins = UIEdgeInsetsMake(10, 10, 10, 10 * 1.7);
    
    CGRect arrowRect = self.settingsBarButton.frame;
    arrowRect.size.height = arrowRect.size.height * 1.5;
    
    [settingsPopover presentPopoverFromRect:arrowRect
                                     inView:self.view
                   permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    
    
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    BOOL canDismiss = YES;
    
    if ([self.settingsMenuViewController isKindOfClass:[SettingsMenuViewController class]])
    {
        DLog(@"current settings menu %@", [self.settingsMenuViewController description]);
        canDismiss = !self.settingsMenuViewController.forceSettingsViewUntilLogin;
    }
    else
        canDismiss = NO;

    if ([popoverController.contentViewController isKindOfClass:[SyncMetadataViewController class]] ||
        [popoverController.contentViewController isKindOfClass:[UploadProgressViewController class]])
        return NO;
    
    return (canDismiss);
}


- (IBAction)createPoiButtonPressed:(id)sender
{
    DLog(@"Create Poi button pressed");
    
    [self.rightViewController showCreatePoiPopover];
}

- (void)reloadPoiTable
{
    DLog(@"Refreshing poi list table");
    
    [self.leftViewController reloadData];
}



- (IBAction)editPoiTablePressed:(id)sender
{
    DLog(@"Edit Poi Table pressed");
    
    if (![self.leftViewController isEditing])
    {
        //ignore if no poi in list
        if (![self.leftViewController.poiList count])
        {
            //TODO: may show an alert or visual feedback to notify upload skipping
            DLog(@"No poi in list, ignoring upload request");
        }
        else
            [self enterEditMode];
    }
    else
    {
        [self leaveEditMode];
    }
}


- (void)uploadCanceled
{
    DLog(@"Upload was canceled");
    
    [[MukurtuSession sharedSession] cancelUpload];
    
    [self dismissPopoverUpload];
    
    //Remove all poi uploaded with success
    //TODO: could verify if poi actually are visibile on server before removing them (complex task)
    NSArray *uploadedPois = [[[MukurtuSession sharedSession] uploadedPoiList] copy];
    
    DLog(@"We have uploaded %d poi with success, removing them", (int)[uploadedPois count]);
#ifdef REMOVE_POI_AFTER_UPLOAD
    [self removePoisFromArray:uploadedPois];
#endif
    
    //show error to user
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning!" message:kUploadAllPoiFailure
                                                       delegate:self
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil];
    [alertView show];
    
    //enabling auto lock screen
    DLog(@"Enabling screen auto lock");
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}


- (void) removePoisFromArray:(NSArray *)poiArray
{
    DLog(@"Removing %d pois after upload", (int)[poiArray count]);
    
    for (Poi *poi in [poiArray copy])
    {
        DLog(@"removing %d media and files for poi %@ from store", (int)[poi.media count], poi.title);
        for (PoiMedia *media in [poi.media allObjects])
        {
            [ImageSaver deleteMedia:media];
        }
        
        DLog(@"removing poi %@ from store", poi.title);
        [poi MR_deleteEntity];
    }
    
    DLog(@"Saving context");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    [self reloadPoiTable];
}


- (void)uploadSuccesful
{
    DLog(@"Upload finished with success");
    
    
    DLog(@"Saving context to store changes and errors");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    [self dismissPopoverUpload];
    
    
    //Remove all poi uploaded with success
    //TODO: could verify if poi actually are visibile on server before removing them (complex task)
    NSArray *uploadedPois = [[[MukurtuSession sharedSession] uploadedPoiList] copy];
    
    DLog(@"We have uploaded %d poi with success, removing them", (int)[uploadedPois count]);
    //DLog(@"DEBUG: uploaded poi list to remove %@", [uploadedPois description]);
#ifdef REMOVE_POI_AFTER_UPLOAD
    [self removePoisFromArray:uploadedPois];
#endif
    
    //display error message for partial upload / upload failed
    [self.leftViewController showUploadResult];
    
    //enabling auto lock screen
    DLog(@"Enabling screen auto lock");
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
}

- (void) dismissPopoverUpload
{
    if (self.uploadPopoverController.isPopoverVisible)
    {
        DLog(@"dismissing popover upload");
        [self.uploadPopoverController dismissPopoverAnimated:YES];
        
        //free upload progress and popover reference
        self.uploadViewController = nil;
        self.uploadPopoverController = nil;
    }
    else
        DLog(@"popover upload was alredy dismissed, ignoring dismiss request");
}

- (void)uploadFailed
{
    DLog(@"Upload failed");
    
    //enabling auto lock screen
    DLog(@"Enabling screen auto lock");
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)syncBeforeUploadCompleted
{
    DLog(@"sync before uplaod completed, continue to login");
    
    MukurtuSession *session = [MukurtuSession sharedSession];
    
    if (session.lastLoginSuccess && session.lastSyncSuccess)
    {
        DLog(@"Last login and sync was ok, continue with upload");
        
        UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
        UploadProgressViewController *uploadViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"UploadProgressViewController"];
        uploadViewController.delegate = self;
        uploadViewController.uploadCancelDelegate = @selector(uploadCanceled);
        uploadViewController.uploadSuccessDelegate = @selector(uploadSuccesful);
        uploadViewController.uploadFailureDelegate = @selector(uploadFailed);
        
        //added callback to handle upload job starting only *after* upload progress controller actually did load
        uploadViewController.uploadDidLoadDelegate = @selector(uploadProgressControllerDidLoad);
        self.uploadViewController = uploadViewController;
        
        //should validate all poi against updated metadata
        [[MukurtuSession sharedSession] validateAllPois];
        [self reloadPoiTable];

        [self.syncViewController reportSyncDone];
        
        DLog(@"\nPresenting upload progress popover");
        //replace sync popover content controller with upload progress
        self.uploadPopoverController = self.syncPopoverController;
        self.uploadPopoverController.contentViewController = uploadViewController;
        
        //release syncMetadata view controller and popover
        self.syncViewController = nil;
        self.syncPopoverController = nil;
        
    }
    else
    {
        DLog(@"Last login or sync failed, quitting upload job with errors");
        [self dismissPopoverSync];
        
    }

}

//added callback to handle upload job starting only *after* upload progress controller actually did load
- (void)uploadProgressControllerDidLoad
{
    DLog(@"Upload view controller loaded, start upload job");
    
    //disable auto lock screen
    DLog(@"Disabling screen auto lock");
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    //Actually start upload job
    [[MukurtuSession sharedSession] startUploadJobFromDelegate:self.uploadViewController];
}

- (IBAction)uploadButtonPressed:(id)sender
{
    DLog(@"Upload button pressed");
    
    //ignore if no poi in list
    if (![self.leftViewController.poiList count])
    {
        //TODO: may show an alert or visual feedback to notify upload skipping
        DLog(@"No poi in list, ignoring upload request");
        return;
    }
    
    if ([[MukurtuSession sharedSession] uploadNeedsYouTubeButNoLogin])
    {
        DLog(@"We have some videos to upload, but user is not logged in youtube, show alert");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"YouTube Login Needed" message:kUploadNeedYouTubeAlert delegate:self cancelButtonTitle:kUploadNeedYouTubeAlertButtonCancel otherButtonTitles:kUploadNeedYouTubeAlertButtonLoginNow,kUploadNeedYouTubeAlertButtonUploadAnyway, nil];
        alert.tag = kYouTubeNeededAlert;
        [alert show];
        return;
    }
    
    [self startUploadJob];
    
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kYouTubeNeededAlert)
    {
        NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
        
        if ([title isEqualToString:kUploadNeedYouTubeAlertButtonLoginNow])
        {
            DLog(@"Cancel upload and force youtube login settings view");
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            appDelegate.forceYouTubeLoginView = YES;
            
            //Force validation of all pois to report invalid pois for having videos and missing youtube login
            MukurtuSession *sharedSession = [MukurtuSession sharedSession];
            [sharedSession resetAllInvalidPoisForVideosAndValidate];
            
            [self showSettingsPopover:nil];
            
        }
        else
            if ([title isEqualToString:kUploadNeedYouTubeAlertButtonUploadAnyway])
            {
                DLog(@"Ignore youtube login, skip pois with videos and upload other ones");
                [self startUploadJob];
            }
            else
            {
                DLog(@"Just cancel upload");
            }
    }
    //else
    //just cancel any other alert view
}

- (void)startUploadJob
{
    DLog(@"Starting upload job (sync, validate, upload)");
    
    //Overlay metadata sync before upload
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    SyncMetadataViewController *syncViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MetadataSyncController"];
    syncViewController.delegate = self;
    syncViewController.cancelSelector = @selector(cancelMetadataSync);
    self.syncViewController = syncViewController;
    
    UIPopoverController *syncPopover  = [[UIPopoverController alloc] initWithContentViewController:syncViewController];
    syncPopover.delegate = self;
    
    self.syncPopoverController = syncPopover;
    
#warning hardcoded size for popover
    self.syncPopoverController.popoverContentSize = CGSizeMake(300, 180);
    
    CGRect arrowRect2 = CGRectMake(self.viewToolbar.frame.size.width / 2, -8, 1, 1);
    
    
    [self.syncPopoverController presentPopoverFromRect:arrowRect2
                                                inView:self.viewToolbar
                              permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
    
    //Actually start metadata sync
    [[MukurtuSession sharedSession] startMetadataSyncFromDelegate:self confirmSelector:@selector(syncBeforeUploadCompleted)];

}

- (void) cancelMetadataSync
{
    DLog(@"User asked to cancel metadata sync");

    //should interrupt mukurtu session here
    
    MukurtuSession *session = [MukurtuSession sharedSession];
    
    [session cancelMetadataSync];
    
    //FIXME: could set local flag isDismissing like mainiphone controller to dismiss popover only once!!
    //dismiss popover
    [self performSelector:@selector(dismissPopoverSync) withObject:nil afterDelay:1.0];
}

- (void) syncCompleted
{
    DLog(@"Session report sync completed, alert user");
    
    if ([[MukurtuSession sharedSession] lastSyncSuccess])
    {
        [self.syncViewController reportSyncDone];
        
        //should validate all poi against updated metadata
        [[MukurtuSession sharedSession] validateAllPois];
        [self reloadPoiTable];
    }
    else
    {
        DLog(@"show invalid sync status warning");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!" message:kSyncInvalidCanceledMessage
                                                           delegate:self
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
        
        [self.syncViewController reportSyncFailed];
    }
    
    [self performSelector:@selector(dismissPopoverSync) withObject:nil afterDelay:1.0];
    
}

- (void) dismissPopoverSync
{
    if (self.syncPopoverController.isPopoverVisible)
    {
        DLog(@"dismissing popover sync");
        [self.syncPopoverController dismissPopoverAnimated:YES];
    }
    else
        DLog(@"popover sync was alredy dismissed, ignoring dismiss request");
}

- (IBAction)syncButtonPressed:(id)sender
{
    DLog(@"Sync button pressed, open action sheet");
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    SyncMetadataViewController *syncViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MetadataSyncController"];
    syncViewController.delegate = self;
    syncViewController.cancelSelector = @selector(cancelMetadataSync);
    self.syncViewController = syncViewController;
    
    UIPopoverController *syncPopover  = [[UIPopoverController alloc] initWithContentViewController:syncViewController];
    syncPopover.delegate = self;

    self.syncPopoverController = syncPopover;

#warning hardcoded size for popover
    self.syncPopoverController.popoverContentSize = CGSizeMake(300, 180);
    
    CGRect arrowRect = CGRectMake(self.viewToolbar.frame.size.width / 2, -8, 1, 1);

    [self.syncPopoverController presentPopoverFromRect:arrowRect
                                                inView:self.viewToolbar
                              permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
    
    //Actually start metadata sync
    [[MukurtuSession sharedSession] startMetadataSyncFromDelegate:self confirmSelector:@selector(syncCompleted)];
    
    
}

////Action Sheet
- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSInteger tag = actionSheet.tag;
    
    switch (tag)
    {
        case kMukurtuActionSheetSyncMetadata:
            if (buttonIndex == 0)
            {
                //cancel poi metadata sync
                
                DLog(@"Canceling metadata sync");
                
            }
            
            break;
            
        default:
            break;
    }
}

@end
