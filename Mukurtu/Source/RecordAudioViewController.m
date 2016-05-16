//
//  RecordAudioViewController.m
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

#import "RecordAudioViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kMaxLevelMeterWidth 310
#define kMaxLevelMeterTruncateWithAt 280

#define  kTempAudioFilename @"/Documents/__tempAudioFile.m4a"

@interface RecordAudioViewController ()<AVAudioRecorderDelegate>
@property (weak, nonatomic) IBOutlet UILabel *statusMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeButton;

@property (strong, nonatomic) AVAudioRecorder *audioRecorder;

@property (assign, nonatomic) float averagePower;
@property (assign, nonatomic) float peakPower;

@property (weak, nonatomic) IBOutlet UIView *levelBarView;

@property (strong, nonatomic) NSString *tempAudioFilename;

@end

@implementation RecordAudioViewController

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
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.closeButton.enabled = NO;
        self.closeButton.image = nil;
    }
    
    BOOL inputAvailable = [[AVAudioSession sharedInstance] inputIsAvailable];
    
    if (!inputAvailable)
    {
        DLog(@"Device has no microphone or other audio input");
        self.recordButton.enabled = NO;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No audio input" message:@"Your device does not support audio recording, no microphone or other audio input available." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        return;
    }
    
    CGRect levelFrame = CGRectMake(self.levelBarView.frame.origin.x, self.levelBarView.frame.origin.y, 0.0, self.levelBarView.frame.size.height);
    self.levelBarView.frame = levelFrame;
    
    //Create temp audio file
    NSString *tempDir = NSHomeDirectory();
    NSString *soundFilePath = [tempDir stringByAppendingString: kTempAudioFilename];
    self.tempAudioFilename = soundFilePath;
    
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryRecord error: nil];
    
    NSError *error = nil;
    NSDictionary *recordSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    [NSNumber numberWithFloat: 44100], AVSampleRateKey,
                                    [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                    [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                    nil];
    
    AVAudioRecorder *newRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:soundFilePath] settings: recordSettings error: &error];
    
    self.audioRecorder = newRecorder;
    
    self.audioRecorder.delegate = self;
    
    if (error)
    {
        DLog(@"Audio Recorder intialization error: %@\ndisabling record button", [error localizedDescription]);
        self.recordButton.enabled = NO;
    }
    else
    {
        DLog(@"Audio Recorder intialization success, preparing to record");
        [self.audioRecorder prepareToRecord];
        
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.audioRecorder)
    {
        self.audioRecorder.meteringEnabled = YES;
    
        NSOperationQueue *queue             = [[NSOperationQueue alloc] init];
        NSInvocationOperation *operation    = [[NSInvocationOperation alloc]
                                           initWithTarget:self selector:@selector(updateMeter) object:nil];
        [queue addOperation: operation];
    }
    
    DLog(@"Current delegate %@", [self.delegate description]);
}

-(void)updateMeter
{
    do {
        if (self.audioRecorder.meteringEnabled)
        {
            //don't forget:
            [self.audioRecorder updateMeters];
            self.averagePower   = [self.audioRecorder averagePowerForChannel:0];
            self.peakPower      = [self.audioRecorder peakPowerForChannel:0];
            
            //we don't to surprise a ViewController with a method call
            //not in main thread
            [self performSelectorOnMainThread:@selector(meterLevelsDidUpdate) withObject:nil waitUntilDone:NO];
        
            [NSThread sleepForTimeInterval:.05]; // 20 FPS
        }
    } while (self.audioRecorder.meteringEnabled);
    
    DLog(@"Audio Recorder metering was disabled, exits meters update thread");
}

- (void)meterLevelsDidUpdate
{
    int translatedValue = (self.averagePower / 6 + 11);
    
    translatedValue = MIN(translatedValue, 10);
    translatedValue = MAX(translatedValue, 1);
    
    CGRect levelFrame;
    if (self.audioRecorder.recording)
    {
        levelFrame = CGRectMake(self.levelBarView.frame.origin.x, self.levelBarView.frame.origin.y,
                                MIN((kMaxLevelMeterWidth / 10)*translatedValue, kMaxLevelMeterTruncateWithAt), self.levelBarView.frame.size.height);
    }
    else
    {
        levelFrame = CGRectMake(self.levelBarView.frame.origin.x, self.levelBarView.frame.origin.y, 0.0, self.levelBarView.frame.size.height);
    }
        self.levelBarView.frame = levelFrame;
    
    
    NSTimeInterval recordDuration = self.audioRecorder.currentTime;
    
    int hours = (int)recordDuration / 3600;
    int minutes = (int)recordDuration / 60;
    int seconds = (int)recordDuration % 60;
    
    [self.timerLabel setText:[NSString stringWithFormat:@"%02d : %02d : %02d",hours,minutes,seconds]];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)closeSettingsButtonPressed:(id)sender
{
    DLog(@"Cancel audio recorder button pressed");
    
    [self cleanAndDismiss];
}


- (void) cleanAndDismiss
{
    DLog(@"Clean before dismissing audio recorder controller");
    
    if (self.audioRecorder.recording)
    {
        DLog(@"Audio recorder is still recording, stop it before exit");
        [self.audioRecorder stop];
    }
    
    DLog(@"Deleting canceled audio record");
    [self.audioRecorder deleteRecording];
    
    self.audioRecorder.meteringEnabled = NO;
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DLog(@"We are on ipad, parent should dismiss controller");
    }
    else
    {
        //on iphone is modal
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    //report failure to delegate (no message means just cancel)
    [self reportErrorDelegate:nil];
}

- (IBAction)recPauseButtonPressed:(id)sender
{
    DLog(@"Record/Pause button pressed");
    
    if (self.audioRecorder)
    {
        if (self.audioRecorder.recording)
        {
            DLog(@"Audio Recorder is recording, pause it");
            [self.audioRecorder pause];
            [self.statusMessageLabel setText:@"Paused"];
            
            [self.recordButton setImage:[UIImage imageNamed:@"rec_button"] forState:UIControlStateNormal];
        }
        else
        {
            DLog(@"Audio recorder is paused, start (or resume) recording");
            [self.audioRecorder record];
            [self.statusMessageLabel setText:@"Recording..."];
            
            [self.recordButton setImage:[UIImage imageNamed:@"rec_pause_button"] forState:UIControlStateNormal];
        }
        
        self.saveButton.enabled = YES;
    }
    else
    {
        DLog(@"Error: no initialized audio recorder object, does nothing and disable rec button");
        self.recordButton.enabled = NO;
    }
}

- (IBAction)saveButtonPressed:(id)sender
{
    DLog(@"Save button pressed");
    
    if (self.audioRecorder.recording)
    {
        DLog(@"Audio recorder is still recording, pause before saving");
        [self.audioRecorder pause];
    }
    
    [self.audioRecorder stop];
    
    self.audioRecorder.meteringEnabled = NO;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DLog(@"We are on ipad, parent should dismiss controller");
    }
    else
    {
        //on iphone is modal
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self reportSuccessDelegate];
}

- (void)reportSuccessDelegate
{
    if (self.delegate)
    {
        DLog(@"send audio record success to delegate");
        
        [self.delegate audioRecordEndedWithTempFilePath:self.tempAudioFilename];
    }
}

- (void)reportErrorDelegate:(NSString *)errorMessage
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(audioRecordEndedWithError:)])
    {
        DLog(@"Error capturing audio, send audio record failure to delegate");
        
        [self.delegate audioRecordEndedWithError:errorMessage];
    }
    else
        DLog(@"Error capturing audio, no audioRecordEndedWithError: delegate implemented, send nothing");
}

@end
