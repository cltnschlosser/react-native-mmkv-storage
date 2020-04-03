#import "MMKVStorage.h"
#import <MMKV/MMKV.h>
#import "SecureStorage.h"
#import "IDStore.h"
#import "StorageIndexer.h"
#import "Getters.h"
#import "Setters.h"



@implementation MMKVStorage

const int DATA_TYPE_STRING = 1;

const  int DATA_TYPE_INT = 2;

const  int DATA_TYPE_BOOL = 3;

const  int DATA_TYPE_MAP = 4;

const  int DATA_TYPE_ARRAY = 5;

static dispatch_queue_t RCTGetMethodQueue()
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("MMKVStorage.Queue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

MMKV *mmkv;
SecureStorage *secureStorage;
IDStore *IdStore;
StorageIndexer *indexer;
Setters *setters;
Getters *getters;
NSMutableDictionary *mmkvMap;
NSString *defaultStorage = @"default";

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return RCTGetMethodQueue();
}

- (id)init
{
    self = [super init];
    if (self) {
        [MMKV initialize];
        secureStorage = [[SecureStorage alloc]init];
        IdStore = [[IDStore alloc] initWithMMKV:[MMKV mmkvWithID:@"mmkvIdStore"]];
        indexer = [[StorageIndexer alloc] init];
        mmkvMap = [NSMutableDictionary dictionary];
        setters = [[Setters init] alloc];
        getters = [[Getters init] alloc];
    }
    
    return self;
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

#pragma mark setupLibraryWithInstanceIDAndEncryption
RCT_EXPORT_METHOD(setupLibraryWithInstanceIDAndEncryption:(NSString *)ID
                  mode:(nonnull NSNumber *)mode
                  alias:(NSString *)alias
                  cryptKey:(NSString *)cryptKey
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    MMKV *kv;
    
    if ([ID isEqualToString:@"default"]) {
        callback(@[@"default ID is reserved", [NSNull null] ]);
        return;
    }
    
    NSData *key = [cryptKey dataUsingEncoding:NSUTF8StringEncoding];
    if ([mode isEqualToNumber:@1]) {
        kv = [MMKV mmkvWithID:ID cryptKey:key mode:MMKVSingleProcess];
    } else {
        kv = [MMKV mmkvWithID:ID cryptKey:key mode:MMKVMultiProcess];
    }
    
    if ([IdStore exists:ID]) {
        [IdStore add:ID encrypted:true alias:alias];
        [kv setBool:true forKey:ID];
        [mmkvMap setObject:kv forKey:ID];
        callback(@[[NSNull null]  , @YES ]);
    } else {
        
        if ([kv containsKey:ID]) {
            [mmkvMap setObject:kv forKey:ID];
            callback(@[[NSNull null]  , @YES ]);
        } else {
            
         [self encryptionHandler:ID mode:mode callback:callback];
            
        }
    }
}


#pragma mark setupLibraryWithInstanceID
RCT_EXPORT_METHOD(setupLibraryWithInstanceID:(NSString *)ID
                  mode:(nonnull NSNumber *)mode
                  callback:(RCTResponseSenderBlock)callback
                  ) {

    if ([IdStore exists:ID]) {
        MMKV *kv;
        if ([mode isEqualToNumber:@1]) {
               kv = [MMKV mmkvWithID:ID mode:MMKVSingleProcess];
           } else {
               kv = [MMKV mmkvWithID:ID mode:MMKVMultiProcess];
           }
         [mmkvMap setObject:kv forKey:ID];
        [IdStore add:ID encrypted:false alias:NULL];
        callback(@[[NSNull null], @YES]);
    } else {
        
        [self encryptionHandler:ID mode:mode callback:callback];
        
    }
}

#pragma mark getAllMMKVInstanceIDs
RCT_EXPORT_METHOD(getAllMMKVInstanceIDs:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject ) {
    
    NSMutableDictionary *ids = [IdStore getAll];
    resolve(ids);
}


#pragma mark getCurrentMMKVInstanceIDs
RCT_EXPORT_METHOD(getCurrentMMKVInstanceIDs:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject ) {
    
    NSArray *ids = [mmkvMap allKeys];
    resolve(ids);
}

#pragma mark setStringAsync
RCT_EXPORT_METHOD(setStringAsync:(NSString *)ID
                  key:(NSString*)key
                  value:(NSString*)value
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    [setters setItemAsync:ID key:key  type:DATA_TYPE_STRING string:value boolean:false number:NULL map:NULL mmkvMap:mmkvMap resolve:resolve rejecter:reject];
}

#pragma mark setString
RCT_EXPORT_METHOD(setString:(NSString *)ID
                  key:(NSString*)key
                  value:(NSString*)value
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    
    [setters setItem:ID key:key type:DATA_TYPE_STRING string:value boolean:false number:NULL map:NULL mmkvMap:mmkvMap callback:callback];
}

#pragma mark getItemAsync
RCT_EXPORT_METHOD(getItemAsync:(NSString *)ID
                  key:(NSString*)key
                  type:(nonnull NSNumber *)type
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [getters getItemAsync:ID key:key type:type mmkvMap:mmkvMap resolve:resolve rejecter:reject];
    
}

#pragma mark getItem
RCT_EXPORT_METHOD(getItem:(NSString *)ID
                  key:(NSString*)key
                  type:(nonnull NSNumber *)type
                  callback:(RCTResponseSenderBlock)callback) {
    
    [getters getItem:ID key:key type:type mmkvMap:mmkvMap callback:callback];
}

#pragma mark setIntAsync
RCT_EXPORT_METHOD(setIntAsync:(NSString *)ID key:(NSString*)key
                  value:(nonnull NSNumber*)value
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    [setters setItemAsync:ID key:key type:DATA_TYPE_INT string:NULL boolean:false number:value map:NULL mmkvMap:mmkvMap  resolve:resolve rejecter:reject];
}

#pragma mark setInt
RCT_EXPORT_METHOD(setInt:(NSString *)ID key:(NSString*)key
                  value:(nonnull NSNumber*)value
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    
    [setters setItem:ID key:key type:DATA_TYPE_INT string:NULL boolean:false number:value map:NULL mmkvMap:mmkvMap  callback:callback];
    
}


#pragma mark setBoolAsync
RCT_EXPORT_METHOD(setBoolAsync:(NSString *)ID key:(NSString*)key
                  value:(BOOL *)value
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    [setters setItemAsync:ID key:key type:DATA_TYPE_BOOL string:NULL boolean:value number:NULL map:NULL mmkvMap:mmkvMap  resolve:resolve rejecter:reject];
    
}

#pragma mark setBool
RCT_EXPORT_METHOD(setBool:(NSString *)ID key:(NSString*)key
                  value:(BOOL *)value
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    [setters setItem:ID key:key type:DATA_TYPE_BOOL string:NULL boolean:value number:NULL map:NULL mmkvMap:mmkvMap  callback:callback];
    
}

#pragma mark setMapAsync
RCT_EXPORT_METHOD(setMapAsync:(NSString *)ID key:(NSString*)key
                  value:(NSDictionary*)value
                  isArray:(bool)isArray
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    int type = DATA_TYPE_MAP;
    if (isArray) {
        type = DATA_TYPE_ARRAY;
    }
    [setters setItemAsync:ID key:key type:type string:NULL boolean:false number:NULL map:value mmkvMap:mmkvMap  resolve:resolve rejecter:reject];
    
}

#pragma mark setMap
RCT_EXPORT_METHOD(setMap:(NSString *)ID key:(NSString*)key
                  value:(NSDictionary*)value
                  isArray:(bool)isArray
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    int type = DATA_TYPE_MAP;
    if (isArray) {
        type = DATA_TYPE_ARRAY;
    }
    [setters setItem:ID key:key type:type string:NULL boolean:false number:NULL map:value mmkvMap:mmkvMap  callback:callback];
    
}

#pragma mark getMultipleItemsAsync
RCT_EXPORT_METHOD(getMultipleItemsAsync:(NSString *)ID key:(NSArray*)keys
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    [getters getMultipleItemsAsync:ID key:keys mmkvMap:mmkvMap resolve:resolve rejecter:reject];
    
}

#pragma mark getMultipleItems
RCT_EXPORT_METHOD(getMultipleItems:(NSString *)ID key:(NSArray*)keys
                  callback:(RCTResponseSenderBlock)callback
                  ) {
    
    [getters getMultipleItems:ID key:keys mmkvMap:mmkvMap callback:callback];
    
}

#pragma mark getKeys
RCT_EXPORT_METHOD(getKeys:(NSString *)ID resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        MMKV *kv = [mmkvMap objectForKey:ID];
        NSArray *array =  kv.allKeys;
        resolve(array);
        
    } else {
        
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}



#pragma mark hasKey
RCT_EXPORT_METHOD(hasKey:(NSString *)ID key:(NSString*)key
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        MMKV *kv = [mmkvMap objectForKey:ID];
        
        if ([kv containsKey:key]) {
            resolve(@YES);
        } else {
            resolve(@NO);
        }
        
    } else {
        
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
}



#pragma mark removeItem
RCT_EXPORT_METHOD(removeItem:(NSString *)ID key:(NSString*)key
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        MMKV *kv = [mmkvMap objectForKey:ID];
        
        if ([kv containsKey:key]) {
            [kv removeValueForKey:key];
        } else {
            resolve(@NO);
        }
        resolve(@YES);
    } else {
        
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
    
}

#pragma mark clearStore
RCT_EXPORT_METHOD(clearStore:(NSString *)ID resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        MMKV *kv = [mmkvMap objectForKey:ID];
        [kv clearAll];
        [kv setBool:true forKey:ID];
        resolve(@YES);
        
    } else {
        
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}


#pragma mark clearMemoryCache
RCT_EXPORT_METHOD(clearMemoryCache:(NSString *)ID resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        MMKV *kv = [mmkvMap objectForKey:ID];
        [kv clearMemoryCache];
        resolve(@YES);
        
    } else {
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}

#pragma mark getAllItemsForTypeAsync
RCT_EXPORT_METHOD(getAllItemsForTypeAsync:(NSString *)ID
                  type:(nonnull NSNumber *)type
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [getters getAllItemsForTypeAsync:ID type:type mmkvMap:mmkvMap resolve:resolve rejecter:reject];
    
}

#pragma mark getAllItemsForType
RCT_EXPORT_METHOD(getAllItemsForType:(NSString *)ID
                  type:(nonnull NSNumber *)type
                  callback:(RCTResponseSenderBlock)callback) {
    
    [getters getAllItemsForType:ID type:type mmkvMap:mmkvMap callback:callback];
}

#pragma mark encrypt
RCT_EXPORT_METHOD(encrypt:(NSString *)ID
                  cryptKey:(NSString *)cryptKey
                  alias:(nullable NSString *)alias
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        [IdStore add:ID encrypted:true alias:alias];
        MMKV *kv = [mmkvMap objectForKey:ID];
        [kv setBool:true forKey:ID];
        NSData *key = [cryptKey dataUsingEncoding:NSUTF8StringEncoding];
        [kv reKey:key];
        resolve(@YES);
    } else {
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}

#pragma mark decrypt
RCT_EXPORT_METHOD(decrypt:(NSString *)ID
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
  
        [IdStore add:ID encrypted:false alias:NULL];
        MMKV *kv = [mmkvMap objectForKey:ID];
        [kv setBool:true forKey:ID];
        [kv reKey:NULL];
        resolve(@YES);
        
    } else {
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}

#pragma mark changeEncryptionKey
RCT_EXPORT_METHOD(changeEncryptionKey:(NSString *)ID
                  cryptKey:(NSString *)cryptKey
                  alias:(nullable NSString *)alias
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    
    if ([[mmkvMap allKeys] containsObject:ID]) {
        
        [IdStore add:ID encrypted:true alias:alias];
        MMKV *kv = [mmkvMap objectForKey:ID];
        [kv setBool:true forKey:ID];
        NSData *key = [cryptKey dataUsingEncoding:NSUTF8StringEncoding];
        [kv reKey:key];
        resolve(@YES);
        
    } else {
        reject(@"cannot_get", @"database not initialized for the given ID", nil);
    }
    
}

#pragma mark setSecureKey
RCT_EXPORT_METHOD(setSecureKey: (NSString *)key value:(NSString *)value
                  options: (NSDictionary *)options
                  callback:(RCTResponseSenderBlock)callback
                  )
{
    
    [secureStorage setSecureKey:key value:value options:options callback:callback];
    
}

#pragma mark getSecureKey
RCT_EXPORT_METHOD(getSecureKey:(NSString *)key
                  callback:(RCTResponseSenderBlock)callback)
{
    
    [secureStorage getSecureKey:key callback:callback];
    
    
}

#pragma mark secureKeyExists
RCT_EXPORT_METHOD(secureKeyExists:(NSString *)key
                  callback:(RCTResponseSenderBlock)callback)
{
    
    [secureStorage secureKeyExists:key callback:callback];
    
}
#pragma mark removeSecureKey
RCT_EXPORT_METHOD(removeSecureKey:(NSString *)key
                  callback:(RCTResponseSenderBlock)callback)
{
    
    [secureStorage removeSecureKey:key callback:callback];
    
}

-(void) encryptionHandler:(NSString *)ID
                     mode:(NSNumber *)mode
                 callback:(nullable RCTResponseSenderBlock)callback   {
    
    MMKV *kv;
    
    if ([IdStore encrypted:ID]) {
        
        NSString *alias = [IdStore getAlias:ID];
        if (alias != NULL) {
            
            if ([secureStorage secureKeyExists:alias callback:NULL]) {
                
                NSData *cryptKey = [[secureStorage getSecureKey:alias callback:NULL] dataUsingEncoding:NSUTF8StringEncoding];
                
                if ([mode isEqualToNumber:@1]) {
                    kv = [MMKV mmkvWithID:ID  cryptKey:cryptKey mode:MMKVSingleProcess];
                } else {
                    kv = [MMKV mmkvWithID:ID  cryptKey:cryptKey mode:MMKVMultiProcess ];
                }
                if (callback != NULL) {
                    callback(@[[NSNull null]  , @YES ]);
                }
                [mmkvMap setObject:kv forKey:defaultStorage];
                
            } else {
                if (callback != NULL) {
                    callback(@[@"Wrong Password or database corrupted", [NSNull null] ]);
                }
                
            }
        }
        
    } else {
        
        if ([mode isEqualToNumber:@1]) {
            kv = [MMKV mmkvWithID:ID mode:MMKVSingleProcess];
        } else {
            kv = [MMKV mmkvWithID:ID mode:MMKVMultiProcess];
        }
       [mmkvMap setObject:kv forKey:defaultStorage];
    }
    
    
    
}

@end

