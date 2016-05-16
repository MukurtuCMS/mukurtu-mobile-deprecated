//
//  MukurtuSession.h
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

#import <Foundation/Foundation.h>

#import "YouTubeHelper.h"

@class Poi;
@class PoiMedia;

@protocol YouTubeStatusReportDelegate <NSObject>
- (void) reportLoginError:(NSError *)error;

@end

@interface MukurtuSession : NSObject <YouTubeHelperDelegate>

@property (nonatomic, strong) NSArray *currentCommunities;
@property (nonatomic, strong) NSArray *currentCulturalProtocols;
@property (nonatomic, strong) NSArray *currentCategories;
@property (assign, nonatomic, readonly) BOOL userIsLoggedIn;

@property (copy, nonatomic)NSString *storedUsername;
@property (copy, nonatomic)NSString *storedPassword;
@property (copy, nonatomic)NSString *storedBaseUrl;

@property (copy, nonatomic)NSString *storedBaseUrlCMSVersion;

@property (assign, readonly, nonatomic) BOOL lastLoginSuccess;
@property (assign, readonly, nonatomic) BOOL lastSyncSuccess;

@property (assign, readonly, nonatomic) BOOL lastCulturalProtocolsSyncSuccess;
@property (assign, readonly, nonatomic) BOOL lastCommunitiesSyncSuccess;
@property (assign, readonly, nonatomic) BOOL lastCategoriesSyncSuccess;
@property (assign, readonly, nonatomic) BOOL lastKeywordsSyncSuccess;
@property (assign, readonly, nonatomic) BOOL lastContributorsSyncSuccess;
@property (assign, readonly, nonatomic) BOOL lastCreatorsSyncSuccess;


@property (assign, readonly, nonatomic) BOOL serverCMSVersion1;

@property (nonatomic, strong) NSMutableArray *uploadedPoiList;

@property (weak, nonatomic) NSObject *currentSessionDelegate;
@property (assign, nonatomic) SEL currentSessionSelector;

@property (weak, nonatomic) UINavigationController *youTubeSettingsNavigationController;

//support for Open groups hierarchy
@property (strong, nonatomic) NSDictionary *currentGroupsTree;

//youtube helper as singleton component
@property (strong, nonatomic) YouTubeHelper *youTubeHelper;
@property (weak, nonatomic) id<YouTubeStatusReportDelegate> youTubeStatusReportDelegate;

+ (MukurtuSession*) sharedSession;

- (BOOL)isBaseUrlReachable;
- (void)resetClientReachabilityTest;

- (void)setCurrentGroups;
- (void) updateAllGroupsFromRemoteServer;

- (void)loginNewSession;
- (void)loginNewSessionForController:(NSObject *)delegate confirmSelector:(SEL)selector;

- (void)logoutUserAndRemovePois;
- (void)logoutAndRemovePoisForController:(NSObject *)delegate confirmSelector:(SEL)selector;

- (void)startMetadataSyncFromDelegate:(NSObject *)delegate confirmSelector:(SEL)selector;
- (void)cancelMetadataSync;

- (void) validateAllPois;
- (BOOL) uploadNeedsYouTubeButNoLogin;
- (void) resetAllInvalidPoisForVideosAndValidate;

- (void) startUploadJobFromDelegate:(NSObject *)delegate;

- (void)setDemoLogin;
- (BOOL)isUsingDemoUser;
- (void)cancelUpload;

-(void)addLocalKeyword:(NSString *)localKeyword;

@end
