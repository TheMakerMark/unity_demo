#import "MapsyncWrapper.h"
#import <MapsyncLib/MapsyncLib-Swift.h>
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

@interface MapsyncWrapper()

@property (nonatomic, strong) MapSession *mapSession;
@property (nonatomic, strong) ARSession *session;
@property (nonatomic) Mode mode;
@property (nonatomic, strong) NSString *appId;
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *mapId;

@end

@implementation MapsyncWrapper

static MapsyncWrapper *instance = nil;
static NSString* unityCallbackGameObject = @"";
static NSString* assetLoadedCallback = @"";
static NSString* statusUpdatedCallback = @"";
static NSString* storePlacementCallback = @"";

+ (void)setUnityCallbackGameObject:(NSString *)objectName {
    unityCallbackGameObject = objectName;
}

+ (void)setStatusUpdatedCallbackFunction:(NSString *)functionName {
    statusUpdatedCallback = functionName;
}

+ (void)setAssetLoadedCallbackFunction:(NSString *)functionName {
    assetLoadedCallback = functionName;
}

+ (void)setStorePlacementCallbackFunction:(NSString*)functionName {
    storePlacementCallback = functionName;
}

+ (instancetype)sharedInstanceWithARSession:(ARSession *)session mapMode:(Mode)mode appId:(NSString*) appId mapId: (NSString*) mapId userId:(NSString*) userId developerKey: (NSString*) developerKey;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void)
                  {
                      instance = [[self alloc] initWithARSession:session mapMode:mode appId:appId mapId:mapId userId:userId developerKey:developerKey];
                  });
    
    return instance;
}

+ (instancetype)sharedInstance
{
    if (instance == nil)
    {
        NSLog(@"error: shared called before setup");
    }
    return instance;
}

- (instancetype)initWithARSession:(ARSession *)session appId:(NSString*) appId mapId: (NSString*) mapId userId:(NSString*) userId developerKey: (NSString*) developerKey;
{
    return [self initWithARSession:session mapMode:ModeMapping appId:appId mapId:mapId userId:userId developerKey:developerKey];
}

- (instancetype)initWithARSession:(ARSession *)session mapMode:(Mode)mode appId:(NSString*) appId mapId: (NSString*) mapId userId:(NSString*) userId developerKey: (NSString*) developerKey;
{
    self = [super init];
    if (self)
    {
        self.session = session;
        self.mode = mode;
        self.appId = appId;
        self.mapId = mapId;
        self.userId = userId;
    
        self.mapSession = [[MapSession alloc] initWithArSession:self.session mapMode:mode userID:self.userId mapID:self.mapId developerKey:developerKey assetsFoundCallback:^(NSArray<MapAsset *> * assets) {
            
            for (MapAsset *asset in assets)
            {
                NSError* error;
                NSDictionary* dict = [NSMutableDictionary dictionary];
                [dict setValue:asset.assetID forKey:@"assetId"];
                NSDictionary* pos = [NSMutableDictionary dictionary];
                [pos setValue:@(asset.position.x) forKey:@"x"];
                [pos setValue:@(asset.position.y) forKey:@"y"];
                [pos setValue:@(asset.position.z) forKey:@"z"];
                [dict setValue:@(asset.orientation) forKey:@"orientation"];
                [dict setValue:pos forKey:@"position"];
                
                NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                                   options:NSJSONWritingPrettyPrinted error:&error];
                
                NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSASCIIStringEncoding];
                
                NSLog(@"%@", json);
                UnitySendMessage([unityCallbackGameObject cStringUsingEncoding:NSASCIIStringEncoding], [assetLoadedCallback cStringUsingEncoding:NSASCIIStringEncoding], [json cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            
        } statusCallback:^(enum MapStatus mapStatus) {
            NSLog(@"mapStatus: %li", mapStatus);
            UnitySendMessage([unityCallbackGameObject cStringUsingEncoding:NSASCIIStringEncoding], [statusUpdatedCallback cStringUsingEncoding:NSASCIIStringEncoding], mapStatus);

        }];
    }
    
    return self;
}

- (void)uploadAssetWithID:(NSString *)assetID position:(SCNVector3)position orientation:(CGFloat)orientation
{
    if (self.mode != ModeMapping)
    {
        NSLog(@"Error, not in mapping mode");
        return;
    }
    
     MapAsset *asset = [[MapAsset alloc] init:assetID :position :orientation];
     BOOL result = [self.mapSession storePlacementWithAssets:@[asset] callback:^(BOOL stored)
      {
          NSLog(@"model stored: %i", stored);
          UnitySendMessage([unityCallbackGameObject cStringUsingEncoding:NSASCIIStringEncoding], [storePlacementCallback cStringUsingEncoding:NSASCIIStringEncoding], stored);
      }];
}

- (void) updateWithFrame:(ARFrame*)frame
{
    [self.mapSession updateWithFrame:frame];
}

@end
