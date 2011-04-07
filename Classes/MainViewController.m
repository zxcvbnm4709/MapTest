//
//  MainViewController.m
//
//  Created by Donie Kelly on 07 April '11

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <MediaPlayer/MediaPlayer.h>
#import "MainViewController.h"
#import "MKMapView+Additions.h"
#import "QuartzCore/QuartzCore.h"
#import "AppDelegate.h"

@interface MainViewController (PrivateMethods)
// Local function decelerations
@end

@implementation MainViewController

@synthesize mapView, googleLogo, viewToRotate;

#pragma mark -
#pragma mark Google Logo 
- (UIImageView *)relocateGoogleLogo 
{
	UIImageView *logo = [mapView googleLogo];
	if (logo == nil)
		return nil;
    else
        return logo;
}


#pragma mark -
#pragma mark LifeCycle
- (void)viewDidLoad
{
    [super viewDidLoad];
 
    gMainViewController = self;
    queueCompass = [[NSMutableArray alloc] init];
    
    if([CLLocationManager locationServicesEnabled] == NO)
    {
        NSLog(@"Location services not available");
    }
    else
    {
        gLocManager = [[CLLocationManager alloc] init];
        gLocManager.delegate = self;
        gLocManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        mapView.showsUserLocation = YES;
    }
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"locateme.png"] 
                                                               style:UIBarButtonItemStyleBordered 
                                                              target:self action:@selector(turnTrackingOn:)];
    self.navigationItem.leftBarButtonItem = button;
    [button release];
    
    // Zoom to Ireland
    MKCoordinateRegion newRegion;
    newRegion.center.latitude = 53.5;
    newRegion.center.longitude = -7.7;
    newRegion.span.latitudeDelta = 20.728;
    newRegion.span.longitudeDelta = 20.728;
    
    [mapView setRegion:newRegion animated:YES];
        
    // Make mapview larger than screen area so that it can rotate
    CGRect mapRect = mapView.frame;
    
    mapRect.origin.x = mapRect.origin.x - 140;
    mapRect.origin.y = mapRect.origin.y - 140;
    mapRect.size.width = mapRect.size.width + 280;
    mapRect.size.height = mapRect.size.height + 280;    
    
    mapView.frame = mapRect;
    
    // Take google logo from underlying maps
    googleLogo.image = [self relocateGoogleLogo].image;
}



-(void) rotateMapOff:(id)action
{

    gRotate = NO;
    [gLocManager stopUpdatingHeading];
    
    // Change icon in navigation bar
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"locateme.png"] 
                                                               style:UIBarButtonItemStyleBordered 
                                                              target:self action:@selector(turnTrackingOn:)];
    self.navigationItem.leftBarButtonItem = button;
    [button release];

    // Put map back to normal rotation
    [mapView setTransform:CGAffineTransformMakeRotation(0)];
    
    // Stop tracking user locaiton
    gTracking = NO;
        
    // Allow map to be scrolled and zoomed again
    mapView.scrollEnabled = YES;
    mapView.zoomEnabled = YES;
}

-(void) rotateMapOn:(id)action
{
    if([CLLocationManager headingAvailable])
    {
        gRotate = YES;
        [gLocManager startUpdatingHeading];
        
        // Change icon in navigation bar
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"compass_icon.png"] 
                                                                   style:UIBarButtonItemStyleDone 
                                                                  target:self action:@selector(rotateMapOff:)];
        self.navigationItem.leftBarButtonItem = button;
        [button release];
    }
    else // No heading in simulator so just turn off tracking mode
    {
        [self rotateMapOff:action];
    }
}

-(void) turnTrackingOn:(id)action
{
    // Change icon in navigation bar
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"locateme.png"] 
                                                               style:UIBarButtonItemStyleDone 
                                                              target:self action:@selector(rotateMapOn:)];
    self.navigationItem.leftBarButtonItem = button;
    [button release];
    
    // Jump to current position immdeiatly (don't wait for update from Core Location as it takes time)
    if([CLLocationManager locationServicesEnabled])
    {
        [mapView setCenterCoordinate:gLocManager.location.coordinate animated:YES];
    }
    // Start tracking user locaiton
    gTracking = YES;
    
    // Disable zooming and panning in tracking mode
    mapView.scrollEnabled = NO;
    mapView.zoomEnabled = NO;
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager
{
    return YES;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if(error.code == kCLErrorLocationUnknown)
        return;
    
    if(error.code == kCLErrorDenied)
    {
        NSLog(@"Location services disabled");
    }
    
    if(error.code == kCLErrorNetwork)
        NSLog(@"Network error in location services");
    
    if(error.code == kCLErrorHeadingFailure)
        NSLog(@"Heading cannot be determined");
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading
{
    if(gRotate)
    {
        int newHeading;
        int queuecount;
        
        newHeading = heading.trueHeading;
        [queueCompass addObject:[NSNumber numberWithInt:newHeading]];
        
        if([queueCompass count] > 10) [queueCompass removeObjectAtIndex:0];
        queuecount = [queueCompass count];
        
        NSEnumerator *e = [queueCompass objectEnumerator];
        NSNumber *sum;
        int oldd = 0 , newd, average =0;
        BOOL firstLoop = YES;
        while ((sum = [e nextObject])) 
        {
            newd = [sum intValue];
            if(firstLoop) {oldd = newd;firstLoop=NO;}
            
            if((newd +180) < oldd)
            {
                newd +=360; oldd = newd;
                average = average + newd;
                continue;
            }
            if((newd - 180) > oldd) 
            {
                newd -=360;oldd = newd;
                average = average + newd;
                continue;
            }
            
            average = average + newd;
            oldd = newd;
        }
        average = (average / queuecount) % 360;
        
        [gMainViewController.mapView setTransform:CGAffineTransformMakeRotation((-1 * average * M_PI) /180)];
    }
    else
        [gMainViewController.mapView setTransform:CGAffineTransformMakeRotation(0)];
}

#pragma mark -
#pragma mark Location Manager Delegate Objects
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    // throw away settings older than 10 seconds andaccuracy more than 500 meters
    NSTimeInterval timeDifference = [newLocation.timestamp timeIntervalSinceDate:oldLocation.timestamp];
    if(newLocation.horizontalAccuracy > 500  && timeDifference > 10)
    {
        NSLog(@"GPS reading are too coarse or too old");
        return;
    }
        
    // track user position
    if(gTracking)
    {
        CLLocation *center = newLocation;
        if([CLLocationManager locationServicesEnabled])
            [mapView setCenterCoordinate:center.coordinate animated:YES];        
    }
}

-(void) dealloc
{
    [viewToRotate release];
    [googleLogo release];
    [mapView release];
    [queueCompass release];
    [super dealloc];
}

@end




