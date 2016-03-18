//
//  IphoneCreatePoiOptionalViewController.m
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

#import "IphoneCreatePoiOptionalViewController.h"
#import "IphoneCreatePoiGeneralViewController.h"
#import "IphoneCreatePoiMetadataViewController.h"

#import "OptMetadataTableViewController.h"
#import "PSPDFTextView.h"

#import "Poi.h"

@interface IphoneCreatePoiOptionalViewController ()<OptMetadataContainerControllerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *doneEditButton;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) OptMetadataTableViewController *optMetadataTableController;

@end

@implementation IphoneCreatePoiOptionalViewController

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updatePoiOptionalMetadata
{
    DLog(@"Updating temp poi optional metadata");
    
    //text fields
    self.tempPoi.longdescription = [self.optMetadataTableController.descriptionTextView.text copy];
    self.tempPoi.culturalNarrative = [self.optMetadataTableController.culturalNarrativeTextView.text copy];
    
    //FIX 2.5: added token field for keywords
    //self.tempPoi.keywordsString = [self.optMetadataTableController.keywordsTextView.text copy];
    self.tempPoi.keywordsString = [self.optMetadataTableController.keywords copy];
    
    //DLog(@"fields: \n%@\n%@\n%@", self.tempPoi.longdescription, self.tempPoi.culturalNarrative, self.tempPoi.keywordsString);
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"OptionalMetadataTable"])
    {
        DLog(@"Embedding segue optional metadata table");
        OptMetadataTableViewController * optTableController = segue.destinationViewController;
        optTableController.parentContainer = self;
        
        self.optMetadataTableController = optTableController;
        
        [self.optMetadataTableController loadOptionaMetadataFromPoi:self.tempPoi];
    }
}


-(void)childControllerBeginEdit
{
    DLog(@"Child controller begin edit");

    self.saveButton.hidden = YES;
    self.doneEditButton.hidden = NO;
}

- (IBAction)savePoiButtonPressed:(id)sender
{
    DLog(@"Save Poi button pressed");
    
    //handle save poi here
    IphoneCreatePoiGeneralViewController *generalPoiController = self.precedentController.precedentController;
    
    [self updatePoiOptionalMetadata];
    [generalPoiController saveCurrentPoi];
    
    //[self.presentingViewController.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)editDoneButtonPressed:(id)sender
{
    
    self.saveButton.hidden = NO;
    self.doneEditButton.hidden = YES;
    [self.optMetadataTableController editDoneButtonPressed];
}

@end
