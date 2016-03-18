//
//  GalleryViewController.m
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

#import "GalleryViewController.h"
#import "IpadRightViewController.h"
#import "PoiMedia.h"

#import "ImageSaver.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "NSMutableDictionary+ImageMetadata.h"

#define  kDetailLabelTextPadding  110.0;

@interface GalleryViewController ()<UIPopoverControllerDelegate, AVAudioPlayerDelegate>
{
    BOOL wasPlayingAudio;
    BOOL showDetailsView;
    float fittedDetailsViewHeight;
}

@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) UIPopoverController *videoPopoverController;
@property (strong, nonatomic) MPMoviePlayerController *playerController;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;

@property (weak, nonatomic) IBOutlet UIImageView *audioMicImageView;
@property (weak, nonatomic) IBOutlet UIButton *audioPlayPauseButton;
@property (weak, nonatomic) IBOutlet UILabel *audioTimerLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioStartTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioEndTimeLabel;
@property (strong,nonatomic) NSTimer *uiUpdateTimer;
@property (weak, nonatomic) IBOutlet UISlider *audioSlider;

@property (weak, nonatomic) IBOutlet UIView *detailsView;
@property (weak, nonatomic) IBOutlet UIButton *showHideDetailsButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *detailsViewHeight;
@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;


@end

@implementation GalleryViewController

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
    DLog(@"Gallery loaded");
    
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    //FIX 2.5: hides back button on ipad while using nav controller to push gallery view
    [self.navigationItem setHidesBackButton:YES];
    
    //remove any pending observer
    //[[NSNotificationCenter defaultCenter] removeObserver:self];

    //init local flags
    wasPlayingAudio = NO;
    
    if ([self.visibleMedia.type isEqualToString:@"photo"])
    {
        self.playButton.hidden = YES;
        self.imageView.hidden = NO;
        [self hideAudioPlayer];
        
        //UIImage *photo = [UIImage imageWithContentsOfFile:self.visibleMedia.path];
        UIImage *photo = [UIImage imageWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.path]];
        [self.imageView setImage:photo];
    }
    else
        if ([self.visibleMedia.type isEqualToString:@"video"])
        {
            self.playButton.hidden = NO;
            self.imageView.hidden = NO;
            [self hideAudioPlayer];
            
            //NSString *bigThumbPath = [ImageSaver getBigThumbPathForThumbnail:self.visibleMedia.thumbnail];
            NSString *bigThumbPath = [ImageSaver getBigThumbPathForThumbnail:[NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.thumbnail]];
            
            UIImage *frame = [UIImage imageWithContentsOfFile:bigThumbPath];
            [self.imageView setImage:frame];
            
            
        }
    else
        if ([self.visibleMedia.type isEqualToString:@"audio"])
        {
            DLog(@"Gallery media is audio");
            
            self.playButton.hidden = YES;
            self.imageView.hidden = YES;
            
            //should init audio player here
            [self initAudioPlayer];
            
            [self showAudioPlayer];
            
        }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self resetDetailsView];
}

- (void) initAudioPlayer
{
    DLog(@"Initializing Audio Player");
    //NSString *audioFilePath = self.visibleMedia.path;
    NSString *audioFilePath = [NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.path];
    DLog(@"Preparing to play %@", [audioFilePath lastPathComponent]);
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    NSURL *url = [NSURL fileURLWithPath:audioFilePath];
    NSError *error;
    
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (!player)
    {
        DLog(@"Failed to init audio player: %@", error);
        self.audioPlayPauseButton.enabled = NO;
        return;
    }
    
    player.delegate = self;
    player.volume = 1.0;
    
    [player prepareToPlay];
    self.audioPlayer = player;
    
    self.audioSlider.value = 0;
    
    NSTimeInterval recordDuration = self.audioPlayer.duration;
    
    int hours = (int)recordDuration / 3600;
    int minutes = (int)recordDuration / 60;
    int seconds = (int)recordDuration % 60;
    
    [self.audioEndTimeLabel setText:[NSString stringWithFormat:@"%02d:%02d:%02d",hours,minutes,seconds]];
    
    self.uiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    
    
}

-(void)updateTimer
{
    
    NSTimeInterval playDuration = self.audioPlayer.currentTime;
    
    int hours = (int)playDuration / 3600;
    int minutes = (int)playDuration / 60;
    int seconds = (int)playDuration % 60;
    
    [self.audioTimerLabel setText:[NSString stringWithFormat:@"%02d : %02d : %02d",hours,minutes,seconds]];
    
    //update slider
    if (!self.audioSlider.isTouchInside)
    {
        self.audioSlider.value = self.audioPlayer.currentTime / self.audioPlayer.duration;
    }
    
}

- (IBAction)sliderChanged:(id)sender
{
    if (self.audioPlayer && !self.audioPlayer.isPlaying)
    {
        self.audioPlayer.currentTime = self.audioSlider.value * self.audioPlayer.duration;
    }
}
- (IBAction)sliderTouchDown:(id)sender
{
    DLog(@"Slider touch down");
    if (self.audioPlayer.isPlaying)
    {
        [self.audioPlayer pause];
    }
}

- (IBAction)sliderTouchUp:(id)sender
{
    DLog(@"Slider touch up");
    if (wasPlayingAudio)
    {
        DLog(@"Player was playing, resume from new current time");
        [self.audioPlayer play];
    }
}


- (IBAction)audioPlayButtonPressed:(id)sender
{
    DLog(@"Audio Play Button Pressed");
    
    if (self.audioPlayer)
    {
        if (self.audioPlayer.playing)
        {
            DLog(@"Audio Player is playing, pause it");
            [self.audioPlayer pause];
            
            wasPlayingAudio = NO;
            
            [self.audioPlayPauseButton setImage:[UIImage imageNamed:@"play_audio_button"] forState:UIControlStateNormal];
        }
        else
        {
            DLog(@"Audio Player is paused, start (or resume) playing");
            [self.audioPlayer play];
            wasPlayingAudio = YES;

            
            [self.audioPlayPauseButton setImage:[UIImage imageNamed:@"rec_pause_button"] forState:UIControlStateNormal];
        }
    }
    else
    {
        DLog(@"Error: no initialized audio player object, does nothing and disable play button");
        self.audioPlayPauseButton.enabled = NO;
    }

}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    DLog(@"Audio Player finished playing");

    //reset play button image
    [self.audioPlayPauseButton setImage:[UIImage imageNamed:@"play_audio_button"] forState:UIControlStateNormal];

    if (!flag)
    {
        DLog(@"Error: could not play or decode audio file, disable play button");
        
        self.audioPlayPauseButton.enabled = NO;
        [self.audioPlayer stop];
        return;
    }
    
    self.audioPlayer.currentTime = 0;
    
    //update slider here
    
}

- (void) showAudioPlayer
{
    DLog(@"Enabling Audio Player");
    
    self.audioMicImageView.hidden = NO;
    self.audioPlayPauseButton.hidden = NO;
    self.audioTimerLabel.hidden = NO;
    self.audioSlider.hidden = NO;
    self.audioStartTimeLabel.hidden = NO;
    self.audioEndTimeLabel.hidden = NO;
    
    
}

- (void) hideAudioPlayer
{
    DLog(@"Hiding Audio Player");
    
    self.audioMicImageView.hidden = YES;
    self.audioPlayPauseButton.hidden = YES;
    self.audioTimerLabel.hidden = YES;
    self.audioSlider.hidden = YES;
    self.audioStartTimeLabel.hidden = YES;
    self.audioEndTimeLabel.hidden = YES;
    
}

- (void) cancelVideoPlayback
{
    DLog(@"Canceling video playback");
    
    if (self.videoPlayerVisible)
    {
        DLog(@"gallery was playing video, dismiss and removing player notifications");
        
        _videoPlayerVisible = NO;
        
        [self.playerController.view removeFromSuperview];
        //[self.playerController stop];

        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:self.playerController];
        
        //FIX 2.5: causes crash on ios8 (check for leaks!)
        //self.playerController = nil;
        
    }
}


-(IBAction)playVideoPressed:(id)sender
{
    DLog(@"Play video button pressed");
    
    // 3 - Play the video
    //MPMoviePlayerViewController *theMovie = [[MPMoviePlayerViewController alloc]
    //                                         initWithContentURL:[NSURL fileURLWithPath:self.visibleMedia.path]];
    //[self presentMoviePlayerViewControllerAnimated:theMovie];
    
    
    _videoPlayerVisible = YES;
    
    //MPMoviePlayerController *theMovie = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:self.visibleMedia.path]];
    MPMoviePlayerController *theMovie = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.path]]];
    
    [theMovie prepareToPlay];
    [theMovie setControlStyle:MPMovieControlStyleEmbedded];
    
    self.playerController = theMovie;
    
    [self.playerController.view setFrame:self.imageView.bounds];
    
    self.imageView.userInteractionEnabled = YES;
    self.playButton.hidden = YES;
    
    [self.imageView addSubview:self.playerController.view];
    
    [self.playerController play];
    
    
    // 4 - Register for the playback finished notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myMovieFinishedCallback:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:theMovie];
    
    
    /*
    //[[NSNotificationCenter defaultCenter] addObserver:self
    //                                         selector:@selector(movieEventFullscreenHandler:)
    //                                             name:MPMoviePlayerWillEnterFullscreenNotification
    //                                           object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(movieEventFullscreenHandler:)
                                                 name:MPMoviePlayerDidEnterFullscreenNotification
                                               object:theMovie];

     */
}

- (void)movieEventFullscreenHandler:(NSNotification*)notification {
    [self.playerController setFullscreen:NO animated:YES];
    //[self.playerController setControlStyle:MPMovieControlStyleEmbedded];
}


// When the movie is done, release the controller.
-(void)myMovieFinishedCallback:(NSNotification*)aNotification
{
    DLog(@"Movie finished");
    
    _videoPlayerVisible = NO;
    self.playButton.hidden = NO;
    
    [self.playerController.view removeFromSuperview];
    //[self.playerController stop];
    
    MPMoviePlayerController* theMovie = [aNotification object];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:MPMoviePlayerPlaybackDidFinishNotification object:theMovie];
    
    //FIX 2.5: causes crash on ios8 (check for leaks!)
    //self.playerController = nil;
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)showHideDetailsButtonPressed:(id)sender
{
    DLog(@"Show Hide details button pressed");
    
    CGRect newFrame = self.detailsView.frame;

    float newHeight;
    BOOL hideDetailsLabel;
    
    if (showDetailsView)
    {
        DLog(@"Hiding details view");
        showDetailsView = NO;
        
        newFrame.size.height = 0;
        [self.showHideDetailsButton setTitle:@"See Metadata" forState:UIControlStateNormal];
        
        hideDetailsLabel = YES;
        self.detailsLabel.hidden = YES;
        
        newHeight = 0.0;
    }
    else
    {
        DLog(@"Showing details view");
        
        showDetailsView = YES;
        
        newFrame.size.height = 200;
        [self.showHideDetailsButton setTitle:@"Hide Metadata" forState:UIControlStateNormal];
        
        hideDetailsLabel = NO;
        
        newHeight = fittedDetailsViewHeight;

    }
    
    self.detailsViewHeight.constant = newHeight;

    [UIView animateWithDuration:0.5 animations:^{
        //[self.detailsView setFrame:newFrame];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.detailsLabel.hidden = hideDetailsLabel;
    }];
    
}

- (void)resetDetailsView
{
    showDetailsView = NO;
    
    [self.showHideDetailsButton setTitle:@"See Metadata" forState:UIControlStateNormal];
    self.detailsViewHeight.constant = 0.0;
    

    
    self.detailsLabel.hidden = YES;
    
    NSString *mediaDetailsText = [NSMutableString stringWithString:@"Media Details\n\n"];
    
    
    if ([self.visibleMedia.type isEqualToString:@"video"])
    {
        
        //MPMoviePlayerController *theMovie = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:self.visibleMedia.path]];
        //[theMovie prepareToPlay];
        
        //NSURL *sourceMovieURL = [NSURL fileURLWithPath:self.visibleMedia.path];
        NSURL *sourceMovieURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.path]];
        
        AVURLAsset *movieAsset = [AVURLAsset URLAssetWithURL:sourceMovieURL options:nil];
        int duration = CMTimeGetSeconds(movieAsset.duration);
    
        DLog(@"movie details  url:%@, duration:%d, tracks: %@", self.visibleMedia.path, duration, movieAsset.tracks);
        
        //disable details view
        //self.showHideDetailsButton.hidden = YES;
        
        
        int seconds = (int)duration % 60;
        int minutes = (int)duration / 60;
        int hours = (int)duration / 3600;
        
        mediaDetailsText = [mediaDetailsText stringByAppendingString:@"Type: Video\n"];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Duration: %02d:%02d:%02d\n", hours,minutes,seconds];
        
        if ([[movieAsset tracksWithMediaType:AVMediaTypeVideo] count])
        {
            AVAssetTrack *videoTrack = [movieAsset tracksWithMediaType:AVMediaTypeVideo][0];
            
            DLog(@"video track details  size:%@, formats:%@, fps: %f", NSStringFromCGSize(videoTrack.naturalSize), videoTrack.formatDescriptions, videoTrack.nominalFrameRate);
            
            CGSize videoSize = videoTrack.naturalSize;
            mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Video Size (W x H): %d x %d\n", (int)videoSize.width, (int)videoSize.height];
            
            mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"FPS: %.3f\n", videoTrack.nominalFrameRate];
            
            if ([videoTrack.formatDescriptions count])
            {
                CMFormatDescriptionRef  videoFormatDescription = (__bridge CMFormatDescriptionRef) videoTrack.formatDescriptions[0];
                
                // Get the codec and correct endianness
                CMVideoCodecType formatCodec = CFSwapInt32BigToHost(CMFormatDescriptionGetMediaSubType(videoFormatDescription));
            
                // add 1 for null terminator
                char formatCodecBuf[sizeof(CMVideoCodecType) + 1] = {0};
                memcpy(formatCodecBuf, &formatCodec, sizeof(CMVideoCodecType));
            
                NSString *formatCodecString = @(formatCodecBuf);
                
                if (formatCodecBuf && formatCodecString && [formatCodecString length])
                {
                    //add codec information
                    mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Video Codec: %@\n", formatCodecString];
                }
            }
        }
        
        NSString *localDate = [NSDateFormatter localizedStringFromDate:self.visibleMedia.timestamp dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"\nVideo added on: %@\n", localDate];
        
    }
    else
    if ([self.visibleMedia.type isEqualToString:@"audio"])
    {
        int seconds = (int)self.audioPlayer.duration % 60;
        int minutes = (int)self.audioPlayer.duration / 60;
        int hours = (int)self.audioPlayer.duration / 3600;
        
        mediaDetailsText = [mediaDetailsText stringByAppendingString:@"Type: Audio\n"];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Duration: %02d:%02d:%02d\n", hours,minutes,seconds];
        
        NSString *localDate = [NSDateFormatter localizedStringFromDate:self.visibleMedia.timestamp dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Recorded: %@\n", localDate];
    }
    else
    if ([self.visibleMedia.type isEqualToString:@"photo"])
    {
        mediaDetailsText = [mediaDetailsText stringByAppendingString:@"Type: Photo\n"];
        
        
        //NSMutableDictionary *metadata = [[NSMutableDictionary alloc] initFromFileAtPath:self.visibleMedia.path];
        NSMutableDictionary *metadata = [[NSMutableDictionary alloc] initFromFileAtPath:[NSHomeDirectory() stringByAppendingPathComponent:self.visibleMedia.path]];
        DLog(@"Raw Metadata %@", metadata);
        
        CLLocation *photoLocation = [metadata location];
        NSDictionary *exifDic = [metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary];
        NSDictionary *tiffDic = [metadata objectForKey:(NSString *)kCGImagePropertyTIFFDictionary];
        //NSDictionary *gpsDic = [metadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary];
        
        //size
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Size (W x H): %@ x %@\n", metadata[(NSString *)kCGImagePropertyPixelWidth],
                                                                                                   metadata[(NSString *)kCGImagePropertyPixelHeight]];
        //date time
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Taken: %@\n\n", exifDic[(NSString *)kCGImagePropertyExifDateTimeOriginal]];
        
        
        //camera
        float rawShutterSpeed = [[exifDic objectForKey:(NSString *)kCGImagePropertyExifExposureTime] floatValue];
        int decShutterSpeed = (1 / rawShutterSpeed);
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Camera: %@\n",[tiffDic objectForKey:(NSString *)kCGImagePropertyTIFFModel]];
        
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Focal Length: %@mm\n",[exifDic objectForKey:(NSString *)kCGImagePropertyExifFocalLength]];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Shutter Speed: %@\n", [NSString stringWithFormat:@"1/%d", decShutterSpeed]];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"Aperture: f/%@\n",[exifDic objectForKey:(NSString *)kCGImagePropertyExifFNumber]];
        NSNumber *ExifISOSpeed  = [[exifDic objectForKey:(NSString*)kCGImagePropertyExifISOSpeedRatings] objectAtIndex:0];
        mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"ISO: %i\n",(int)[ExifISOSpeed integerValue]];
        
        //GPS
        if (photoLocation && CLLocationCoordinate2DIsValid(photoLocation.coordinate))
        {
            mediaDetailsText = [mediaDetailsText stringByAppendingFormat:@"GPS Cordinates:  Lat %2.5f  Lon %2.5f",photoLocation.coordinate.latitude, photoLocation.coordinate.longitude];
        }
    }
    
    self.detailsLabel.text = mediaDetailsText;
    

    fittedDetailsViewHeight = [self.detailsLabel.text boundingRectWithSize:self.view.frame.size
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{ NSFontAttributeName:self.detailsLabel.font }
                                                     context:nil].size.height + kDetailLabelTextPadding;
    

    
}

- (IBAction)deleteButtonPressed:(id)sender
{
    DLog(@"Gallery Delete button pressed");
    
    if (self.audioPlayer)
    {
        [self.audioPlayer stop];
    }
    
    //FIX 2.5: added to prevent crash on exit gallery with video
    if (self.playerController)
    {
        DLog(@"Video player controller still loaded, release it");
        [self.playerController stop];
    }

    if (self.visibleMedia)
    {
        [self cancelVideoPlayback];
        [self.delegate deleteGalleryMedia:self.visibleMedia];
    }
    else
    {
        DLog(@"Attempting to delete visibile media, but no media is visible, dismiss gallery");
        [self.delegate dismissMediaGallery];
    }
    
}

- (IBAction)backButtonPressed:(id)sender
{
    DLog(@"Gallery back button pressed");
    
    [self cancelVideoPlayback];
    
    if (self.audioPlayer)
    {
        [self.audioPlayer stop];
    }
    
    //FIX 2.5: added to prevent crash on exit gallery with video
    if (self.playerController)
    {
        DLog(@"Video player controller still loaded, release it");
        [self.playerController stop];
    }
    
    [self.uiUpdateTimer invalidate];
    
    [self.delegate dismissMediaGallery];
}



- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    
    for (UITouch *touch in touches)
    {
        NSArray *array = touch.gestureRecognizers;
        for (UIGestureRecognizer *gesture in array)
        {
            if (gesture.enabled && [gesture isMemberOfClass:[UIPinchGestureRecognizer class]])
            {
                DLog(@"Ignoring pinch/zoom gesture received");
                
                gesture.enabled = NO;
            }
        }
    }
    
}

@end
