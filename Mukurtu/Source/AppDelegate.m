//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import "MukurtuSession.h"
#import "MainIpadViewController.h"
#import "SplashScreenViewController.h"

#import "PDKeychainBindings.h"


@interface AppDelegate()
{
    BOOL _forceLoginView;
    BOOL _forceYouTubeLoginView;
}

@end

@implementation AppDelegate

@synthesize forceLoginView = _forceLoginView;
@synthesize forceYouTubeLoginView = _forceYouTubeLoginView;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    DLog(@"App Major Version 2.5");
    
    //store Major version lock to remove DB in old versions at first launch
    PDKeychainBindings *bindings=[PDKeychainBindings sharedKeychainBindings];
    NSString *appVersion = [[bindings objectForKey:kMukurtuAccountKeychainAppMajorVersion] copy];
    
    if ([appVersion length] && [appVersion isEqualToString:@"2.5"])
    {
        DLog(@"Version 2.5 already run on this device, keep old DB");
    }
    else
    {
        DLog(@"Version 2.5 never run on this device, wipe old db and data if any");
        
        //store lock tag for this major version in keychain
        [bindings setObject:@"2.5" forKey:kMukurtuAccountKeychainAppMajorVersion];
   
        NSURL *oldDBUrl = [NSPersistentStore MR_urlForStoreName:[MagicalRecord defaultStoreName]];
        DLog(@"Old DB URL %@", [oldDBUrl description]);
        
        NSError *error;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[oldDBUrl path]])
        {
            DLog(@"Deleting old DB file: \n%@", [oldDBUrl path]);
            if ([[NSFileManager defaultManager] removeItemAtURL:oldDBUrl error:&error])
            {
                DLog(@"Old DB file succesfully removed");
            }
            else
            {
                DLog(@"Error: Could not remove old DB file");
                DLog(@"result: %@", [error description]);
            }
        }
        
        DLog(@"Resetting stored credentials if any");
        [bindings setObject:@"" forKey:kMukurtuAccountKeychainUsername];
        
        [bindings setObject:@"" forKey:kMukurtuAccountKeychainPassword];
        
        [bindings setObject:@"" forKey:kMukurtuAccountKeychainCMSVersion];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@"" forKey:kMukurtuBaseUrlKey];
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:kMukurtuStoredLoggedInStatus];
        [defaults synchronize];
        
        //TODO: could remove all documents files here
    }
    
    DLog(@"Setup Core Data stack");
    [MagicalRecord setupCoreDataStack];
    
    MukurtuSession *sharedSession = [MukurtuSession sharedSession];
    
    if (!sharedSession.userIsLoggedIn)
    {
        DLog(@"User is not logged in, forcing login view");
        _forceLoginView = YES;
    }
    
    _forceYouTubeLoginView = NO;
    
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}


#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
