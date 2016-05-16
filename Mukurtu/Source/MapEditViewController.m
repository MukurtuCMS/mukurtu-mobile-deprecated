//
//  MapEditViewController.m
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

#import "MapEditViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "PlaceAnnotation.h"


#define SHOWPINONMAP

@interface MapEditViewController ()<CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate>
{
    BOOL _mapUpdatePosition;
    BOOL _geocodingAddressFound;
}

@property (nonatomic, assign) MKCoordinateRegion boundingRegion;

@property (nonatomic, strong) MKLocalSearch *localSearch;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic) CLLocationCoordinate2D userLocation;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@property(strong, nonatomic) CLLocation *lastLocationFound;
@property(strong, nonatomic) CLGeocoder *geocoder;

@property(strong, nonatomic) MKPlacemark *lastPlacemarkFound;
@end

@implementation MapEditViewController

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

    //hides back button on ipad while using nav controller to push map edit view
    [self.navigationItem setHidesBackButton:YES];

    // start by locating user's current position
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	[self.locationManager startUpdatingLocation];

    //geocoding
    self.geocoder = [[CLGeocoder alloc] init];
    
    UIPanGestureRecognizer* panRec = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didMoveMap:)];
    [panRec setDelegate:self];
    [self.mapView addGestureRecognizer:panRec];

    UIPinchGestureRecognizer *pinchRec = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didMoveMap:)];
    [pinchRec setDelegate:self];
    [self.mapView addGestureRecognizer:pinchRec];
    
    //init map here
    if (CLLocationCoordinate2DIsValid(self.initialLocationCoordinate))
    {

        DLog(@"Init map and adress bar with initial values: coord lat %f, lon %f , address: %@", self.initialLocationCoordinate.latitude,
             self.initialLocationCoordinate.latitude, self.initialAddress);
        
        _mapUpdatePosition = NO;
        
        self.addressLabel.text = self.initialAddress;
        
#ifdef SHOWPINONMAP
        [self.mapView removeAnnotations:self.mapView.annotations];
        
        // add the single annotation to our map
        PlaceAnnotation *annotation = [[PlaceAnnotation alloc] init];
        annotation.coordinate = self.initialLocationCoordinate;
        annotation.title = self.initialAddress;
        annotation.url = nil;
        [self.mapView addAnnotation:annotation];
        
        // we have only one annotation, select it's callout
        [self.mapView selectAnnotation:[self.mapView.annotations objectAtIndex:0] animated:YES];
#endif
        
        [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(self.initialLocationCoordinate, kMapIpadDefaultZoomDistanceMeters, kMapIpadDefaultZoomDistanceMeters) animated:YES];
        
    }
    else
        [self.mapView setVisibleMapRect:MKMapRectWorld];
    
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)didMoveMap:(UIGestureRecognizer*)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
        DLog(@"map drag/pinch started, enabling geocoding for new center");
        _mapUpdatePosition = YES;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.locationManager stopUpdatingLocation];
    [self.geocoder cancelGeocode];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
}


#pragma mark - UISearchBarDelegate
- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];

    self.saveButton.hidden = YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
    
    self.saveButton.hidden = NO;
}

- (void)startSearch:(NSString *)searchString
{
    if (self.localSearch.searching)
    {
        [self.localSearch cancel];
    }
    
    // confine the map search area to the user's current location
    MKCoordinateRegion newRegion;
    newRegion.center.latitude = self.userLocation.latitude;
    newRegion.center.longitude = self.userLocation.longitude;
    
    // setup the area spanned by the map region:
    // we use the delta values to indicate the desired zoom level of the map,
    //      (smaller delta values corresponding to a higher zoom level)
    //
    newRegion.span.latitudeDelta = 0.112872;
    newRegion.span.longitudeDelta = 0.109863;
    
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    
    request.naturalLanguageQuery = searchString;
    request.region = newRegion;
    
    MKLocalSearchCompletionHandler completionHandler = ^(MKLocalSearchResponse *response, NSError *error)
    {
        if (error != nil)
        {
            NSString *errorStr = [[error userInfo] valueForKey:NSLocalizedDescriptionKey];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Could not find address"
                                                            message:errorStr
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            DLog(@"First matching address found %@", [[response mapItems][0] description]);
            
            self.boundingRegion = response.boundingRegion;
            MKMapItem *mapItem = [response mapItems][0];
            
            self.lastLocationFound = mapItem.placemark.location;
            DLog (@"placemark location %@", [self.lastLocationFound description]);
            
            //customize placemark before formatting
            MKPlacemark *placemark = mapItem.placemark;
            DLog (@"placemark address dictionary %@", [placemark.addressDictionary description]);
            
            NSString *currentLocationAddress = [self getAddressStringFromPlacemark:placemark];
             
            self.addressLabel.text = currentLocationAddress;
            
            //FIXED bug in empty coordinates after search
            MKPlacemark *mergePlacemark = [[MKPlacemark alloc] initWithCoordinate:self.lastLocationFound.coordinate
                                                                addressDictionary:placemark.addressDictionary];
            self.lastPlacemarkFound = mergePlacemark;
            
#ifdef SHOWPINONMAP
            [self.mapView removeAnnotations:self.mapView.annotations];

            // add the single annotation to our map
            PlaceAnnotation *annotation = [[PlaceAnnotation alloc] init];
            annotation.coordinate = placemark.location.coordinate;
            annotation.title = mapItem.name;
            annotation.url = mapItem.url;
            [self.mapView addAnnotation:annotation];
            
            // we have only one annotation, select it's callout
            [self.mapView selectAnnotation:[self.mapView.annotations objectAtIndex:0] animated:YES];
#endif
            // center the region around this map item's coordinate
            _mapUpdatePosition = NO;
            //self.mapView.centerCoordinate = mapItem.placemark.coordinate;
            self.mapView.centerCoordinate = placemark.location.coordinate;
        }
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    };
    
    if (self.localSearch != nil)
    {
        self.localSearch = nil;
    }
    self.localSearch = [[MKLocalSearch alloc] initWithRequest:request];
    
    [self.localSearch startWithCompletionHandler:completionHandler];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    // check to see if Location Services is enabled, there are two state possibilities:
    // 1) disabled for entire device, 2) disabled just for this app
    NSString *causeStr = nil;
    
    // check whether location services are enabled on the device
    if ([CLLocationManager locationServicesEnabled] == NO)
    {
        causeStr = @"device";
    }
    // check the application’s explicit authorization status:
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
    {
        causeStr = @"app";
    }
    else
    {
        // we are good to go, start the search
        [self startSearch:searchBar.text];
        [searchBar resignFirstResponder];
    }
    
    if (causeStr != nil)
    {
        NSString *alertMessage = [NSString stringWithFormat:@"You currently have location services disabled for this %@. Please refer to \"Settings\" app to turn on Location Services.", causeStr];
        
        UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                                                        message:alertMessage
                                                                       delegate:nil
                                                              cancelButtonTitle:@"OK"
                                                              otherButtonTitles:nil];
        [servicesDisabledAlert show];
    }
}


#pragma mark - CLLocationManagerDelegate methods
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    // remember for later the user's current location
    self.userLocation = newLocation.coordinate;
    
	[manager stopUpdatingLocation]; // we only want one update
    
    manager.delegate = nil;         // we might be called again here, even though we
    // called "stopUpdatingLocation", remove us as the delegate to be sure
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    // report any errors returned back from Location Services
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	MKPinAnnotationView *annotationView = nil;
	if ([annotation isKindOfClass:[PlaceAnnotation class]])
	{
		annotationView = (MKPinAnnotationView *)[self.mapView dequeueReusableAnnotationViewWithIdentifier:@"Pin"];
		if (annotationView == nil)
		{
			annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin"];
			annotationView.canShowCallout = YES;
			annotationView.animatesDrop = YES;
		}
	}
	return annotationView;
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
        currentLocationAddress = [placemark.addressDictionary valueForKey:@"Name"];
    }
    
    return currentLocationAddress;
}

- (void)mapView:(MKMapView *)aMapView regionDidChangeAnimated:(BOOL)animated
{
    DLog(@"map did change");
    
    //map have been really moved, not called if just loaded from edit view controller
    if (_mapUpdatePosition)
    {
        //start geocoding and check for address
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

        if (!self.geocoder.geocoding)
        {
            CLLocation *centerLocation = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.latitude
                                                                    longitude:self.mapView.centerCoordinate.longitude];
         
            self.lastLocationFound = centerLocation;
            
            [self.geocoder reverseGeocodeLocation:centerLocation
                                completionHandler:^(NSArray *placemarks, NSError *error)
             {
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                 
                 if (error != nil)
                 {
                     CLLocation *lastLocation = self.mapView.userLocation.location;
                     NSString *message = [NSString stringWithFormat:kNewPoiGeocodingGenericError, lastLocation.coordinate.latitude, lastLocation.coordinate.longitude];
                     
                     [self.addressLabel setText:message];
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
                         _geocodingAddressFound = YES;
                         
                         MKPlacemark *mergePlacemark = [[MKPlacemark alloc] initWithCoordinate:self.lastLocationFound.coordinate
                                                                             addressDictionary:placemark.addressDictionary];
                         
                         self.lastPlacemarkFound = mergePlacemark;
                         
#ifdef SHOWPINONMAP
                         [self.mapView removeAnnotations:self.mapView.annotations];
                         
                         // add the single annotation to our map
                         PlaceAnnotation *annotation = [[PlaceAnnotation alloc] init];
                         //annotation.coordinate = placemark.location.coordinate;
                         annotation.coordinate = self.lastLocationFound.coordinate;
                         annotation.title = currentLocationAddress;
                         //annotation.url = mapItem.url;
                         [self.mapView addAnnotation:annotation];
                         
                         // we have only one annotation, select it's callout
                         [self.mapView selectAnnotation:[self.mapView.annotations objectAtIndex:0] animated:YES];
#endif
                     }
             }];
        }
    }
}

- (IBAction)cancelButtonPressed:(id)sender
{
    DLog(@"Cancel button pressed, ask dismiss map edit view controller");
    
    if (self.delegate)
        [self.delegate mapEditDidCancel];
}

- (IBAction)saveButtonPressed:(id)sender
{
    DLog(@"Save button pressed, ask save and dismiss map edit view controller");

    if (self.delegate)
        [self.delegate mapEditDidSavePlacemark:self.lastPlacemarkFound];

}

@end
