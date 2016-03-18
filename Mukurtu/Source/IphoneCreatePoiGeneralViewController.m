//
//  IphoneCreatePoiGeneralViewController.m
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

#import "IphoneCreatePoiGeneralViewController.h"
#import "SlideLeftSegue.h"
#import "IphoneCreatePoiMetadataViewController.h"
#import "MetadataTableViewController.h"
#import "MainIphoneViewController.h"
#import "GalleryViewController.h"
#import "RecordAudioViewController.h"


#warning should add a protocol
#import "IpadRightViewController.h"

#import "MukurtuSession.h"

#import "Poi.h"
#import "Poi+clonePoiTo.h"
#import "PoiMedia.h"
#import "ImageSaver.h"
#import "UIImage+Resize.h"
#import "NSMutableDictionary+ImageMetadata.h"

#import "MapEditViewController.h"

@import CoreLocation;

#define kMukurtuActionSheetAddMedia 0


@interface IphoneCreatePoiGeneralViewController ()<UITextFieldDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MapEditViewDelegate, AudioRecorderDelegate, CLLocationManagerDelegate>
{
    BOOL isEditingPoi;
    
    BOOL geocodingAddressFound;
    
    BOOL addressManuallyEntered;
}

@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView0;
@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView1;
@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView2;
@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView3;
@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView4;
@property (weak, nonatomic) IBOutlet UIImageView *thumbImageView5;

@property (weak, nonatomic) IBOutlet UIView *mediaGalleryView;
//@property (strong, nonatomic) GalleryViewController* galleryViewController;

@property (strong, nonatomic) NSMutableArray *tempAddedMedias;
@property (strong, nonatomic) NSMutableArray *tempRemovedMedias;


@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;

@property (weak, nonatomic) IphoneCreatePoiMetadataViewController *nextController;

//geocoding
@property(strong, nonatomic) CLGeocoder *geocoder;
@property (nonatomic, strong) CLLocation *lastLocationFound;
@property(nonatomic, strong) CLPlacemark *lastPlacemarkFound;

//location copy for exif on camera shoots
@property (nonatomic, strong) CLLocation *lastExifLocationFound;

@property (strong, nonatomic) CLLocationManager *locationManager;

//@property(strong, nonatomic) RecordAudioViewController *recordAudioViewController;


@end

@implementation IphoneCreatePoiGeneralViewController

@synthesize isEditingPoi = isEditingPoi;

///Helpers
- (void) errorAlert:(NSString *) message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.tempAddedMedias = [NSMutableArray array];
    self.tempRemovedMedias = [NSMutableArray array];
    
    self.tempPoi = [Poi MR_createEntity];
    
    
    if (!self.currentPoi)
    {
        //self.currentPoi = [Poi createEntity];
        //self.tempPoi = [Poi createEntity];
        isEditingPoi = NO;
    }
    else
    {
        [self.currentPoi clonePoiTo:self.tempPoi];
        //[self clonePoi:self.currentPoi toPoi:self.tempPoi];
        DLog(@"temp poi title %@, obj %@", self.tempPoi.title, [self.tempPoi description]);
        DLog(@"current poi obj %@", [self.currentPoi description]);
        isEditingPoi = YES;
        
        if ([self.tempPoi.key length] > 0)
        {
            //Editing poi with errors, alert user to help fix them
            [self errorAlert:[self.tempPoi.key copy]];
        }
    }
    
    //global default values
    //sharing protocol
    //self.tempPoi.sharingProtocol =  [NSNumber numberWithInt:kMukurtuSharingProtocolDefault];
    
    if ([self.tempPoi.title length] > 0)
    {
        [self.titleTextField setText:self.tempPoi.title];
    }
    
    //retrieve address and location
    if ([self.tempPoi.formattedAddress length] > 0)
    {
        self.addressLabel.text = self.tempPoi.formattedAddress;
    }
    else
    {
        self.addressLabel.text = [NSString stringWithFormat:kNewPoiGeocodingGenericError, [self.tempPoi.locationLat doubleValue], [self.tempPoi.locationLong doubleValue]];
    }
    
    //FIXED bug lost coords when editing poi!
    if ([self.currentPoi.locationLat length] > 0 && [self.currentPoi.locationLong length] > 0)
    {
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[self.currentPoi.locationLat floatValue] longitude:[self.currentPoi.locationLong floatValue]];
        self.lastLocationFound = location;
    }
    
    [self updateThumbnailsButtons];
    
    //geocoding
    self.geocoder = [[CLGeocoder alloc] init];
    [self initMapView];
    
    addressManuallyEntered = NO;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//DEBUG
#ifdef DEBUG

- (void) viewWillDisappear:(BOOL)animated
{
    DLog(@"DEBUG View will disappear");
    
    [super viewWillDisappear:animated];
    
    // DEBUG Show the current contents of the documents folder
    CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));

}


- (void) viewWillAppear:(BOOL)animated
{
    DLog(@"DEBUG View will Appear");
    
    [super viewWillDisappear:animated];
    
    
    // DEBUG Show the current contents of the documents folder
    CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"] error:NULL]));
    
}

#endif

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //check core location permissions and enable user location if ok
    [self authorizeLocationServices];
}

- (void) dealloc
{
    DLog(@"Dealloc create poi iphone general data controller");
}



//map handling
//FIX 2.5: added user permission request for location services (only under iOS8)
-(void) authorizeLocationServices
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    //In iOS 7 no athorization is required, skip auth request at all
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    DLog(@"Autorization status %d", status);
    
    //check current auht status and request permission if needed
    if (status == kCLAuthorizationStatusNotDetermined)
    {
        DLog(@"Autorization status kCLAuthorizationStatusNotDetermined");
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
        {
            DLog(@"We are on iOS 8 or later, ask user permission");
            [self.locationManager requestWhenInUseAuthorization];
        }
        else
        {
            //else iOS 7 -> not auth required
            DLog(@"We are on iOS 7, no user permission needed");
            if (self.mapView != nil)
            {
                self.mapView.showsUserLocation = YES;
            }
        }
    }
    else if(status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        DLog(@"Autorization status kCLAuthorizationStatusAuthorized or kCLAuthorizationStatusAuthorizedWhenInUse");
        if (self.mapView != nil)
        {
            self.mapView.showsUserLocation = YES;
        }
    }
    else if(status == kCLAuthorizationStatusDenied)
    {
        DLog(@"Autorization status kCLAuthorizationStatusDenied");
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Access Denied"
                                                        message:@"You have denied access to location services. Please change this in Settings->Privacy->Location Services->Mukurtu"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        
        [alert show];
    }
    else if(status == kCLAuthorizationStatusRestricted)
    {
        DLog(@"Autorization status kCLAuthorizationStatusRestricted");
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Not Available"
                                                        message:@"You have no access to location services. Please turn on Location Services in Settings->Privacy->Location Services."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        
        [alert show];
    }
}


-(void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    DLog(@"Autorization status changed: %d", status);
    
    if ((status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedWhenInUse) && self.mapView != nil)
    {
        self.mapView.showsUserLocation = YES;
        //location manager was needed only to check authorization, since is now useless we can safely destroy it
        self.locationManager = nil;
    }
    
}


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
    
    //FIX 2.5: this will be setted after user allows for locations services
    //self.mapView.showsUserLocation = YES;
    
    DLog(@"map user location lat:%f long: %f", self.mapView.userLocation.coordinate.latitude, self.mapView.userLocation.coordinate.longitude);
    
    if (isEditingPoi)
    {
        DLog(@"Editing poi: center small map on poi location");
        
        CLLocationCoordinate2D coords = CLLocationCoordinate2DMake([self.tempPoi.locationLat doubleValue], [self.tempPoi.locationLong doubleValue]);
        
        if ([self isValidCoordinate:coords])
        {
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coords, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            [annotation setCoordinate:coords];
            [annotation setTitle:self.tempPoi.title];
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
            //[self.mapView setVisibleMapRect:MKMapRectWorld];
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(self.mapView.centerCoordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:NO];
            self.addressLabel.hidden = YES;
        }
    }
    
    self.mapView.zoomEnabled = YES;
    //self.mapView.scrollEnabled = NO;
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
    
    if ((!isEditingPoi) && !addressManuallyEntered && [self isValidLocation:self.mapView.userLocation.location])
    {
        
        self.lastLocationFound = self.mapView.userLocation.location;
        DLog(@"Last location saved %@", [self.lastLocationFound description]);
        
        //just update center without changing zoom level
        if (!self.mapView.userLocationVisible)
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


////Store poi locally
- (void)saveCurrentPoi
{
    DLog(@"Save poi message received from child controller");
    
    
    //check if poi has required data
    NSString *result;
    result = [self poiHasValidMetadata:self.tempPoi];
    
    if ([result isEqualToString:@"OK"])
    {
        //[self updatePoiData];
        
        ////Medias, merge changes here
        if ([self.tempRemovedMedias count])
        {
            for (PoiMedia *media in [self.tempRemovedMedias copy])
            {
                DLog(@"Removing parked media before saving");
                
                //[[MukurtuSession sharedSession] deleteMedia:media];
                [ImageSaver deleteMedia:media];
            }
        }
        
        //overwrite current poi with temp poi
        if (isEditingPoi && self.currentPoi)
        {
            DLog(@"Overwriting current poi, deleting current poi and saving new one");
            [self.currentPoi MR_deleteEntity];
        }
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        
        
        //Validate all poi to lazy check the new poi, more robust than checking single poi
        [[MukurtuSession sharedSession] validateAllPois];
        
        //ask parent to dismiss create poi view
        [self.delegate dismissCreatePoiViewController];
    }
    else
    {
        //show error and bring user to first metadata screen
        [self errorAlert:result];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
     
}


- (void)updatePoiGeneralData
{
    DLog(@"updating temp poi");
    
    //timestamp only on creation
    if (self.tempPoi.timestamp == nil)
    {
        DLog(@"Storing temp poi timestamp");
        self.tempPoi.timestamp = [NSDate date];
    }
   
#warning overwrite key and disable alert during edit?
    //reset any error key, will be checked later by validate all poi
    self.tempPoi.key = @"";

    
    //poi title
    DLog(@"updating temp poi title to %@", self.titleTextField.text);
    self.tempPoi.title = self.titleTextField.text;
    
        
    //address and location
    if (self.lastPlacemarkFound)
    {
        self.tempPoi.formattedAddress = self.addressLabel.text;
    }

    //WARNING following check for valid location not validate manual location entered via edit map. Don't uncomment this!
    //if ([self isValidLocation:self.lastLocationFound])
    {
        self.tempPoi.locationLat = [NSString stringWithFormat:@"%f", (float) self.lastLocationFound.coordinate.latitude];
        self.tempPoi.locationLong = [NSString stringWithFormat:@"%f", (float) self.lastLocationFound.coordinate.longitude];
    }
    
}

- (NSString *)poiHasValidMetadata:(Poi *)poi
{
    DLog(@"Validating poi metadata");
    
    NSString *result = @"OK";
    
    //check title (empty string or spaces only are not valid)
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    if ([[poi.title stringByTrimmingCharactersInSet: set] length] == 0)
    {
        result = kPoiStatusMissingTitle;
    }
    
#warning should check all metadata here
    
    return result;
}


////Alert view delegate
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    DLog(@"AlertView: User pressed button %@", buttonTitle);
    
    if ([buttonTitle isEqualToString:kAlertButtonExit])
    {
        if (isEditingPoi)
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
                //DLog(@"Saving core data context");
                //[[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            }
            
            if ([self.tempRemovedMedias count])
            {
                DLog(@"Some media have been removed during edit, adding them back");
                
                //DEBUG
                DLog(@"temp removed medias %@", [self.tempRemovedMedias description]);
                DLog(@"poi temp media %@", [self.tempPoi.media description]);
                
                NSMutableSet *unionPoiMedias = [[NSSet setWithArray:self.tempRemovedMedias] mutableCopy];
                [unionPoiMedias unionSet:self.tempPoi.media];
                
                DLog(@"union original medias %@", [unionPoiMedias description]);
                self.tempPoi.media = unionPoiMedias;
                
                DLog(@"current poi resulting medias %@", [self.tempPoi.media description]);
                
                //DLog(@"Saving core data context");
                //[[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            }

            
            DLog(@"Re-attach medias to current poi and removing from temp poi");
            NSSet *medias = [NSSet setWithSet:self.tempPoi.media];
            self.currentPoi.media = medias;
            self.tempPoi.media = nil;
        }
        else
        {
             DLog(@"Removing media for canceled new poi, not editing old one");
            
            //remove any linked media with files
            for (PoiMedia *media in [self.tempPoi.media allObjects])
            {
                DLog(@"Removing media for canceled new temp poi");
                
                [ImageSaver deleteMedia:media];
            }
            
        }
        
        DLog(@"delete temp poi entity");
        [self.tempPoi MR_deleteEntity];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
            if (success) {
                DLog(@"You successfully saved your context.");
            } else if (error) {
                DLog(@"Error saving context: %@", error.description);
            }
        }];
        
        //[self.delegate createPoiCloseButtonPressed];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)cancelCreatePoiPressed:(id)sender
{
    DLog(@"Create Poi close button pressed");
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:kPoiStatusWarningLostChanges delegate:self cancelButtonTitle:kAlertButtonKeepEditing otherButtonTitles:kAlertButtonExit, nil];
    [alertView show];
}


- (IBAction) unwindFromSegue:(UIStoryboardSegue *)segue
{
	DLog(@"Unwinding to general poi data");
    
    //update temp poi with metadata
    //[self updatePoiMetadata];
    [self.nextController updatePoiMetadata];
    
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController fromViewController:(UIViewController *)fromViewController identifier:(NSString *)identifier
{
    SlideLeftSegue *slideSegueUnwind = [[SlideLeftSegue alloc] initWithIdentifier:identifier source:fromViewController destination:toViewController];
    
    slideSegueUnwind.unwinding = YES;
    
    return slideSegueUnwind;
    
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"GeneralToMetadataSegue"])
    {
        DLog(@"Force title insertion if missing");
        
        //check if poi has required data
        //check title (empty string or spaces only are not valid)
        NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
        if ([[self.titleTextField.text stringByTrimmingCharactersInSet: set] length] == 0)
        {
            DLog(@"Poi has not title, alert user and cancel transition");
            
            //show error
            [self errorAlert:kPoiStatusMissingTitle];
            
            return NO;
        }
        else
            {
                return YES;
            }
    }
   
    return YES;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"GeneralToMetadataSegue"])
    {
        [self updatePoiGeneralData];
        self.nextController = segue.destinationViewController;
        self.nextController.precedentController = self;
        self.nextController.tempPoi = self.tempPoi;
    }
}


////Text Field Delegate
#pragma mark Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

/*
 - (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
 {
 return YES;
 
 }*/


#pragma mark Media Handling
////Gesture Recognizer
- (IBAction)takePicture:(UITapGestureRecognizer*)sender {
	
    DLog(@"Thumbnail Image tapped");
    
    CGPoint point = [sender locationInView:self.mediaGalleryView];
    UIImageView *tappedView = (UIImageView *)[self.mediaGalleryView hitTest:point withEvent:nil];
    
    DLog(@"Tapped image view tag %d",(int) tappedView.tag);
    
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *orderedPoiMedias = [self.tempPoi.media sortedArrayUsingDescriptors:sortDescriptors];
    
    
    if (tappedView.tag < [orderedPoiMedias count])
    {
        DLog(@"We have an image for index %d", (int)tappedView.tag);
        PoiMedia *media = orderedPoiMedias[tappedView.tag];
        
        DLog(@"Tapped media thumbnail %@", [media.path lastPathComponent]);
        
        [self showMediaGalleryFromMedia:media];
        
    }
    else
    {
        DLog(@"No image for index %d, ignore tap", (int)tappedView.tag);
        
    }
    
}


- (void)updateThumbnailsButtons
{
    DLog(@"Reloading thumbnails");
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    NSArray *orderedPoiMedias = [self.tempPoi.media sortedArrayUsingDescriptors:sortDescriptors];
    
    for (int i = 0; i<kMukurtuMaxMediaForPoi; i++)
    {
        UIImageView *buttonToUpdate;
        
        switch (i)
        {
            case 0:
                buttonToUpdate = self.thumbImageView0;
                break;
            case 1:
                buttonToUpdate = self.thumbImageView1;
                break;
            case 2:
                buttonToUpdate = self.thumbImageView2;
                break;
            case 3:
                buttonToUpdate = self.thumbImageView3;
                break;
            case 4:
                buttonToUpdate = self.thumbImageView4;
                break;
            case 5:
                buttonToUpdate = self.thumbImageView5;
                break;
                
                //just to be sure... ugly, should never reach this
            default:
                buttonToUpdate = self.thumbImageView0;
                break;
        }
        
        if (i < [orderedPoiMedias count])
        {
            DLog(@"We have an image for index %d", i);
            
            PoiMedia *media = orderedPoiMedias[i];
            //UIImage *image = [UIImage imageWithContentsOfFile:[media.thumbnail copy]];
            UIImage *image = [UIImage imageWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:media.thumbnail]];
                        
            [buttonToUpdate setImage:image];
            buttonToUpdate.userInteractionEnabled = YES;
            
        }
        else
        {
            DLog(@"No image for index %d, resetting placeholder", i);
            
            buttonToUpdate.userInteractionEnabled = NO;
            //[buttonToUpdate setImage:[UIImage imageNamed:@"background_thumbnail"]];
            [buttonToUpdate setImage:nil];
        }
    }
    
}

///Audio record delegates and methods
- (void) presentAudioRecorderController
{
    DLog(@"Adding audio from live recording");
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    UINavigationController *recordAudioNavigationController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"RecordAudioNavigationController"];
    
    RecordAudioViewController *recordAudioViewController = [recordAudioNavigationController.viewControllers firstObject];
    recordAudioViewController.delegate = self;
    
    
    [self presentViewController:recordAudioNavigationController animated:YES completion:nil];
}

- (void) audioRecordEndedWithTempFilePath:(NSString *)tempfilepath
{
    DLog(@"Audio record ended with success, creating audio media for poi");
    
    NSString *prefix;
    if ([self.tempPoi.title length] > 0)
        prefix = [self.tempPoi.title copy];
    else
        prefix = [[MukurtuSession sharedSession] storedUsername];
    
    PoiMedia *newMedia = [ImageSaver saveAudioToDisk:tempfilepath andCreateMediawithNamePrefix:prefix];
    
    if (newMedia != nil)
    {
        DLog(@"file saved and new audio media created, attaching to current poi");
        newMedia.parent = self.tempPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media");
    }
    
    //self.recordAudioViewController = nil;

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
    
    //self.recordAudioViewController = nil;
}


////Image Picker delegate
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    DLog(@"User canceled media picker controller");
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    
    DLog(@"User picked media of type %@ with path %@",info[UIImagePickerControllerMediaType], info[UIImagePickerControllerMediaURL]);
    
    //Get media type
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    NSString *prefix;
    if ([self.tempPoi.title length] > 0)
        prefix = [self.tempPoi.title copy];
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
        newMedia.parent = self.tempPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media");
    }
    
    [self updateThumbnailsButtons];
    
    [picker dismissViewControllerAnimated:YES completion:nil];
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
    if ([self.tempPoi.title length] > 0)
        prefix = [self.tempPoi.title copy];
    else
        prefix = [[MukurtuSession sharedSession] storedUsername];
    
    PoiMedia *newMedia;
    
    //force orientation up
    //NSMutableDictionary *fixedMetadata = [[NSMutableDictionary alloc] initWithDictionary:metadata];
    //[fixedMetadata setImageOrientation:UIImageOrientationUp];

    UIImage *image = [ImageSaver extractImageAndFixOrientationFromMediaInfo:info];
 
    //newMedia = [ImageSaver saveImageToDisk:image withExifMetadata:fixedMetadata andCreateMediawithNamePrefix:prefix];
    newMedia = [ImageSaver saveImageToDisk:image withExifMetadata:metadata andCreateMediawithNamePrefix:prefix];
    
    if (newMedia != nil)
    {
        DLog(@"file saved and new media created, attaching to current poi");
        newMedia.parent = self.tempPoi;
        [self.tempAddedMedias addObject:newMedia];
        
        DLog(@"Saving core data context");
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    }
    else
    {
        DLog(@"ERROR while saving media file and creating media in async mode");
    }
    
    
    [self updateThumbnailsButtons];
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

////Action Sheet
- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSInteger tag = actionSheet.tag;
    
    NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    switch (tag)
    {
        case kMukurtuActionSheetAddMedia:
            if ([buttonTitle isEqualToString:kMukurtuAddMediaSourceButtonAlbumPhoto])
            {
                DLog(@"Adding image from photoroll");
                [self pickNewMediaSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                //[self pickNewMediaSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
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


- (void) pickNewMediaSourceType:(UIImagePickerControllerSourceType)sourceType wantVideo:(BOOL) wantVideo
{
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;
    
    switch (sourceType)
    {
        case UIImagePickerControllerSourceTypeCamera: {
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
            {
                //_takingPhoto = YES;
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
#warning ios 7 .0 bug cover status bar in camer view
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
            
            DLog(@"Presenting photoroll picker controller as modal: should never happen on iPad, iphone only");
            
            if (wantVideo)
            {
                DLog(@"Filter photo album to show videos only");
                imagePicker.videoQuality = kMukurtuMediaDefaultVideoQuality;
                
                imagePicker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *)kUTTypeMovie, nil];
                imagePicker.title = @"Videos";
            }
            else
            {
                DLog(@"Filter photo album to show images only");
                imagePicker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *)kUTTypeImage, nil];
            }
            
            //imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            imagePicker.sourceType = sourceType;
            [self presentViewController:imagePicker animated:YES completion:nil];
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

- (IBAction)addMediaButtonPressed:(id)sender
{
    DLog(@"Add media button pressed");
    
    NSArray *currentMedias = [self.tempPoi.media allObjects];
    
    DLog(@"temp poi has %d medias", (int) [currentMedias count]);
    
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


- (void)dismissMediaGallery
{
    DLog(@"dismissing media gallery");
    
    
    [self dismissViewControllerAnimated:YES completion:nil];
    //self.galleryViewController = nil;
}

- (void)deleteGalleryMedia:(PoiMedia *)media
{
    DLog(@"delete gallery media %@", [media.path lastPathComponent]);
    
    DLog(@"Asking create poi controller to handle parking and delete of visibile media");
    [self currentPoiRemoveMedia:media];
    
    DLog(@"delete completed, dismissing media gallery");
    [self dismissViewControllerAnimated:YES completion:nil];
    //self.galleryViewController = nil;
}


- (void)showMediaGalleryFromMedia:(PoiMedia *)media
{
    DLog(@"Init new modal gallery view controler for media %@", media);
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    GalleryViewController *galleryViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"GalleryViewController"];

    //self.galleryViewController = galleryViewController;
#warning lazy coding, should use a protocol!!
    galleryViewController.delegate = (IpadRightViewController *) self;
    galleryViewController.visibleMedia = media;
    
    
    [self presentViewController:galleryViewController animated:YES completion:nil];
    
    
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
        
        NSMutableSet *newPoiMedias = [self.tempPoi.media mutableCopy];
        [newPoiMedias removeObject:media];
        self.tempPoi.media = [NSSet setWithSet:newPoiMedias];
    }
    
    DLog(@"Saving core data context");
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    [self updateThumbnailsButtons];
    
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
        CLLocationCoordinate2D coords = CLLocationCoordinate2DMake([self.tempPoi.locationLat doubleValue], [self.tempPoi.locationLong doubleValue]);
     
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
    
    [self presentViewController:mapEditViewController animated:YES completion:nil];
}


#pragma mark Map Edit View Controller Delegate
- (void) mapEditDidCancel
{
    DLog(@"map edit canceled, dismissing modal view controller");
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) mapEditDidSavePlacemark:(MKPlacemark *)placemark
{
    DLog(@"map edit save, store new placemark and dismiss modal view controller");
    
    
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
            [annotation setTitle:self.tempPoi.title];
            [self.mapView addAnnotation:annotation];
        }
        
        //restart map updates for exif gps data for new camera shoots, also after manually editing address (lastlocation updated will be disabled by addressManuallyEntered flag)
        self.mapView.showsUserLocation = YES;
    }
    else
        DLog(@"Map edit saved but no placemark specified, just dismiss");
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
