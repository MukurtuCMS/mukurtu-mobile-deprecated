//
//  IpadRightViewController.m
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
#import <CoreLocation/CoreLocation.h>

#import "IpadRightViewController.h"
#import "MainIpadViewController.h"
#import "CreatePoiViewController.h"

#import "Poi.h"
#import "PoiMedia.h"

#import "MukurtuSession.h"
#import "GalleryViewController.h"

#import "PoiClassBasedMapAnnotation.h"

@import CoreLocation;


@interface IpadRightViewController ()<CreatePoiPopoverDelegate, MKMapViewDelegate, UIPopoverControllerDelegate, CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet MKMapView *mainMapView;
@property (weak, nonatomic) IBOutlet UIButton *zoomToFitButton;
@property (weak, nonatomic) IBOutlet UIButton *overlayCreateButton;

@property (strong,nonatomic) UIPopoverController *createPoiPopoverController;
@property (weak, nonatomic) CreatePoiViewController *createPoiController;

@property (strong, nonatomic) UIPopoverController *galleryPopoverController;

//@property (nonatomic, strong) CLLocation *lastLocationFound;
@property (nonatomic, assign) CLLocationCoordinate2D lastMapCenterWithoutOffset;

@property (strong, nonatomic) CLLocationManager *locationManager;


@end

@implementation IpadRightViewController

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
    
    [self updateOverlayButtons];
    
    [self.mainMapView setVisibleMapRect:MKMapRectWorld];
    
    [self initMainMap];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

////Popover handling
#pragma mark - popover handling
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return NO;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    
    
    /*
     - fix rotation while recording (important) ok
     - fix rotation while image preview ok
     - fix rotation while edit map ok
     - fix rotation while image picker not implemented
     - fix rotation while taking photo to test
     */

    DLog(@"rotation detected, redrawing views");
    
    //FIX 2.5: dirty force update costraints (wihtout this on ios8 does not work well when drawing imagepicker popover)
    DLog(@"Force update costraint on right view controller");
    [self.mainViewController updateViewConstraints];
    
    if (self.createPoiPopoverController.popoverVisible && !self.createPoiController.takingPhoto)
    {
        //dismiss media picker controller if present
        [self.createPoiController dismissPickerPopoverController];
        
        [self.createPoiPopoverController dismissPopoverAnimated:NO];
        
        
        //FIX 2.5: use member to address create poi controller
        if (self.createPoiController.isEditingPoi)
        {
            [self centerMapAndDrawPopover:self.createPoiPopoverController forPoi:self.createPoiController.currentPoi animated:YES];
        }
        else
        {
            //center on user location
            [self centerMapInUserLocationAndDrawPopover:self.createPoiPopoverController animated:YES];
        }
        
        //FIX 2.5: not needed using nav controller
        //redraw map edit controller if visible
        //[self.createPoiController redrawMapEditPopoverController];
        
        //redraw audio controller if visibile
        [self.createPoiController redrawAudioRecorderPopoverController];
        
    }
    
    [self updateOverlayButtons];
}

- (void) updateOverlayButtons
{
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        //portrait, show create button
        self.overlayCreateButton.hidden = NO;
    }
    else
    {
        self.overlayCreateButton.hidden = YES;
    }

}


- (void)centerMapInUserLocationAndDrawPopover:(UIPopoverController *)popover animated:(BOOL)animated
{
    CLLocationCoordinate2D newMapCenter = self.mainMapView.centerCoordinate;
    
    if ([self isValidLocation:self.mainMapView.userLocation.location])
    {
        newMapCenter = self.mainMapView.userLocation.coordinate;
        DLog(@"userLocation coords %f,%f", self.mainMapView.userLocation.coordinate.latitude,self.mainMapView.userLocation.coordinate.longitude);
    }
    
    [self centerMapAndDrawPopover:popover centerLocation:newMapCenter animated:animated];

}

- (void)centerMapAndDrawPopover:(UIPopoverController *)popover forPoi:(Poi*)poi animated:(BOOL)animated
{
    //CLLocationCoordinate2D newMapCenter = self.mainMapView.centerCoordinate;
    CLLocationCoordinate2D newMapCenter = self.lastMapCenterWithoutOffset;
    CLLocationCoordinate2D poiLocation;
    
    if (poi != nil)
    {
        poiLocation = CLLocationCoordinate2DMake([poi.locationLat doubleValue], [poi.locationLong doubleValue]);
        
        if ([self isValidCoordinate:poiLocation])
        {
            newMapCenter = poiLocation;
        }
    }
    
    [self centerMapAndDrawPopover:popover centerLocation:newMapCenter animated:animated];
}


- (void)centerMapAndDrawPopover:(UIPopoverController *)popover centerLocation:(CLLocationCoordinate2D)location animated:(BOOL)animated
{
    DLog(@"calculating new map center and drawing popover");
    
    [self.mainMapView setRegion:MKCoordinateRegionMakeWithDistance(self.mainMapView.centerCoordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:NO];

    CGRect arrowRect;
    UIPopoverArrowDirection arrowDirection;
    //CLLocationCoordinate2D newMapCenter, poiLocation;
    
    CLLocationCoordinate2D newMapCenter = self.mainMapView.centerCoordinate;
    
    if ([self isValidCoordinate:location])
    {
        newMapCenter = location;
        self.lastMapCenterWithoutOffset = location;
    }
    
    
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        //portrait
        arrowRect = CGRectMake(CGRectGetMidX(self.view.frame), CGRectGetMaxY(self.view.frame)*kPinNewPoiMapYRatioPortrait, 1,1);
        arrowDirection = UIPopoverArrowDirectionDown;
        newMapCenter.latitude += self.mainMapView.region.span.latitudeDelta * kPinNewPoiMapYRatioPortrait - self.mainMapView.region.span.latitudeDelta/2.04;
    }
    else
    {
        //landscape
#warning Should create an empty row at top and point popover there
        arrowRect = CGRectMake(0.0, CGRectGetMidY(self.view.frame), 1,1);
        //arrowRect = CGRectMake(0.0, 70.0, 1,1);
        arrowDirection = UIPopoverArrowDirectionLeft;
        
        popover.popoverLayoutMargins = UIEdgeInsetsMake(80, 10, 10, 10);
        
        /*
         arrowRect = CGRectMake(CGRectGetMidX(self.view.frame), CGRectGetMaxY(self.view.frame)*kPinNewPoiMapYRatioLandscape, 1,1);
         arrowDirection = UIPopoverArrowDirectionDown;
         newMapCenter.latitude += self.mainMapView.region.span.latitudeDelta * kPinNewPoiMapYRatioLandscape - self.mainMapView.region.span.latitudeDelta/2;
         */
        
    }
    
    DLog(@"new map center coords %f,%f", newMapCenter.latitude, newMapCenter.longitude);
    
    
    [self.mainMapView setCenterCoordinate:newMapCenter animated:animated];
    
    
    [popover presentPopoverFromRect:arrowRect
                                      inView:self.view
                    permittedArrowDirections:arrowDirection animated:YES];
    
}


- (void)showCreatePoiPopover
{
    
    [self showCreatePoiPopoverForPoi:nil];
}

- (void) showCreatePoiPopoverForPoi:(Poi *)poi
{
    
    DLog(@"Show create poi popover, setting up");
    
    UIStoryboard *mainStoryboard = self.storyboard;
    CreatePoiViewController *createPoiViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"CreatePoiViewController"];
    
    createPoiViewController.currentPoi = poi;
    self.createPoiController = createPoiViewController;
    
    //FIX 2.5: embed in navigation controller to support multiple popover vc push on ios 8
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.createPoiController];
    
    //[navController.navigationBar setBarStyle:UIBarStyleBlack];
    [navController.navigationBar setTranslucent:NO];
    [navController.navigationBar setBarTintColor:kUIColorDarkBarBackground];

    //close button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_close90"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self.createPoiController
                                                                    action:@selector(closeButtonPressed:)];
    cancelButton.tintColor = [UIColor whiteColor];
    cancelButton.imageInsets = UIEdgeInsetsMake(5.0, -12.0, 0.0, 18.0);
    navController.navigationBar.topItem.leftBarButtonItem = cancelButton;
    
    //save button
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"SAVE-rett"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self.createPoiController
                                                                    action:@selector(saveButtonPressed:)];
    saveButton.imageInsets = UIEdgeInsetsMake(0.0, -16.0, 0.0, 16.0);
    navController.navigationBar.topItem.rightBarButtonItem = saveButton;
    
    
    //FIX 2.5: avoid resize of popover during dismiss/create (f.e. during interface rotation)
    navController.preferredContentSize = CGSizeMake(kCreatePoiIPadPreferredWidth, kCreatePoiIPadPreferredHeight);
    
    UIPopoverController *createPoiPopover = [[UIPopoverController alloc] initWithContentViewController:navController];
    
    createPoiPopover.delegate = self;
    createPoiViewController.delegate = self;

    self.createPoiPopoverController = createPoiPopover;
    
    if (poi != nil)
    {
        //editing poi, center on poi location
        [self centerMapAndDrawPopover:self.createPoiPopoverController forPoi:poi animated:NO];
    }
    else
    {
        //new poi, center on user location
        [self centerMapInUserLocationAndDrawPopover:self.createPoiPopoverController animated:NO];
    }
    
}

- (void)dismissMediaGallery
{
    DLog(@"dismissing media gallery");
 
    //FIX 2.5: using nav controller
    [self.createPoiController.navigationController popViewControllerAnimated:YES];
    
    //[self.galleryPopoverController dismissPopoverAnimated:YES];
}

- (void)deleteGalleryMedia:(PoiMedia *)media
{
    DLog(@"delete gallery media %@", [media.path lastPathComponent]);
    
    DLog(@"Asking create poi controller to handle parking and delete of visibile media");
    [self.createPoiController currentPoiRemoveMedia:media];
    
    DLog(@"delete completed, dismissing media gallery");
    
    //FIX 2.5: using nav controller
    [self.createPoiController.navigationController popViewControllerAnimated:YES];

    //[self.galleryPopoverController dismissPopoverAnimated:YES];
}

- (void)showMediaGalleryFromMedia:(PoiMedia *)media
{
    DLog(@"Init new modal gallery view controler");
    
#warning should dismiss keyboard if present
    //[self resignFirstResponder];
    
    UIStoryboard *sharedStoryboard = [UIStoryboard storyboardWithName:@"sharedUI" bundle:[NSBundle mainBundle]];
    GalleryViewController *galleryViewController = [sharedStoryboard instantiateViewControllerWithIdentifier:@"GalleryViewController"];
    galleryViewController.delegate = self;
    galleryViewController.visibleMedia = media;
    
    //FIX 2.5: uses nav controller and push view without creating another popover
    [self.createPoiController.navigationController pushViewController:galleryViewController animated:YES];
    
//    UIPopoverController *galleryPopover = [[UIPopoverController alloc] initWithContentViewController:galleryViewController];
//    galleryPopover.delegate = self;
//    galleryPopover.popoverContentSize = self.createPoiController.view.frame.size;
//    self.galleryPopoverController = galleryPopover;
//    
//    //UIImage *photo = [UIImage imageWithContentsOfFile:media.path];
//    //[galleryViewController.imageView setImage:photo];
//    
//    //Poi *poi = media.parent;
//    Poi *poi = self.createPoiController.currentPoi;
//    
//    if (poi != nil)
//    {
//        //editing poi, center on poi location
//        [self centerMapAndDrawPopover:galleryPopover forPoi:poi animated:YES];
//    }
//    else
//    {
//        //new poi, center on user location
//        [self centerMapInUserLocationAndDrawPopover:galleryPopover animated:YES];
//    }
    
    
    //[self presentViewController:galleryViewController animated:YES completion:nil];
    
}


- (void)createPoiCloseButtonPressed
{
    DLog(@"Received close button message from create poi view controller");
    
    [self.createPoiPopoverController dismissPopoverAnimated:YES];
    
    //FIX 2.5: release any reference to create poi controller after dismiss
    self.createPoiController = nil;
    self.createPoiPopoverController = nil;
}

- (void)savePoiCloseButtonPressed
{
    DLog(@"Received save button message from create poi view controller");
    
    DLog(@"Saving core data context");
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    //ask refresh of poi list
    //[self.mainViewController reloadPoiTable];
    
    [self resetMainMapAnnotations];
    
    //Validate all poi to lazy check the new poi, more robust than checking single poi
    [[MukurtuSession sharedSession] validateAllPois];
    [self.mainViewController reloadPoiTable];
    
    [self.createPoiPopoverController dismissPopoverAnimated:YES];
    
    //FIX 2.5: release any reference to create poi controller after dismiss
    self.createPoiController = nil;
    self.createPoiPopoverController = nil;
}


//Main map handling
#pragma mark - Main Map Handling
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
            if (self.mainMapView != nil)
            {
                self.mainMapView.showsUserLocation = YES;
            }
        }
    }
    else if(status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        DLog(@"Autorization status kCLAuthorizationStatusAuthorized or kCLAuthorizationStatusAuthorizedWhenInUse");
        if (self.mainMapView != nil)
        {
            self.mainMapView.showsUserLocation = YES;
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
    
    if ((status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedWhenInUse) && self.mainMapView != nil)
    {
        self.mainMapView.showsUserLocation = YES;
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
    if ((coordinate.longitude < 180) && (coordinate.longitude > -180) &&
        (coordinate.latitude < 90) && (coordinate.latitude > -90))
        return YES;
    else
        return NO;
}

-(void) initMainMap
{
    DLog(@"Init main map");
    //self.mainMapView.showsUserLocation = YES;
    DLog(@"map user location lat:%f long: %f", self.mainMapView.userLocation.coordinate.latitude, self.mainMapView.userLocation.coordinate.longitude);
   
    /*
    if ([self isValidLocation:self.mainMapView.userLocation.location])
    {
        self.lastLocationFound = self.mainMapView.userLocation.location;
        DLog(@"Last location saved %@", [self.lastLocationFound description]);
        
        
        [self.mainMapView setRegion:MKCoordinateRegionMakeWithDistance(self.mainMapView.userLocation.coordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
        
    }
    else
    {
        //just set zoom level
        //[self.mainMapView setRegion:MKCoordinateRegionMakeWithDistance(self.mainMapView.centerCoordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
        [self.mainMapView setVisibleMapRect:MKMapRectWorld];
    }
*/
    
    
    NSArray *poiList = [[Poi MR_findAllSortedBy:@"timestamp" ascending:NO] copy];
    
    for (Poi *poi in poiList)
    {
        [self addPinForPoi:poi];
    }
    
    [self zoomToFitMapAnnotations:self.mainMapView animated:YES];
    
    self.mainMapView.zoomEnabled = YES;
}

- (void) addPinForPoi:(Poi *)poi
{
    DLog(@"Adding pin for poi %@", poi.title);
    if (poi.locationLat && poi.locationLong)
    {
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([poi.locationLat doubleValue], [poi.locationLong doubleValue]);
        
        
        //MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
        //[annotation setCoordinate:coordinate];
        //[annotation setTitle:poi.title];
        
        PoiClassBasedMapAnnotation *annotation = [[PoiClassBasedMapAnnotation alloc] initWithTitle:poi.title subtitle:poi.formattedAddress coordinate:coordinate] ;
        
        [self.mainMapView addAnnotation:annotation];
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    self.lastMapCenterWithoutOffset = mapView.centerCoordinate;
    DLog(@"Map changed, new center %@", NSStringFromCGPoint(CGPointMake(self.lastMapCenterWithoutOffset.latitude, self.lastMapCenterWithoutOffset.longitude)));
}

/*
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    DLog(@"Map updated user location");
    
    
    
}*/

/*
- (void) centerAndZoomToUserLocation
{
    DLog(@"Center and zoom to user location");
    
    if ([self isValidLocation:self.mainMapView.userLocation.location])
    {
        //show location accuracy
        NSArray *overlays = [self.mainMapView overlays];
        if ([overlays count])
            [self.mainMapView removeOverlays:overlays];
        
        [self.mainMapView addOverlay:[MKCircle circleWithCenterCoordinate:self.mainMapView.userLocation.location.coordinate radius:self.mainMapView.userLocation.location.horizontalAccuracy]];
        
        self.lastLocationFound = self.mainMapView.userLocation.location;
        DLog(@"Last location saved %@", [self.lastLocationFound description]);
        
        //if position is already visible, just update center without changing zoom level
        if (!self.mainMapView.userLocationVisible)
        {
            [self.mainMapView setCenterCoordinate:self.mainMapView.userLocation.location.coordinate animated:NO];
        }
    }
}
*/

- (void) restartMapUserLocationUpdate
{
    //trick the map view to restart updating position
    if (self && self.mainMapView != nil)
    {
        self.mainMapView.showsUserLocation = NO;
        self.mainMapView.showsUserLocation = YES;
    }
}

/*
-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:(MKCircle *)overlay];
    circleView.fillColor = [UIColor  lightGrayColor];
    circleView.alpha = 0.3;
    
    return circleView;
}*/


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
            
            //TODO: choose pin based on poi type
            //customPinView.image = [UIImage imageNamed:@"pin_generic.png"];
            //DLog(@"new user location pin %@", [customPinView description]);
            customPinView = nil;
        }
        else
            customPinView.image = [UIImage imageNamed:@"POI_arancio.png"];
        
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

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    static NSString *identifier = @"PoiClassBasedMapAnnotation";
    if ([annotation isKindOfClass:[PoiClassBasedMapAnnotation class]]) {
        
        MKAnnotationView *annotationView = (MKAnnotationView *) [self.mainMapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (annotationView == nil) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView.enabled = YES;
            annotationView.canShowCallout = YES;
            annotationView.image = [UIImage imageNamed:@"POI_arancio_small"];
            annotationView.centerOffset = CGPointMake(1.0, -(annotationView.image.size.height / 3));
            
            
            
#warning should add button and handle tap to edit poi
            //UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            //UIImage *image = [UIImage imageNamed:@"btn_tondo_map.png"];
            //button.bounds = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
            //[button setImage:image forState:UIControlStateNormal];
            //annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            //annotationView.rightCalloutAccessoryView = button;
        } else {
            annotationView.annotation = annotation;
        }
        
        return annotationView;
    }
    
    return nil;
}


-(void)resetMainMapAnnotations
{
    //reset all annotations
    DLog(@"Reset and refresh all map annotations");
    [self.mainMapView removeAnnotations:self.mainMapView.annotations];
    
    [self initMainMap];
}

-(void)zoomToFitMapAnnotations:(MKMapView*)mapView animated:(BOOL)animated
{
    
    DLog(@"Zoom to fit all poi annotation");
    
    MKMapRect zoomRect = MKMapRectNull;
    for (id <MKAnnotation> annotation in mapView.annotations)
    {
        MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
        MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0.1, 0.1);
        zoomRect = MKMapRectUnion(zoomRect, pointRect);
    }
    
    //DLog(@"Minimum zoom rect %@",NSStringFromCGRect(CGRectMake(zoomRect.origin.x, zoomRect.origin.y, zoomRect.size.width, zoomRect.size.width)));
    
    //[mapView setVisibleMapRect:zoomRect edgePadding:UIEdgeInsetsZero animated:animated];
    [mapView setVisibleMapRect:zoomRect edgePadding:UIEdgeInsetsMake(30, 30, 30, 30) animated:animated];
    
    self.lastMapCenterWithoutOffset = mapView.centerCoordinate;
    
}

- (IBAction)zoomToFitButtonPressed:(id)sender
{
    [self zoomToFitMapAnnotations:self.mainMapView animated:YES];
}

- (IBAction)overlayCreateButtonPressed:(id)sender
{
    [self.mainViewController createPoiButtonPressed:nil];
}

@end
