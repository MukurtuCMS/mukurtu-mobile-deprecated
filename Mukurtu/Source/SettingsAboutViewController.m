//
//  SettingsAboutViewController.m
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

#import "SettingsAboutViewController.h"

@interface SettingsAboutViewController ()
@property (weak, nonatomic) IBOutlet UIButton *learnMoreButton;

@end

@implementation SettingsAboutViewController

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

    //style text links buttons
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.learnMoreButton attributedTitleForState:UIControlStateNormal]];
    
    // making text property to underline text-
    [titleString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, [titleString length])];
    
    // using text on button
    [self.learnMoreButton setAttributedTitle: titleString forState:UIControlStateNormal];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)learnMoreButtonPressed:(id)sender
{
    DLog(@"Learn More Link Pressed, launching Safari URL: %@", kLearnMoreButtonUrl);
}

- (IBAction)openSafariLink:(id)sender
{
    UIButton *button = sender;
    NSString *url = nil;
    
    switch (button.tag)
    {
        case kSafariLinkMukurtuCMStag:
            url = kSafariLinkMukurtuCMSurl;
            break;
            
        case kSafariLinkCoDAtag:
            url = kSafariLinkCoDAurl;
            break;
            
        case kSafariLinkM2Atag:
            url = kSafariLinkM2Aurl;
            break;
            
        case kSafariLinkGetMukurtutag:
            url = kSafariLinkGetMukurtuurl;
            break;
            
        case kSafariLinkVisitMukurtutag:
            url = kSafariLinkVisitMukurtuurl;
            break;
            
        case kSafariLinkVideotag:
            url = kSafariLinkVideourl;
            break;
            
        case kSafariLinkSupporttag:
            url = kSafariLinkSupporturl;
            break;
            
        case kSafariLinkSupportEnabletag:
            url = kSafariLinkSupportEnableurl;
            break;
            
        case kSafariLinkWSUtag:
            url = kSafariLinkWSUurl;
            break;
            
        default:
            DLog(@"Unknown button pressed in slide/help screen, skip");
            break;
    }

    if (url != nil)
    {
        DLog(@"Opening external url %@ in Safari", url);
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

@end
