//
//  ACArchiverCenter.m
//  xulinfeng
//
//  Created by xulinfeng on 2016/12/22.
//  Copyright © 2016年 xulinfeng. All rights reserved.
//

#import <objc/runtime.h>
#import "ACArchiverCenter.h"

NSString * const ACArchiverCenterRootFolderPath = @"com.archiver.center.archives";
NSString * const ACArchiverCenterStorageNamesFilename = @"com.archiver.center.storage.names";

NSString * const ACArchiverCenterDefaultName = @"com.archiver.center.default";
NSString * const ACArchiverStorageDefaultName = @"com.archiver.storage.default";

NSString * const ACArchiveStorageSetPredicateString = @"^set[A-Z]([a-z]|[A-Z])*:forKey:$";
NSString * const ACArchiveStorageGetPredicateString = @"^[a-z]([a-z]|[A-Z])*ForKey:$";

#define BBLinkArchiverCenterRetain(obj)     if (@available(iOS 8, *)) CFRetain((__bridge void *)obj)

UIKIT_STATIC_INLINE id ACArchiveStorageBoxValue(const char *type, ...) {
    va_list v;
    va_start(v, type);
    id obj = nil;
    if (strcmp(type, @encode(id)) == 0) {
        id actual = va_arg(v, id);
        obj = actual;
    } else if (strcmp(type, @encode(CGPoint)) == 0) {
        CGPoint actual = (CGPoint)va_arg(v, CGPoint);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        CGSize actual = (CGSize)va_arg(v, CGSize);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets actual = (UIEdgeInsets)va_arg(v, UIEdgeInsets);
        obj = [NSValue value:&actual withObjCType:type];
    } else if (strcmp(type, @encode(double)) == 0) {
        double actual = (double)va_arg(v, double);
        obj = [NSNumber numberWithDouble:actual];
    } else if (strcmp(type, @encode(float)) == 0) {
        float actual = (float)va_arg(v, double);
        obj = [NSNumber numberWithFloat:actual];
    } else if (strcmp(type, @encode(int)) == 0) {
        int actual = (int)va_arg(v, int);
        obj = [NSNumber numberWithInt:actual];
    } else if (strcmp(type, @encode(long)) == 0) {
        long actual = (long)va_arg(v, long);
        obj = [NSNumber numberWithLong:actual];
    } else if (strcmp(type, @encode(long long)) == 0) {
        long long actual = (long long)va_arg(v, long long);
        obj = [NSNumber numberWithLongLong:actual];
    } else if (strcmp(type, @encode(short)) == 0) {
        short actual = (short)va_arg(v, int);
        obj = [NSNumber numberWithShort:actual];
    } else if (strcmp(type, @encode(char)) == 0) {
        char actual = (char)va_arg(v, int);
        obj = [NSNumber numberWithChar:actual];
    } else if (strcmp(type, @encode(bool)) == 0) {
        bool actual = (bool)va_arg(v, int);
        obj = [NSNumber numberWithBool:actual];
    } else if (strcmp(type, @encode(unsigned char)) == 0) {
        unsigned char actual = (unsigned char)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedChar:actual];
    } else if (strcmp(type, @encode(unsigned int)) == 0) {
        unsigned int actual = (unsigned int)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedInt:actual];
    } else if (strcmp(type, @encode(unsigned long)) == 0) {
        unsigned long actual = (unsigned long)va_arg(v, unsigned long);
        obj = [NSNumber numberWithUnsignedLong:actual];
    } else if (strcmp(type, @encode(unsigned long long)) == 0) {
        unsigned long long actual = (unsigned long long)va_arg(v, unsigned long long);
        obj = [NSNumber numberWithUnsignedLongLong:actual];
    } else if (strcmp(type, @encode(unsigned short)) == 0) {
        unsigned short actual = (unsigned short)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedShort:actual];
    }
    va_end(v);
    return obj;
}

@interface ACArchiveStorage ()

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) NSString *filePath;

@property (nonatomic, strong) NSMutableDictionary *mutableKeyValues;

@property (nonatomic, strong, readonly) NSDictionary *keyValues;

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, assign) void *queueTag;

@end

@implementation ACArchiveStorage

+ (instancetype)archiveStorageWithName:(NSString *)name filePath:(NSString *)filePath;{
    return [[self alloc] initWithName:name filePath:filePath];
}

- (instancetype)initWithName:(NSString *)name filePath:(NSString *)filePath;{
    if (self = [super init]) {
        self.name = name;
        self.filePath = filePath;
        self.queueTag = &_queueTag;
        self.queue = dispatch_queue_create([[@"com.archive.center.storage." stringByAppendingString:name] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        dispatch_queue_set_specific([self queue], _queueTag, _queueTag, NULL);
        [self reload];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone;{
    ACArchiveStorage *copy = [[ACArchiveStorage allocWithZone:zone] init];
    copy.mutableKeyValues = [[self mutableKeyValues] copy];
    copy.name = [[self name] copy];
    copy.filePath = [[self filePath] copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [self init]) {
        self.mutableKeyValues = [coder decodeObjectForKey:@"mutableKeyValues"];
        self.name = [coder decodeObjectForKey:@"name"];
        self.filePath = [coder decodeObjectForKey:@"filePath"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self mutableKeyValues] forKey:@"mutableKeyValues"];
    [coder encodeObject:[self name] forKey:@"name"];
    [coder encodeObject:[self filePath] forKey:@"filePath"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation{
    NSMethodSignature *signature = [anInvocation methodSignature];
    NSString *selectorString = NSStringFromSelector([anInvocation selector]);
    if ([[NSPredicate predicateWithFormat:@"SELF MATCHES %@", ACArchiveStorageSetPredicateString] evaluateWithObject:selectorString]) {
        const char *type = [signature getArgumentTypeAtIndex:2];
        void *value = NULL; NSString *key = nil;
        [anInvocation getArgument:&value atIndex:2];
        [anInvocation getArgument:&key atIndex:3];
        BBLinkArchiverCenterRetain(key);
        
        NSString *copiedKey = [key copy];
        id result = ACArchiveStorageBoxValue(type, value);
        [self setObject:result forKey:copiedKey];
        
        anInvocation.target = nil;
        [anInvocation invoke];
        
        return;
    } else if ([[NSPredicate predicateWithFormat:@"SELF MATCHES %@", ACArchiveStorageGetPredicateString] evaluateWithObject:selectorString]){
        NSString *getter = [selectorString substringToIndex:[selectorString rangeOfString:@"ForKey:"].location];
        getter = [getter hasSuffix:@"Value"] ? getter : [getter stringByAppendingString:@"Value"];
        
        NSString *key = nil;
        [anInvocation getArgument:&key atIndex:2];
        BBLinkArchiverCenterRetain(key);
        
        NSString *copiedKey = [key copy];
        if ([copiedKey isKindOfClass:[NSString class]] && [copiedKey length]) {
            id object = [self objectForKey:copiedKey];
            if (object && [object respondsToSelector:NSSelectorFromString(getter)]) {
                anInvocation.selector = NSSelectorFromString(getter);
            }
            if (object) {
                [anInvocation invokeWithTarget:object];
            } else {
                anInvocation.target = nil;
                [anInvocation invoke];
            }
            return;
        }
    }
    
    [super forwardInvocation:anInvocation];
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return NO;
}

#pragma mark - public

- (NSMutableDictionary *)mutableKeyValues{
    if (!_mutableKeyValues) {
        _mutableKeyValues = [NSMutableDictionary dictionary];
    }
    return _mutableKeyValues;
}

- (NSDictionary *)keyValues{
    __block NSDictionary *keyValues = nil;
    [self _sync:^ {
        keyValues = [[self mutableKeyValues] copy];
    }];
    return keyValues;
}

- (NSArray<NSString *> *)allKeys {
    return [[self keyValues] allKeys];
}

- (NSArray<id> *)allValues {
    return [[self keyValues] allValues];
}

- (NSUInteger)count{
    return [[self keyValues] count];
}

- (NSArray<NSString *> *)allKeysForObject:(id)anObject{
    return [[self keyValues] allKeysForObject:anObject];
}

- (NSArray<NSObject, NSCopying, NSCoding> *)objectsForKeys:(NSArray<NSString *> *)keys notFoundMarker:(id)marker;{
    return [[self keyValues] objectsForKeys:keys notFoundMarker:marker];
}

- (NSString *)stringForKey:(NSString *)aKey;{
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSString class]]) {
        return object;
    } else if ([object respondsToSelector:@selector(stringValue)]) {
        return [object stringValue];
    } else {
        return [object description];
    }
}

- (NSDate *)dateForKey:(NSString *)aKey;{
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSDate class]]) {
        return object;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    } else if ([object respondsToSelector:@selector(dateValue)]) {
        return [object performSelector:@selector(dateValue)];
#pragma clang diagnostic pop
    } else if ([object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSString class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[object floatValue]];
    } else {
        return nil;
    }
}

- (NSData *)dataForKey:(NSString *)aKey;{
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSData class]]) {
        return object;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    } else if ([object respondsToSelector:@selector(dataValue)]) {
        return [object performSelector:@selector(dataValue)];
#pragma clang diagnostic pop
    } else if ([object isKindOfClass:[NSString class]]) {
        return [object dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([object isKindOfClass:[NSNumber class]]) {
        return [[object stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

- (NSURL *)URLForKey:(NSString *)aKey;{
    id object = [self objectForKey:aKey];
    if ([object isKindOfClass:[NSURL class]]) {
        return object;
    } else if ([object respondsToSelector:@selector(URL)]) {
        return [object URL];
    } else if ([object isKindOfClass:[NSString class]]) {
        return [NSURL URLWithString:object];
    } else {
        return nil;
    }
}

- (id<NSObject, NSCopying, NSCoding>)objectForKey:(NSString *)aKey;{
    __block id object = nil;
    [self _sync:^ {
        object = [self keyValues][aKey];
    }];
    return object;
}

- (void)setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey{
    [self _setObject:anObject forKey:aKey];
}

- (void)syncSetObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey;{
    [self setObject:anObject forKey:aKey];
    [self save];
}

- (void)removeObjectForKey:(NSString *)aKey{
    [self _asyncSaveWithSyncBlock:^ {
        [[self mutableKeyValues] removeObjectForKey:aKey];
    }];
}

- (void)reload;{
    [self _sync:^ {
        self.mutableKeyValues = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]] ?: [@{} mutableCopy];
    }];
}

- (BOOL)save;{
    __block BOOL result = NO;
    [self _sync:^ {
        result = [self _save];
    }];
    return result;
}

- (NSString *)description{
    __block NSString *description = nil;
    [self _sync:^ {
        description = [[self mutableKeyValues] description];
    }];
    return description;
}

#pragma mark - private

- (void)_async:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_async([self queue], block);
    }
}

- (void)_sync:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_sync([self queue], block);
    }
}

- (void)_asyncSaveWithSyncBlock:(dispatch_block_t)block;{
    dispatch_block_t innerBlock = ^{
        block();
        
        [self _async:^{
            [self _save];
        }];
    };
    [self _sync:innerBlock];
}

- (BOOL)_save;{
    return [NSKeyedArchiver archiveRootObject:[self mutableKeyValues] toFile:[self filePath]];
}

- (void)_setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKey:(NSString *)aKey{
    if (!anObject || ![aKey length]) return;
    if (![anObject respondsToSelector:@selector(copyWithZone:)]) return;
    if (![anObject respondsToSelector:@selector(encodeWithCoder:)]) return;
    if (![anObject respondsToSelector:@selector(initWithCoder:)]) return;
    
    [self _asyncSaveWithSyncBlock:^{
        [self willChangeValueForKey:aKey];
        
        self.mutableKeyValues[[aKey copy]] = anObject;
        
        [self didChangeValueForKey:aKey];
    }];
}

- (void)setObject:(id<NSObject, NSCopying, NSCoding>)anObject forKeyedSubscript:(NSString *)aKey{
    [self _setObject:anObject forKey:aKey];
}

- (id)objectForKeyedSubscript:(NSString *)key{
    return [self objectForKey:key];
}

@end

@interface ACArchiverCenter ()

@property (nonatomic, strong) NSMutableArray<NSString *> *storageNames;

@property (nonatomic, strong) NSMutableDictionary<NSString*, id<ACArchiveStorage>> *cachedStorages;

@property (nonatomic, copy) NSString *directory;

@property (nonatomic, copy) NSString *uniqueIdentifier;

@property (nonatomic, copy, readonly) NSString *rootFolderPath;
@property (nonatomic, copy, readonly) NSString *storageNamesFilePath;

@end

@implementation ACArchiverCenter

+ (id)defaultCenter;{
    static ACArchiverCenter *center = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *rootFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        center = [[self alloc] initWithUniqueIdentifier:ACArchiverCenterDefaultName directory:rootFolder];
    });
    return center;
}

+ (id<ACArchiveStorage>)defaultStorage;{
    return [[self defaultCenter] defaultStorage];
}

- (id<ACArchiveStorage>)defaultStorage;{
    return [self requireStorageWithName:ACArchiverStorageDefaultName];
}

- (instancetype)initWithUniqueIdentifier:(NSString *)uniqueIdentifier directory:(NSString *)directory;{
    if (self = [super init]) {
        self.directory = directory;
        self.uniqueIdentifier = uniqueIdentifier;
        
        [self initialize];
    }
    return self;
}

- (void)initialize{
    [self reloadAll];
}

#pragma mark = accessor

- (NSMutableArray<NSString *> *)storageNames{
    if (!_storageNames) {
        _storageNames = [NSMutableArray array];
    }
    return _storageNames;
}

- (NSMutableDictionary<NSString *,id<ACArchiveStorage>> *)cachedStorages{
    if (!_cachedStorages) {
        _cachedStorages = [NSMutableDictionary dictionary];
    }
    return _cachedStorages;
}

- (NSString *)rootFolderPath{
    return [NSString stringWithFormat:@"%@/%@/%@", [self directory], ACArchiverCenterRootFolderPath, [self uniqueIdentifier]];
}

- (NSString *)storageNamesFilePath{
    return [self _storageFilePathWithName:ACArchiverCenterStorageNamesFilename];
}

#pragma mark - private

- (NSString *)_storageFilePathWithName:(NSString *)name{
    return [NSString stringWithFormat:@"%@/%@.archiver", [self rootFolderPath], name];
}

- (BOOL)_saveStorageNames{
    return [NSKeyedArchiver archiveRootObject:[self storageNames] toFile:[self storageNamesFilePath]];
}

- (void)_readStorageNames{
    BOOL isDirectory = NO;
    void (^createDirectoryHandler)(void) = ^{
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[self rootFolderPath] withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create directorr with error : %@", error);
        }
    };
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self rootFolderPath] isDirectory:&isDirectory]) {
        if (!isDirectory) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:[self rootFolderPath] error:&error];
            if (error) {
                NSLog(@"Failed to remove file path with error : %@", error);
            }
            createDirectoryHandler();
        }
    } else {
        createDirectoryHandler();
    }
    
    self.storageNames = [NSKeyedUnarchiver unarchiveObjectWithFile:[self storageNamesFilePath]] ?: [NSMutableArray array];
}

#pragma mark - public

- (id<ACArchiveStorage>)requireStorageWithName:(NSString *)name {
    NSParameterAssert([name length]);
    id<ACArchiveStorage> result = nil;
    id<ACArchiveStorage> (^newStorage)(NSString *storageName) = ^(NSString *storageName){
        // New an storage from archive file.
        id<ACArchiveStorage> storage = [ACArchiveStorage archiveStorageWithName:storageName filePath:[self _storageFilePathWithName:storageName]];
        if (storage) {
            self.cachedStorages[name] = storage;
        }
        return storage;
    };
    // Append name if the storage hasn't loaded.
    if ([[self storageNames] containsObject:name] && [[[self cachedStorages] allKeys] containsObject:name]) {
        result = [self cachedStorages][name];
    } else {
        result = newStorage(name);
    }
    
    if (result && ![[self storageNames] containsObject:name]) {
        [[self storageNames] addObject:name];
        [self _saveStorageNames];
    }
    
    return result;
}

- (void)reloadAll {
    [[self storageNames] removeAllObjects];
    for (id<ACArchiveStorage> storage in [[self cachedStorages] allValues]) {
        [storage reload];
    }
    [self _readStorageNames];
}

- (void)saveAll;{
    for (id<ACArchiveStorage> storage in [[self cachedStorages] allValues]) {
        [storage save];
    }
    [self _saveStorageNames];
}

@end
