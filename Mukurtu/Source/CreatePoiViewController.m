//
//  CreatePoiViewController.m
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

#import <MapKit/MapKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "CreatePoiViewController.h"
#import "IpadRightViewController.h"
#import "PSPDFTextView.h"
#import "MetadataTableViewController.h"
#import "MapEditViewController.h"
#import "RecordAudioViewController.h"

#import "MukurtuSession.h"

#import "Poi.h"
#import "PoiMedia.h"
#import "ImageSaver.h"
#import "UIImage+Resize.h"
#import "NSMutableDictionary+ImageMetadata.h"

//FIX 2.5: added custom ui control to handle keywords
#import "JSTokenField.h"
#import "TOMSSuggestionBar.h"


#define kTabDescription 0
#define kTabCulturalNarrative 1
#define kTabKeywords 2

#define kMukurtuActionSheetAddMedia 0

#define kThumbButtonTL 0
#define kThumbButtonTR 1
#define kThumbButtonML 2
#define kThumbButtonMR 3
#define kThumbButtonBL 4
#define kThumbButtonBR 5


@interface CreatePoiViewController ()<MetadataContainerControllerDelegate, UITextViewDelegate, UITextFieldDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate, MapEditViewDelegate, AudioRecorderDelegate, JSTokenFieldDelegate, TOMSSuggestionDelegate>
//Note: Added navigation controller delegate support to avoid warning, safe since all methods in protocol are optional
//http://stackoverflow.com/questions/2829796/setting-the-uiimagepickercontroller-delegate-throws-a-warning-about-uinavigation

{
    CGRect _keyboardRect;
    BOOL _keyboardVisible;
    NSInteger selectedTab;
    
    BOOL isEditingPoi;
    
    BOOL geocodingAddressFound;
    BOOL _takingPhoto;
    
    BOOL addressManuallyEntered;
}

@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;


@property (weak, nonatomic) IBOutlet PSPDFTextView *textView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewHeight;
@property (weak, nonatomic) IBOutlet UIView *metadataContainerView;
@property (weak, nonatomic) MetadataTableViewController  *metadataTableController;

//thumbnail buttons
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonTL;
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonTR;
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonML;
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonMR;
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonBL;
@property (weak, nonatomic) IBOutlet UIButton *thumbButtonBR;



//local store
@property (strong, nonatomic) NSString *descriptionText;
@property (strong, nonatomic) NSString *culturalNarrativeText;

@property (weak, nonatomic) IBOutlet UIButton *descriptionTabButton;
@property (weak, nonatomic) IBOutlet UIButton *culturalNarrativeTabButton;
@property (weak, nonatomic) IBOutlet UIButton *keywordsTabButton;

@property (weak, nonatomic) IBOutlet UIButton *addMediaButton;
@property (strong, nonatomic) NSMutableArray *tempAddedMedias;
@property (strong, nonatomic) NSMutableArray *tempRemovedMedias;


//geocoding
@property(strong, nonatomic) CLGeocoder *geocoder;
@property (nonatomic, strong) CLLocation *lastLocationFound;
@property(nonatomic, strong) CLPlacemark *lastPlacemarkFound;


//location copy for exif on camera shoots
@property (nonatomic, strong) CLLocation *lastExifLocationFound;


@property(strong, nonatomic)UIPopoverController *imagePickerPopoverController;
@property(strong, nonatomic)UIPopoverController *audioRecorderPopoverController;

@property(strong, nonatomic)UIPopoverController *mapEditPopoverController;


//FIX 2.5: added custom ui control to handle keywords
@property (nonatomic, strong) NSMutableArray *keywordsTokens;
@property (nonatomic, strong) JSTokenField *keywordTokenField;
@property (weak, nonatomic) IBOutlet UIView *tabTextBgView;

@end

@implementation CreatePoiViewController

@synthesize isEditingPoi = isEditingPoi;
@synthesize takingPhoto = _takingPhoto;

///Helpers
- (void) errorAlert:(NSString *) message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // Register notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
    
    
    self.tempAddedMedias = [NSMutableArray array];
    self.tempRemovedMedias = [NSMutableArray array];
    
    
    //FIX 2.5: added custom ui control to handle keywords
    self.keywordsTokens = [NSMutableArray array];
    self.keywordTokenField = [[JSTokenField alloc] initWithFrame:CGRectMake(0, 0, self.tabTextBgView.bounds.size.width, 31)];
    //[[self.keywordTokenField label] setText:@"keywords:"];
    [self.keywordTokenField setDelegate:self];
    [self.tabTextBgView addSubview:self.keywordTokenField];
    self.keywordTokenField.hidden = YES;
    
    //make keyword bg view tappable to handle selection anywhere
    SEL selectorKeywordViewTap= NSSelectorFromString(@"keywordViewTap:");
    [self.tabTextBgView setUserInteractionEnabled:YES];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selectorKeywordViewTap];
    [tap setNumberOfTapsRequired:1];
    [self.tabTextBgView setGestureRecognizers:[NSArray arrayWithObject:tap]];
    
    if (!self.currentPoi)
    {
        self.currentPoi = [Poi MR_createEntity];
        isEditingPoi = NO;
    }
    else
    {
        isEditingPoi = YES;
        if ([self.currentPoi.key length] > 0)
        {
            //Editing poi with errors, alert user to help fix them
            [self errorAlert:[self.currentPoi.key copy]];
        }
        
        //DEBUG
        DLog(@"Loaded poi dump:\n%@", [self.currentPoi description]);
    }
    
    //global default values
    //sharing protocol
    //self.currentPoi.sharingProtocol =  [NSNumber numberWithInt:kMukurtuSharingProtocolDefault];
    
    if ([self.currentPoi.title length] > 0)
    {
        [self.titleTextField setText:self.currentPoi.title];
    }
    
    self.descriptionText = self.currentPoi.longdescription;
    self.culturalNarrativeText = self.currentPoi.culturalNarrative;
    
    //FIX 2.5: keyword uses token field, rebuild tokens
    if ([self.currentPoi.keywordsString length])
    {
        NSArray *keywords;
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            keywords = [self.currentPoi.keywordsString componentsSeparatedByString:@","];
        }
        else
        {
            keywords = [self.currentPoi.keywordsString componentsSeparatedByString:@";"];
        }
        
        for (NSString *keyword in keywords)
        {
            if ([keyword length])
            {
                NSString *tokenId = [self getTokenIdForKeyword:keyword];
                [self.keywordTokenField addTokenWithTitle:keyword representedObject:tokenId];
            }
        }
    }
    

    selectedTab = kTabDescription;
    [self.textView setText:self.descriptionText];
    [self.textView scrollToVisibleCaretAnimated:NO];
    
    //retrieve address and location
    if ([self.currentPoi.formattedAddress length] > 0)
    {
        self.addressLabel.text = self.currentPoi.formattedAddress;
    }
    else
    {
        self.addressLabel.text = [NSString stringWithFormat:kNewPoiGeocodingGenericError, [self.currentPoi.locationLat doubleValue], [self.currentPoi.locationLong doubleValue]];
    }
    
    //FIXED bug lost coords when editing poi!
    if ([self.currentPoi.locationLat length] > 0 && [self.currentPoi.locationLong length] > 0)
    {
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[self.currentPoi.locationLat floatValue] longitude:[self.currentPoi.locationLong floatValue]];
        self.lastLocationFound = location;
    }
    
    [self updateThumbnailsButtons];
    
    [self updateUI];
    
    [self displayMetadataTable];
    
    
    //geocoding
    self.geocoder = [[CLGeocoder alloc] init];
    [self initMapView];
    
    _takingPhoto = NO;
    addressManuallyEntered = NO;

}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.keywordTokenField updateBarFrame];
    
    //add keyword suggestions bar
    TOMSSuggestionBar *suggestionBar = [[TOMSSuggestionBar alloc] initWithNumberOfSuggestionFields:3];
    [suggestionBar subscribeTextInputView:self.keywordTokenField.textField
           toSuggestionsForAttributeNamed:@"name"
                            ofEntityNamed:@"PoiKeyword"
                             inModelNamed:@"Mukurtu2"];
    suggestionBar.font = [UIFont systemFontOfSize:20];
    suggestionBar.delegate = self;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//map handling
- (BOOL) isValidLocation:(CLLocation *)location
{
    if (location.horizontalAccuracy != 0 &&
        [self isValidCoordinate:location.coordinate])
        return YES;
    else
        return NO;
}

- (BOOL) isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    return (CLLocationCoordinate2DIsValid(coordinate));
    
    /*
    if ((coordinate.longitude < 180) && (coordinate.longitude > -180) &&
        (coordinate.latitude < 90) && (coordinate.latitude > -90))
        return YES;
    else
        return NO;
     */
}

#pragma mark - MapKit methods
-(void) initMapView
{
    DLog(@"Init main map");
    self.mapView.showsUserLocation = YES;
    DLog(@"map user location lat:%f long: %f", self.mapView.userLocation.coordinate.latitude, self.mapView.userLocation.coordinate.longitude);
    
    if (isEditingPoi)
    {
        DLog(@"Editing poi: center small map on poi location");
        
        //CLLocation *location = [[CLLocation alloc] initWithLatitude:[self.currentPoi.locationLat doubleValue] longitude:[self.currentPoi.locationLong doubleValue]];
        CLLocationCoordinate2D coords = CLLocationCoordinate2DMake([self.currentPoi.locationLat doubleValue], [self.currentPoi.locationLong doubleValue]);
        
        if ([self isValidCoordinate:coords])
        {
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coords, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            [annotation setCoordinate:coords];
            [annotation setTitle:self.currentPoi.title];
            [self.mapView addAnnotation:annotation];
        }
    }
    else
    {
        if ([self isValidLocation:self.mapView.userLocation.location])
        {
            self.lastLocationFound = self.mapView.userLocation.location;
            DLog(@"Last location saved %@", [self.lastLocationFound description]);
            
            
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(self.mapView.userLocation.coordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
            
        }
        else
        {
            //just set zoom level
            //[self.mapView setRegion:MKCoordinateRegionMakeWithDistance(self.mapView.centerCoordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
            [self.mapView setVisibleMapRect:MKMapRectWorld];
            self.addressLabel.hidden = YES;
        }
    }
    
    self.mapView.zoomEnabled = YES;
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    DLog(@"Map updated user location create poi");
    
    static int geocodingRetries = kMaxGeocodingRetries;
    
    DLog(@"location horizontal accuracy %f", userLocation.location.horizontalAccuracy);

    if ([self isValidLocation:self.mapView.userLocation.location])
    {
        DLog(@"Saving last location for exif photos, also while editing for new photos");
        self.lastExifLocationFound = self.mapView.userLocation.location;

    }
    
    
    if (!isEditingPoi && !_takingPhoto && !addressManuallyEntered && [self isValidLocation:self.mapView.userLocation.location])
    {
        //show location accuracy
        /*
        NSArray *overlays = [self.mapView overlays];
        if ([overlays count])
            [self.mapView removeOverlays:overlays];
        
        [self.mapView addOverlay:[MKCircle circleWithCenterCoordinate:self.mapView.userLocation.location.coordinate radius:self.mapView.userLocation.location.horizontalAccuracy]];
         */
        
        
        self.lastLocationFound = self.mapView.userLocation.location;
        DLog(@"Last location saved %@", [self.lastLocationFound description]);
        
        //just update center without changing zoom level

        //if (!self.mapView.userLocationVisible)
        {
            [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:NO];
        }
        
        
        
        //[self.mainMapView setRegion:MKCoordinateRegionMakeWithDistance(self.mainMapView.userLocation.coordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
        
        
        if (!self.geocoder.geocoding)
            [self.geocoder reverseGeocodeLocation:self.mapView.userLocation.location
                                completionHandler:^(NSArray *placemarks, NSError *error)
             {
                 //DLog(@"geocoder completed with error %@ , placemarks %@", [error description], [placemarks description]);
                 
                 //if (self.geocoderActivityIndicator.isAnimating)
                 //    [self.geocoderActivityIndicator stopAnimating];
                 
                 //if ([error code] == kCLErrorNetwork)
                 if (error != nil)
                 {
                     CLLocation *lastLocation = self.mapView.userLocation.location;
                     NSString *message = [NSString stringWithFormat:kNewPoiGeocodingGenericError, lastLocation.coordinate.latitude, lastLocation.coordinate.longitude];
                     
                     [self.addressLabel setText:message];
                     self.addressLabel.hidden = NO;
                 }
                 else
                     if (placemarks != nil && [placemarks count])
                     {
                         CLPlacemark *placemark = [placemarks objectAtIndex:0];
                         
                         //customize placemark before formatting
                         DLog (@"placemark address dictionary %@", [placemark.addressDictionary description]);
                         
                         NSString *currentLocationAddress = [self getAddressStringFromPlacemark:placemark];
                         
                         /*
                         NSMutableDictionary *cleanedDictionary = [NSMutableDictionary dictionaryWithDictionary:placemark.addressDictionary];
                         
                         [cleanedDictionary setValue:nil forKey:@"State"];
                         
                         NSString *currentLocationAddress = [ABCreateStringWithAddressDictionary(cleanedDictionary, YES) stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
                         */
                          
                         DLog(@"Geocode success, current address is %@", currentLocationAddress);
                         [self.addressLabel setText:[NSString stringWithFormat:@"%@", currentLocationAddress]];
                         geocodingAddressFound = YES;
                         self.lastPlacemarkFound = placemark;
                         
                         
                         self.addressLabel.hidden = NO;
                         
                         //if location accuracy is too low, trick the map view and retry a few times
                         geocodingRetries--;
                         if (self.lastLocationFound.horizontalAccuracy > kMinGeocodingAccuracy && geocodingRetries > 0)
                         {
                             //self.mapView.showsUserLocation = NO;
                             //self.mapView.showsUserLocation = YES;
                             [self performSelector:@selector(restartMapUserLocationUpdate) withObject:nil afterDelay:1.0];
                         }
                     }
             }];
        
    }
}

- (NSString *) getAddressStringFromPlacemark:(CLPlacemark *)placemark
{
    NSString *currentLocationAddress;
    if ([placemark.addressDictionary valueForKey:@"Country"] != nil)
    {
        NSMutableDictionary *cleanedDictionary = [NSMutableDictionary dictionaryWithDictionary:placemark.addressDictionary];
        
        [cleanedDictionary setValue:nil forKey:@"State"];
        
        currentLocationAddress = [ABCreateStringWithAddressDictionary(cleanedDictionary, YES) stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
    }
    else
    {
        //DLog(@"location is an ocean, inland water or other weird area, use raw name");
        currentLocationAddress = [placemark.addressDictionary valueForKey:@"Name"];
    }
    
    return currentLocationAddress;
}


- (void) restartMapUserLocationUpdate
{
    //trick the map view to restart updating position
    if (self && self.mapView != nil)
    {
        self.mapView.showsUserLocation = NO;
        self.mapView.showsUserLocation = YES;
    }
}


/*
-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:(MKCircle *)overlay];
    circleView.fillColor = [UIColor  lightGrayColor];
    circleView.alpha = 0.3;
    
    return circleView;
}
 */

/*
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id < MKAnnotation >)annotation
{
    static NSString* AnnotationIdentifier = @"Annotation";
    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationIdentifier];
    
    if (!pinView)
    {
        
        MKAnnotationView *customPinView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationIdentifier];
        if (annotation == mapView.userLocation)
        {
            customPinView.image = [UIImage imageNamed:@"pin_generic.png"];
            DLog(@"new user location pin %@", [customPinView description]);
            //customPinView = nil;
        }
        //else
        //    customPinView.image = [UIImage imageNamed:@"mySomeOtherImage.png"];
        
        customPinView.enabled = YES;
        //customPinView.animatesDrop = YES;
        //customPinView.canShowCallout = YES;
        customPinView.centerOffset = CGPointMake(1.0, -(customPinView.image.size.height / 3));
        return customPinView;
    } else
    {
        
        pinView.annotation = annotation;
    }
    
    return pinView;
    
}*/


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
    
    self.metadataTableController = metadataTableController;
    
    //init with poi metadata
    if (isEditingPoi)
    {
        DLog(@"Editing poi: ask metadata table update");
        [self.metadataTableController loadMetadataFromPoi:self.currentPoi];
    }
    
}

////Metadata delegate
#pragma mark - Metadata Delegate

-(CGRect)getContainerViewFrame
{
    
    //FIX 2.5: removed since cause UIViewAlertForUnsatisfiableConstraints exception in ios 8.0
    //[self.metadataContainerView layoutIfNeeded];
    
    CGRect frame = self.metadataContainerView.frame;
    
    return frame;
}


////Keyboard Notifications
#pragma mark - Keyboard Notifications

- (void)keyboardWillShowNotification:(NSNotification *)notification {
    if (!_keyboardVisible) {
        _keyboardVisible = YES;
        _keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        //[self updateTextViewContentInset];
        //[(PSPDFTextView *)self.textView scrollToVisibleCaretAnimated:NO]; // Animating here won't bring us to the correct position.
        [self updateControlsToFitKeyboard];
    }
}

- (void)keyboardWillHideNotification:(NSNotification *)notification {
    if (_keyboardVisible) {
        _keyboardVisible = NO;
        _keyboardRect = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        //[self updateTextViewContentInset];
        [self updateControlsToFitKeyboard];
    }
}

- (void) updateControlsToFitKeyboard
{
    CGFloat textViewHeight, delay;
    
    
    [self.view layoutIfNeeded]; // Ensures that all pending layout operations have been completed
    
    if (_keyboardVisible)
    {
        textViewHeight = 150.0f;
        delay = 0.0f;
    }
    else
    {
        textViewHeight = 180.0f;
        delay = .2f;
        [self.textView scrollRangeToVisible:NSRangeFromString(@"")];
    }
    
    [UIView animateWithDuration:.4f delay:delay options:UIViewAnimationOptionCurveEaseInOut animations:^{
        // Make all constraint changes here
        self.textViewHeight.constant = textViewHeight;
        [self.view layoutIfNeeded]; // Forces the layout of the subtree animation block and then captures all of the frame changes
        
        
    } completion:nil];
    
}

/*
- (void)updateTextViewContentInset {
    CGFloat top = self.topLayoutGuide.length, bottom = 0.f;
 
    // Don't execute this if in a popover.
    if (_keyboardVisible) {
        bottom = __tg_fmin(CGRectGetHeight(_keyboardRect), CGRectGetWidth(_keyboardRect)); // also work in landscape
    }
    
    //UIEdgeInsets contentInset = UIEdgeInsetsMake(top, 0.f, bottom, 0.f);
    UIEdgeInsets contentInset = UIEdgeInsetsMake(top, 0.f, bottom, 0.f);
    self.textView.contentInset = contentInset;
    self.textView.scrollIndicatorInsets = contentInset;
    
}*/


////Local Store
-(void) storeTexts
{
    switch (selectedTab)
    {
        case kTabDescription:
            self.descriptionText = [self.textView.text copy];
            break;
            
        case kTabCulturalNarrative:
            self.culturalNarrativeText = [self.textView.text copy];
            break;
            
        case kTabKeywords:
            //FIX 2.5: added custom ui control to handle keywords
            break;
            
        default:
            break;
    }

}

- (void)updatePoiData
{
    //timestamp only on creation
    if (self.currentPoi.timestamp == nil)
    {
        DLog(@"Storing timestamp");
        self.currentPoi.timestamp = [NSDate date];
    }
    
#warning overwrite key and disable alert during edit?
    //reset any error key, will be checked later by validate all poi
    self.currentPoi.key = @"";
    
    //poi title
    DLog(@"updating current poi title to %@", self.titleTextField.text);
    self.currentPoi.title = self.titleTextField.text;
    
    //sharing protocol
    self.currentPoi.sharingProtocol =  [NSNumber numberWithInt:kMukurtuSharingProtocolDefault];
    
    //text fields
    self.currentPoi.culturalNarrative = self.culturalNarrativeText;
    self.currentPoi.longdescription = self.descriptionText;
    
    //FIX 2.5: uses keywords tokens
    //build a semicolon separated list of all inserted keyword tokens
    NSMutableString *keywordList = [NSMutableString string];
    
    for (NSDictionary *keywordToken in self.keywordsTokens)
    {
        NSString *keywordTitle = [[keywordToken allKeys] objectAtIndex:0];
        
        if ([MukurtuSession sharedSession].serverCMSVersion1)
        {
            [keywordList appendFormat:@"%@,", keywordTitle];
        }
        else
        {
            [keywordList appendFormat:@"%@;", keywordTitle];
        }
        
        [[MukurtuSession sharedSession] addLocalKeyword:keywordTitle];
    }
    
    self.currentPoi.keywordsString = [keywordList copy];
    
    //address and location
    if (self.lastPlacemarkFound)
    {
        self.currentPoi.formattedAddress = self.addressLabel.text;
    }
    
    //WARNING following check for valid location not validate manual location entered via edit map. Don't uncomment this!
    //if ([self isValidLocation:self.lastLocationFound])
    {
        self.currentPoi.locationLat = [NSString stringWithFormat:@"%f", (float) self.lastLocationFound.coordinate.latitude];
        self.currentPoi.locationLong = [NSString stringWithFormat:@"%f", (float) self.lastLocationFound.coordinate.longitude];
    }
    
    //metadata
    self.currentPoi.categories = [NSSet setWithSet:self.metadataTableController.selectedCategories];
    self.currentPoi.culturalProtocols = [NSSet setWithSet:self.metadataTableController.selectedCulturalProtocols];
    //DLog([self.currentPoi.culturalProtocols description]);
    self.currentPoi.communities = [NSSet setWithSet:self.metadataTableController.selectedCommunities];
    
    //FIX 2.5: clean orphan communities if any
    
    
    //FIX 2.5: handle contributor and creator as token fields
    self.currentPoi.creator = self.metadataTableController.creatorString;
    self.currentPoi.contributor = self.metadataTableController.contributorString;
    
    if (self.metadataTableController.dateIsString)
    {
        //date is string
        self.currentPoi.creationDateString = [self.metadataTableController.creationDateTextField.text copy];
        self.currentPoi.creationDate = nil;
    }
    else
    {
        //date is NSDate
        self.currentPoi.creationDateString = nil;
        self.currentPoi.creationDate = [self.metadataTableController.creationDate copy];
    }
    
    
    ////Medias, merge changes here
    if ([self.tempRemovedMedias count])
    {
        for (PoiMedia *media in [self.tempRemovedMedias copy])
        {
            DLog(@"Removing parked media before saving");
            
            //[[MukurtuSession sharedSession] deleteMedia:media];
            [ImageSaver deleteMedia:media];
        }
        
       // DLog(@"Saving core data context");
       // [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    
}

- (NSString *)poiHasValidMetadata
{
    DLog(@"Validating poi metadata");
    
    NSString *result = @"OK";
    
    //check title (empty string or spaces only are not valid)
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    if ([[self.titleTextField.text stringByTrimmingCharactersInSet: set] length] == 0)
    {
        result = kPoiStatusMissingTitle;
    }
    
    return result;
}

////TextView and TextField Delegate
#pragma mark - text view/field delegate

- (void)textViewDidChange:(UITextView *)textView
{
    [self storeTexts];
}


- (void)textFieldDidEndEditing:(UITextField *)textField {
   
 }

- (IBAction)didFinishEditingTitle:(id)sender {
	[self.titleTextField resignFirstResponder];
}


////UI update
- (void)enableTab:(UIButton*)tab
{
    tab.backgroundColor = [UIColor whiteColor];
    [tab setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
}

- (void)disableTab:(UIButton*)tab
{
    tab.backgroundColor = kUIColorOrange;
    //tab.titleLabel.textColor = [UIColor whiteColor];
    [tab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

- (void) updateUI
{
    //text tabs
    switch (selectedTab)
    {
        case kTabDescription:
            [self enableTab:self.descriptionTabButton];
            [self disableTab:self.culturalNarrativeTabButton];
            [self disableTab:self.keywordsTabButton];
            break;
            
        case kTabCulturalNarrative:
            [self disableTab:self.descriptionTabButton];
            [self enableTab:self.culturalNarrativeTabButton];
            [self disableTab:self.keywordsTabButton];
            break;
            
        case kTabKeywords:
            [self disableTab:self.descriptionTabButton];
            [self disableTab:self.culturalNarrativeTabButton];
            [self enableTab:self.keywordsTabButton];
            break;
            
        default:
            break;
    }
}


#pragma mark - Media Handling stuff

////Image Picker delegate
#warning better present picker from main controller for orientation issues and spaghetti glue code...

- (void) dismissPickerPopoverController
{
    DLog(@"Dissmiss picker controller without animation");
    
    if (!_takingPhoto && self.imagePickerPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing pick media popover");
        
        [self.imagePickerPopoverController dismissPopoverAnimated:NO];
    }
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    DLog(@"User canceled media picker controller");
    
    if (self.imagePickerPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing pick media popover");
        
        [self.imagePickerPopoverController dismissPopoverAnimated:YES];
    }
        
    else
    {
        DLog(@"dismissing modal pick media popover");
        
        //FIX 2.5: fixed a crash on dismiss picker
        [picker dismissViewControllerAnimated:YES completion:^{
            _takingPhoto = NO;
        }];
        
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    DLog(@"User picked media of type %@ with path %@",info[UIImagePickerControllerMediaType], info[UIImagePickerControllerMediaURL]);
    
    //Get media type
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    NSString *prefix;
    if ([self.currentPoi.title length] > 0)
        prefix = [self.currentPoi.title copy];
    else
        prefix = [[MukurtuSession sharedSession] storedUsername];
    
    PoiMedia *newMedia;
    
    if (CFStringCompare ((__bridge_retained CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo)
    {
        DLog(@"Picked Media is an image, handle it");
        
        //if we used camera, save photo also in PhotoAlbum
        if ([picker sourceType] == UIImagePickerControllerSourceTypeCamera)
        {
            
            UIImage *image = [ImageSaver extractImageAndFixOrientationFromMediaInfo:info];
            
            NSMutableDictionary *metadata = [ImageSaver extractMetadataFromMediaInfo:info forceOrientationUp:YES];
            
            //set location
            [metadata setLocation:self.lastExifLocationFound];
            
            DLog(@"Saving camera shoot to PhotoAlbum");
            
            ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
            
            [library writeImageToSavedPhotosAlbum:[image CGImage] metadata:metadata completionBlock:nil];
            
            newMedia = [ImageSaver saveImageToDisk:image withExifMetadata:metadata andCreateMediawithNamePrefix:prefix];
        }
        else //photo was imported from photoroll
        {
            [self saveAsyncImagePicker:picker WithInfo:info];
            
            return;
        }
    }
    else
        if (CFStringCompare ((__bridge_retained CFStringRef)mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo)
        {
            DLog(@"Picked media is a video, handle it");
            
            NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
            NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
            
            newMedia = [ImageSaver saveVideoToDisk:videoData andCreateMediawithNamePrefix:prefix];
            
        }
    
    if (newMedia != nil)
    {
        DLog(@"file saved and new media created, attaching to current poi");
        newMedia.parent = self.currentPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media");
    }
    
    [self updateThumbnailsButtons];
    
    if (self.imagePickerPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing pick media popover");
        
        [self.imagePickerPopoverController dismissPopoverAnimated:YES];
    }
    else
        //FIX 2.5: fixed a crash on dismiss picker
        [picker dismissViewControllerAnimated:YES completion:^{
            _takingPhoto = NO;
        }];
    
}

-(void) saveAsyncImagePicker:(UIImagePickerController *)picker WithInfo:(NSDictionary *)info
{
    DLog(@"Saving picked image in async mode to copy valid exif metadata ");
    
    NSURL* assetURL = nil;
    NSMutableDictionary *exifMetadata = [NSMutableDictionary dictionary];
    
    if ((assetURL = [info objectForKey:UIImagePickerControllerReferenceURL]))
    {
        
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library assetForURL:assetURL
                 resultBlock:^(ALAsset *asset)  {
                     NSDictionary *metadata = asset.defaultRepresentation.metadata;
                     [exifMetadata addEntriesFromDictionary:metadata];
                     
                     //fix orientation issues
                     [exifMetadata setImageOrientation:UIImageOrientationUp];
                     
                     DLog(@"Read metadata success from asset library");
                     DLog(@"Fixed Orientation Metadata: %@", [exifMetadata description]);
                     
                     [self writeImageFilePicker:picker FromInfo:info withMetadata:exifMetadata];
                 }
                failureBlock:^(NSError *error)
         {
             DLog(@"Failed reading asset metadata, use empty exif data and continue, error: %@", [error description]);
             
             [self writeImageFilePicker:picker FromInfo:info withMetadata:nil];
             
         }];
    }
    else
    {
        DLog(@"No media URL in imagePicker Info, WEIRD! skip exif metadata and continue");
        [self writeImageFilePicker:picker FromInfo:info withMetadata:nil];
    }    
}

-(void) writeImageFilePicker:(UIImagePickerController *)picker FromInfo:(NSDictionary *)info withMetadata:(NSDictionary *)metadata
{
    DLog(@"Writing local image copy as jpeg with extracted exif metadata");
    DLog(@"Metadata: %@", [metadata description]);
    
    NSString *prefix;
    if ([self.currentPoi.title length] > 0)
        prefix = [self. currentPoi.title copy];
    else
        prefix = [[MukurtuSession sharedSession] storedUsername];
    
    PoiMedia *newMedia;
    
    UIImage *image = [ImageSaver extractImageAndFixOrientationFromMediaInfo:info];
    
    newMedia = [ImageSaver saveImageToDisk:image withExifMetadata:metadata andCreateMediawithNamePrefix:prefix];

    if (newMedia != nil)
    {
        DLog(@"file saved and new media created, attaching to current poi");
        newMedia.parent = self.currentPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media in async mode");
    }
    
    
    [self updateThumbnailsButtons];
    
    
    if (self.imagePickerPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing pick media popover");
        
        [self.imagePickerPopoverController dismissPopoverAnimated:YES];
    }
    else
        //FIX 2.5: fixed a crash on dismiss picker
        [picker dismissViewControllerAnimated:YES completion:^{
            _takingPhoto = NO;
        }];

}


- (void)updateThumbnailsButtons
{
    DLog(@"Reloading thumbnails");
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *orderedPoiMedias = [self.currentPoi.media sortedArrayUsingDescriptors:sortDescriptors];

    for (int i = 0; i<kMukurtuMaxMediaForPoi; i++)
    {
        UIButton *buttonToUpdate;
        
        switch (i)
        {
            case kThumbButtonTL:
                buttonToUpdate = self.thumbButtonTL;
                break;
            case kThumbButtonTR:
                buttonToUpdate = self.thumbButtonTR;
                break;
            case kThumbButtonML:
                buttonToUpdate = self.thumbButtonML;
                break;
            case kThumbButtonMR:
                buttonToUpdate = self.thumbButtonMR;
                break;
            case kThumbButtonBL:
                buttonToUpdate = self.thumbButtonBL;
                break;
            case kThumbButtonBR:
                buttonToUpdate = self.thumbButtonBR;
                break;
                
                //just to be sure... ugly
            default:
                buttonToUpdate = self.thumbButtonTL;
                break;
        }
        
        if (i < [orderedPoiMedias count])
        {
            DLog(@"We have an image for index %d", i);
            
            PoiMedia *media = orderedPoiMedias[i];
            DLog(@"media description %@", [media description]);
            
            UIImage *image = [UIImage imageWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail]];
            
            [buttonToUpdate setImage:image forState:UIControlStateNormal];
            buttonToUpdate.imageEdgeInsets = UIEdgeInsetsMake(0, 11, 0, 11);
            
            buttonToUpdate.enabled = YES;
            
        }
        else
        {
            DLog(@"No image for index %d, resetting placeholder", i);
            
            buttonToUpdate.enabled = NO;
            [buttonToUpdate setImage:[UIImage imageNamed:@"background_thumbnail"] forState:UIControlStateNormal];
            buttonToUpdate.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        }
    }
    
}


- (IBAction)thumbnailButtonPressed:(id)sender
{
    DLog(@"Button thumbnail pressed");
    
    UIButton *button = (UIButton *) sender;
  
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *orderedPoiMedias = [self.currentPoi.media sortedArrayUsingDescriptors:sortDescriptors];
    
    
    if (button.tag < [orderedPoiMedias count])
    {
        DLog(@"We have an image for index %d", (int)button.tag);
        PoiMedia *media = orderedPoiMedias[button.tag];
        
        [self.delegate showMediaGalleryFromMedia:media];
        
    }
    else
    {
        DLog(@"No image for index %d, ignore tap", (int)button.tag);
        
    }

    
}


- (void) currentPoiRemoveMedia:(PoiMedia *)media
{
    DLog(@"Removing media from poi: %@", [media.path lastPathComponent]);
    
    //check if removed media has been added in this edit session
    if ([self.tempAddedMedias containsObject:media])
    {
        //match also any media removed from a new poi (since medias should been added during this session)
        DLog(@"Removing a media added after edit, delete immediately");
        [self.tempAddedMedias removeObject:media];
        
        //[[MukurtuSession sharedSession] deleteMedia:media];
        [ImageSaver deleteMedia:media];
        
    }
    else
    {
        DLog(@"User want delete a media existing before poi edit, park it before saving changes");
        
        //detach from father but wait to delete, needed if users cancel edit
        [self.tempRemovedMedias addObject:media];
        
        NSMutableSet *newPoiMedias = [self.currentPoi.media mutableCopy];
        [newPoiMedias removeObject:media];
        self.currentPoi.media = [NSSet setWithSet:newPoiMedias];
    }
    
    DLog(@"Saving core data context");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    [self updateThumbnailsButtons];

}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    DLog(@"User trying to dismiss popover controller %@", [popoverController description]);
    
    BOOL canDismiss = NO;
    
    
    if ([popoverController.contentViewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *navController = (UINavigationController *)popoverController.contentViewController;
        
        UIViewController *firstController = navController.viewControllers[0];
        if ([firstController isKindOfClass:[RecordAudioViewController class]])
        {
            DLog(@"Want dismiss record audio controller %@", [navController description]);
            
            RecordAudioViewController *audioRecorderController = (RecordAudioViewController *)firstController;
            
            [audioRecorderController cleanAndDismiss];
            
            self.audioRecorderPopoverController = nil;
            
            canDismiss = YES;
        }
    }
    else
        canDismiss = NO;
    
    
    return (canDismiss);
}

/*
-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    DLog(@"Interface orientation change while creating/editing poi");
    
    
    
    if (self.mapEditPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing pick media popover");
        
        [self.mapEditPopoverController dismissPopoverAnimated:NO];
    }
    

}
*/


///Audio record delegates and methods
- (void) presentAudioRecorderController
{
    DLog(@"Adding audio from live recording");
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    UINavigationController *recordAudioNavigationController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"RecordAudioNavigationController"];
    
    RecordAudioViewController *recordAudioViewController = [recordAudioNavigationController.viewControllers firstObject];
    
    //FIX 2.5: should use nav controller... anyway stille works old way, so keep this for now
    //RecordAudioViewController *recordAudioViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"RecordAudioController"];
    
    recordAudioViewController.delegate = self;
    
    
    UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:recordAudioNavigationController];
    popover.delegate = self;
    
    //CGRect rect = self.view.bounds;
    CGRect rect = self.navigationController.view.bounds;
    popover.popoverContentSize = CGSizeMake(rect.size.width / 2, rect.size.height);
    
    //[popover presentPopoverFromRect:rect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    [popover presentPopoverFromRect:rect inView:self.navigationController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    self.audioRecorderPopoverController = popover;
    
    //FIX 2.5: should use nav controller... anyway stille works old way, so keep this for now
    //[self.navigationController pushViewController:recordAudioViewController animated:YES];
}

- (void) redrawAudioRecorderPopoverController;
{
    //FIX 2.5: check for controller existence instead of visibility (popoverVisible don't work correctly on ios8)
    //if (self.audioRecorderPopoverController.popoverVisible)
    if (self.audioRecorderPopoverController != nil)
    {
        DLog(@"Redrawing audio recorder controller without animation");
        
        [self.audioRecorderPopoverController dismissPopoverAnimated:NO];
        
        //CGRect rect = self.view.bounds;
        CGRect rect = self.navigationController.view.bounds;
        self.audioRecorderPopoverController.popoverContentSize = CGSizeMake(rect.size.width / 2, rect.size.height);
        
        //[self.audioRecorderPopoverController presentPopoverFromRect:rect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:NO];
        [self.audioRecorderPopoverController presentPopoverFromRect:rect inView:self.navigationController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:NO];
    }
}

- (void) audioRecordEndedWithTempFilePath:(NSString *)tempfilepath
{
    DLog(@"Audio record ended with success, creating audio media for poi");
    
    NSString *prefix;
    if ([self.currentPoi.title length] > 0)
        prefix = [self.currentPoi.title copy];
    else
        prefix = [[MukurtuSession sharedSession] storedUsername];
    
    PoiMedia *newMedia = [ImageSaver saveAudioToDisk:tempfilepath andCreateMediawithNamePrefix:prefix];
    
    if (newMedia != nil)
    {
        DLog(@"file saved and new audio media created, attaching to current poi");
        newMedia.parent = self.currentPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media");
    }
 
    if (self.audioRecorderPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing audio recorder popover controller");
        [self.audioRecorderPopoverController dismissPopoverAnimated:YES];
    }
    
    //FIX 2.5: free up handle to audio recorder popover (this helps handling rotation in ios8)
    self.audioRecorderPopoverController = nil;
    
    [self updateThumbnailsButtons];
}

- (void) audioRecordEndedWithError:(NSString *)errorMessage
{
    DLog(@"Audio record ended without saving audio file");
    
    if (errorMessage == nil)
    {
        DLog(@"User just canceled, doens nothing");
    }
    else
    {
        DLog(@"Error while saving audio file, alert user");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"Error while saving audio file\n%@", errorMessage]
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles: nil];
        [alert show];
        
    }
    
    if (self.audioRecorderPopoverController.isPopoverVisible)
    {
        DLog(@"Dismissing audio recorder popover controller");
        [self.audioRecorderPopoverController dismissPopoverAnimated:YES];
    }
    
    //FIX 2.5: free up handle to audio recorder popover (this helps handling rotation in ios8)
    self.audioRecorderPopoverController = nil;
    
}


////Action Sheet
//FIX 2.5: changed to handle complete dismiss of action sheet before pushing imagepicker (or other VCs)
//http://stackoverflow.com/questions/24942282/uiimagepickercontroller-not-presenting-in-ios-8
//- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
-(void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    NSInteger tag = actionSheet.tag;
    
    NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    switch (tag)
    {
        case kMukurtuActionSheetAddMedia:
            if ([buttonTitle isEqualToString:kMukurtuAddMediaSourceButtonAlbumPhoto])
            {
                DLog(@"Adding media from photoroll");
                [self pickNewMediaSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            }
            else
                if ([buttonTitle isEqualToString:kMukurtuAddMediaSourceButtonCameraPhoto])
                {
                    DLog(@"Adding media from camera");
                    [self pickNewMediaSourceType:UIImagePickerControllerSourceTypeCamera];
                }
                else
                    if ([buttonTitle isEqualToString:kMukurtuAddMediaSourceButtonAlbumVideo])
                    {
                        DLog(@"Adding video from photoroll");
                        //[self pickNewMediaSourceType:UIImagePickerControllerSourceTypePhotoLibrary wantVideo:YES];
                        [self pickNewMediaSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum wantVideo:YES];
                    }
                    else
                        if ([buttonTitle isEqualToString:kMukurtuAddMediaSourceButtonRecordAudio])
                        {
                            
                            [self presentAudioRecorderController];
                        }
                        else
                        {
                            DLog(@"User canceled adding media");
                            
                        }
            
            break;
            
        default:
            break;
    }

}

- (void) pickNewMediaSourceType:(UIImagePickerControllerSourceType)sourceType
{
    [self pickNewMediaSourceType:sourceType wantVideo:NO];
}


- (void) pickNewMediaSourceType:(UIImagePickerControllerSourceType)sourceType wantVideo:(BOOL)wantVideo
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    switch (sourceType)
    {
        case UIImagePickerControllerSourceTypeCamera: {
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
            {
                _takingPhoto = YES;
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                [self presentViewController:imagePicker animated:YES completion:nil];
            }
            else
            {
                DLog(@"No camera available on device. Warning! should never reach this branch!");
            }
        }
            break;
        case UIImagePickerControllerSourceTypePhotoLibrary:
        case UIImagePickerControllerSourceTypeSavedPhotosAlbum:
        {
            
            imagePicker.sourceType = sourceType;
            
            if (wantVideo)
            {
                DLog(@"Filter photo album to show videos only");
                imagePicker.videoQuality = kMukurtuMediaDefaultVideoQuality;
                
                imagePicker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *)kUTTypeMovie, nil];
            }
            else
            {
                DLog(@"Filter photo album to show images only");
                imagePicker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *)kUTTypeImage, nil];
            }
            
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
            {
                UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];

                //FIX 2.5: fix size on ios8 using nav controller
                //CGRect rect = self.view.bounds;
                CGRect rect = self.navigationController.view.bounds;
                popover.popoverContentSize = CGSizeMake(rect.size.width / 2, rect.size.height);
                
                [popover presentPopoverFromRect:rect inView:self.navigationController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
                self.imagePickerPopoverController = popover;
                
            }
            else
            {
                DLog(@"Presenting photoroll picker controller as modal: should never happen on iPad, iphone only");
                //imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                
                [self presentViewController:imagePicker animated:YES completion:nil];
            }
        }
            break;
        default:
            break;
    }
}

-(void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([navigationController isKindOfClass:[UIImagePickerController class]])
    {
        DLog(@"Will show nav controller %@",[[navigationController class] description]);
        
        UIImagePickerController *picker = (UIImagePickerController *)navigationController;
        
        if ([picker.mediaTypes count] && [picker.mediaTypes[0] isEqualToString:(NSString *)kUTTypeMovie])
        {
            
            DLog(@"Showing picker for videos");
            [picker.navigationItem setTitle:@"Videos"];
            viewController.title = @"Videos";
        }
    }
}



////Alert view delegate
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    DLog(@"AlertView: User pressed button %@", buttonTitle);
    
    if ([buttonTitle isEqualToString:kAlertButtonExit])
    {
        if (!isEditingPoi)
        {
            //remove any linked media with files
            for (PoiMedia *media in [self.currentPoi.media allObjects])
            {
                DLog(@"Removing media for canceled new poi");
                
                //[[MukurtuSession sharedSession] deleteMedia:media];
                [ImageSaver deleteMedia:media];
            }
            
            DLog(@"delete unsaved poi entity");
            [self.currentPoi MR_deleteEntity];
            
            DLog(@"Saving core data context");
            [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        }
        else
        {
            //if editing poi, we should only remove added medias in this update and leave old ones
            if ([self.tempAddedMedias count])
            {
                DLog(@"Some media have been added during edit, removing immediately");
                for (PoiMedia *media in [self.tempAddedMedias copy])
                {
                    DLog(@"Removing temp media");
                    
                    //[[MukurtuSession sharedSession] deleteMedia:media];
                     [ImageSaver deleteMedia:media];
                }
                DLog(@"Saving core data context");
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            }
            
            if ([self.tempRemovedMedias count])
            {
                DLog(@"Some media have been removed during edit, adding them back");
                
                //DEBUG
                //DLog(@"temp removed medias %@", [self.tempRemovedMedias description]);
                //DLog(@"poi current media %@", [self.currentPoi.media description]);
                
                NSMutableSet *unionPoiMedias = [[NSSet setWithArray:self.tempRemovedMedias] mutableCopy];
                [unionPoiMedias unionSet:self.currentPoi.media];
                
                DLog(@"union original medias %@", [unionPoiMedias description]);
                self.currentPoi.media = unionPoiMedias;
                
                //DLog(@"current poi resulting medias %@", [self.currentPoi.media description]);
                
                DLog(@"Saving core data context");
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            }
            
        }
        
        [self.delegate createPoiCloseButtonPressed];
    }
}




////Actions
#pragma mark - Actions
- (IBAction)closeButtonPressed:(id)sender
{
    DLog(@"Create Poi close button pressed");
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:kPoiStatusWarningLostChanges delegate:self cancelButtonTitle:kAlertButtonKeepEditing otherButtonTitles:kAlertButtonExit, nil];
    [alertView show];
    
}

- (IBAction)addMediaButtonPressed:(id)sender
{
    DLog(@"Add media button pressed");
    NSArray *currentMedias = [self.currentPoi.media allObjects];
    
    DLog(@"current poi has %d medias", (int) [currentMedias count]);
    
    if ([currentMedias count] < kMukurtuMaxMediaForPoi)
    {
        DLog(@"Adding new media, asking media source with action sheet");
    
        UIActionSheet *sheet;
        
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
        {
            sheet = [[UIActionSheet alloc] initWithTitle:@"Add new media"
                                                delegate:self
                                       cancelButtonTitle:nil
                                  destructiveButtonTitle:nil
                                       otherButtonTitles:kMukurtuAddMediaSourceButtonCameraPhoto, kMukurtuAddMediaSourceButtonAlbumPhoto, kMukurtuAddMediaSourceButtonAlbumVideo, nil];
        }
        else
        {//no camera
            sheet = [[UIActionSheet alloc] initWithTitle:@"Add new media"
                                                delegate:self
                                       cancelButtonTitle:nil
                                  destructiveButtonTitle:nil
                                       otherButtonTitles:kMukurtuAddMediaSourceButtonAlbumPhoto,  kMukurtuAddMediaSourceButtonAlbumVideo, nil];
        }
        
        //Check if device as an audio input
        BOOL inputAvailable = [[AVAudioSession sharedInstance] inputIsAvailable];
        if (inputAvailable)
        {
            [sheet addButtonWithTitle:kMukurtuAddMediaSourceButtonRecordAudio];
        }
        
        //add cancel button at bottom
        [sheet addButtonWithTitle:@"Cancel"];
        
        sheet.tag = kMukurtuActionSheetAddMedia;
        [sheet showInView:self.view];
    }
    else
    {
        DLog(@"Poi already has maximum number of media allowed");
#warning with scrolling gallery add an alert to user asking to remove some media before adding new ones
    }
    
    
}


- (IBAction)saveButtonPressed:(id)sender
{
    DLog(@"Save Poi button pressed");
    
    //FIX 2.5: fix bug for current first responder not saving entered values
    [self.view endEditing:YES];
    
    //check if poi has required data
    NSString *result;
    result = [self poiHasValidMetadata];
    
    if ([result isEqualToString:@"OK"])
    {
        [self updatePoiData];
        [self.delegate savePoiCloseButtonPressed];
    }
    else
        [self errorAlert:result];
    
}

- (IBAction)descriptionTabPressed:(id)sender
{
    //store edited text
    [self storeTexts];

    //FIX 2.5: added custom ui control to handle keywords
    self.textView.hidden = NO;
    self.keywordTokenField.hidden = YES;
    
    self.textView.autocorrectionType = UITextAutocorrectionTypeYes;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    
    [self.textView reloadInputViews];
    
    [self.textView setText:self.descriptionText];
    [self.textView scrollToVisibleCaretAnimated:NO];

    selectedTab = kTabDescription;
    [self updateUI];

    [self.textView resignFirstResponder];
    [self.textView becomeFirstResponder];

}


- (IBAction)culturalNarrativeTabPressed:(id)sender
{
    //store edited text
    [self storeTexts];

    //FIX 2.5: added custom ui control to handle keywords
    self.textView.hidden = NO;
    self.keywordTokenField.hidden = YES;
    
    self.textView.autocorrectionType = UITextAutocorrectionTypeYes;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    
    [self.textView reloadInputViews];
    
    [self.textView setText:self.culturalNarrativeText];
    [self.textView scrollToVisibleCaretAnimated:NO];

    selectedTab = kTabCulturalNarrative;
    [self updateUI];
    
    [self.textView resignFirstResponder];
    [self.textView becomeFirstResponder];

}

- (IBAction)keywordsTabPressed:(id)sender
{
    //FIX 2.5: added custom ui control to handle keywords
    [self storeTexts];
    
    [self.textView setText:@""];
    self.textView.hidden = YES;
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    
    self.keywordTokenField.hidden = NO;
    
    selectedTab = kTabKeywords;
    [self updateUI];
    
    [self.textView resignFirstResponder];
    [self.keywordTokenField.textField becomeFirstResponder];
    
}

- (IBAction)editMapButtonPressed:(id)sender
{
    DLog(@"Edit map button pressed");
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    MapEditViewController *mapEditViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"MapEditViewController"];
    
    mapEditViewController.delegate = self;
    
    if (self.lastLocationFound)
    {
        DLog(@"Setting initial coordinate to last location found: %@", [self.lastLocationFound description]);
        mapEditViewController.initialLocationCoordinate = self.lastLocationFound.coordinate;
        
    }
    else
        if (isEditingPoi)
        {
            CLLocationCoordinate2D coords = CLLocationCoordinate2DMake([self.currentPoi.locationLat doubleValue], [self.currentPoi.locationLong doubleValue]);
            
            DLog(@"Editing poi, setting initial coordinate to stored coordinates: lat %f,  long %f", coords.latitude, coords.longitude);
            
            if ([self isValidCoordinate:coords])
                mapEditViewController.initialLocationCoordinate = coords;
        }
        else //try using user current location (if available, if not defaults to world view)
            if ([self isValidLocation:self.mapView.userLocation.location])
            {
                DLog(@"Setting initial coordinate to user location: %@", [self.mapView.userLocation description]);
                mapEditViewController.initialLocationCoordinate = self.mapView.userLocation.location.coordinate;
            }
    
    if ([self.addressLabel.text length] > 0)
        mapEditViewController.initialAddress = self.addressLabel.text;

    //FIX 2.5: uses nav controller and push view without creating another popover
    [self.navigationController pushViewController:mapEditViewController animated:YES];
}

//FIX 2.5: added custom ui control to handle keywords
#pragma mark - TOMSSuggestionDelegate

- (void)suggestionBar:(TOMSSuggestionBar *)suggestionBar
  didSelectSuggestion:(NSString *)suggestion
     associatedObject:(NSManagedObject *)associatedObject
{
    [self.keywordTokenField.textField setText:@""];
    
    NSString *tokenId = [self getTokenIdForKeyword:suggestion];
    
    if ([tokenId length])
    {
        [self.keywordTokenField addTokenWithTitle:suggestion representedObject:tokenId];
    }
    
    if (self.keywordTokenField.bounds.size.height > self.tabTextBgView.bounds.size.height - self.keywordTokenField.textField.bounds.size.height)
    {
        [self.keywordTokenField.textField resignFirstResponder];
    }

}

#pragma mark JSTokenField Delegate
//Checklist tokenField add on
//- skip already present keyword during add token * 
//- skip add token if limit height set (e.g. ipad keyword tab) *
//- rebuild tokens on poi load *
//- skip ; from allowed text *
//- skin tokens colors bg image *
//- add suggestions on keyboard acessory input view (use https://github.com/TomKnig/TOMSSuggestionBar ) *
//- fix device orientation issues with TOMSSuggestionBar *
//- add help tip "backspace to delete" in keyb accessory view when selecting token *
//- build suggestion keyword list during metadata sync (fectch all titles in an array)*
//- add any new keyword to local DB for suggestion untile next sync (sync will wipe local keywords not yet uploaded) *

- (BOOL)tokenFieldShouldReturn:(JSTokenField *)tokenField
{
    if (![tokenField.textField.text length])
    {
        //dismiss keyboard
        [tokenField.textField resignFirstResponder];
        return NO;
    }
    
    NSString *tokenId = [self getTokenIdForKeyword:[tokenField.textField text]];
    
    if ([tokenField.textField text] && [tokenId length])
    {
        [tokenField addTokenWithTitle:[tokenField.textField text] representedObject:tokenId];
    }
    
    [[tokenField textField] setText:@""];
    
    if (tokenField.bounds.size.height > self.tabTextBgView.bounds.size.height - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
    
    return NO;
}

- (void)tokenField:(JSTokenField *)tokenField didAddToken:(NSString *)title representedObject:(id)obj
{
    NSDictionary *keyword = [NSDictionary dictionaryWithObject:obj forKey:title];
    [self.keywordsTokens addObject:keyword];
    DLog(@"Added token for < %@ : %@ >\n%@", title, obj, self.keywordsTokens);
    
}

- (void)tokenField:(JSTokenField *)tokenField didRemoveToken:(NSString *)title representedObject:(id)obj;
{
    [self.keywordsTokens removeObject:[NSDictionary dictionaryWithObject:obj forKey:title]];
    DLog(@"Deleted token %@\n%@", title, self.keywordsTokens);
}

- (void)tokenFieldDidEndEditing:(JSTokenField *)tokenField
{
    if ([[tokenField.textField text] length] > 1)
    {
        NSString *tokenId = [self getTokenIdForKeyword:[tokenField.textField text]];
        
        [self.keywordTokenField addTokenWithTitle:[tokenField.textField text] representedObject:tokenId];
        [tokenField.textField setText:nil];
    }
    
    if (tokenField.bounds.size.height > self.tabTextBgView.bounds.size.height - tokenField.textField.bounds.size.height)
    {
        [tokenField.textField resignFirstResponder];
    }
}

- (NSString *) getTokenIdForKeyword:(NSString *)keyword
{
    NSMutableString *tokenId = [NSMutableString string];
    
    NSMutableCharacterSet *charSet = [[NSCharacterSet whitespaceCharacterSet] mutableCopy];
    [charSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    
    for (int i = 0; i < [keyword length]; i++)
    {
        if (![charSet characterIsMember:[keyword characterAtIndex:i]])
        {
            [tokenId appendFormat:@"%@",[NSString stringWithFormat:@"%c", [keyword characterAtIndex:i]]];
        }
    }
    
    return [NSString stringWithString:tokenId];
}

- (BOOL)tokenFieldShouldBeginEditing:(JSTokenField *)tokenField
{
    if (tokenField.bounds.size.height > self.tabTextBgView.bounds.size.height - tokenField.textField.bounds.size.height)
    {
        return NO;
    }
    
    return YES;
}

- (void) keywordViewTap:(UITapGestureRecognizer *)tap
{
    if (selectedTab == kTabKeywords)
    {
        DLog(@"Tapped keyword BG, force tokenfield focus");
        [self.keywordTokenField.textField becomeFirstResponder];
    }
    
}

#pragma mark Map Edit View Controller Delegate
- (void) mapEditDidCancel
{
    DLog(@"map edit canceled, dismissing modal view controller");
    
    //FIX 2.5: using nav controller
    //[self.mapEditPopoverController dismissPopoverAnimated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) mapEditDidSavePlacemark:(MKPlacemark *)placemark
{
    DLog(@"map edit save, store new placemark and dismiss modal view controller");
    
    DLog(@"Received placemark %@", [placemark description]);
    
    if (placemark)
    {
        self.mapView.showsUserLocation = NO;
        addressManuallyEntered = YES;
        
        [self.mapView removeAnnotations:self.mapView.annotations];
        self.lastPlacemarkFound = [placemark copy];
        self.lastLocationFound = [placemark.location copy];
        
        //customize placemark before formatting
        DLog (@"placemark address dictionary %@", [placemark.addressDictionary description]);
        
        NSString *currentLocationAddress = [self getAddressStringFromPlacemark:placemark];
        
        [self.addressLabel setText:[NSString stringWithFormat:@"%@", currentLocationAddress]];
        geocodingAddressFound = YES;
        self.addressLabel.hidden = NO;
        
        
        if ([self isValidCoordinate:self.lastLocationFound.coordinate])
        {
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(self.lastLocationFound.coordinate,
                                                                       kMapIpadDefaultZoomDistanceMeters,
                                                                       kMapIpadDefaultZoomDistanceMeters) animated:YES];
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            [annotation setCoordinate:self.lastLocationFound.coordinate];
            [annotation setTitle:self.currentPoi.title];
            [self.mapView addAnnotation:annotation];
        }
        
        //restart map updates for exif gps data for new camera shoots, also after manually editing address (lastlocation updated will be disabled by addressManuallyEntered flag)
        self.mapView.showsUserLocation = YES;
    }
    else
        DLog(@"Map edit saved but no placemark specified, just dismiss");
    
    //FIX 2.5: using nav controller
    //[self.mapEditPopoverController dismissPopoverAnimated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

//FIX 2.5: not needed anymore with nav controller (handle rotation ok=
//- (void)showMapEditPopoverController
//{
//    CGRect arrowRect;// = CGRectMake(0.0, CGRectGetMidY(self.delegate.view.frame), 1,1);
//    UIPopoverArrowDirection arrowDirection;
//
//    if (self.delegate.interfaceOrientation == UIInterfaceOrientationPortrait || self.delegate.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
//    {
//        //portrait
//        arrowRect = CGRectMake(CGRectGetMidX(self.delegate.view.frame), CGRectGetMaxY(self.delegate.view.frame)*kPinNewPoiMapYRatioPortrait, 1,1);
//        arrowDirection = UIPopoverArrowDirectionDown;
//    }
//    else
//    {
//        //landscape
//#warning Should create an empty row at top and point popover there
//        arrowRect = CGRectMake(0.0, CGRectGetMidY(self.delegate.view.frame), 1,1);
//        arrowDirection = UIPopoverArrowDirectionLeft;
//    }
//
//
////    [self.mapEditPopoverController presentPopoverFromRect:arrowRect
////                                    inView:self.delegate.view
////                  permittedArrowDirections:arrowDirection
////                                  animated:YES];
//    [self.mapEditPopoverController presentPopoverFromRect:arrowRect
//                                                   inView:self.view
//                                 permittedArrowDirections:arrowDirection
//                                                 animated:YES];
//
//
//}

//- (void) redrawMapEditPopoverController
//{
//    
//    if (self.mapEditPopoverController.popoverVisible)
//    {
//        DLog(@"Redrawing map edit controller without animation");
//        
//        [self.mapEditPopoverController dismissPopoverAnimated:NO];
//        [self showMapEditPopoverController];
//    }
//}

@end
