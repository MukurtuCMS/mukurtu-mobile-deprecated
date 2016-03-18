//
//  IphoneCreatePoiMetadataViewController.m
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

#import "IphoneCreatePoiMetadataViewController.h"
#import "IphoneCreatePoiOptionalViewController.h"
#import "MetadataTableViewController.h"
#import "SlideLeftSegue.h"
#import "Poi.h"



@interface IphoneCreatePoiMetadataViewController ()<MetadataContainerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *metadataContainerView;

@end

@implementation IphoneCreatePoiMetadataViewController

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
    
    [self displayMetadataTable];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction) unwindFromSegue:(UIStoryboardSegue *)segue
{
	DLog(@"Unwinding to metadata");
    
    [self.nextController updatePoiOptionalMetadata];
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController fromViewController:(UIViewController *)fromViewController identifier:(NSString *)identifier
{
    SlideLeftSegue *slideSegueUnwind = [[SlideLeftSegue alloc] initWithIdentifier:identifier source:fromViewController destination:toViewController];
    
    slideSegueUnwind.unwinding = YES;
    
    return slideSegueUnwind;
    
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"MetadataToOptionalSegue"])
    {
        [self updatePoiMetadata];
        self.nextController = segue.destinationViewController;
        self.nextController.precedentController = self;
        self.nextController.tempPoi = self.tempPoi;
    }
}

////Metadata table handling
#pragma mark - Metadata table handling

- (void) displayMetadataTable

{
    DLog(@"Adding metadata table child controller");
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    MetadataTableViewController *metadataTableController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MetadataTable"];
    
    [self addChildViewController:metadataTableController];
    metadataTableController.parentContainer = self;
    
    metadataTableController.view.frame = self.metadataContainerView.bounds;
    
    [self.metadataContainerView addSubview:metadataTableController.view];
    
    [metadataTableController didMoveToParentViewController:self];
    
    self.metadataTableViewController = metadataTableController;
    
    if (self.tempPoi)
    {
        //init temp poi metadata if needed
        if ([self.tempPoi.creationDateString length] <= 0 && self.tempPoi.creationDate == nil)
            self.tempPoi.creationDate = [NSDate date];
        
        
        
        [self.metadataTableViewController loadMetadataFromPoi:self.tempPoi];
    }
    
}

- (void)updatePoiMetadata
{
    DLog(@"Updating temp poi metadata");
    
    //metadata
    self.tempPoi.categories = [NSSet setWithSet:self.metadataTableViewController.selectedCategories];
    self.tempPoi.culturalProtocols = [NSSet setWithSet:self.metadataTableViewController.selectedCulturalProtocols];
    self.tempPoi.communities = [NSSet setWithSet:self.metadataTableViewController.selectedCommunities];
    
    //FIX 2.5: handle contributor and creator as token fields
    self.tempPoi.creator = self.metadataTableViewController.creatorString;
    self.tempPoi.contributor = self.metadataTableViewController.contributorString;
    
    
    if (self.metadataTableViewController.dateIsString)
    {
        //date is string
        self.tempPoi.creationDateString = [self.metadataTableViewController.creationDateTextField.text copy];
        self.tempPoi.creationDate = nil;
    }
    else
    {
        //date is NSDate
        self.tempPoi.creationDateString = nil;
        self.tempPoi.creationDate = [self.metadataTableViewController.creationDate copy];
    }
    
}

////Metadata delegate
#pragma mark - Metadata Delegate

-(CGRect)getContainerViewFrame
{
    [self.metadataContainerView layoutIfNeeded];
    
    CGRect frame = self.metadataContainerView.frame;
    
    return frame;
}



@end
