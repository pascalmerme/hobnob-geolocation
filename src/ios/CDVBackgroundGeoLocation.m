////
//  CDVBackgroundGeoLocation
//
//  Created by Chris Scott <chris@transistorsoft.com> on 2013-06-15
//
#import "CDVLocation.h"
#import "CDVBackgroundGeoLocation.h"
#import <Cordova/CDVJSON.h>

@implementation CDVBackgroundGeoLocation {
    BOOL isDebugging;
    BOOL enabled;
    BOOL isUpdatingLocation;
    BOOL stopOnTerminate;

    NSString *token;
    NSString *url;
    UIBackgroundTaskIdentifier bgTask;
    NSDate *lastBgTaskAt;

    NSError *locationError;

    BOOL isMoving;

    NSNumber *maxBackgroundHours;
    CLLocationManager *locationManager;
    UILocalNotification *localNotification;

    CDVLocationData *locationData;
    CLLocation *lastLocation;
    NSMutableArray *locationQueue;

    NSDate *suspendedAt;

    CLLocation *stationaryLocation;
    CLCircularRegion *stationaryRegion;
    NSInteger locationAcquisitionAttempts;

    BOOL isAcquiringStationaryLocation;
    NSInteger maxStationaryLocationAttempts;

    BOOL isAcquiringSpeed;
    NSInteger maxSpeedAcquistionAttempts;

    NSInteger stationaryRadius;
    NSInteger distanceFilter;
    NSInteger locationTimeout;
    NSInteger desiredAccuracy;
    CLActivityType activityType;
}

@synthesize syncCallbackId;
@synthesize stationaryRegionListeners;

- (void)pluginInitialize
{
    // background location cache, for when no network is detected.
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;

    localNotification = [[UILocalNotification alloc] init];
    localNotification.timeZone = [NSTimeZone defaultTimeZone];

    locationQueue = [[NSMutableArray alloc] init];

    isMoving = NO;
    isUpdatingLocation = NO;
    stationaryLocation = nil;
    stationaryRegion = nil;
    isDebugging = NO;
    stopOnTerminate = NO;

    maxStationaryLocationAttempts   = 4;
    maxSpeedAcquistionAttempts      = 3;

    bgTask = UIBackgroundTaskInvalid;
}
/**
 * configure plugin
 * @param {String} token
 * @param {String} url
 * @param {Number} stationaryRadius
 * @param {Number} distanceFilter
 * @param {Number} locationTimeout
 */
- (void) configure:(CDVInvokedUrlCommand*)command
{
    stationaryRadius    = [[command.arguments objectAtIndex: 3] intValue];
    distanceFilter      = [[command.arguments objectAtIndex: 4] intValue];
    locationTimeout     = [[command.arguments objectAtIndex: 5] intValue];
    desiredAccuracy     = [self decodeDesiredAccuracy:[[command.arguments objectAtIndex: 6] intValue]];
    stopOnTerminate     = [[command.arguments objectAtIndex: 11] boolValue];
    activityType        = [self decodeActivityType:[command.arguments objectAtIndex:10]];

    self.syncCallbackId = command.callbackId;

    locationManager.activityType = activityType;
    locationManager.pausesLocationUpdatesAutomatically = YES;
    locationManager.distanceFilter = distanceFilter; // meters
    locationManager.desiredAccuracy = desiredAccuracy;
    
    NSLog(@"CDVBackgroundGeoLocation configure");
    NSLog(@"  - token: %@", token);
    NSLog(@"  - url: %@", url);
    NSLog(@"  - distanceFilter: %ld", (long)distanceFilter);
    NSLog(@"  - stationaryRadius: %ld", (long)stationaryRadius);
    NSLog(@"  - locationTimeout: %ld", (long)locationTimeout);
    NSLog(@"  - desiredAccuracy: %ld", (long)desiredAccuracy);
    NSLog(@"  - activityType: %@", [command.arguments objectAtIndex:7]);
    NSLog(@"  - debug: %d", isDebugging);
    NSLog(@"  - stopOnTerminate: %d", stopOnTerminate);
}

-(NSInteger)decodeDesiredAccuracy:(NSInteger)accuracy
{
    switch (accuracy) {
        case 1000:
            accuracy = kCLLocationAccuracyKilometer;
            break;
        case 100:
            accuracy = kCLLocationAccuracyHundredMeters;
            break;
        case 10:
            accuracy = kCLLocationAccuracyNearestTenMeters;
            break;
        case 0:
            accuracy = kCLLocationAccuracyBest;
            break;
        default:
            accuracy = kCLLocationAccuracyHundredMeters;
    }
    return accuracy;
}

-(CLActivityType)decodeActivityType:(NSString*)name
{
    if ([name caseInsensitiveCompare:@"AutomotiveNavigation"]) {
        return CLActivityTypeAutomotiveNavigation;
    } else if ([name caseInsensitiveCompare:@"OtherNavigation"]) {
        return CLActivityTypeOtherNavigation;
    } else if ([name caseInsensitiveCompare:@"Fitness"]) {
        return CLActivityTypeFitness;
    } else {
        return CLActivityTypeOther;
    }
}

/**
 * Turn on background geolocation
 */
- (void) start:(CDVInvokedUrlCommand*)command
{
    enabled = YES;

    NSLog(@"- CDVBackgroundGeoLocation start (background? %d)", state);

    [locationManager startMonitoringSignificantLocationChanges];
    
    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}
/**
 * Turn it off
 */
- (void) stop:(CDVInvokedUrlCommand*)command
{
    NSLog(@"- CDVBackgroundGeoLocation stop");
    enabled = NO;

    [self stopUpdatingLocation];
    [locationManager stopMonitoringSignificantLocationChanges];

    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

-(NSMutableDictionary*) locationToHash:(CLLocation*)location
{
    NSMutableDictionary *returnInfo;
    returnInfo = [NSMutableDictionary dictionaryWithCapacity:10];

    NSNumber* timestamp = [NSNumber numberWithDouble:([location.timestamp timeIntervalSince1970] * 1000)];
    [returnInfo setObject:timestamp forKey:@"timestamp"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.speed] forKey:@"speed"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.verticalAccuracy] forKey:@"altitudeAccuracy"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"accuracy"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.course] forKey:@"heading"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.altitude] forKey:@"altitude"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
    [returnInfo setObject:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];

    return returnInfo;
}
/**
 * Called by js to signify the end of a background-geolocation event
 */
-(void) finish:(CDVInvokedUrlCommand*)command
{
    NSLog(@"- CDVBackgroundGeoLocation finish");
    [self stopBackgroundTask];
}

/**@
 * Termination. Checks to see if it should turn off
 */
-(void) onAppTerminate
{
    NSLog(@"- CDVBackgroundGeoLocation appTerminate");
    if (enabled && stopOnTerminate) {
        NSLog(@"- CDVBackgroundGeoLocation stoping on terminate");

        enabled = NO;
        isMoving = NO;

        [self stopUpdatingLocation];
        [locationManager stopMonitoringSignificantLocationChanges];
        if (stationaryRegion != nil) {
            [locationManager stopMonitoringForRegion:stationaryRegion];
            stationaryRegion = nil;
        }
    }
}


-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"- CDVBackgroundGeoLocation didUpdateLocations (isMoving: %d)", isMoving);

    locationError = nil;

    CLLocation *location = [locations lastObject];

    // test the age of the location measurement to determine if the measurement is cached
    // in most cases you will not want to rely on cached measurements
    if ([self locationAge:location] > 5.0) return;

    // test that the horizontal accuracy does not indicate an invalid measurement
    if (location.horizontalAccuracy < 0) return;

    bgTask = [self createBackgroundTask];
    [self.commandDelegate runInBackground:^{
        NSMutableDictionary *data = [self locationToHash:location];
        CDVPluginResult* result = nil;
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:self.syncCallbackId];
    }];
}

-(UIBackgroundTaskIdentifier) createBackgroundTask
{
    lastBgTaskAt = [NSDate date];
    return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self stopBackgroundTask];
    }];
}

- (void) stopBackgroundTask
{
    UIApplication *app = [UIApplication sharedApplication];
    NSLog(@"- CDVBackgroundGeoLocation stopBackgroundTask (remaining t: %f)", app.backgroundTimeRemaining);
    if (bgTask != UIBackgroundTaskInvalid)
    {
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"- CDVBackgroundGeoLocation locationManager failed:  %@", error);

    locationError = error;
}

/**
 * If you don't stopMonitoring when application terminates, the app will be awoken still when a
 * new location arrives, essentially monitoring the user's location even when they've killed the app.
 * Might be desirable in certain apps.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
    [locationManager stopMonitoringSignificantLocationChanges];
}

- (void)dealloc
{
    locationManager.delegate = nil;
}

@end
