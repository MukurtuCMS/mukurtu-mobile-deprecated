//
//  YouTubeHelper.h
//  YouTube_iOS_API_Sample
//
//  Customized sample code based on tutorial
//  https://nsrover.wordpress.com/2014/04/23/youtube-api-on-ios/
//  by Nirbhay Agarwal

#import <Foundation/Foundation.h>

#import "GTLYouTube.h"
#import "GTMOAuth2ViewControllerTouch.h"

@class PoiMedia;

/*---------------- YoutubeHelper Delegate ----------------*/

@protocol YouTubeHelperDelegate <NSObject>

@required

- (NSString *)youtubeAPIClientID;
- (NSString *)youtubeAPIClientSecret;
- (void)showAuthenticationViewController:(UIViewController *)authView;
- (void)authenticationEndedWithError:(NSError *)error;

- (void) uploadDoneForMedia:(PoiMedia *)media withVideoId:(NSString *)videoId andError:(NSError *)error;

@optional

- (void)uploadedVideosPlaylist:(NSArray *)array;
- (void)uploadProgressPercentage:(int)percentage;

@end

/*---------------- YoutubeHelper ----------------*/

@interface YouTubeHelper : NSObject

@property (weak) id <YouTubeHelperDelegate> delegate;

//Initialization function
- (id)initWithDelegate:(id <YouTubeHelperDelegate>)delegate;

//User authentication
- (void)authenticate;

//Delete stored auth object from keychain
- (void)signOut;

//Get a list of videos uploaded by user
- (void)getUploadedPlaylist;

- (void)uploadVideoWithTitle:(NSString *)title description:(NSString *)description commaSeperatedTags:(NSString *)tags andMedia:(PoiMedia *)media;

- (void)cancelAllCurrentUploads;

- (BOOL)isAuthValid;

- (NSString *)getLoggedUserEmail;

@end
