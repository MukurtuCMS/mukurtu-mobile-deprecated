//
//  YouTubeHelper.m
//  YouTube_iOS_API_Sample
//
//  Customized sample code based on tutorial
//  https://nsrover.wordpress.com/2014/04/23/youtube-api-on-ios/
//  by Nirbhay Agarwal

#import "YouTubeHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "GTMHTTPUploadFetcher.h"

#import "PoiMedia.h"

@interface YouTubeHelper ()

@property (strong) GTLServiceYouTube *youTubeService;

@property (strong) GTLServiceTicket *channelListTicket;
@property (strong) GTLYouTubeChannelContentDetailsRelatedPlaylists *playlists;
@property (strong) GTLServiceTicket *playlistItemListTicket;
@property (strong) GTLYouTubePlaylistItemListResponse *playlistItemList;


//@property (strong) GTLServiceTicket *uploadFileTicket;

@property (strong) NSMutableArray *uploadFileTickets;

//@property (strong) NSString* videoTitle;
//@property (strong) NSString* videoDescription;
//@property (strong) NSString* videoTags;
//@property (strong) NSString* videoPath;

@property (strong) NSString* clientID;
@property (strong) NSString* clientSecret;

@end

static NSString* kKeychainItemName = @"MukurtuYouTubeToken";

@implementation YouTubeHelper

#pragma mark Initialization

- (id)initWithDelegate:(id <YouTubeHelperDelegate>)delegate {
    self = [super init];
    
    self.delegate = delegate;
    [self initYoutubeService];
    
    self.uploadFileTickets = [NSMutableArray array];
    
    return self;
}

- (id)init {
    DLog(@"YouTubeHelper: Use the initWithDelegate: method instead of init");
    return nil;
}

#pragma mark Public

- (void)authenticate {
    //Get auth object from keychain if available
    [self storedAuth];
    
    //Check if auth was valid
    if (![self isAuthValid]) {
        if ([self hasViewController]) {
            [self showOAuthSignInView];
        }
    }
    else
        DLog(@"Stored token found, already autheticated");
}

- (void)signOut {
    DLog(@"Signing out...");
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
}

- (void)getUploadedPlaylist {
    
    if ([self isAuthValid]) {
        [self getChannelList];
    }
    else
    {
        DLog(@"YouTubeHelper: User not authenticated yet.");
    }
}


#pragma mark Misk Tasks

- (BOOL)hasViewController {
    if (_delegate && [_delegate respondsToSelector:@selector(showAuthenticationViewController:)])
    {
        return YES;
    }
    return NO;
}

- (void)returnUploadedPlaylist {
    if (_delegate && [_delegate respondsToSelector:@selector(uploadedVideosPlaylist:)]) {
        [_delegate uploadedVideosPlaylist:_playlistItemList.items];
    }
}

- (NSString *)MIMETypeForFilename:(NSString *)filename
                  defaultMIMEType:(NSString *)defaultType {
    NSString *result = defaultType;
    NSString *extension = [filename pathExtension];
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)extension, NULL);
    if (uti) {
        CFStringRef cfMIMEType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
        if (cfMIMEType) {
            result = CFBridgingRelease(cfMIMEType);
        }
        CFRelease(uti);
    }
    return result;
}

- (BOOL)isAuthValid {
    
    [self storedAuth];
    
    if (!((GTMOAuth2Authentication *)_youTubeService.authorizer).canAuthorize) {
        return NO;
    }
    return YES;
}

- (NSString *)getLoggedUserEmail
{
    NSString *email = @"";
    
    if (((GTMOAuth2Authentication *)_youTubeService.authorizer).canAuthorize)
    {
        email = [(GTMOAuth2Authentication *)_youTubeService.authorizer.userEmail copy];
    }
    
    return  email;
}

#pragma mark Tasks

- (BOOL)initYoutubeService {
    
    self.youTubeService = [[GTLServiceYouTube alloc] init];
    _youTubeService.shouldFetchNextPages = YES;
    _youTubeService.retryEnabled = YES;
    
#warning should test shouldFetchInBackground flag to enable background uploads
    //enable backround uploads
    _youTubeService.shouldFetchInBackground = YES;
    
    //Client id
    if (_delegate && [_delegate respondsToSelector:@selector(youtubeAPIClientID)]) {
        self.clientID = [_delegate youtubeAPIClientID];
    }
    else
    {
        DLog(@"YouTube Helper: Client ID not provided, please implement the required delegate method");
    }
    
    //Client Secret
    if (_delegate && [_delegate respondsToSelector:@selector(youtubeAPIClientSecret)]) {
        self.clientSecret = [_delegate youtubeAPIClientSecret];
    }
    else
    {
        DLog(@"YouTube Helper: Client Secret not provided, please implement the required delegate method");
    }
    
    return YES;
}

- (void)storedAuth {
    _youTubeService.authorizer =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                       clientID:_clientID
                                                      clientSecret:_clientSecret];
}

- (void)showOAuthSignInView {
    // Show the OAuth 2 sign-in controller.
    GTMOAuth2ViewControllerTouch *viewController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeYouTube
                                                                                               clientID:_clientID
                                                                                           clientSecret:_clientSecret
                                                                                       keychainItemName:kKeychainItemName
                                                                                              delegate:self
                                                                                      finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    [_delegate showAuthenticationViewController:viewController];
//    [_currentViewController presentViewController:viewController animated:YES completion:nil];
//    [_currentViewController.navigationController pushViewController:viewController animated:YES];
}

- (void)getChannelList {
    self.playlists = nil;
    
    GTLServiceYouTube *service = self.youTubeService;
    
    GTLQueryYouTube *query = [GTLQueryYouTube queryForChannelsListWithPart:@"contentDetails"];
    query.mine = YES;
    query.maxResults = 50;
    // query.fields = @"kind,etag,items(id,etag,kind,contentDetails)";
    
    self.channelListTicket = [service executeQuery:query
                             completionHandler:^(GTLServiceTicket *ticket,
                                                 GTLYouTubeChannelListResponse *channelList,
                                                 NSError *error) {
                                 if ([[channelList items] count] > 0) {
                                     GTLYouTubeChannel *channel = channelList[0];
                                     DLog(@"channel n %lu", (unsigned long)[[channelList items] count]);
                                     self.playlists = channel.contentDetails.relatedPlaylists;
                                 }
                                 
                                 if (_playlists) {
                                     [self getPlaylist];
                                 }
                                 else
                                 {
                                     DLog(@"Unable to get channels info error %@", [error description]);
                                 }
                             }];
}

- (void)getPlaylist {
    NSString *playlistID = _playlists.uploads;
    
    if ([playlistID length] > 0) {
        GTLServiceYouTube *service = self.youTubeService;
        
        GTLQueryYouTube *query = [GTLQueryYouTube queryForPlaylistItemsListWithPart:@"snippet,contentDetails"];
        query.playlistId = playlistID;
        query.maxResults = 50;
        
        self.playlistItemListTicket = [service executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLYouTubePlaylistItemListResponse *playlistItemList,
                                                          NSError *error) {
                                          // Callback
                                          self.playlistItemList = playlistItemList;
                                          
                                          [self returnUploadedPlaylist];
                                      }];
    }
    else
    {
        self.playlists = nil;
    }
}

/*
- (void)prepareUploadVideo {
    
    // Status.
    GTLYouTubeVideoStatus *status = [GTLYouTubeVideoStatus object];
    //status.privacyStatus = @"private";
   
#warning fix unlisted video flag based on settings
    status.privacyStatus = @"unlisted";
    
    // Snippet.
    GTLYouTubeVideoSnippet *snippet = [GTLYouTubeVideoSnippet object];
    snippet.title = _videoTitle;
    if ([_videoDescription length] > 0) {
        snippet.descriptionProperty = _videoDescription;
    }
    if ([_videoTags length] > 0) {
        snippet.tags = [_videoTags componentsSeparatedByString:@","];
    }
//    if ([_uploadCategoryPopup isEnabled]) {
//        NSMenuItem *selectedCategory = [_uploadCategoryPopup selectedItem];
//        snippet.categoryId = [selectedCategory representedObject];
//    }
    
    GTLYouTubeVideo *video = [GTLYouTubeVideo object];
    video.status = status;
    video.snippet = snippet;
    
    [self uploadVideoWithVideoObject:video
             resumeUploadLocationURL:nil];
}
 */


- (void)uploadVideoWithTitle:(NSString *)title description:(NSString *)description commaSeperatedTags:(NSString *)tags andMedia:(PoiMedia *)media
{
    
    if (![self isAuthValid]) {
        DLog(@"YouTubeHelper: User not authenticated yet.");
        return;
    }
    
    if (!title) {
        DLog(@"Title missing");
        return;
    }
    
    if (!media) {
        DLog(@"PoiMedia missing");
        return;
    }
    
    if (!media.path) {
        DLog(@"Video path missing");
        return;
    }
    
    //[self prepareUploadVideo];
    
    
    //Video metadata
    // Status.
    GTLYouTubeVideoStatus *status = [GTLYouTubeVideoStatus object];
    //status.privacyStatus = @"private";
    
    //default key for unlisted should be present, anyway defaults to unlisted video
    NSString *privacyStatus = @"unlisted";

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                            
    if ([defaults objectForKey:kPrefsUnlistedVideoKey] &&
        ![defaults boolForKey:kPrefsUnlistedVideoKey])
    {
        DLog(@"setting video privacy to public");
        privacyStatus = @"public";
    }
    status.privacyStatus = privacyStatus;
    
    // Snippet.
    GTLYouTubeVideoSnippet *snippet = [GTLYouTubeVideoSnippet object];
    
    snippet.title = title;
    
    if ([description length] > 0) {
        snippet.descriptionProperty = description;
    }
    
    if ([tags length] > 0) {
        snippet.tags = [tags componentsSeparatedByString:@";"];
    }
    //    if ([_uploadCategoryPopup isEnabled]) {
    //        NSMenuItem *selectedCategory = [_uploadCategoryPopup selectedItem];
    //        snippet.categoryId = [selectedCategory representedObject];
    //    }
    
    GTLYouTubeVideo *video = [GTLYouTubeVideo object];
    video.status = status;
    video.snippet = snippet;
    
    [self uploadVideoWithVideoObject:video media:media
             resumeUploadLocationURL:nil];
}


- (void)cancelAllCurrentUploads
{
    DLog(@"Canceling all current upload to youtube");
    
    //fixed crash while fast enumerating
    
    
    for (GTLServiceTicket *ticket in self.uploadFileTickets)
    {
        [ticket cancelTicket];
        //[self removeUploadTicket:ticket];
    }
    
    [self.uploadFileTickets removeAllObjects];
    
}

- (void)removeUploadTicket:(GTLServiceTicket *)ticket
{
    if ([self.uploadFileTickets containsObject:ticket])
    {
        [self.uploadFileTickets removeObject:ticket];
    }
    
    //ticket = nil;
}


- (void)uploadVideoWithVideoObject:(GTLYouTubeVideo *)video media:(PoiMedia *)media resumeUploadLocationURL:(NSURL *)locationURL {
    // Get a file handle for the upload data.
    
    NSString *filename = [media.path lastPathComponent];
    
    //FIX 2.5: uses relative path to home directory for ios8 compatibility
    //NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:media.path];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:[NSHomeDirectory() stringByAppendingPathComponent:media.path]];
    
    if (fileHandle) {
        NSString *mimeType = [self MIMETypeForFilename:filename
                                       defaultMIMEType:@"video/mp4"];
        GTLUploadParameters *uploadParameters =
        [GTLUploadParameters uploadParametersWithFileHandle:fileHandle
                                                   MIMEType:mimeType];
        uploadParameters.uploadLocationURL = locationURL;
        
        GTLQueryYouTube *query = [GTLQueryYouTube queryForVideosInsertWithObject:video
                                                                            part:@"snippet,status"
                                                                uploadParameters:uploadParameters];
        
        GTLServiceYouTube *service = self.youTubeService;
        GTLServiceTicket *uploadFileTicket;
        
        uploadFileTicket = [service executeQuery:query
                                completionHandler:^(GTLServiceTicket *ticket,
                                                    GTLYouTubeVideo *uploadedVideo,
                                                    NSError *error) {
                                    // Callback
                                    
                                    [self removeUploadTicket:ticket];
                                    NSString *videoId;
                                    
                                    if (error == nil) {
                                        DLog(@"Video Uploaded : %@", uploadedVideo.snippet.title);
                                        DLog(@"Video Url : %@", uploadedVideo.identifier);
                                        videoId = [uploadedVideo.identifier copy];
                                    }
                                    else
                                    {
                                        DLog(@"Video Upload failed : %@", uploadedVideo.snippet.title);
                                    }
                                    
                                    //Inform delegate
                                    if (_delegate && [_delegate respondsToSelector:@selector(uploadDoneForMedia:withVideoId:andError:)])
                                    {
                                        [_delegate uploadDoneForMedia:media withVideoId:videoId andError:error];
                                    }
                                    
                                }];
        
        __weak YouTubeHelper *dummySelf = self;
        uploadFileTicket.uploadProgressBlock = ^(GTLServiceTicket *ticket,
                                                  unsigned long long numberOfBytesRead,
                                                  unsigned long long dataLength) {
        
            long double division = (double)numberOfBytesRead / (double)dataLength;
            int percentage = division * 100;
            
            if ([dummySelf.uploadFileTickets firstObject] == ticket)
            {
                //show percentage only for first added upload (assuming is oldest one)
                
                if (dummySelf.delegate && [dummySelf.delegate respondsToSelector:@selector(uploadProgressPercentage:)]) {
                    [dummySelf.delegate uploadProgressPercentage:percentage];
            }
            }
        };
        
        // To allow restarting after stopping, we need to track the upload location
        // URL.
        //
        // For compatibility with systems that do not support Objective-C blocks
        // (iOS 3 and Mac OS X 10.5), the location URL may also be obtained in the
        // progress callback as ((GTMHTTPUploadFetcher *)[ticket objectFetcher]).locationURL
        
//        GTMHTTPUploadFetcher *uploadFetcher = (GTMHTTPUploadFetcher *)[_uploadFileTicket objectFetcher];
//        uploadFetcher.locationChangeBlock = ^(NSURL *url) {
//            _uploadLocationURL = url;
//            [self updateUI];
//        };
        
        //hold an handle to executing query
        [self.uploadFileTickets addObject:uploadFileTicket];
        
    }
    else
    {
        DLog(@"YouTube Helper: invalid/missing file at location provided %@", media.path);
    }
}

#pragma mark Auth Delegate

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    
    
    //FIX 2.5: fixed bug in youtubelogin, auth token should be saved BEFORE reporting to delegate!
    //If no error, assign to instance variable
    if (error == nil) {
        _youTubeService.authorizer = auth;
    }
    
    //Inform delegate
    if (_delegate && [_delegate respondsToSelector:@selector(authenticationEndedWithError:)]) {
        [_delegate authenticationEndedWithError:error];
    }

}

@end
