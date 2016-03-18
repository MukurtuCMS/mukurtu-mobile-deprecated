//
//  MainIphoneViewController.m
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

#import "MainIphoneViewController.h"
#import "IphoneCreatePoiGeneralViewController.h"

#import "PoiTableViewController.h"

#import "Poi.h"
#import "AppDelegate.h"

#import "SyncMetadataViewController.h"
#import "MukurtuSession.h"

#import "UploadProgressViewController.h"

#import "SettingsMenuViewController.h"
#import "SplashScreenViewController.h"


#import "ImageSaver.h"


#define kYouTubeNeededAlert 42

@interface MainIphoneViewController ()<UIAlertViewDelegate>
{
    BOOL _dismissingSyncController;
}

@property (strong, nonatomic) PoiTableViewController  *poiTableController;
@property (weak, nonatomic) IphoneCreatePoiGeneralViewController *createPoiController;

@property (weak, nonatomic) IBOutlet UIButton *settingsBarButton;

@property (weak, nonatomic) IBOutlet UIButton *createButton;
@property (weak, nonatomic) IBOutlet UIButton *editPoiTableButton;
@property (weak, nonatomic) IBOutlet UIButton *syncMetadataButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadPoisButton;
@property (weak, nonatomic) IBOutlet UIButton *openWebViewButton;

@property (weak, nonatomic) IBOutlet UILabel *editButtonLabel;
@property (weak, nonatomic) IBOutlet UIView *editButtonBgView;


@property (weak, nonatomic) SyncMetadataViewController *syncViewController;
@property (weak, nonatomic) UploadProgressViewController *uploadViewController;
@property (strong, nonatomic) SplashScreenViewController *splashScreenViewController;


@end

@implementation MainIphoneViewController

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
 
    DLog(@"Main Iphone View Loaded");
    
    _dismissingSyncController = NO;
    
    //reachability disabled by now
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
            //this avoid presenting splashcreen everytime for disk write problems (device full?)
            
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
        
        if (appDelegate.forceLoginView)
        {
            DLog(@"Forcing login view");
            [self showSettingsView:nil];
        }
    }
    
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) dismissCreatePoiViewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.poiTableController reloadData];
}


- (void) reloadPoiTable
{
    [self.poiTableController reloadData];
}

-(void) editPoi:(Poi *)poi
{
    DLog(@"Poi table ask to edit poi %@", poi.title);
    
    IphoneCreatePoiGeneralViewController *createPoiController = [self.storyboard instantiateViewControllerWithIdentifier:@"createPoiGeneral"];
    createPoiController.delegate = self;
    createPoiController.currentPoi = poi;
    self.createPoiController = createPoiController;
    
    [self presentViewController:createPoiController animated:YES completion:nil];
    
}

- (void) enterEditMode
{
    DLog(@"Entering edit mode");
    
    [self.poiTableController setEditing:YES animated:YES];
    
    self.createButton.enabled = NO;
    self.syncMetadataButton.enabled = NO;
    self.uploadPoisButton.enabled = NO;
    self.settingsBarButton.enabled = NO;
    self.openWebViewButton.enabled = NO;
    
    [self.editPoiTableButton setImage:[UIImage imageNamed:@"icon_edit_DONE"] forState:UIControlStateNormal];
    [self.editButtonBgView setBackgroundColor:kUIColorOrange];
    [self.editButtonLabel setText:@"Done"];
}


- (void) leaveEditMode
{
    DLog(@"Leaving edit mode");
    
    [self.poiTableController setEditing:NO animated:YES];
    
    self.createButton.enabled = YES;
    self.syncMetadataButton.enabled = YES;
    self.uploadPoisButton.enabled = YES;
    self.settingsBarButton.enabled = YES;
    self.openWebViewButton.enabled = YES;
    
    
    [self.editPoiTableButton setImage:[UIImage imageNamed:@"icon_edit"] forState:UIControlStateNormal];
    [self.editButtonBgView setBackgroundColor:kUIColorDarkBarBackground];
    [self.editButtonLabel setText:@"Edit"];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"MainIphoneToCreatePoiGeneralData"])
    {
        DLog(@"presenting modal create poi general data controller");
        IphoneCreatePoiGeneralViewController *createPoiController =  segue.destinationViewController;
        createPoiController.delegate = self;
        self.createPoiController = createPoiController;
    }
    else
        if ([segue.identifier isEqualToString:@"EmbedPoiTableSegue"])
        {
            self.poiTableController = segue.destinationViewController;
            self.poiTableController.mainViewController = self;
        }
}

- (void) dismissModalSync
{
    DLog(@"dismissing modal sync");
    //if ( self.syncViewController.isViewLoaded && self.syncViewController.view.window)
  
    {
        [self dismissViewControllerAnimated:YES completion:nil];
        //DLog(@"Sync view alredy dismissed, ignoring dismiss");
    }
}

- (void) dismissModalUpload
{
    DLog(@"dismissing modal upload");
    [self dismissViewControllerAnimated:YES completion:nil];
    
    //free upload progress and popover reference
    self.uploadViewController = nil;
}

- (void) cancelMetadataSync
{
    DLog(@"User asked to cancel metadata sync");
    
    //should interrupt mukurtu session here
    MukurtuSession *session = [MukurtuSession sharedSession];
    [session cancelMetadataSync];
    
    //dismiss modal sync controller
    //if (!_dismissingSyncController)
    _dismissingSyncController = YES;
    [self performSelector:@selector(dismissModalSync) withObject:nil afterDelay:1.0];
}

- (void) syncCompleted
{
    DLog(@"Session report sync completed, alert user");
    
    if ([[MukurtuSession sharedSession] lastSyncSuccess])
    {
        [self.syncViewController reportSyncDone];
        
        //should validate all poi against updated metadata
        [[MukurtuSession sharedSession] validateAllPois];
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
    
    //dismiss modal sync controller
    //_dismissingSyncController = YES;
    if (!_dismissingSyncController)
        [self performSelector:@selector(dismissModalSync) withObject:nil afterDelay:1.0];
    //[self dismissModalSync];
}

#warning MOVE this method in imagesaver class
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
    
    [self.poiTableController reloadData];
}


- (void)uploadCanceled
{
    DLog(@"Upload was canceled");
    
    [[MukurtuSession sharedSession] cancelUpload];
    
    [self dismissModalUpload];
    
    //some poi status could be changed or uploaded
    //[self.poiTableController reloadData];
    
    //Remove all poi uploaded with success
#warning, could verify if poi actually are visibile con server before removing them (complex task)
    NSArray *uploadedPois = [[[MukurtuSession sharedSession] uploadedPoiList] copy];
    
    DLog(@"We have uploaded %d poi with success, removing them", (int)[uploadedPois count]);
    //DLog(@"DEBUG: uploaded poi list to remove %@", [uploadedPois description]);
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

- (void)uploadSuccesful
{
    DLog(@"Upload finished with success");
    
    [self dismissModalUpload];
    
    
    //Remove all poi uploaded with success
#warning, could verify if poi actually are visibile con server before removing them (complex task)
    NSArray *uploadedPois = [[[MukurtuSession sharedSession] uploadedPoiList] copy];
    
    DLog(@"We have uploaded %d poi with success, removing them", (int)[uploadedPois count]);
    //DLog(@"DEBUG: uploaded poi list to remove %@", [uploadedPois description]);
#ifdef REMOVE_POI_AFTER_UPLOAD
    [self removePoisFromArray:uploadedPois];
#endif

    
    //display error message for partial upload / upload failed
#warning check upload success and messages for any result
    [self.poiTableController showUploadResult];
    
    //enabling auto lock screen
    DLog(@"Enabling screen auto lock");
    [UIApplication sharedApplication].idleTimerDisabled = NO;
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
        
        self.uploadViewController = uploadViewController;
        
        
        //should validate all poi against updated metadata
        [[MukurtuSession sharedSession] validateAllPois];
        [self.poiTableController reloadData];
        
        //FIX 2.5: fix race condition that starts upload before upload view controller actually loaded (verified on io8)
        //do the magic trick: overwrite sync controller with upload
        DLog(@"do the magic trick: overwrite sync controller with upload");
        [self dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:uploadViewController animated:NO completion:^{
                [self.syncViewController reportSyncDone];
                
                //disable auto lock screen
                DLog(@"Disabling screen auto lock");
                [UIApplication sharedApplication].idleTimerDisabled = YES;
                
                //Actually start upload job
                [[MukurtuSession sharedSession] startUploadJobFromDelegate:self.uploadViewController];
            }];
        }];
        
        
//        //do the magic trick: overwrite sync controller with upload
//        DLog(@"do the magic trick: overwrite sync controller with upload");
//        [self dismissViewControllerAnimated:NO completion:^{
//            [self presentViewController:uploadViewController animated:NO completion:nil];
//        }];
//        
//        [self.syncViewController reportSyncDone];
//        
//        //disable auto lock screen
//        DLog(@"Disabling screen auto lock");
//        [UIApplication sharedApplication].idleTimerDisabled = YES;
//        
//        //Actually start upload job
//        [[MukurtuSession sharedSession] startUploadJobFromDelegate:self.uploadViewController];
    }
    else
    {
        DLog(@"Last login or sync failed, quitting upload job with errors");
        //[self dismissModalSync];
        
    }
    
}

- (IBAction)uploadButtonPressed:(id)sender
{
    DLog(@"Upload button pressed");
    
    //ignore if no poi in list
    if (![self.poiTableController.poiList count])
    {
#warning could show an alert, to ask Coda
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

- (void)startUploadJob
{
    DLog(@"Starting upload job (sync, validate, upload)");
    
     _dismissingSyncController = NO;
    
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    SyncMetadataViewController *syncViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MetadataSyncController"];
    syncViewController.delegate = self;
    syncViewController.cancelSelector = @selector(cancelMetadataSync);
    
    self.syncViewController = syncViewController;
    
    [self presentViewController:syncViewController animated:YES completion:nil];
    
    
    //Actually start metadata sync
    [[MukurtuSession sharedSession] startMetadataSyncFromDelegate:self confirmSelector:@selector(syncBeforeUploadCompleted)];
    
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
            
            DLog(@"Forcing youtube login view");
            [self showSettingsView:nil];
            
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
    //just cancel other alert view doing nothing
}


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


- (IBAction)syncButtonPressed:(id)sender
{
    DLog(@"Sync button pressed, open action sheet");
    
    _dismissingSyncController = NO;
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    SyncMetadataViewController *syncViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MetadataSyncController"];
    syncViewController.delegate = self;
    syncViewController.cancelSelector = @selector(cancelMetadataSync);
    
    self.syncViewController = syncViewController;
    
    [self presentViewController:syncViewController animated:YES completion:nil];
    
    
    //Actually start metadata sync
    [[MukurtuSession sharedSession] startMetadataSyncFromDelegate:self confirmSelector:@selector(syncCompleted)];
    
}

- (IBAction)showSettingsView:(id)sender
{
    DLog(@"Pushing settings view");
    
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    SettingsMenuViewController *settingsViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"SettingsMainMenu"];
    
    
    //Tricky trick to fix status bar color change in modal controller
    /*
    {
        UIView *fixbar = [[UIView alloc] init];
        fixbar.frame = CGRectMake(0, 0, 320, 20);
        fixbar.backgroundColor = [UIColor colorWithRed:0.973 green:0.973 blue:0.973 alpha:1]; // the default color of iOS7 bacground or any color suits your design
        [settingsViewController.view addSubview:fixbar];
    }
     */
    
    [self presentViewController:settingsViewController animated:YES completion:nil];
}

- (IBAction)editPoiTablePressed:(id)sender
{
    DLog(@"Edit Poi Table pressed");
    
    if (![self.poiTableController isEditing])
    {
        //ignore if no poi in list
        if (![self.poiTableController.poiList count])
        {
            DLog(@"No poi in list, ignoring edit request");
            return;
        }
        [self enterEditMode];
    }
    else
        [self leaveEditMode];
}


@end
