//
//  MukurtuSession.m
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

#import <CoreLocation/CoreLocation.h>

#import "MukurtuSession.h"

#import "Poi.h"
#import "PoiCategory.h"
#import "PoiCulturalProtocol.h"
#import "PoiCommunity.h"
#import "PoiKeyword.h"
#import "PoiCreator.h"
#import "PoiContributor.h"
#import "PoiMedia.h"

#import "AppDelegate.h"

#import "PDKeychainBindings.h"
#import "AFNetworking.h"

#import "UploadProgressViewController.h"

#import "NSData+Base64.h"

#import "ImageSaver.h"

#define kDummyVideoThumbnailFid @"0"

#ifndef kServerDontUseCustomServicesEndpointGroupsFetch
    #define kServerDontUseCustomServicesEndpointGroupsFetch NO
#endif

@interface MukurtuSession()
{
     int batchOperationsFinished;
    
    BOOL _userIsLoggedIn;
    BOOL _lastLoginSuccess;
    BOOL _lastSyncSuccess;
    BOOL _lastCulturalProtocolSyncSuccess;
    BOOL _lastCommunitiesSyncSuccess;
    BOOL _lastCategoriesSyncSuccess;
    BOOL _lastKeywordsSyncSuccess;
    BOOL _lastContributorsSyncSuccess;
    BOOL _lastCreatorsSyncSuccess;

    BOOL _cancelingSync;
    
    BOOL _serverCMSVersion1;
    
}

@property  (strong, nonatomic) AFHTTPClient *httpClient;


//@property (nonatomic, assign, readonly) BOOL baseUrlReachable;
@property (nonatomic, assign, readonly) BOOL updating;
//@property (nonatomic, assign, readonly) BOOL updateErrors;


//@property (nonatomic, strong) NSArray *toUploadPoiList;
//@property (nonatomic, strong) NSMutableArray *toKeepPoiList;

@property (nonatomic, strong) NSArray *serverCommunities;
@property (nonatomic, strong) NSArray *serverCulturalProtocols;
@property (nonatomic, strong) NSArray *serverCategories;
@property (nonatomic, strong) NSArray *serverKeywords;
@property (nonatomic, strong) NSArray *serverContributors;
@property (nonatomic, strong) NSArray *serverCreators;


@property (nonatomic, weak) UploadProgressViewController *uploadDelegate;

@property (assign, nonatomic)AFNetworkReachabilityStatus baseUrlReachabilityStatus;

//@property (nonatomic, assign, readonly) BOOL youTubeTokenValid;

@property (nonatomic, strong) NSString *sessionTokenCSRF;

@end



@implementation MukurtuSession

@synthesize userIsLoggedIn = _userIsLoggedIn;

@synthesize lastLoginSuccess = _lastLoginSuccess;
@synthesize lastSyncSuccess = _lastSyncSuccess;

@synthesize lastCategoriesSyncSuccess = _lastCategoriesSyncSuccess;
@synthesize lastCommunitiesSyncSuccess  = _lastCommunitiesSyncSuccess;
@synthesize lastCulturalProtocolsSyncSuccess = _lastCulturalProtocolsSyncSuccess;
@synthesize lastKeywordsSyncSuccess = _lastKeywordsSyncSuccess;
@synthesize lastContributorsSyncSuccess = _lastContributorsSyncSuccess;
@synthesize lastCreatorsSyncSuccess = _lastCreatorsSyncSuccess;

@synthesize serverCMSVersion1 = _serverCMSVersion1;

+ (MukurtuSession *)sharedSession {
    
    static dispatch_once_t once;
    static MukurtuSession *sharedSession;
    dispatch_once(&once, ^{
        
        DLog(@"Creating Mukurtu Session singleton");
        
        sharedSession = [[MukurtuSession alloc] init];
        
        //build local array to groups from DB for quick access
        [sharedSession setCurrentGroups];
        
        [sharedSession initYouTubeHelper];
        
        //check all pois validity
        //[sharedSession validateAllPois];
        
        /*
        if (sharedSession.storedBaseUrl && [sharedSession.storedBaseUrl length])
        {
            DLog(@"We have a stored base url, reset http client to start reachability test");
            [sharedSession resetHttpClientSession];
        }
         */
        
    });
    
    
    return sharedSession;
}


#pragma mark - youtube helper methods
-(void) initYouTubeHelper
{
    DLog(@"Initializing youtube helper object");
    
    self.youTubeHelper = [[YouTubeHelper alloc] initWithDelegate:self];
    
}


- (NSString *) youtubeAPIClientID
{
    //TODO: in order to login and upload videos to youtube you must enter your ClientID & Secret here
    //https://developers.google.com/youtube/registering_an_application#create_project
    return @"INSERT_YOUR_YOUTUBE_API_CLIENT_ID_HERE";
}

- (NSString *) youtubeAPIClientSecret
{
    //TODO: in order to login and upload videos to youtube you must enter your ClientID & Secret here
    //https://developers.google.com/youtube/registering_an_application#create_project
    return @"INSERT_YOUR_YOUTUBE_API_CLIENT_SECRET_HERE";
}

- (void) showAuthenticationViewController:(UIViewController *)authView
{
    NSLog(@"Show auth view controller");
    //[self presentViewController:authView animated:YES completion:nil];
    
    if (self.youTubeSettingsNavigationController)
    {
        
        //AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        
        /*
         if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
         {
         DLog(@"Taking a weak reference to main view controller");
         
         MainIpadViewController *mainIpad = (MainIpadViewController *)appDelegate.window.rootViewController;
         
         [mainIpad dismissSettingsPopover];
         [mainIpad presentViewController:authView animated:YES completion:nil];
         }*/
        
        CGSize size = [[UIScreen mainScreen] bounds].size; // size of view in popover should match device screen size
        authView.preferredContentSize = size;
        [self.youTubeSettingsNavigationController pushViewController:authView animated:YES];
        
    }
    else
    {
        DLog(@"Error! no settings navigation controller delegate set to show youtube auth view");
    }
    
}

- (void) authenticationEndedWithError:(NSError *)error
{
    if (error)
    {
        DLog(@"YouTube Auth Error %@, send error to delegate", error.description);
    }
    else
    {
        DLog(@"Auth Success! Dismissing auht view controller");
        
    }
    
    [self resetAllInvalidPoisForVideosAndValidate];
    
    if (self.youTubeStatusReportDelegate)
    {
        [self.youTubeStatusReportDelegate reportLoginError:error];
    }
    
    //[self updateAuthButton];
    //[self dismissViewControllerAnimated:YES completion:nil];
}

- (void) resetAllInvalidPoisForVideosAndValidate
{
    DLog(@"Set all invalid pois with video as valid");
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"key == %@", kPoiStatusNoYouTubeLoginForVideos];
    NSArray *allPoisWithInvalidVideos = [Poi MR_findAllWithPredicate:predicate];
    DLog(@"We have %d invalid pois with videos", [allPoisWithInvalidVideos count]);
    
    for (Poi *poi in allPoisWithInvalidVideos)
    {
        poi.key = nil;
    }
    
    //force new validation, this may result in poi still invalid for some other reason than having videos with missing youtube login
    //validate all pois will also save context to eventually confirm valid key for future upload
    [self validateAllPois];
}

- (BOOL) uploadNeedsYouTubeButNoLogin
{
    DLog(@"Check before upload if we have videos to upload but user is not logged in youtube");
    
    
    if (!_youTubeHelper.isAuthValid)
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", @"video" ];

        
        NSArray *allVideos = [PoiMedia MR_findAllWithPredicate:predicate];
        DLog(@"We have %lu videos to upload", (unsigned long)[allVideos count]);
        DLog(@"Videos found: %@", [allVideos description]);
        
        if ([allVideos count] > 0)
        {
            return YES;
        }
        
    }
    
    return NO;
}

- (void) uploadDoneForMedia:(PoiMedia *)media withVideoId:(NSString *)videoId andError:(NSError *)error
{
    DLog(@"YouYube helper reported upload done for media %@ with error %@", [media.path lastPathComponent], error.description);
    
    if (error == nil)
    {
        DLog(@"Upload video successful, saving video id in media key");
        
        if (self.serverCMSVersion1)
        {
            //support the ugly fid-videoid dance to support later video embedding in poi body
            NSString *thumbnailFid = [[media.key copy] substringFromIndex:[@"fid-" length]];
            
            media.key = [NSString stringWithFormat:@"%@,%@",thumbnailFid, videoId];
            
            DLog(@"combined media video key (fid,videoid): %@", media.key);
        }
        else
        {
            //just store video id then we will add a scald atom reference to it
            media.key = [videoId copy];
            DLog(@"Obtained media video youtube id: %@", media.key);
            
            //save Context
            DLog(@"Saving Context after video upload terminated");
            [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            
            [self createScaldAtomForMedia:media];
            
            //CMS 2.0 return here, uploadPoi will be called after scald atom has been created
            return;
        }
        
    }
    else
    {
        
#warning by now if we fail youtube video we reset all media key, forgetting fid for already uploaded big thumbnail
        //upload failed, mark this media as invalid to stop upload for this poi
        DLog(@"Upload video failure, mark media as invalid");
        media.key = kPoiStatusInvalid;
    }
    
    //save Context
    DLog(@"Saving Context after video upload terminated");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    //call again upload for this poi: if all media are ok poi upload will start
    //(if not it will trigger next media upload)
    //[self uploadPoi:media.parent];
    
    //FIX 2.5: upload using already obtained CSRF token
    [self uploadPoiWithCSRFToken:media.parent];
    
}

- (void)uploadProgressPercentage:(int)percentage
{
    DLog(@"Video upload progress: %02i%%",percentage);
    
    if (self.uploadDelegate)
    {
        [self.uploadDelegate updateProgressStatus:[NSString stringWithFormat:@"Uploading video %02i%%",percentage]];
    }
}

/*
- (void) validateYouTubeSession
{
    DLog(@"Validating youtube session token");
 
    _youTubeTokenValid = NO;
 
    if ([_youTubeHelper isAuthValid])
    {
        DLog(@"User is logged in youtube, try a request to validate token");
        _youTubeTokenValid = YES;
    }
    else
    {
        DLog(@"User is not logged in youtube, should skip all poi with videos");
    }

}
*/

#pragma mark - mukurtu session methods
- (NSString *)storedBaseUrlCMSVersion
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    NSString *version = [[bindings objectForKey:kMukurtuAccountKeychainCMSVersion] copy];
    
    return version;
}

- (void)setStoredBaseUrlCMSVersion:(NSString *)storedBaseUrlCMSVersion
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    [bindings setObject:storedBaseUrlCMSVersion forKey:kMukurtuAccountKeychainCMSVersion];
}

- (NSString *)storedUsername
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    NSString *username = [[bindings objectForKey:kMukurtuAccountKeychainUsername] copy];
    
    return username;
}

- (void)setStoredUsername:(NSString *)storedUsername
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    [bindings setObject:storedUsername forKey:kMukurtuAccountKeychainUsername];
}


- (NSString *)storedPassword
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    NSString *password = [[bindings objectForKey:kMukurtuAccountKeychainPassword] copy];
    
    return password;
}

- (void)setStoredPassword:(NSString *)storedPassword
{
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    [bindings setObject:storedPassword forKey:kMukurtuAccountKeychainPassword];
}


- (NSString *)storedBaseUrl
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *baseUrl = [defaults objectForKey:kMukurtuBaseUrlKey];
    
    return baseUrl;
}

- (void)setStoredBaseUrl:(NSString *)storedBaseUrl
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:storedBaseUrl forKey:kMukurtuBaseUrlKey];
    [defaults synchronize];
}

- (void) resetStoredLoginCredentials
{
    DLog(@"deleting stored login credentials");
    
    self.storedUsername = @"";
    self.storedPassword = @"";
    self.storedBaseUrl = @"";
    
    self.storedBaseUrlCMSVersion = @"";
    
    [self setStoredLoggedInStatus:NO];

}

- (void)setStoredLoggedInStatus:(BOOL)isLoggedIn
{
    DLog(@"Setting logged in status permanently");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:isLoggedIn] forKey:kMukurtuStoredLoggedInStatus];
    [defaults synchronize];

}

- (BOOL)storedLoggedInStatus
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *loggedIn = [defaults objectForKey:kMukurtuStoredLoggedInStatus];
    
    return [loggedIn boolValue];
}

- (BOOL)isBaseUrlReachable
{
    DLog(@"Network reachability %d", self.baseUrlReachabilityStatus);
    //return (self.baseUrlReachabilityStatus > 0);
    
#warning reachability not working well by now, always return true
    return YES;
}

- (void)resetClientReachabilityTest
{
    if (self.storedBaseUrl && [self.storedBaseUrl length])
    {
        DLog(@"We have a stored base url, reset http client to start reachability test");
        [self resetHttpClientSession];
    }
}

- (BOOL)isUsingDemoUser
{
    if ([self.storedUsername isEqualToString:kMukurtuServerDemoCredentialsUser] &&
        [self.storedPassword isEqualToString:kMukurtuServerDemoCredentialsPassword] &&
        [self.storedBaseUrl isEqualToString:kMukurtuServerDemoCredentialsBaseUrl]
        )
    {
        DLog(@"Confirm user is using demo credentials");
        return YES;
    }
    else
    {
        DLog(@"Deny user is using demo credentials");
        return NO;
    }
}

- (BOOL)userIsLoggedIn
{
    DLog(@"Checking if user is logged in");
    
    _userIsLoggedIn = NO;
    
    //DEBUG
    //self.storedUsername = @"";
    //self.storedPassword = @"";
    //self.storedBaseUrl = @"";
    
    
    if ([self storedLoggedInStatus] &&
        self.storedUsername.length > 0 && self.storedPassword.length > 0 && self.storedBaseUrl.length > 0)
    {
        DLog(@"Keychain has stored credentials and baseurl is set: assume we could log in with username %@, baseurl %@", self.storedUsername, self.storedBaseUrl);
        
        _userIsLoggedIn = YES;
    }
    else
    {
        //if only some credentials is missing, delete all from store since are valid no more
        //[self resetStoredLoginCredentials];
        DLog(@"No stored credentials, user is logged out");
    }
    
    return _userIsLoggedIn;
}

- (void) resetHttpClientSession
{
    DLog(@"Starting a new HTTP session with stored credentials");
    
    if (self.httpClient)
    {
        DLog(@"Stopping any pending http operation");
        [self.httpClient.operationQueue cancelAllOperations];
    }
    
    self.httpClient = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:self.storedBaseUrl]];
    [self.httpClient setParameterEncoding:AFJSONParameterEncoding];
    [self.httpClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self.httpClient setDefaultHeader:@"Accept" value:@"application/json"];
    [self.httpClient setDefaultHeader:@"Content-Type" value:@"application/json"];
    
    
    [self resetHttpClientAuthCookies];
    
    //reset any pending youtube upload
    [_youTubeHelper cancelAllCurrentUploads];

#warning should check network availability!!

    //__weak MukurtuSession *weakSelf = self;
    
    
    //initialize network reachability as rechable.
    //This could lead to false positive, so NEVER use network status for logic, just for diagnostic purpose (f.e. bandwidth limit, ecc)
    self.baseUrlReachabilityStatus = AFNetworkReachabilityStatusReachableViaWWAN;
    
    
#warning reachability not working sometimes, better try with afnetowrking 2.0 or other libs
    /*
    [self.httpClient setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status)
    {
        if (status == AFNetworkReachabilityStatusNotReachable ||
            status == AFNetworkReachabilityStatusUnknown)
        {
            DLogBlock(@"Base URL become not reachable!");
        }
        else
            if (status == AFNetworkReachabilityStatusReachableViaWWAN)
        {
            // 3g/LTE
            DLogBlock(@"Base URL reachable via WWAN (Edge/3g/4g/LTE)");
        }
        else
        if (status == AFNetworkReachabilityStatusReachableViaWiFi)
        {
            // On wifi
            DLogBlock(@"Base URL reachable via Wifi");
        }
        
        weakSelf.baseUrlReachabilityStatus = status;

    }];
     */
}


/*
- (void)setUserIsLoggedIn:(BOOL)userIsLoggedIn
{
    DLog(@"Setting logged in status permanently");
    
    //dummy, useless since property is readonly
}
 */

- (void)resetHttpClientAuthCookies
{
    DLog(@"Resetting authorization cookies");
    
    //reset all internal status to out of sync
    _lastLoginSuccess = NO;
    _lastSyncSuccess = NO;
    
    _lastCulturalProtocolsSyncSuccess = NO;
    _lastCategoriesSyncSuccess = NO;
    _lastCommunitiesSyncSuccess = NO;
    _lastKeywordsSyncSuccess = NO;
    _lastContributorsSyncSuccess = NO;
    _lastCreatorsSyncSuccess = NO;

    
    //forget server gourps, should be retrieved on new sync
    self.serverCategories = nil;
    self.serverCommunities = nil;
    self.serverCulturalProtocols = nil;
    self.serverKeywords = nil;
    self.serverContributors = nil;
    self.serverCreators = nil;
    
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    [bindings setObject:@"" forKey:kMukurtuAccountKeychainSessionName];
    [bindings setObject:@"" forKey:kMukurtuAccountKeychainSessionValue];
    
    if (self.httpClient)
    {
        [self.httpClient setDefaultHeader:@"Cookie" value:nil];
        [self.httpClient setDefaultHeader:@"X-CSRF-Token" value:nil];
        //[self.httpClient cleanCookieStorage];
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [cookieStorage cookies];
        for (NSHTTPCookie *cookie in cookies)
        {
            DLog(@"check if we must clean cookie name: %@", cookie.name);
            if ([cookie.name hasPrefix:@"SESS"])
                [cookieStorage deleteCookie:cookie];
        }
    }

    
    self.sessionTokenCSRF = nil;
    _serverCMSVersion1 = NO;
}

- (void)storeHttpClientCookiesInKeychain
{
    DLog(@"Store auth cookies in keychain");
    
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    
    //store session token in keychain
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    for (NSHTTPCookie *cookie in cookies) {
        DLog(@"storing cookie name: %@", cookie.name);
        if ([cookie.name hasPrefix:@"SESS"]) {
            [bindings setObject:cookie.name forKey:kMukurtuAccountKeychainSessionName];
            [bindings setObject:cookie.value forKey:kMukurtuAccountKeychainSessionValue];
        }
    }
}

- (void)setDemoLogin
{
    DLog(@"Setting demo login credentials");
    
    _userIsLoggedIn = NO;
    
    self.storedUsername = kMukurtuServerDemoCredentialsUser;
    self.storedPassword = kMukurtuServerDemoCredentialsPassword;
    self.storedBaseUrl = kMukurtuServerDemoCredentialsBaseUrl;
    
    [self resetHttpClientSession];
    
}


- (void)loginNewSession
{
    DLog(@"Start Login session to server in background");
    
    [self loginNewSessionForController:nil confirmSelector:nil];
}


- (void)loginNewSessionForController:(NSObject *)delegate confirmSelector:(SEL)selector
{
    DLog(@"Start Login session to server %@ with stored credentials", self.storedBaseUrl);
    
    [self resetHttpClientSession];
    
    //prevent further network errors messages for this login/sync/upload session
     _cancelingSync = NO;
    

    NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:self.storedUsername, self.storedPassword, nil]
                                                       forKeys:[NSArray arrayWithObjects:@"username", @"password", nil]];
    
    NSString *endpointPath = [NSString stringWithFormat:@"/%@/%@/login", kMukurtuServerEndpoint, kMukurtuServerBaseUser];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&error];
    
    DLog(@"params dict %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    [self.httpClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self.httpClient setDefaultHeader:@"Accept" value:@"application/json"];
    [self.httpClient setDefaultHeader:@"Content-Type" value:@"application/json"];
    
    [self.httpClient postPath:endpointPath parameters:params
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          NSDictionary *nodeJSON = responseObject;
                          DLog(@"login success: response object: %@", [nodeJSON description]);
                          
                          //FIX 2.5: check CMS version to support old installations
                          if ([[nodeJSON valueForKey:@"user"] valueForKey:@"field_culturalprotocol"] != nil)
                          {
                              DLog(@"Backend CMS VERSION 1.0: enable legacy support for old cms version");
                              _serverCMSVersion1 = YES;
                              
                              self.storedBaseUrlCMSVersion = @"1.0";
                          }
                          else
                          {
                              DLog(@"Backend CMS VERSION 2.0: latest server version found, enable 2.5 features");
                              _serverCMSVersion1 = NO;
                              
                              self.storedBaseUrlCMSVersion = @"2.0";
                          }
                          
                          //store received cookie in keychain
                          [self storeHttpClientCookiesInKeychain];
                          
                          //store logged in status permanently
                          [self setStoredLoggedInStatus:YES];
                          
                          //remember lastLogin was ok for delegate
                          _lastLoginSuccess = YES;
                          
                          [self analyticsReportSuccesfulLogin];
                          
                          if (delegate && [delegate respondsToSelector:selector])
                          {
                              DLog(@"Reporting login success to controller %@", [delegate description]);
                              SuppressPerformSelectorLeakWarning([delegate performSelector:selector]);
                          }
                          
                          //update metadata handle delegate to callback when done
                          //[session updateMetadataWithDelegate:self];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DLog(@"login error: %@ responseString %@",error, [operation.response allHeaderFields]);
        
        [self showConnectionErrorForErrorCode:error.code];
        
        //remember lastLogin was failure for delegate
        _lastLoginSuccess = NO;
        
        if (delegate && [delegate respondsToSelector:selector])
        {
            DLog(@"Reporting login failure to controller %@", [delegate description]);
            SuppressPerformSelectorLeakWarning([delegate performSelector:selector]);
        }
        
    }];

}

- (void)analyticsReportSuccesfulLogin
{
    NSString *cleanBaseUrl;
    NSString *prefix = @"http://";
    
    if ([self.storedBaseUrl hasPrefix:prefix])
        cleanBaseUrl = [self.storedBaseUrl substringFromIndex:[prefix length]];
    else
        cleanBaseUrl = self.storedBaseUrl;
    
    if ([cleanBaseUrl hasSuffix:@"/"])
        cleanBaseUrl = [cleanBaseUrl substringToIndex:([cleanBaseUrl length] - 1)];
    
    
    NSString *targetUrlString = [NSString stringWithFormat:@"%@%@", kMukurtuServerAnalyticsSuccesfulLoginReportUrl, cleanBaseUrl];
    
    DLog(@"Reporting succesful login to analytics at url %@", targetUrlString);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:targetUrlString]];
    
    AFHTTPRequestOperation *httpOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    [httpOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        DLog(@"Analytics ping login successful reported to %@", targetUrlString);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        DLog(@"FAILED Analytics ping login report to %@", targetUrlString);
        DLog(@"error: %@ responseString %@",error, [operation.response allHeaderFields]);
    }];
    
    [httpOperation start];
    
    
}

- (void)logoutUserAndRemovePois
{
    DLog(@"Start logout session in background");
    [self logoutAndRemovePoisForController:nil confirmSelector:nil];
}

- (void)logoutAndRemovePoisForController:(NSObject *)delegate confirmSelector:(SEL)selector
{
    DLog(@"Start Logout from server %@", self.storedBaseUrl);
    
#ifdef DEBUG
    // DEBUG Show the current contents of the documents folder
    DLog(@"app documents before logout:");
    CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif

    
    //Delete all poi and media here!
#warning should delete all poi and media here
    DLog(@"Deleting all poi, groups and media in local store");
    for (PoiMedia *media in [PoiMedia MR_findAll])
    {
        [ImageSaver deleteMedia:media];
    }
    
    [Poi MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiCulturalProtocol MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiCategory MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiCommunity MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiKeyword MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiContributor MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    [PoiCreator MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    
    DLog(@"Saving core data context");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            DLog(@"You successfully saved your context.");
        } else if (error) {
            DLog(@"Error saving context: %@", error.description);
        }
    }];
    
    //reset local groups
    [self setCurrentGroups];

#ifdef DEBUG
    // DEBUG Show the current contents of the documents folder
    DLog(@"app documents after logout:");
    CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
#endif

    
#warning could call logout session on server! not really needed, but subtle better security server side (stolen sessions)
    
    //actually we don't remove all credentials for later login, could be changed
    //we remove only password for security purpose
    self.storedPassword = @"";
    
    //store logged in status permanently
    [self setStoredLoggedInStatus:NO];
    
    [self resetHttpClientAuthCookies];
    
    //logout from youtube too
    [self.youTubeHelper signOut];
    self.youTubeStatusReportDelegate = nil;
    
    if (delegate && [delegate respondsToSelector:selector])
    {
        DLog(@"Reporting logout success to controller %@", [delegate description]);
        SuppressPerformSelectorLeakWarning([delegate performSelector:selector]);
    }
}

- (void)cancelMetadataSync
{
    DLog(@"Canceling Metadata Sync");
    _cancelingSync = YES;
    
    [self resetHttpClientSession];
    
}

- (void)cancelUpload
{
    DLog(@"canceling upload by user request");
    _cancelingSync = YES;
    [self resetHttpClientSession];
    
}

-(void)loginForMetadataSyncDone
{
    DLog(@"Login for metadata terminated with success status %d", self.lastLoginSuccess);
    
    
    if (!_lastLoginSuccess)
    {
        DLog(@"Login for metadata failed, error should be already showed by login handle, dismiss metadata sync controller");
        
        _updating = NO;
        
        //report sync done (failure)
        if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
        {
            DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
            SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
        }

    }
    else
    {
        DLog(@"Login for metadata successful! Start retrieving groups from server");
        //should call metadata update here
       [self updateAllGroupsFromRemoteServer];
        
    }
}


- (void)startMetadataSyncFromDelegate:(NSObject *)delegate confirmSelector:(SEL)selector
{
    DLog(@"Session start metadata sync");
    
    
    if (_updating)
    {
        DLog(@"Avoid update at all, another one is still waiting");
        //[self notifySessionDelegate:delegate result:kMukurtuSessionDelegateResultUpdateRunning];
        return;
    }
    else
        _updating = YES;
    
    _cancelingSync = NO;
    
#warning should check network availability
    /*
    if (!session.baseUrlReachable || ![session isSignedIn])
    {
        DLog(@"Cannot reach server or not signed in, cancel metadata update");
        updating = NO;
        [self notifySessionDelegate:delegate result:kMukurtuSessionDelegateResultFailure];
        return;
    }
     */
    
    
    //DEBUG: wrong login simulate server user tampering (disabled user, ecc)
    //self.storedUsername = @"WRONG LOGIN";
    
    self.currentSessionDelegate = delegate;
    self.currentSessionSelector = selector;
    
#warning could use system connect, but more stable this way
    //do a new login with stored credentials
    [self loginNewSessionForController:self confirmSelector:@selector(loginForMetadataSyncDone)];
    
}

- (void) updateAllGroupsFromRemoteServer
{
    DLog(@"Start retrieve groups from server and sync with local groups");
    
    //call all operations at same time, everyone should check completed delegate to continue
    NSMutableDictionary *params;
    NSString *endpoint;
    
    if (self.serverCMSVersion1 || kServerDontUseCustomServicesEndpointGroupsFetch)
    {
        //skip contributors and creators sync, set them as already succesfully fetched
        _lastContributorsSyncSuccess = YES;
        _lastCreatorsSyncSuccess = YES;
        
        ////COMMUNITIES fetch request
        params = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:kMukurtuMaxGroupSize,@"community",@"type,nid,title,language", nil]
                                                    forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[type]",@"fields", nil]];
        
        endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseNode];
        
        [self.httpClient getPath:endpoint parameters:params
                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                             DLog(@"Success: Fetch communities completed, updating local store");
                             NSArray *JSONResponse = responseObject;
                             DLog(@"JSON response object: %@", JSONResponse);
                             
                             [self updateLocalStoreCommunitiesWithObjects:(NSArray *)JSONResponse];
                             
                         }
                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                             DLog(@"Failure: Fetch communities");
                             DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                             
                             
                             //show alert view with error
                             [self showNetworkErrorAlert];
                             
#warning refactor following stop http task lines below in callable method!!
                             _updating = NO;
                             
                             //report sync done (failure)
                             if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                             {
                                 DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                 SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                             }
                             
                         }];
        
        
        
        ////CULTURAL PROTOCOLS fetch request
        params = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:kMukurtuMaxGroupSize,@"cultural_protocol_group",@"type,nid,title,language", nil]
                                                    forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[type]",@"fields", nil]];
        
        endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseNode];
        
        [self.httpClient getPath:endpoint parameters:params
                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                             DLog(@"Success: Fetch cultural protocols completed, updating local store");
                             NSArray *JSONResponse = responseObject;
                             DLog(@"JSON response object: %@", JSONResponse);
                             
                             [self updateLocalStoreCulturalProtocolsWithObjects:(NSArray *)JSONResponse];
                             
                         }
                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                             DLog(@"Failure: Fetch cultural protocols");
                             DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                             
                             
                             //show alert view with error
                             [self showNetworkErrorAlert];
                             
#warning refactor following stop http task lines below in callable method!!
                             _updating = NO;
                             
                             //report sync done (failure)
                             if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                             {
                                 DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                 SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                             }
                             
                         }];
    }
    else
    {
        //FIX 2.5: server CMS version is >=2.0
        //With latest CMS version (2.0+) we should fetch communities and CPs using new ad hoc services extensions
        //this method retrieves both communities and cultural protocols, listing only:
        //- all communities accessible to current users (i.e. all communities where user is member in)
        //-all CPs where user can post to (i.e. all CPs where user is member in AND has contributor or protocol steward roles, read only CPs are not listed here)
        DLog(@"CMS >=2.0 Fetch user accessible groups from server");
        
        ////COMMUNITIES and CULTURAL PROTOCOLS fetch
        params = nil;
        endpoint = [NSString stringWithFormat:@"%@/%@/index.json", kMukurtuServerEndpoint, kMukurtuServerBaseGroups];
        
        [self.httpClient getPath:endpoint parameters:params
                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                             DLog(@"Success: Fetch user accessible groups completed, updating local store");
                             NSArray *JSONResponse = responseObject;
                             DLog(@"JSON response object: %@", JSONResponse);
                             
                             NSMutableArray *fetchedCommunities = [NSMutableArray array];
                             NSMutableArray *fetchedCPs = [NSMutableArray array];
                             
                             for (NSDictionary *group in JSONResponse)
                             {
                                 if ([group valueForKey:@"nid"] != nil)
                                 {
                                     //fix missing model data fields from received groups (language and uri are actually not used in current version)
                                     NSString *forgedUri = [NSString stringWithFormat:@"%@%@/%@/%@",
                                                            self.storedBaseUrl,
                                                            kMukurtuServerEndpoint,
                                                            kMukurtuServerBaseNode,
                                                            [[group objectForKey:@"nid"] description]];
                                     
                                     NSMutableDictionary *newGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                                      [[group objectForKey:@"nid"] description],        @"nid",
                                                                      [[group objectForKey:@"title"] description],      @"title",
                                                                      @"en",                                            @"language",
                                                                      forgedUri,                                        @"uri",
                                                                      nil];
                                     
                 
                                     if ([[group valueForKey:@"type"] isEqualToString:@"community"])
                                     {
                                         [fetchedCommunities addObject:newGroup];
                                     }
                                     else if ([[group valueForKey:@"type"] isEqualToString:@"cultural_protocol"])
                                     {
                                         [fetchedCPs addObject:newGroup];
                                     }
                                     
                                     //discard unknown group types
                                 }
                             }
                             
                             //DEBUG
                             DLog(@"fetched communities: %@", [fetchedCommunities description]);
                             DLog(@"fetched CPs: %@", [fetchedCPs description]);
                             
                             //updates local groups with fetched communities and CPs
                             [self updateLocalStoreCommunitiesWithObjects:fetchedCommunities];
                             [self updateLocalStoreCulturalProtocolsWithObjects:fetchedCPs];
                         }
                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                             DLog(@"Failure: Fetch user accessible groups");
                             DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                             
                             //show alert view with error
                             [self showNetworkErrorAlert];
                             
#warning refactor following stop http task lines below in callable method!!
                             _updating = NO;
                             
                             //report sync done (failure)
                             if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                             {
                                 DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                 SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                             }
                             
                         }];
        
        ////CONTRIBUTORS fetch request
#warning contributor TID  could change in future, we may add a check in 3.0?
        
        NSString *serverContributorVID = kMukurtuContributorVID;
        
        params = [NSMutableDictionary dictionaryWithObjects:[NSArray
                                                             arrayWithObjects:kMukurtuMaxGroupSize,serverContributorVID,@"name,tid", nil]
                                                    forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[vid]",@"fields", nil]];
        
        endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseTaxonmyTerm];
        
        [self.httpClient getPath:endpoint parameters:params
                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                             DLog(@"Success: Fetch contributors completed, updating local store");
                             NSArray *JSONResponse = responseObject;
                             DLog(@"JSON response object: %@", JSONResponse);
                             
                             [self updateLocalStoreContributorsWithObjects:(NSArray *)JSONResponse];
                             
                         }
                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                             DLog(@"Failure: Fetch contributors");
                             DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                             
                             //show alert view with error
                             [self showNetworkErrorAlert];
                             
                             _updating = NO;
                             
                             //report sync done (failure)
                             if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                             {
                                 DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                 SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                             }
                             
                         }];
        
        ////CREATOR fetch request
#warning creator TID  could change in future, we may add a check in 3.0?
        
        NSString *serverCreatorVID = kMukurtuCreatorVID;
        
        params = [NSMutableDictionary dictionaryWithObjects:[NSArray
                                                             arrayWithObjects:kMukurtuMaxGroupSize,serverCreatorVID,@"name,tid", nil]
                                                    forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[vid]",@"fields", nil]];
        
        endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseTaxonmyTerm];
        
        [self.httpClient getPath:endpoint parameters:params
                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                             DLog(@"Success: Fetch creators completed, updating local store");
                             NSArray *JSONResponse = responseObject;
                             DLog(@"JSON response object: %@", JSONResponse);
                             
                             [self updateLocalStoreCreatorsWithObjects:(NSArray *)JSONResponse];
                             
                         }
                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                             DLog(@"Failure: Fetch creators");
                             DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                             
                             //show alert view with error
                             [self showNetworkErrorAlert];
                             
                             _updating = NO;
                             
                             //report sync done (failure)
                             if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                             {
                                 DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                 SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                             }
                             
                         }];

    }
    
    ////CATEGORIES fetch request
#warning category TID kMukurtuCategoryVID could change in future, we may add a check in 3.0?
    params = [NSMutableDictionary dictionaryWithObjects:[NSArray
                                                          arrayWithObjects:kMukurtuMaxGroupSize,kMukurtuCategoryVID,@"name,tid", nil]
               forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[vid]",@"fields", nil]];
    
    endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseTaxonmyTerm];
    
    [self.httpClient getPath:endpoint parameters:params
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                         DLog(@"Success: Fetch categories completed, updating local store");
                         NSArray *JSONResponse = responseObject;
                         DLog(@"JSON response object: %@", JSONResponse);
                         
                         [self updateLocalStoreCategoriesWithObjects:(NSArray *)JSONResponse];
                         
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                         DLog(@"Failure: Fetch categories");
                         DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                         
                         
                         //show alert view with error
                         [self showNetworkErrorAlert];
                         
#warning refactor following stop http task lines below in callable method!!
                         _updating = NO;
                         
                         //report sync done (failure)
                         if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                         {
                             DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                             SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                         }
                         
                     }];
    
    
    ////KEYWORDS fetch request
#warning keyword TID  could change in future, we may add a check in 3.0?
    
    NSString *serverKeywordVID;
    if (self.serverCMSVersion1)
    {
        serverKeywordVID = kMukurtuKeywordCMSVersion1VID;
    }
    else
    {
        serverKeywordVID = kMukurtuKeywordVID;
    }
    
    
    params = [NSMutableDictionary dictionaryWithObjects:[NSArray
                                                         arrayWithObjects:kMukurtuMaxGroupSize,serverKeywordVID,@"name,tid", nil]
                                                forKeys:[NSArray arrayWithObjects:@"pagesize",@"parameters[vid]",@"fields", nil]];
    
    endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseTaxonmyTerm];
    
    [self.httpClient getPath:endpoint parameters:params
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                         DLog(@"Success: Fetch keywords completed, updating local store");
                         NSArray *JSONResponse = responseObject;
                         DLog(@"JSON response object: %@", JSONResponse);
                         
                         [self updateLocalStoreKeywordsWithObjects:(NSArray *)JSONResponse];
                         
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                         DLog(@"Failure: Fetch keywords");
                         DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                         
                         //show alert view with error
                         [self showNetworkErrorAlert];
                         
                         _updating = NO;
                         
                         //report sync done (failure)
                         if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                         {
                             DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                             SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                         }
                         
                     }];

}


- (void)fetchCulturalProtocolsParents
{
    DLog(@"Fetching Cultural Protocols details to build hierarchy");
    
    NSMutableDictionary *groupTreeDictionary = [NSMutableDictionary dictionary];
    
    for (NSDictionary *serverCommunity in self.serverCommunities)
    {
        //DLog(@"community dump %@", [community description]);
        [groupTreeDictionary setObject:[NSMutableSet set] forKey:[serverCommunity valueForKey:@"nid"]];
    }
    
    DLog(@"Initial group tree dictionary to fill \n%@", [groupTreeDictionary description]);
    
    
    NSMutableArray *operations = [NSMutableArray array];
    
    for (NSDictionary *serverCP in self.serverCulturalProtocols)
    {
        NSString *nidCP = [serverCP  valueForKey:@"nid"];
    
        NSString *endpoint = [NSString stringWithFormat:@"%@/%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseNode, nidCP];
        
        //fetch all cp details
        NSURLRequest *request = [self.httpClient requestWithMethod:@"GET" path:endpoint parameters:nil];
        
        AFHTTPRequestOperation *operation = [self.httpClient HTTPRequestOperationWithRequest:request
                                                                                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                         DLog(@"Fetched cp nid %@: %@", nidCP, [responseObject valueForKey:@"title"]);
                                                                                     }
                                                                                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                         DLog(@"Failed fetching cp nid %@",  nidCP);
                                                                                     }];
        [operations addObject:operation];
    }
    
    DLog(@"Start fetching all CP details");
    [self.httpClient enqueueBatchOfHTTPRequestOperations:operations
                                           progressBlock:^(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations) {
                                               DLog(@"Fetched %d CPs of %d", numberOfFinishedOperations, totalNumberOfOperations);
                                           }
                                         completionBlock:^(NSArray *operations) {
                                             
                                             DLog(@"Fetched all CPs");
                                             
                                             bool errorsFound = NO;
                                             
                                             for (AFJSONRequestOperation *operation in operations)
                                             {
                                                 NSDictionary *responseDict = [operation responseJSON];
                                                 
                                                 if (!operation.error && responseDict != nil)
                                                 {
                                                     
                                                     DLog(@"fetched CP %@ has nid %@", [responseDict valueForKey:@"title"], [responseDict valueForKey:@"nid"] );
                                                     
                                                     NSArray *parentCommunitiesTargets = [[responseDict valueForKey:@"og_group_ref"] valueForKey:@"und"];
                                                     
                                                     DLog(@"CP parent targets %@", [parentCommunitiesTargets description]);
                                                     
                                                     for (NSDictionary *target in parentCommunitiesTargets)
                                                     {
                                                         NSString *commId = [[target valueForKey:@"target_id"] description];
                                                         
                                                         NSMutableSet *cpChildren = [groupTreeDictionary valueForKey:commId];
                                                         
                                                         if (cpChildren != nil)
                                                         {
                                                             DLog(@"Found parent community %@ for CP %@", commId, [responseDict valueForKey:@"title"]);
                                                             [cpChildren addObject:[[responseDict valueForKey:@"nid"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                                                         }
                                                         else
                                                         {
                                                             DLog(@"Parent community %@ for CP %@ not found in tree: not accessible community (this CP should be child of another accessible community)",commId, [responseDict valueForKey:@"title"]);
                                                         }
                                                     }
                                                 }
                                                 else
                                                 {
                                                     DLog(@"Found failed JSON response, failed fetching a CP. Cancel metadata sync");
                                                     
                                                     errorsFound = YES;
                                                     
                                                     break;
                                                     
                                                 }
                                             }
                                             
                                             if (!errorsFound)
                                             {
                                                 DLog(@"Hierarchy build ended with success, store and continue sync");
                                                 
                                                 [self setGroupHierarchyAndEndMetadataSync:[NSDictionary dictionaryWithDictionary:groupTreeDictionary]];
                                             }
                                             else
                                             {
                                                 DLog(@"Hierarchy build failed, cancel sync and report error");
                                                 
                                                 //show alert view with error
                                                 [self showNetworkErrorAlert];
                                                 
                                                 _updating = NO;
                                                 
                                                 //report sync done (failure)
                                                 if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
                                                 {
                                                     DLog(@"Reporting metadata sync failure to controller %@", [self.currentSessionDelegate description]);
                                                     SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
                                                 }
                                                 
                                             }
                                             
                                         }];
}

- (void) checkAllGroupsFetchCompleted
{
    DLog(@"Checking if all groups completed fetch from server");
    
    
    if (_lastCommunitiesSyncSuccess &&
        _lastCategoriesSyncSuccess  &&
        _lastCulturalProtocolsSyncSuccess &&
        _lastKeywordsSyncSuccess &&
        _lastContributorsSyncSuccess &&
        _lastCreatorsSyncSuccess)
    {
        DLog(@"Fetched all groups from server.");
        
        //if CMS v2.0, build OG hierarchy for nested communities/cp
        if (self.serverCMSVersion1)
        {
            DLog(@"CMS version 1, skipping hierarchy and end sync");
            [self setGroupHierarchyAndEndMetadataSync:nil];
        }
        else
        {
            DLog(@"CMS version 2, building OG hierarchy");
            //fetch cp deatails and build groups hierarchy
            [self fetchCulturalProtocolsParents];
        }
    }
    else
    {
        //Wait for other fetch operations to complete
        DLog(@"Some group still fetching, skip");
        
    }
    
}

- (void)setGroupHierarchyAndEndMetadataSync:(NSDictionary *)groupsHierarchyDict
{
    DLog(@"All data fetched with sucess. Store new metadata to local DB");
    
    //create local DB entities objects from fetched groups
    [self createNewEntitiesFromServerGroups];
    
    if (groupsHierarchyDict != nil)
    {
        DLog(@"Storing groups Hierarchy to relations");
        [self storeHierarchyDictToEntityRelations:groupsHierarchyDict];
    }

    //update session handlers for current metadata groups and updated hierarchy
    //hierarchy is already updated since we just built core data relations from groupsHierarchyDict
    //anyway it safer to consider setCurrentGroups as an atomic operations that updated all public session handlers from underlying DB in one step
    //this also ensure no discrepancy from public exposed hierarchy Dict and current metadata objects
    [self setCurrentGroups];
    
    
    _updating = NO;
    _lastSyncSuccess = YES;
    
    //report sync done (success)
    if (self.currentSessionDelegate && [self.currentSessionDelegate respondsToSelector:self.currentSessionSelector])
    {
        DLog(@"Reporting metadata sync success to controller %@", [self.currentSessionDelegate description]);
        SuppressPerformSelectorLeakWarning([self.currentSessionDelegate performSelector:self.currentSessionSelector]);
    }
}

- (void)storeHierarchyDictToEntityRelations:(NSDictionary *)groupsHierarchyDict
{
    DLog(@"Storing hierarchy dict to entity relations");

    
    //store CP and Community hierarchy for future access
    //CP 1->* Community
    DLog(@"Forged group tree hierarchy dictionary \n%@", groupsHierarchyDict);
    
    //STORE CURRENT HIERARCHY TO CORE DATA RELATIONS HERE
    for (NSString *communityNid in [groupsHierarchyDict allKeys])
    {
        DLog(@"Updating cp childs of community %@", communityNid);
        
        PoiCommunity *matchingCommunity = [PoiCommunity MR_findFirstByAttribute:@"nid" withValue:communityNid];
        
        if (matchingCommunity != nil)
        {
            NSSet *communityChildsNids = [groupsHierarchyDict valueForKey:communityNid];
            NSMutableSet *communityNewChilds = [NSMutableSet set];
            
            DLog(@"Community %@ going to have %d children", matchingCommunity.title, [communityChildsNids count]);
            
            for (NSString *cpNid in communityChildsNids)
            {
                PoiCulturalProtocol *matchingCP = [PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:cpNid];
                
                if (matchingCP != nil)
                {
                    DLog(@"Adding child %@", matchingCP.title);
                    [communityNewChilds addObject:matchingCP];
                }
            }
            
            //update relations with child cultural protocols
            matchingCommunity.culturalProtocols = [NSSet setWithSet:communityNewChilds];
            
            DLog(@"Updated Child object set %@", [matchingCommunity description]);
        }
    }
    
    DLog(@"Saving core data context");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    //FIXME currentGroupsTree should be assigned ONLY from setCurrentGroups
    //self.currentGroupsTree = groupsHierarchyDict;
}

- (NSDictionary *)buildHierarchyDictFromEntityRelations
{
    DLog(@"Building hierarchy dict from entity relations");
    
    NSMutableDictionary *groupTreeDictionary = [NSMutableDictionary dictionary];
    
    for (PoiCommunity *community in [PoiCommunity MR_findAllSortedBy:@"title" ascending:YES])
    {
        NSMutableSet *childNidSet = [NSMutableSet set];
        
        for (PoiCulturalProtocol *cp in community.culturalProtocols)
        {
            [childNidSet addObject:cp.nid];
        }
        
        [groupTreeDictionary setObject:childNidSet forKey:[community.nid description]];
        
    }
    
    DLog(@"Built group tree dictionary from DB \n%@", [groupTreeDictionary description]);
    
    
    if ([groupTreeDictionary count])
    {
        return [NSDictionary dictionaryWithDictionary:groupTreeDictionary];
    }
    else
    {
        DLog(@"No relationship found, maybe are we VS CMS v1.0?");

        return nil;
    }
}


-  (void)invalidatePoisUsingManagedObject:(NSManagedObject *)group
{
    DLog(@"Finding all pois using object %@", [[group valueForKey:@"uri"] description]);
    
    
    NSSet *poiSet = [group valueForKey:@"pois"];
    NSArray *poiList = [poiSet allObjects];
    //DLog(@"raw group %@ associated pois",[poiSet description]);
    
    
    if (poiList != nil && [poiList count])
    {
        for (Poi *poi in poiList)
        {
            DLog(@"poi %@ was using removed group %@, invalidate poi", poi.title, [[group valueForKey:@"uri"] description]);
            poi.key = kPoiStatusInvalidMetadata;
        }
    }
}


- (void)createNewEntitiesFromServerGroups
{
    DLog(@"creating new entity objects for retrieved server groups");
    
    
    ////COMMUNITIES
    NSMutableArray *serverCommunitiesGids = [NSMutableArray array];
    for (NSDictionary *serverCommunity in self.serverCommunities)
    {
        NSString *nid = [serverCommunity  valueForKey:@"nid"];
        if (nid.length > 0)
            [serverCommunitiesGids addObject:nid];
    }
    //DLog(@"Server gids are %@", serverCommunitiesGids);
    
   
    //first of all, clean from local store all groups no more on server
    NSArray *tombstonedComm = [PoiCommunity MR_findAll];
    DLog(@"By now we have %d communities in local store", (int)[tombstonedComm count]);
    
    for (PoiCommunity *group in tombstonedComm)
    {
        NSString *gid = [group.nid copy];
        if (![serverCommunitiesGids containsObject:gid])
        {
            DLog(@"Local Community %@ is not on server, removing it from local store", group.title);
            
            DLog(@"Check if deleted community was used by pois and invalidate them");
            [self invalidatePoisUsingManagedObject:group];
            
            [group MR_deleteEntity];
        }
    }
    
    //add missing groups and overwrite data for existing one (groups could have same id but have been renamed server side!)
    for (NSDictionary *group in self.serverCommunities)
    {
        DLog(@"Merging server group %@", [group valueForKey:@"title"]);
        NSString *nid = [group  valueForKey:@"nid"];
        PoiCommunity *matchingCommunity = [PoiCommunity MR_findFirstByAttribute:@"nid" withValue:nid];
        if (matchingCommunity != nil)
        {
            DLog(@"Community %@ alredy on store, updating fields", [group valueForKey:@"title"]);
            
            //existing group on server, overwrite field with updated server ones
            matchingCommunity.title = [group valueForKey:@"title"];
            matchingCommunity.nid = [group  valueForKey:@"nid"]; //useless
            matchingCommunity.language = [group  valueForKey:@"language"];
            matchingCommunity.uri = [group  valueForKey:@"uri"];
        }
        else
        {
            DLog(@"Community %@ is new, creating new entity", [group valueForKey:@"title"]);
            
            //new group from server, create entity
            PoiCommunity *community = [PoiCommunity MR_createEntity];
            community.title = [group valueForKey:@"title"];
            community.nid = [group  valueForKey:@"nid"];
            community.language = [group  valueForKey:@"language"];
            community.uri = [group  valueForKey:@"uri"];
        }
    }
   
    
    ////CULTURAL PROTOCOLS
    NSMutableArray *serverCPGids = [NSMutableArray array];
    for (NSDictionary *serverCP in self.serverCulturalProtocols)
    {
        NSString *nid = [serverCP  valueForKey:@"nid"];
        if (nid.length > 0)
            [serverCPGids addObject:nid];
    }
    //DLog(@"Server gids are %@", serverCPGids);
    
    
    //first of all, clean from local store all groups no more on server
    NSArray *tombstonedCP = [PoiCulturalProtocol MR_findAll];
    DLog(@"By now we have %d cultural protocols in local store", (int)[tombstonedCP count]);
    
    for (PoiCulturalProtocol *group in tombstonedCP)
    {
        NSString *gid = [group.nid copy];
        if (![serverCPGids containsObject:gid])
        {
            DLog(@"Local Cultural Protocol %@ is not on server, removing it from local store", group.title);
            
            DLog(@"Check if deleted cultural protocol was used by pois and invalidate them");
            [self invalidatePoisUsingManagedObject:group];
            
            [group MR_deleteEntity];
        }
    }
    
    //add missing groups and overwrite data for existing one (groups could have same id but have been renamed server side!)
    for (NSDictionary *group in self.serverCulturalProtocols)
    {
        DLog(@"Merging server group %@", [group valueForKey:@"title"]);
        NSString *nid = [group  valueForKey:@"nid"];
        PoiCulturalProtocol *matchingCP = [PoiCulturalProtocol MR_findFirstByAttribute:@"nid" withValue:nid];
        if (matchingCP != nil)
        {
            DLog(@"Cultural Protocol %@ alredy on store, updating fields", [group valueForKey:@"title"]);
            
            //existing group on server, overwrite field with updated server ones
            matchingCP.title = [group valueForKey:@"title"];
            matchingCP.nid = [group  valueForKey:@"nid"]; //useless
            matchingCP.language = [group  valueForKey:@"language"];
            matchingCP.uri = [group  valueForKey:@"uri"];
        }
        else
        {
            DLog(@"Cultural Protocol %@ is new, creating new entity", [group valueForKey:@"title"]);
            
            //new group from server, create entity
            PoiCulturalProtocol *cp = [PoiCulturalProtocol MR_createEntity];
            cp.title = [group valueForKey:@"title"];
            cp.nid = [group  valueForKey:@"nid"];
            cp.language = [group  valueForKey:@"language"];
            cp.uri = [group  valueForKey:@"uri"];
        }
    }
     
    
    ////CATEGORIES
    NSMutableArray *serverCategoriesGids = [NSMutableArray array];
    for (NSDictionary *serverCategory in self.serverCategories)
    {
        NSString *tid = [serverCategory  valueForKey:@"tid"];
        if (tid.length > 0)
            [serverCategoriesGids addObject:tid];
    }
    //DLog(@"Server gids are %@", serverCategoriesGids);
    
    
    //first of all, clean from local store all groups no more on server
    NSArray *tombstonedCategories = [PoiCategory MR_findAll];
    DLog(@"By now we have %d categories in local store", (int)[tombstonedCategories count]);
    
    for (PoiCategory *group in tombstonedCategories)
    {
        NSString *gid = [group.tid copy];
        if (![serverCategoriesGids containsObject:gid])
        {
            DLog(@"Local Category %@ is not on server, removing it from local store", group.name);
            
            DLog(@"Check if deleted category was used by pois and invalidate them");
            [self invalidatePoisUsingManagedObject:group];
            
            [group MR_deleteEntity];
        }
    }
    
    //add missing groups and overwrite data for existing one (groups could have same id but have been renamed server side!)
    for (NSDictionary *group in self.serverCategories)
    {
        DLog(@"Merging server group %@", [group valueForKey:@"name"]);
        NSString *tid = [group  valueForKey:@"tid"];
        PoiCategory *matchingCategory = [PoiCategory MR_findFirstByAttribute:@"tid" withValue:tid];
        if (matchingCategory != nil)
        {
            DLog(@"Category %@ alredy on store, updating fields", [group valueForKey:@"name"]);
            
            //existing group on server, overwrite field with updated server ones
            matchingCategory.name = [group valueForKey:@"name"];
            matchingCategory.tid = [group  valueForKey:@"tid"]; //useless
            matchingCategory.uri = [group  valueForKey:@"uri"];
        }
        else
        {
            DLog(@"Category %@ is new, creating new entity", [group valueForKey:@"name"]);
            
            //new group from server, create entity
            PoiCategory *category = [PoiCategory MR_createEntity];
            category.name = [group valueForKey:@"name"];
            category.tid = [group  valueForKey:@"tid"]; 
            category.uri = [group  valueForKey:@"uri"];
        }
    }
    
    
    ////KEYWORDS
    //since keywords are not related to POIs, we just update local store with server defined keywords.
    //any local created keyword not already uploaded with a poi will be deleted (but poi that use it are not affected since it is copied as a string value)
    //clean local store
    [PoiKeyword MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    for (NSDictionary *keyword in self.serverKeywords)
    {
        DLog(@"Creating local keyword %@", [keyword valueForKey:@"name"]);
            
        //new group from server, create entity
        PoiKeyword *poiKeyword = [PoiKeyword MR_createEntity];
        poiKeyword.name = [keyword valueForKey:@"name"];
        poiKeyword.tid = [keyword  valueForKey:@"tid"];
        poiKeyword.uri = [keyword  valueForKey:@"uri"];
    }
    
    
    ////CONTRIBUTORS
    //since contributors are not related to POIs, we just update local store with server defined contributors.
    //clean local store
    [PoiContributor MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    for (NSDictionary *contributor in self.serverContributors)
    {
        DLog(@"Creating local contributor %@", [contributor valueForKey:@"name"]);
        
        //new group from server, create entity
        PoiContributor *poiContributor = [PoiContributor MR_createEntity];
        poiContributor.name = [contributor valueForKey:@"name"];
        poiContributor.tid = [contributor  valueForKey:@"tid"];
        poiContributor.uri = [contributor  valueForKey:@"uri"];
    }

    ////CREATORS
    //since creators are not related to POIs, we just update local store with server defined creators.
    //clean local store
    [PoiCreator MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
    for (NSDictionary *creator in self.serverCreators)
    {
        DLog(@"Creating local creator %@", [creator valueForKey:@"name"]);
        
        //new group from server, create entity
        PoiCreator *poiCreator = [PoiCreator MR_createEntity];
        poiCreator.name = [creator valueForKey:@"name"];
        poiCreator.tid = [creator  valueForKey:@"tid"];
        poiCreator.uri = [creator  valueForKey:@"uri"];
    }
    
     
    DLog(@"Saving core data context 3");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    DLog(@"Current Stack: \n%@", [MagicalRecord currentStack]);
}

- (void)updateLocalStoreCommunitiesWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local communities Objs");
    
    self.serverCommunities = objs;
    
    _lastCommunitiesSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}

- (void)updateLocalStoreCulturalProtocolsWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local cultural protocols Objs");
    
    self.serverCulturalProtocols = objs;
    
    _lastCulturalProtocolsSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}

- (void)updateLocalStoreCategoriesWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local categories Objs");
    
    self.serverCategories = objs;
    
    _lastCategoriesSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}

- (void)updateLocalStoreKeywordsWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local keywords Objs");
    
    self.serverKeywords = objs;
    
    _lastKeywordsSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}

- (void)updateLocalStoreContributorsWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local contributors Objs");
    
    self.serverContributors = objs;
    
    _lastContributorsSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}

- (void)updateLocalStoreCreatorsWithObjects:(NSArray *)objs
{
    DLog(@"Storing temp local creators Objs");
    
    self.serverCreators = objs;
    
    _lastCreatorsSyncSuccess = YES;
    [self checkAllGroupsFetchCompleted];
}


- (void)setCurrentGroups
{
    DLog(@"Updating current groups");
    

//#define WANTDUMMYDATA
#ifdef WANTDUMMYDATA
    //DEBUG DATA SOURCE
    // Setup App with prefilled metadata
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"MR_HasDebugMetadata"])
    {
        DLog(@"DEBUG: DB is empty, creating some fake metadata for debug...");
        
        // create N object for type
        for (int i=0;i<6;i++)
        {
            PoiCategory *category = [PoiCategory createEntity];
            category.name = [NSString stringWithFormat:@"Category %d", i];
            category.tid = [NSString stringWithFormat:@"100%d", i];
            category.uri = @"__Debug_URI";
            
            PoiCommunity *community = [PoiCommunity createEntity];
            community.title = [NSString stringWithFormat:@"Community %d", i];
            community.nid = [NSString stringWithFormat:@"100%d", i];
            community.language = @"en";
            community.uri = @"__Debug_URI";
            
            PoiCulturalProtocol *culturalProtocol = [PoiCulturalProtocol createEntity];
            culturalProtocol.title = [NSString stringWithFormat:@"Cultural Protocol %d", i];
            culturalProtocol.nid = [NSString stringWithFormat:@"200%d", i];
            culturalProtocol.language = @"en";
            culturalProtocol.uri = @"__Debug_URI";
            
        }
        
        // Save Managed Object Context
        [[NSManagedObjectContext defaultContext] saveToPersistentStoreAndWait];
        
        // Set User Default to prevent another preload of data on startup.
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MR_HasDebugMetadata"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
#endif
    
    
    self.currentCategories = [[PoiCategory MR_findAllSortedBy:@"name" ascending:YES] copy];
    self.currentCommunities = [[PoiCommunity MR_findAllSortedBy:@"title" ascending:YES] copy];
    self.currentCulturalProtocols = [[PoiCulturalProtocol MR_findAllSortedBy:@"title" ascending:YES] copy];
    
    //FIX 2.5: build local community/CP hierarchy tree from DB
    self.currentGroupsTree = [self buildHierarchyDictFromEntityRelations];
    
    //update CMS version, defaults to 2.0
    if ([self.storedBaseUrlCMSVersion isEqualToString:@"1.0"])
    {
        DLog(@"Found stored key for CMS version 1.0, enabling old CMS compatibility");
        _serverCMSVersion1 = YES;
        
        //voids group hierarchy on CMS v1.0
        self.currentGroupsTree = nil;
    }
    else if ([self.storedBaseUrlCMSVersion isEqualToString:@"2.0"])
    {
        DLog(@"Found stored key for CMS version 2.0, enabling new features");
        _serverCMSVersion1 = NO;
    }
    else
    {
        DLog(@"No CMS version key or invalid found, defaults to CMS version 2.0");
        _serverCMSVersion1 = NO;
    }
}

- (void) validateAllPois
{
    DLog(@"Validating all pois againsted stored metadata");
    
    //check if user is logged on youtube and if current token is still valid
    //[self validateYouTubeSession];
    BOOL hasValidYoutubeToken = _youTubeHelper.isAuthValid;
    
    
    NSArray *storedPois = [Poi MR_findAll];
   
    
    for (Poi *poi in storedPois)
    {
        
        NSString *errorMessage = kPoiStatusMissingHeaderText;
        BOOL errorFound = NO;
        
        if ([poi.key isEqualToString:kPoiStatusInvalid])
        {
            DLog(@"poi %@ is already marked as not valid, skip it from validation", poi.title);
        }
        else
        {
            
            //FIX 2.5: search and remove "orphan" communities (with no selected children), no error is reported
            DLog(@"Checking poi %@ for orphan communities", poi.title);
            NSMutableSet *orphanCommunities = [NSMutableSet set];
            for (PoiCommunity *community in poi.communities)
            {
                BOOL communityValid = false;
                
                for (PoiCulturalProtocol *cp in community.culturalProtocols)
                {
                    if ([poi.culturalProtocols containsObject:cp])
                    {
                        DLog(@"community %@ is valid", community.title);
                        communityValid = true;
                        break;
                    }
                }
                
                if (!communityValid)
                {
                    DLog(@"WARNING: community %@ is orphan, removing it", community.title);
                    
                    //remove orphan community from poi
                    [orphanCommunities addObject:community];
                }
            }
            
            if ([orphanCommunities count])
            {
                NSMutableSet *newCommunities = [NSMutableSet setWithSet:poi.communities];
                [newCommunities minusSet:orphanCommunities];
                poi.communities = [newCommunities copy];
            }
            
            //FIX 2.5: clean any orphan CPs, could rarely happen if communities are removed from server or permission changed for current user
            //in this case a general alert to review content since metadata changed is showed to user. This will double ensure we don't have any invalid CPs stored in poi.
            //no error is reported, anyway if a poi results without any  communities or CPs after validation, error is reported
            DLog(@"Checking poi %@ for orphan CPs", poi.title);
            NSMutableSet *orphanCPs = [NSMutableSet set];
            for (PoiCulturalProtocol *cp in poi.culturalProtocols)
            {
                BOOL cpValid = false;
                for (PoiCommunity *community in cp.parentCommunities)
                {
                    if ([poi.communities containsObject:community])
                    {
                        DLog(@"CP %@ is valid", cp.title);
                        cpValid = true;
                        break;
                    }
                }
                
                if (!cpValid)
                {
                    DLog(@"WARNING: cp %@ is orphan, removing it", cp.title);
                    
                    //remove orphan cp from poi
                    [orphanCPs addObject:cp];
                }
            }
            
            if ([orphanCPs count])
            {
                NSMutableSet *newCPs = [NSMutableSet setWithSet:poi.culturalProtocols];
                [newCPs minusSet:orphanCPs];
                poi.culturalProtocols = [newCPs copy];
            }
            

            //we check communities and CPs only after orphan groups cleaning,
            //this ensure we report error also when cleaning orphan obejcts leaves a poi without any community or CP
            
            //check fields
            if (![poi.culturalProtocols count])
            {
                //cultural protocols are required fields, cancel if missing
                
                DLog(@"poi %@ validation not passed: no required cultural protocols found", poi.title);
                //poi.key = kPoiStatusMissingGroup;
                errorMessage = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, kPoiStatusMissingGroup];
                errorFound = YES;
            }
            
            //FIX 2.5: at least 1 community is needed
            if (![poi.communities count])
            {
                //at least 1 community is needed, cancel if missing
                
                DLog(@"poi %@ validation not passed: at least 1 community is needed", poi.title);
                //poi.key = kPoiStatusMissingGroup;
                errorMessage = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, kPoiStatusMissingCommunity];
                errorFound = YES;
            }
            
            if (![poi.categories count])
            {
                //categories are required fields, cancel if missing
                DLog(@"poi %@ validation not passed: no required categories found", poi.title);
                //poi.key = kPoiStatusMissingCategories;
                errorMessage = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, kPoiStatusMissingCategories];
                errorFound = YES;
            }
            
            
            if ([poi.creator length] == 0)
            {
                DLog(@"poi %@ validation not passed: no creator found",poi.title);
                //poi.key = kPoiStatusMissingCreator;
                errorMessage = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, kPoiStatusMissingCreator];
                errorFound = YES;
            }
            
            if  (([poi.creationDateString length] == 0) &&
                 (poi.creationDate == nil || ![poi.creationDate isKindOfClass:[NSDate class]]))
            {
                DLog(@"poi %@ validation not passed: no valid creation date found", poi.title);
                //poi.key = kPoiStatusMissingDate;
                errorMessage = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, kPoiStatusMissingDate];
                errorFound = YES;
            }
            
            
            //show youtube error only if all other fileds are ok, to avoi confusion and long alert text
            if (!errorFound && !hasValidYoutubeToken)
            {
                NSArray *poiMedias = [poi.media allObjects];
                
                for (PoiMedia *media in poiMedias)
                {
                    if ([media.type isEqualToString:@"video"])
                    {
                        DLog(@"Poi has videos but user is not logged on youtube, mark this poi as not valid");
                        //poi.key = kPoiStatusNoYouTubeLoginForVideos;
                        errorMessage = kPoiStatusNoYouTubeLoginForVideos;
                        errorFound = YES;
                        break;
                    }
                }
                
            }
            
            //check if we found errors and in the case set key accordingly to alert user of issues when editing poi again
            if (errorFound)
            {
                poi.key = [errorMessage copy];
            }
            
        }
        
    }
    
    
    //save Context
    DLog(@"Saving Context after poi validation");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
}


////Poi upload
- (void) startUploadJobFromDelegate:(NSObject *)delegate
{
    DLog(@"Upload job started");
    
    
    self.uploadedPoiList = [NSMutableArray array];
    
    self.uploadDelegate = (UploadProgressViewController *) delegate;
    self.uploadDelegate.poiUploaded = 0;
    
    
    NSMutableArray *poiListUpload = [[Poi MR_findAll] mutableCopy];
    
    //remove invalid pois before upload starts
    for (Poi *poi in [poiListUpload copy])
    {
        //check for invalid poi
        if ([poi.key length]>0)
        {
            DLog(@"Poi %@ is invalid, removing from upload list", poi.title);
            
            [poiListUpload removeObject:poi];
            
        }
    }
    
    //FIX 2.5: setup upload progress delegate *before* actually starting poi upload jobs
    self.uploadDelegate.poiToUpload = [poiListUpload count];
    [self.uploadDelegate updateProgressBar];
    
    
    //second pass to actually upload pois
    for (Poi *poi in poiListUpload)
    {
        DLog(@"uploading poi %@", poi.title);
        [self uploadPoi:poi];
        
    }
    
    //DEBUG
    //DLog(@"Report success to upload delegate");
    //[self.uploadDelegate successConfirmed];
    
}


- (void) uploadMedia:(PoiMedia *)media forPoi:(Poi *)poi
{
    DLog(@"Uploading media %@ for poi %@", [media.path lastPathComponent], poi.title);
    
    
    if ([media.type isEqualToString:@"photo"])
    {
        DLog(@"media is an image, upload it to mukurtu");
        
        if (self.uploadDelegate)
        {
            [self.uploadDelegate updateProgressStatus:[NSString stringWithFormat:@"Uploading story photo"]];
        }
        
        [self uploadPhotoMedia:media];
    }
    else
        if ([media.type isEqualToString:@"video"])
        {
            DLog(@"media is a video, upload it to youtube");
            
            if (self.uploadDelegate)
            {
                [self.uploadDelegate updateProgressStatus:[NSString stringWithFormat:@"Uploading story video    "]];
            }
            
            //at this point we are sure youtube login is ok, if not poi should be invalid
            
            if (self.serverCMSVersion1)
            {
                //with CMS v1 we may need a video thumbnail on server to use it as first media
                [self uploadVideoThumbnailForMedia:media];
            }
            else
            {
                //CMS v2 supports video objects without embedding, proceed with upload
                [self uploadVideoForMedia:media];
            }
            
            //upload is async and uploadPoi will be called when youtube upload finishes with protocol method uploadDone
        }
        else
            if ([media.type isEqualToString:@"audio"])
            {
                DLog(@"media is an audio, upload it to mukurtu");
                
                if (self.uploadDelegate)
                {
                    [self.uploadDelegate updateProgressStatus:[NSString stringWithFormat:@"Uploading story audio    "]];
                }
                
                [self uploadAudioMedia: media];
            }
    
}

- (void) createScaldAtomForMedia:(PoiMedia *)media
{
    //FIX 2.5: handle scald atom creation for every media (will use obtained sids in upload poi node)
    DLog(@"Creating Scald Atom for media %@", [media.path lastPathComponent]);
    
    //we should have a valid fid for media here, if not, mark media as invalid
    if (!media.key ||
        (![media.type isEqualToString:@"video"] &&
         !NSEqualRanges([media.key rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet].invertedSet], NSMakeRange(NSNotFound, 0))))
    {
        DLog(@"Invalid media key %@ found during scald atom creation for media %@", media.key, [media.path lastPathComponent]);
        
        //upload failed, mark this media as invalid to stop upload for this poi
        DLog(@"mark media as invalid");
        media.key = kPoiStatusInvalid;
        
        //save Context
        DLog(@"Saving Context after image upload failure");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        
        //call again upload for this poi: if all media are ok poi upload will start
        //(if not it will trigger next media upload)
        //FIX 2.5: upload using already obtained CSRF token
        [self uploadPoiWithCSRFToken:media.parent];
        return;
    }
    
    NSString *endpoint;
    if ([media.type isEqualToString:@"video"])
    {
        //GET scald endpoint to create an atom video from youtube id
        endpoint = [NSString stringWithFormat:@"%@/%@/create?id=%@&external=youtube", kMukurtuServerEndpoint, kMukurtuServerBaseScald, media.key];
    }
    else
    {
        //GET scald endpoint to create an atom for media fid (photo or audio)
        endpoint = [NSString stringWithFormat:@"%@/%@/create?id=%@", kMukurtuServerEndpoint, kMukurtuServerBaseScald, media.key];
    }
    
    [self.httpClient postPath:endpoint parameters:nil
                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                     DLog(@"Success: Scald id succesfully created for media %@", [media.path lastPathComponent]);
                     
                     NSDictionary *jsonResponse = responseObject;
                     
                     DLog(@"Assigning sid %@ to media fid %@", [[jsonResponse valueForKey:@"sid"] description], media.key);
                     if ([jsonResponse valueForKey:@"sid"] != nil)
                     {
                         media.sid = [[jsonResponse valueForKey:@"sid"] description];
                     }
                     
                     //save Context
                     DLog(@"Saving Context after scald creation success");
                     [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                     
                     [self uploadPoiWithCSRFToken:media.parent];
                 }
                 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                     DLog(@"Failure: Creating scald atom failed for media \n%@ responseString %@",[media.path lastPathComponent], operation.responseString);
                     DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                     
                     //mark this media with invalid sid value, so upload will restart from scald creation again, skipping actual media file upload.
                     media.sid = kPoiStatusInvalid;
                     
                     //save Context
                     DLog(@"Saving Context after scald creation failure");
                     [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                     
                     [self uploadPoiWithCSRFToken:media.parent];
                 }];
    
}

- (void) uploadPhotoMedia:(PoiMedia *)media
{
    DLog(@"Uploading media photo file");
    
    Poi *poi = media.parent;
    
    //FIX 2.5: use relative path in ios8
    //NSString *imagePath = [[media valueForKey:@"path"] description];
    NSString *imagePath = [NSHomeDirectory() stringByAppendingPathComponent:media.path];
    
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    
    NSMutableDictionary *file = [[NSMutableDictionary alloc] init];
    
    NSString *base64Image = [imageData base64EncodedString];
    
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HHmmss"];
    
    NSString *creationDateString;
    
    if (media.expectedSize != nil && media.expectedSize > 0)
    {
        NSNumber *originalTimestamp = media.expectedSize;
        creationDateString = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[originalTimestamp doubleValue]]];
    }
    else
        creationDateString = [dateFormatter stringFromDate:media.timestamp];
    
    DLog(@"Image original creation date: %@", creationDateString);
    
    
    //for debug only
    //DLog(@"base 64 string %@", base64Image);
    
    [file setObject:base64Image forKey:@"file"];
    
    NSString *basename = [[poi.title componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    //get resized factor postfix (if present)
    NSString *resizedPostfix = @"";
    NSArray *filenameParts = [[[media.path lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_pic"];
    
    //DLog(@"filename parts %@", filenameParts);
    
    if ([filenameParts count])
    {
        resizedPostfix = filenameParts[1];
        DLog(@"Image was resized, get image suffix %@", resizedPostfix);
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@_photo_%@%@.%@", basename, creationDateString, resizedPostfix, [media.path pathExtension]];
    
    DLog(@"File to upload new filename: %@", filename);
    
    [file setObject:filename forKey:@"filename"];
    
    //DEBUG
    //NSError *error;
    //NSData* jsonData = [NSJSONSerialization dataWithJSONObject:file options:NSJSONWritingPrettyPrinted error:&error];
    //NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //DLog(@"JSON object:\n%@", jsonString);
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseFile];
    
    
    [self.httpClient postPath:endpoint
                   parameters:file
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          NSDictionary *nodeJSON = responseObject;
                          DLog(@"FILE save success: response object: %@", [nodeJSON description]);
                          
                          DLog(@"Assigning fid %@ to media %@", [[nodeJSON valueForKey:@"fid"] description], [media.path lastPathComponent]);
                          if ([nodeJSON valueForKey:@"fid"] != nil)
                              media.key = [[nodeJSON valueForKey:@"fid"] description];
                          
                          //save Context
                          DLog(@"Saving Context after image upload success");
                          [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                          
                          if (self.serverCMSVersion1)
                          {
                              //call again upload for this poi: if all media are ok poi upload will start
                              //(if not it will trigger next media upload)
                              //[self uploadPoi:poi];
                              
                              //FIX 2.5: upload using already obtained CSRF token
                              [self uploadPoiWithCSRFToken:poi];
                          }
                          else
                          {
                              //CMS version 2, proceed with scald atom creation to obtain sid for media
                              [self createScaldAtomForMedia:media];
                          }
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          DLog(@"FILE save error: %@ responseString %@",error, operation.responseString);
                          
                          //upload failed, mark this media as invalid to stop upload for this poi
                          DLog(@"mark media as invalid");
                          media.key = kPoiStatusInvalid;
                          
                          //save Context
                          DLog(@"Saving Context after image upload failure");
                          [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                          
                          //call again upload for this poi: if all media are ok poi upload will start
                          //(if not it will trigger next media upload)
                          //[self uploadPoi:poi];
                          
                          //FIX 2.5: upload using already obtained CSRF token
                          [self uploadPoiWithCSRFToken:poi];
                      }];

}

- (void) uploadAudioMedia:(PoiMedia *)media
{
    DLog(@"Uploading media audio file");
    
    Poi *poi = media.parent;
    
    //FIX 2.5: use relative path in ios8
    //NSString *audioPath = [[media valueForKey:@"path"] description];
    NSString *audioPath = [NSHomeDirectory() stringByAppendingPathComponent:media.path];
    
    NSData *audioData = [NSData dataWithContentsOfFile:audioPath];
    
    NSMutableDictionary *file = [[NSMutableDictionary alloc] init];
    
    NSString *base64Audio = [audioData base64EncodedString];
    
    
    //for debug only
    //DLog(@"base 64 string %@", base64Audio);
    
    [file setObject:base64Audio forKey:@"file"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HHmmss"];
    
    NSString *creationDateString = [dateFormatter stringFromDate:media.timestamp];
    
    DLog(@"Audio creation date: %@", creationDateString);

    NSString *basename = [[poi.title componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    NSString *filename = [NSString stringWithFormat:@"%@_audio_%@.%@", basename, creationDateString, [media.path pathExtension]];
    
    DLog(@"uploading filename: %@", filename);
    
    [file setObject:filename forKey:@"filename"];
    
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseFile];
    
    [self.httpClient postPath:endpoint
                   parameters:file
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          NSDictionary *nodeJSON = responseObject;
                          DLog(@"FILE save success: response object: %@", [nodeJSON description]);
                          
                          DLog(@"Assigning fid %@ to media %@", [[nodeJSON valueForKey:@"fid"] description], [media.path lastPathComponent]);
                          if ([nodeJSON valueForKey:@"fid"] != nil)
                              media.key = [[nodeJSON valueForKey:@"fid"] description];
                          
                          //save Context
                          DLog(@"Saving Context after audio upload success");
                          [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                          
                          if (self.serverCMSVersion1)
                          {
                              //call again upload for this poi: if all media are ok poi upload will start
                              //(if not it will trigger next media upload)
                              //[self uploadPoi:poi];
                              
                              //FIX 2.5: upload using already obtained CSRF token
                              [self uploadPoiWithCSRFToken:poi];
                          }
                          else
                          {
                              //CMS version 2, proceed with scald atom creation to obtain sid for media
                              [self createScaldAtomForMedia:media];
                          }
                      }
     
                      failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          DLog(@"FILE save error: %@ responseString %@",error, operation.responseString);
                          
                          //upload failed, mark this media as invalid to stop upload for this poi
                          DLog(@"mark media as invalid");
                          media.key = kPoiStatusInvalid;
                          
                          //save Context
                          DLog(@"Saving Context after audio upload failure");
                          [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                          
                          //call again upload for this poi: if all media are ok poi upload will start
                          //(if not it will trigger next media upload)
                          //[self uploadPoi:poi];
                          
                          //FIX 2.5: upload using already obtained CSRF token
                          [self uploadPoiWithCSRFToken:poi];
                          
                      }];
    
}

-(void)uploadVideoThumbnailForMedia:(PoiMedia *)media
{
    DLog(@"Uploading video thumbnail for media %@", [media.path lastPathComponent]);
    
    Poi *poi = media.parent;
    
    //ENABLE VIDEO THUMBNAIL ONLY IF NO IMAGES
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", @"photo" ];
    
    //this is the fixed version
    NSArray *allImages = [[media.parent.media allObjects] filteredArrayUsingPredicate:predicate];
    
    if ([allImages count] != 0)
    {
        DLog(@"Poi has some images, we don't need to upload big thumbnail for video %@", [media.path lastPathComponent]);
        
        //set media key to a dummy fid to pass upload video tests
        NSString *tempFid = [NSString stringWithFormat:@"fid-%@",kDummyVideoThumbnailFid];
        DLog(@"tempFid media key is %@", tempFid);
        media.key = tempFid;
        
        
        //save Context
        DLog(@"Saving Context after dummy video thumbnail fid added");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        
        [self uploadVideoForMedia:media];
        
        return;
    }

    //check if already have fid for video thumb
    if ([media.key length] > 0)
    {
        DLog(@"We already have valid fid %@ for media", media.key);
        
        //proceed with youtube upload now
        [self uploadVideoForMedia:media];
    }
    else
    {
        //key is empty, we need to upload video thumbnail before video
        
        //get big thumbnail path from thumbnail path
        //FIX 2.5: use relative path in ios8
        //NSString *imagePath = [ImageSaver getBigThumbPathForThumbnail:media.thumbnail];
        NSString *imagePath = [ImageSaver getBigThumbPathForThumbnail:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail]];
        DLog(@"Big thumbnail filename for media is %@",[imagePath lastPathComponent]);
        
        NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
        
        NSMutableDictionary *file = [[NSMutableDictionary alloc] init];
        
        NSString *base64Image = [imageData base64EncodedString];
        
        
        [file setObject:base64Image forKey:@"file"];
        
        NSString *basename = [[poi.title componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
        
        NSString *filename = [NSString stringWithFormat:@"%@-%d.%@", basename, (int)[[NSDate date] timeIntervalSince1970], [imagePath pathExtension]];
        
        [file setObject:filename forKey:@"filename"];
        
        
        //add video description
#warning description not working
        /*
        NSString *videoDescription = @"A test description";
        
        NSArray *descriptionArray = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObject:videoDescription forKey:@"value"], @"format", nil];
        
        NSDictionary *fieldDescriptionDict = [NSDictionary dictionaryWithObject:descriptionArray forKey:@"und"];
        [file setObject:fieldDescriptionDict forKey:@"field_media_description"];
         */
        
        NSString *endpoint = [NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseFile];
        
        
        [self.httpClient postPath:endpoint
                       parameters:file
                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                              NSDictionary *nodeJSON = responseObject;
                              //DLog(@"FILE save success: response object: %@", [nodeJSON description]);
                              DLog(@"Big thumbnail save success");
                              
                              DLog(@"Assigning fid %@ for video thumbnail to media %@", [[nodeJSON valueForKey:@"fid"] description], [media.path lastPathComponent]);
                              if ([nodeJSON valueForKey:@"fid"] != nil)
                              {
                                  NSString *tempFid = [NSString stringWithFormat:@"fid-%@",[[nodeJSON valueForKey:@"fid"] description]];
                                  DLog(@"tempFid media key is %@", tempFid);
                                  media.key = tempFid;
                              }
                              
                              //save Context
#warning should chagen if saving context here is ok
                              DLog(@"Saving Context after image upload success");
                              [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                              
                              [self uploadVideoForMedia:media];
                              
                              
                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              DLog(@"Big thumbnail save error: %@ responseString %@",error, operation.responseString);
                              
                              //upload failed, mark this media as invalid to stop upload for this poi
                              DLog(@"mark media as invalid");
                              media.key = kPoiStatusInvalid;
                              
                              //save Context
#warning should chagen if saving context here is ok
                              DLog(@"Saving Context after image upload failure");
                              [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                              
                              //call again upload for this poi: if all media are ok poi upload will start
                              //(if not it will trigger next media upload)
                              //[self uploadPoi:poi];
                              
                              //FIX 2.5: upload using already obtained CSRF token
                              [self uploadPoiWithCSRFToken:poi];
                              
                          }];
    }

}

-(void)uploadVideoForMedia:(PoiMedia *)media
{
    DLog(@"Uploading video for media %@", [media.path lastPathComponent]);

    int videoIndex = 0;
    
    NSSet* medias = media.parent.media;
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *sortedMedia = [[medias allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    
    for (PoiMedia *orderedMedia in sortedMedia)
    {
        if ([orderedMedia.type isEqualToString:@"video"])
        {
            videoIndex++;
            if ([orderedMedia.path isEqualToString:media.path])
            {
                //we found index of current media, stop iterating
                break;
            }
        }
    }
    
    NSString *videoTitle = [NSString stringWithFormat:@"%@ - %d", [media.parent.title copy], videoIndex];
    
    NSString *videoDescription = @"";
    
    if ([media.parent.longdescription length] > 0)
    {
        videoDescription = [media.parent.longdescription copy];
    }
    
    
    NSString *videoTagsList = @"";
    if ([media.parent.keywordsString length] > 0)
    {
        videoTagsList = [media.parent.keywordsString copy];
    }
    
    DLog(@"Uploading video with metadata\nname: %@\ndescription: %@\ntags: %@", videoTitle, videoDescription, videoTagsList);
    
    //[self.youTubeHelper uploadVideoWithTitle:videoTitle description:videoDescription commaSeperatedTags:videoTagsList andMedia:media];
#warning by now we choose to non disclosure any poi information on youtube, so description has been removed
    [self.youTubeHelper uploadVideoWithTitle:videoTitle description:nil commaSeperatedTags:videoTagsList andMedia:media];
}


- (void) uploadPoi:(Poi *)poi
{
    DLog(@"Starting upload poi for %@", poi.title);
    
    
     //FIX 2.5: OBTAIN CSRF TOKEN HERE
    NSString *endpoint = [NSString stringWithFormat:@"%@", kMukurtuServerCSRFTokenRequestEndpoint];
    
    AFHTTPClient *tokenClient = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:self.storedBaseUrl]];
    [tokenClient setDefaultHeader:@"Accept" value:@"text/plain"];
    
    [tokenClient getPath:endpoint parameters:nil
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                         DLog(@"Success: Obtained a valid CSRF Token");
                         NSString *CSRFToken = operation.responseString;
                        
                         self.sessionTokenCSRF = [CSRFToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                         DLog(@"token: %@", self.sessionTokenCSRF);
                         
                         //add CSRF token to request header
                         [self.httpClient setDefaultHeader:@"X-CSRF-Token" value:self.sessionTokenCSRF];
                         
                         [self uploadPoiWithCSRFToken:poi];
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                         DLog(@"Failure: Requesting CSRF Token failed \n%@ responseString %@",error, operation.responseString);
                         DLog(@"error %@, response Headers %@",error, [operation.response allHeaderFields]);
                         
                         //cancel upload for this poi
                         //self.uploadDelegate.poiUploaded += 1;
                         //[self.uploadDelegate updateProgressBar];
                         
                         //try to upload poi anyway  without token (old drupal services version retro compatibility)
                         DLog(@"Trying to upload without CSRF Token (old drupal services version retro compatibility)");
                         [self uploadPoiWithCSRFToken:poi];
                     }];
    
}

- (void) uploadPoiWithCSRFToken:(Poi *)poi
{
    DLog(@"Starting poi upload with CSFR Token %@ for poi %@", self.sessionTokenCSRF, poi.title);
    
    //check if there are media to upload
    if ([poi.media count])
    {
#warning by now we upload one media at time, to avoid overload mukurtu server
        
        DLog(@"Poi has media, check media upload status before uploading");
        for (PoiMedia *media in [poi.media allObjects])
        {
            if ( [media.key length] == 0 )
            {
                DLog(@"media %@ has not been uploaded, launch upload", [media.path lastPathComponent]);
                [self uploadMedia:media forPoi:poi];
                return;
            }
            else if ([media.key isEqualToString:kPoiStatusInvalid])
            {
                DLog(@"media %@ has failed upload, skip upload of this poi until next job", [media.path lastPathComponent]);
                media.key = @"";
                
                self.uploadDelegate.poiUploaded += 1;
                [self.uploadDelegate updateProgressBar];
                
                //save Context
                DLog(@"Saving Context after skipping poi upload for invalid media");
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                
                return;
            }
            else if ([media.type isEqualToString:@"video"] &&
                     [media.key hasPrefix:@"fid-"])
            {
                //valid case only for mukurtu CMS 1
                DLog(@"Media is a video and we already have an uploaded thumbnail");
                [self uploadMedia:media forPoi:poi];
                return;
            }
            else if (!self.serverCMSVersion1 && [media.sid length] == 0) //valid only for CMS v2
            {
                //media have been uploaded but we still miss a scald atom id for this media, let's create one
                DLog(@"media %@ misses scald atom id (sid=%@), create a sid for this media", [media.path lastPathComponent], media.sid);

                [self createScaldAtomForMedia:media];
                return;
            }
            else if (!self.serverCMSVersion1 && [media.sid isEqualToString:kPoiStatusInvalid]) //valid only for CMS v2
            {
                //scald atom creation failed, mark error and stop poi upload
                DLog(@"media %@ has failed scald id creation, skip upload of this poi until next job", [media.path lastPathComponent]);
                media.sid = @"";
                
                //save Context
                DLog(@"Saving Context after skipping poi upload for invalid media");
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                
                self.uploadDelegate.poiUploaded += 1;
                [self.uploadDelegate updateProgressBar];
            
                return;
            }
            else
                DLog(@"media %@ has been uploaded with fid %@ and sid %@", [media.path lastPathComponent], media.key, media.sid);
        }
        
        DLog(@"All medias for poi %@ have been uploaded! proceed with poi upload", poi.title);
    }
    else
        DLog(@"Poi %@ has no media, continue with poi upload", poi.title);
    
    ////if we reach here, all media for this poi are on server and we have a valid file id to link remote media files to this poi
    if (self.uploadDelegate)
    {
        //update progress status
        [self.uploadDelegate updateProgressStatus:[NSString stringWithFormat:@"Uploading Story %@",poi.title]];
    }
    
    
    if ([poi.key length] > 0)
    {
        DLog(@"poi %@ is not valid, skip it from upload. Error: %@", poi.title, poi.key);
        
        //[self.toKeepPoiList addObject:poi];
        //[self markPoiUploadFinished];
        return;
    }
    
    NSDictionary *nodeData;
    
    if (self.serverCMSVersion1)
    {
        DLog(@"CMS version 1, build node in legacy format");
        nodeData = [self buildLegacyNodeDictionaryForPoi:poi];
    }
    else
    {
        DLog(@"CMS version 2+, build node in latest format");
        nodeData = [self buildNodeDictionaryForPoi:poi];
    }
    
    if (nodeData == nil)
    {
        //some error occured during dictionary build, skip upload and report as failed
        
        DLog(@"error: node dictionary is %@, upload failed for poi %@",[nodeData description], [poi.title description]);
        
        self.uploadDelegate.poiUploaded += 1;
        [self.uploadDelegate updateProgressBar];
    }
    else
    {
        DLog(@"Dictionary for poi %@ is ok, POST it to server", [poi.title description]);
        
        //DLog(@"forged node data: %@",[nodeData description]);
        
        [self.httpClient postPath:[NSString stringWithFormat:@"%@/%@", kMukurtuServerEndpoint, kMukurtuServerBaseNode]
                       parameters:nodeData
                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                              NSDictionary *nodeJSON = responseObject;
                              DLog(@"node save success: response object: %@", [nodeJSON description]);
                              
                              self.uploadDelegate.poiUploaded += 1;
                              [self.uploadDelegate updateProgressBar];
                              
                              [self.uploadedPoiList addObject:poi];
                              DLog(@"Succesful Uploaded poi list contains %d objects", (int)[self.uploadedPoiList count]);
                              
                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              DLog(@"node save error: %@ responseString %@",error, operation.responseString);
                              
                              self.uploadDelegate.poiUploaded += 1;
                              [self.uploadDelegate updateProgressBar];
                          }];
        
    }
}

-(NSDictionary *)buildNodeDictionaryForPoi:(Poi *)poi
{
    NSMutableDictionary *nodeData = [NSMutableDictionary dictionary];
    
    //initi node dictionary
    [nodeData setValue:poi.title forKey:@"title"];
    
    
    //set type
    [nodeData setValue:@"digital_heritage" forKey:@"type"];
    
    //set language (FIXME default to en by now)
    [nodeData setValue:@"en" forKey:@"language"];
    
    
    //authoring date (for content, different from digital heritage creation date)
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    NSString *dateAuthoringString = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:poi.timestamp]];
    [nodeData setValue:dateAuthoringString forKey:@"date"];
    
    
    //MEDIA: poi medias should all have valid fids and sids here
    //format: (media order is preserved)
    //"field_media_asset": {
    //    "und": [
    //            {
    //                "sid": "2"
    //            },
    //            {
    //                "sid": "3"
    //            },
    //            {
    //                "sid": "1"
    //            }
    //    ]
    //}
    
    NSSet* medias = poi.media;
  
    if ([medias count])
    {
        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
        NSArray *sortedMedia = [[medias allObjects] sortedArrayUsingDescriptors:sortDescriptors];
        
        NSMutableArray *sidList = [NSMutableArray arrayWithCapacity:[sortedMedia count]];
        
        for (PoiMedia *media in sortedMedia)
        {
            [sidList addObject:[NSDictionary dictionaryWithObject:[media.sid copy] forKey:@"sid"]];
        }
        
        NSDictionary *fieldMediaDict = [NSDictionary dictionaryWithObject:sidList forKey:@"und"];
        [nodeData setValue:fieldMediaDict forKey:@"field_media_asset"];
    }
    else
    {
        DLog(@"Poi has no media to upload and/or embed, skip field_media_asset section");
    }
    
     
    NSArray *communities = [poi.communities allObjects];
    NSArray *categories = [poi.categories allObjects];
    NSArray *culturalProtocols = [poi.culturalProtocols allObjects];
    
    //communities and CPs
    //JSON format
    //"oggroup_fieldset": [
    //    {
    //        "dropdown_first": "2",            //communities
    //        "dropdown_second": ["3", "4"]     //cultural protocols
    //    }
    //]

    NSMutableArray *poiGroupsArrayRoot = [NSMutableArray array];
    
    for (PoiCommunity *community in communities)
    {
        NSMutableArray *culturalProtocolsNids = [NSMutableArray array];
        
        for (PoiCulturalProtocol *cp in culturalProtocols)
        {
            NSArray *childrenIds = self.currentGroupsTree[community.nid];
            
            if ([childrenIds containsObject:cp.nid])
            {
                [culturalProtocolsNids addObject:cp.nid];
            }
        }
        
        NSDictionary *groupsValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [community.nid copy], @"dropdown_first",
                                      culturalProtocolsNids, @"dropdown_second", nil];
        
        [poiGroupsArrayRoot addObject:groupsValues];
    }
    
    [nodeData setValue:poiGroupsArrayRoot forKey:@"oggroup_fieldset"];
    
    
    //categories
    //format "field_category":{"en":{"2":"2"}}
    NSMutableDictionary *categoriesTids = [NSMutableDictionary dictionary];
    
    for (NSManagedObject *category in categories)
        [categoriesTids setValue:[category valueForKey:@"tid"] forKey:[category valueForKey:@"tid"]];
    //[categoriesTids setValue:@"2" forKey:@"2"];
    
    NSDictionary *fieldCategoriesDict = [NSDictionary dictionaryWithObject:categoriesTids forKey:@"en"];
    [nodeData setValue:fieldCategoriesDict forKey:@"field_category"];
    
    //keywords (tags)
    NSMutableString *keywordList = [poi.keywordsString copy];
    DLog(@"Keyword list string for poi: %@",keywordList);
    
    //adding mukurtumobile tag if enabled in settings
    //default key for mukurtumobile default tag should be present, anyway defaults to on
    NSString *defaultKeyword = @"mukurtumobile";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:kPrefsMukurtuKeywordKey] &&
        ![defaults boolForKey:kPrefsMukurtuKeywordKey])
    {
        DLog(@"Removing mukurtumobile default tag");
        defaultKeyword = nil;
    }
    
    if ([defaultKeyword length] > 0)
    {
        if ([keywordList length] >0)
            keywordList = [NSMutableString stringWithFormat:@"%@;%@",keywordList,defaultKeyword];
        else
            keywordList = [NSMutableString stringWithString:defaultKeyword];
    }
    
    if ([keywordList length] > 0)
    {
        NSDictionary *fieldKeywordDict = [NSDictionary dictionaryWithObject:keywordList forKey:@"en"];
        [nodeData setValue:fieldKeywordDict forKey:@"field_tags"];
    }
    
    
    //creator
    //format "field_creator":{"und":"CreatorName"}
    if (poi.creator != nil &&
        [poi.creator length] > 0)
    {
        NSDictionary *fieldCreatorDict = [NSDictionary dictionaryWithObject:[poi.creator description] forKey:@"und"];
        [nodeData setValue:fieldCreatorDict forKey:@"field_creator"];
    }
    else
    {
        DLog(@"poi upload error: no creator found");
        
        //        [self.toKeepPoiList addObject:poi];
        //        [self markPoiUploadFinished];
        return nil;
    }
    
    
    //contributor (optional)
    //format "field_contributor":{"und":"ContributorName"}
    if (poi.contributor != nil &&
        [poi.contributor length] > 0)
    {
        NSDictionary *fieldContributorDict = [NSDictionary dictionaryWithObject:[poi.contributor description] forKey:@"und"];
        [nodeData setValue:fieldContributorDict forKey:@"field_contributor"];
    }
    
    //creationDate
    //format "field_date":{"und":[{"value":"yyyy-mm-dd"}]}
    //string date has priority
    if (poi.creationDateString != nil &&
        [poi.creationDateString length])
    {
        NSString *dateString = [poi.creationDateString description];
        
        NSArray *creationDateArray = [NSArray arrayWithObject:
                                      [NSDictionary dictionaryWithObject:dateString forKey:@"value"]];
        NSDictionary *fieldDateDict = [NSDictionary dictionaryWithObject:creationDateArray forKey:@"und"];
        [nodeData setValue:fieldDateDict forKey:@"field_date"];
    }
    else
        if (poi.creationDate != nil &&
            [poi.creationDate isKindOfClass:[NSDate class]])
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            NSString *dateString = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:poi.creationDate]];
            
            NSArray *creationDateArray = [NSArray arrayWithObject:
                                          [NSDictionary dictionaryWithObject:dateString forKey:@"value"]];
            NSDictionary *fieldDateDict = [NSDictionary dictionaryWithObject:creationDateArray forKey:@"und"];
            [nodeData setValue:fieldDateDict forKey:@"field_date"];
        }
        else
        {
            DLog(@"poi upload error: invalid creation date found");
            return nil;
        }
    
    //description
    //format "field_description":{"und":[{"value":"description text","format":"plain_text"}]}
    if (poi.longdescription != nil && [poi.longdescription length] > 0)
    {
        NSString *descriptionString = [poi.longdescription description];

        NSArray *descriptionArray = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObject:descriptionString forKey:@"value"], [NSDictionary dictionaryWithObject:@"format" forKey:@"filtered_html"], nil];
        
        NSDictionary *fieldDescriptionDict = [NSDictionary dictionaryWithObject:descriptionArray forKey:@"und"];
        [nodeData setValue:fieldDescriptionDict forKey:@"field_description"];
    }
    
    //cultural narrative (aka body)
    //format "body":{"und":[{"value":"cultural narrative text"}]}
    if (poi.culturalNarrative != nil && [poi.culturalNarrative length] > 0)
    {
        NSString *culturalNarrativeString = [poi.culturalNarrative description];
        
        NSArray *culturalNarrativeArray = [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:culturalNarrativeString forKey:@"value"]];
        
        NSDictionary *fieldCultDict = [NSDictionary dictionaryWithObject:culturalNarrativeArray forKey:@"und"];
        [nodeData setValue:fieldCultDict forKey:@"body"];
    }
    
    //location coordinates
    if (poi.locationLat.length > 0 && poi.locationLong.length > 0 &&
        !([poi.locationLat doubleValue] == 0.0 && [poi.locationLong doubleValue] == 0.0)) //don't include location for lat:0.0, lon:0.0 (probably invalid)
    {
        NSString *latitude = [poi.locationLat copy];
        NSString *longitude = [poi.locationLong copy];
        
        NSDictionary *locationDict =  [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObjectsAndKeys: latitude, @"lat",longitude, @"lon", nil]
                                                                  forKey: @"geom"];
        
        NSDictionary * fieldCoverageDict = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:locationDict] forKey:@"und"];
        [nodeData setValue:fieldCoverageDict forKey:@"field_coverage"];
    }
    
    //address
    //format "field_coverage_description":{"und":[{"value":"via della minchia"}]}
    if ([poi.formattedAddress length] > 0)
    {
        NSString *formattedAddress = [poi.formattedAddress copy];
        NSDictionary *addrDictionary = [NSDictionary dictionaryWithObject:formattedAddress forKey:@"value"];
        
        NSDictionary *fieldCoverageDescDict = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:addrDictionary] forKey:@"und"];
        
        [nodeData setValue:fieldCoverageDescDict forKey:@"field_coverage_description"];
    }
    
    
    DLog(@"Forging poi JSON for poi %@ completed", poi.title);
    //DLog(@"Node details for poi %@:\n%@", poi.title, [nodeData description]);
    
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:nodeData options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    DLog(@"JSON object:\n%@", jsonString);
    
    return [NSDictionary dictionaryWithDictionary:nodeData];
}

-(NSDictionary *)buildLegacyNodeDictionaryForPoi:(Poi *)poi
{
    NSMutableDictionary *nodeData = [NSMutableDictionary dictionary];
    
    //initi node dictionary
    [nodeData setValue:poi.title forKey:@"title"];
    
    
    //set type
    [nodeData setValue:@"digital_heritage" forKey:@"type"];
    
    //set language (FIXME default to en by now)
    [nodeData setValue:@"en" forKey:@"language"];
    
    
    //authoring date (for content, different from digital heritage creation date)
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    NSString *dateAuthoringString = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:poi.timestamp]];
    [nodeData setValue:dateAuthoringString forKey:@"date"];
    
    
    //poi medias should all have valid fids here
    //NSSet* media = [[NSSet alloc] initWithSet:[poi mutableSetValueForKey:@"media"]];
    NSSet* medias = poi.media;
    
    NSMutableArray *videoIdsToEmbed = [NSMutableArray array];
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *sortedMedia = [[medias allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    
    //format "field_media":{"und":[{"fid":"1","_weight":"0"},{"fid":"13","_weight":"1"}]}
    NSMutableArray *fidList = [NSMutableArray arrayWithCapacity:[sortedMedia count]];
    int weightCounter = 0;
    
    
    NSPredicate *predicatePhoto = [NSPredicate predicateWithFormat:@"type == %@", @"photo" ];
    NSArray *poiImages = [[[medias filteredSetUsingPredicate:predicatePhoto] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    
    NSPredicate *predicateVideo = [NSPredicate predicateWithFormat:@"type == %@", @"video" ];
    NSArray *poiVideos = [[[medias filteredSetUsingPredicate:predicateVideo] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    
    NSPredicate *predicateAudio = [NSPredicate predicateWithFormat:@"type == %@", @"audio" ];
    NSArray *poiAudios = [[[medias filteredSetUsingPredicate:predicateAudio] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    
    
    DLog(@"Poi has %lu Images to upload", (unsigned long)[poiImages count]);
    if ([poiImages count])
    {
        //we have images, put them first
        for (PoiMedia *media in poiImages)
        {
            [fidList addObject:[media.key copy]];
        }
    }
    
    DLog(@"Poi has %lu Videos to upload", (unsigned long)[poiVideos count]);
    if ([poiVideos count])
    {
        //we have videos, put them after images
        for (PoiMedia *media in poiVideos)
        {
            NSString *mediaFid = [media.key copy];
            NSArray *mediaFidComponents = [mediaFid componentsSeparatedByString:@","];
            
            if ([mediaFidComponents count] > 1)
            {
                //media should be a video, we have first component containing video thumbnail fid, second component containing video id
                mediaFid = mediaFidComponents[0];
                
                //save video id for adding later as embedded object in content description
                [videoIdsToEmbed addObject:mediaFidComponents[1]];
            }
            
            if (![poiImages count] &&
                ![mediaFid isEqualToString:kDummyVideoThumbnailFid])
            {
                DLog(@"Poi has no images, adding video big thumbnail placeholder as first media for icon in mukurtu browse view");
                [fidList addObject:mediaFid];
            }
            else
            {
                DLog(@"Poi has %lu images and video thumbnail fid is %@, just embed video without creating placeholder", (unsigned long)[poiImages count], mediaFid);
            }
        }
        
        DLog(@"Final videosToEmbed youtube id list is: %@",[videoIdsToEmbed description]);
    }
    
    
    DLog(@"Poi has %lu Audio to upload", (unsigned long)[poiAudios count]);
    if ([poiAudios count])
    {
        //we have audios, put them at bottom of the media list
        for (PoiMedia *media in poiAudios)
        {
            [fidList addObject:[media.key copy]];
        }
    }
    
    if ([sortedMedia count])
    {
        NSMutableArray *fileList = [NSMutableArray array];
        
        for (NSString *fid in fidList)
        {
            
            NSDictionary *fidElement = [NSDictionary
                                        dictionaryWithObjects:[NSArray
                                                               arrayWithObjects:
                                                               fid,
                                                               [NSString stringWithFormat:@"%d", weightCounter], nil]
                                        forKeys:[NSArray arrayWithObjects: @"fid",@"__weight",nil]];
            [fileList addObject:fidElement];
            
            weightCounter++;
        }
        
        NSDictionary *fieldMediaDict = [NSDictionary dictionaryWithObject:fileList forKey:@"und"];
        [nodeData setValue:fieldMediaDict forKey:@"field_media"];
    }
    else
    {
        DLog(@"Poi has no media to upload and/or embed, skip field_media section");
    }
    
    
    NSArray *communities = [poi.communities allObjects];
    NSArray *categories = [poi.categories allObjects];
    NSArray *culturalProtocols = [poi.culturalProtocols allObjects];
    
    //communities are optional
    if ([communities count])
    {
        //JSON format "field_communities":{"en":["12"]}
        NSMutableArray *communitiesNids = [NSMutableArray array];
        for (NSManagedObject *community in communities)
            [communitiesNids addObject:[[community valueForKey:@"nid"] description]];
        
        NSDictionary *fieldCommunitiesDict = [NSDictionary dictionaryWithObject:communitiesNids forKey:@"en"];
        [nodeData setValue:fieldCommunitiesDict forKey:@"field_communities"];
    }
    
    //cultural protocols
    //JSON format "field_culturalprotocol":{"en":["2"]}
    NSMutableArray *culturalProtocolsNids = [NSMutableArray array];
    for (NSManagedObject *culturalProtocol in culturalProtocols)
        [culturalProtocolsNids addObject:[[culturalProtocol valueForKey:@"nid"] description]];
    
    NSDictionary *fieldCulturalProtocolsDict = [NSDictionary dictionaryWithObject:culturalProtocolsNids forKey:@"en"];
    [nodeData setValue:fieldCulturalProtocolsDict forKey:@"field_culturalprotocol"];
    
    
    
    //categories
    //format "field_category":{"en":{"2":"2"}}
    NSMutableDictionary *categoriesTids = [NSMutableDictionary dictionary];
    
    for (NSManagedObject *category in categories)
        [categoriesTids setValue:[category valueForKey:@"tid"] forKey:[category valueForKey:@"tid"]];
    //[categoriesTids setValue:@"2" forKey:@"2"];
    
    NSDictionary *fieldCategoriesDict = [NSDictionary dictionaryWithObject:categoriesTids forKey:@"en"];
    [nodeData setValue:fieldCategoriesDict forKey:@"field_category"];
    
    
    NSMutableString *keywordList = [poi.keywordsString copy];
    DLog(@"Keyword list string for poi: %@",keywordList);
    
    //adding mukurtumobile tag if enabled in settings
    //default key for mukurtumobile default tag should be present, anyway defaults to on
    NSString *defaultKeyword = @"mukurtumobile";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:kPrefsMukurtuKeywordKey] &&
        ![defaults boolForKey:kPrefsMukurtuKeywordKey])
    {
        DLog(@"Removing mukurtumobile default tag");
        defaultKeyword = nil;
    }
    
    if ([defaultKeyword length] > 0)
    {
        if ([keywordList length] >0)
            keywordList = [NSMutableString stringWithFormat:@"%@,%@",keywordList,defaultKeyword];
        else
            keywordList = [NSMutableString stringWithString:defaultKeyword];
    }
    
    if ([keywordList length] > 0)
    {
        NSDictionary *fieldKeywordDict = [NSDictionary dictionaryWithObject:keywordList forKey:@"en"];
        [nodeData setValue:fieldKeywordDict forKey:@"field_tags"];
    }
    
    //content access
    //format "group_content_access":{"und":"1"}
#warning forcing sharing protocol 0
    poi.sharingProtocol = [NSNumber numberWithInt:kMukurtuSharingProtocolDefault];
    
    if (poi.sharingProtocol != nil &&
        [poi.sharingProtocol intValue] >= 0 &&
        [poi.sharingProtocol intValue] < 3)
    {
        NSString *sharingProtocolString = [NSString stringWithFormat:@"%d", [poi.sharingProtocol intValue]];
        NSDictionary *fieldContentAccessDict = [NSDictionary dictionaryWithObject:sharingProtocolString forKey:@"und"];
        [nodeData setValue:fieldContentAccessDict forKey:@"group_content_access"];
    }
    else
    {
        DLog(@"poi upload error: no valid sharing protocol found");
        
        //        [self.toKeepPoiList addObject:poi];
        //        [self markPoiUploadFinished];
        return nil;
    }
    
    //creator
    //format "field_creator":{"und":"CreatorName"}
    if (poi.creator != nil &&
        [poi.creator length] > 0)
    {
        NSDictionary *fieldCreatorDict = [NSDictionary dictionaryWithObject:[poi.creator description] forKey:@"und"];
        [nodeData setValue:fieldCreatorDict forKey:@"field_creator"];
    }
    else
    {
        DLog(@"poi upload error: no creator found");
        
        //        [self.toKeepPoiList addObject:poi];
        //        [self markPoiUploadFinished];
        return nil;
    }
    
    
    //contributor (optional)
    //format "field_contributor":{"und":"ContributorName"}
    if (poi.contributor != nil &&
        [poi.contributor length] > 0)
    {
        NSDictionary *fieldContributorDict = [NSDictionary dictionaryWithObject:[poi.contributor description] forKey:@"und"];
        [nodeData setValue:fieldContributorDict forKey:@"field_contributor"];
    }
    
    //creationDate
    //format "field_date":{"und":[{"value":"yyyy-mm-dd"}]}
    //string date has priority
    if (poi.creationDateString != nil &&
        [poi.creationDateString length])
    {
        NSString *dateString = [poi.creationDateString description];
        
        NSArray *creationDateArray = [NSArray arrayWithObject:
                                      [NSDictionary dictionaryWithObject:dateString forKey:@"value"]];
        NSDictionary *fieldDateDict = [NSDictionary dictionaryWithObject:creationDateArray forKey:@"und"];
        [nodeData setValue:fieldDateDict forKey:@"field_date"];
    }
    else
        if (poi.creationDate != nil &&
            [poi.creationDate isKindOfClass:[NSDate class]])
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            NSString *dateString = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:poi.creationDate]];
            
            NSArray *creationDateArray = [NSArray arrayWithObject:
                                          [NSDictionary dictionaryWithObject:dateString forKey:@"value"]];
            NSDictionary *fieldDateDict = [NSDictionary dictionaryWithObject:creationDateArray forKey:@"und"];
            [nodeData setValue:fieldDateDict forKey:@"field_date"];
        }
        else
        {
            DLog(@"poi upload error: invalid creation date found");
            return nil;
        }
    
    //description
    //format "field_description":{"und":[{"value":"description text","format":"plain_text"}]}
    //should contain embedded videos then any poi description if present
    
    //should initialize strings to avoid garbage in description text when combining strings
    NSString *descriptionEmbeddedVideos = @"";
    NSString *descriptionString = @"";
    
    if ([videoIdsToEmbed count] > 0)
    {
        //We have some videos to embed
        for (NSString *videoId in videoIdsToEmbed)
        {
            NSString *embeddedVideoString = [NSString stringWithFormat:@"<iframe width='420' height='315' src='//www.youtube-nocookie.com/embed/%@' frameborder='0' allowfullscreen></iframe> <br/>",videoId];
            DLog(@"New video embed string: %@", embeddedVideoString);
            
            NSString *addedVideoEmbedString = [descriptionEmbeddedVideos stringByAppendingString:embeddedVideoString];
            descriptionEmbeddedVideos = addedVideoEmbedString;
        }
        
        //DLog(@"description embedded videos is %@", descriptionEmbeddedVideos);
    }
    
    if (poi.longdescription != nil &&
        [poi.longdescription length] > 0)
    {
        descriptionString = [poi.longdescription description];
        
    }
    
    if ([descriptionEmbeddedVideos length] > 0 || [descriptionString length] > 0)
    {
        NSString *combinedDescription = [NSString stringWithFormat:@"%@%@", descriptionEmbeddedVideos, descriptionString];
        
        NSArray *descriptionArray = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObject:combinedDescription forKey:@"value"], [NSDictionary dictionaryWithObject:@"format" forKey:@"full_html"], nil];
        
        NSDictionary *fieldDescriptionDict = [NSDictionary dictionaryWithObject:descriptionArray forKey:@"und"];
        [nodeData setValue:fieldDescriptionDict forKey:@"field_description"];
    }
    
    //cultural narrative (aka body)
    //format "body":{"und":[{"value":"cultural narrative text"}]}
    if (poi.culturalNarrative != nil &&
        [poi.culturalNarrative length] > 0)
    {
        NSString *culturalNarrativeString = [poi.culturalNarrative description];
        
        NSArray *culturalNarrativeArray = [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:culturalNarrativeString forKey:@"value"]];
        
        NSDictionary *fieldCultDict = [NSDictionary dictionaryWithObject:culturalNarrativeArray forKey:@"und"];
        [nodeData setValue:fieldCultDict forKey:@"body"];
    }
    
    //location coordinates
    //format "field_coverage":{"und":[{"wkt":"POINT (11 45)","geo_type":"point","lat":"45","lon":"11","left":"11","right":"11","bottom":"45","top":"45","master_column":"latlon"}]}
    
    if (poi.locationLat.length > 0 && poi.locationLong.length > 0)
    {
        NSString *latitude = [poi.locationLat copy];
        NSString *longitude = [poi.locationLong copy];
        
        NSDictionary *locationDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"POINT (%@ %@)", longitude, latitude],@"point",latitude,longitude,longitude,longitude,latitude,latitude, @"latlon", nil] forKeys:[NSArray arrayWithObjects:@"wkt",@"geo_type",@"lat",@"lon",@"left",@"right",@"bottom",@"top",@"master_column", nil]];
        
        NSDictionary * fieldCoverageDict = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:locationDict] forKey:@"und"];
        [nodeData setValue:fieldCoverageDict forKey:@"field_coverage"];
    }
    
    //address
    //format "field_coverage_description":{"und":[{"value":"via della minchia"}]}
    if ([poi.formattedAddress length] > 0)
    {
        NSString *formattedAddress = [poi.formattedAddress copy];
        NSDictionary *addrDictionary = [NSDictionary dictionaryWithObject:formattedAddress forKey:@"value"];
        
        NSDictionary *fieldCoverageDescDict = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:addrDictionary] forKey:@"und"];
        
        [nodeData setValue:fieldCoverageDescDict forKey:@"field_coverage_description"];
    }
    DLog(@"Forging poi JSON for poi %@ completed", poi.title);
    
    //DLog(@"Node details for poi %@:\n%@", poi.title, [nodeData description]);
    
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:nodeData options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    DLog(@"JSON object:\n%@", jsonString);
    
    return [NSDictionary dictionaryWithDictionary:nodeData];
}


-(void)addLocalKeyword:(NSString *)localKeyword
{
    DLog(@"Add keyword %@ if not present", localKeyword);
    
    PoiKeyword *newKeyword = [PoiKeyword MR_findFirstByAttribute:@"name" withValue:localKeyword];
    
    if (newKeyword == nil)
    {
        //new keyword, create a local stub object
        DLog(@"Adding keyword %@", localKeyword);

        PoiKeyword *poiKeyword = [PoiKeyword MR_createEntity];
        poiKeyword.name = [localKeyword  copy];
        poiKeyword.tid = @"0";
        poiKeyword.uri = @"";
    
        //should save core data context after adding local keyword (will be done later by save poi)
    }
    else
    {
        DLog(@"Keyword %@ already present", localKeyword);
    }
}


////Alerts
- (void) showConnectionErrorForErrorCode:(NSInteger)errorCode
{
    //check for host unreachable or not found
    if (errorCode == -1003 || errorCode == -1009)
        [self showNetworkErrorAlert];
    else
        [self showInvalidCredentialsAlert];

}

- (void) showInvalidCredentialsAlert
{
    //ignore alert if canceling
    if (_cancelingSync)
        return;
    
    NSString *message = @"Please provide a valid username, password and base URL for your Mukurtu CMS instance.";
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    
    
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //if (![defaults boolForKey:kMukurtuMetadataMustUpdateKey])
    //    [alertView addButtonWithTitle:@"Cancel"];
    
    [alertView show];
}

- (void) showNetworkErrorAlert
{
    //ignore alert if canceling
    if (_cancelingSync)
        return;
    
    NSString *message = @"Your Mukurtu instance is not reachable now. Check base URL and your Internet connection and retry.";
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error!" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //if (![defaults boolForKey:kMukurtuMetadataMustUpdateKey])
    //    [alertView addButtonWithTitle:@"Cancel"];
    
    [alertView show];
}



@end
