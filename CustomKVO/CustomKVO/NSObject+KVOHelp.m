//
//  NSObject+KVOHelp.m
//  CustomKVO
//
//  Created by Melody Chan on 16/10/29.
//  Copyright © 2016年 canlife. All rights reserved.
//

#import "NSObject+KVOHelp.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const kCMYKVOClassPrefix = @"CMYKVOClassPrefix_";
NSString *const kCMYKVOAssociatedObservers = @"CMYKVOAssociatedObservers";


@interface CMYObservationObject : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) CMY_ObservingBlock block;

@end



@implementation CMYObservationObject

- (instancetype)initWithObserver:(NSObject *)observer Key:(NSString *)key block:(CMY_ObservingBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end

#pragma mark - Debug Help Methods
static NSArray *ClassMethodNames(Class c)
{
    NSMutableArray *array = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(c, &methodCount);
    unsigned int i;
    for(i = 0; i < methodCount; i++) {
        [array addObject: NSStringFromSelector(method_getName(methodList[i]))];
    }
    free(methodList);
    
    return array;
}


static void PrintDescription(NSString *name, id obj)
{
    NSString *str = [NSString stringWithFormat:
                     @"%@: %@\n\tNSObject class %s\n\tRuntime class %s\n\timplements methods <%@>\n\n",
                     name,
                     obj,
                     class_getName([obj class]),
                     class_getName(object_getClass(obj)),
                     [ClassMethodNames(object_getClass(obj)) componentsJoinedByString:@", "]];
    printf("%s\n", [str UTF8String]);
}


#pragma mark - Helpers
#pragma mark - Overridden Methods

static NSString * getterForSetter(NSString *setter)
{
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }

    //前面移除'set' 后面移除:’
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    // 第一个字母小写
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    
    return key;
}
static NSString * setterForGetter(NSString *getter)
{
    if (getter.length <= 0) {
        return nil;
    }
    
    // 让第一个字母大写
    NSString *firstLetter = [[getter substringToIndex:1] uppercaseString];
    NSString *remainingLetters = [getter substringFromIndex:1];
    
    // 前面添加set后面添加:
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", firstLetter, remainingLetters];
    
    return setter;
}

#pragma mark - Overridden Methods
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // 转换指针
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // 调用父类方法
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    // 遍历数组回调block
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kCMYKVOAssociatedObservers));
    for (CMYObservationObject *each in observers) {
        if ([each.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                each.block(self, getterName, oldValue, newValue);
            });
        }
    }
}

static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}


@implementation NSObject (KVOHelp)

- (void)CMY_addObserver:(NSObject *)observer
                 forKey:(NSString *)key
              withBlock:(CMY_ObservingBlock)block{

    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    //1.检查对象的类有没有相应的 setter 方法。如果没有抛出异常；
    if (setterMethod == nil) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        
        return;
    }
    
    Class self_class = object_getClass(self);
    NSString *className = NSStringFromClass(self_class);
    
    // 2.检查对象 isa 指向的类是不是一个 KVO 类。如果不是，新建一个继承原来类的子类,把 isa 指向这个新建的子类
    if (![className hasPrefix:kCMYKVOClassPrefix]) {
        self_class = [self makeKVOClassWithOriginalClassName:className];
        object_setClass(self, self_class);
    }
    
    // 3.检查对象的 KVO 类重写过没有这个 setter 方法。如果没有，添加重写的 setter 方法；
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(self_class, setterSelector, (IMP)kvo_setter, types);
    }
    
    // 4.添加这个观察者
    CMYObservationObject *info = [[CMYObservationObject alloc] initWithObserver:observer Key:key block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kCMYKVOAssociatedObservers));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(kCMYKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];

    
}


- (void)CMY_removeObserver:(NSObject *)observer forKey:(NSString *)key{
    NSMutableArray* observers = objc_getAssociatedObject(self, (__bridge const void *)(kCMYKVOAssociatedObservers));
    
    CMYObservationObject *infoToRemove;
    for (CMYObservationObject* info in observers) {
        if (info.observer == observer && [info.key isEqual:key]) {
            infoToRemove = info;
            break;
        }
    }
    
    [observers removeObject:infoToRemove];

}


- (Class)makeKVOClassWithOriginalClassName:(NSString *)originalClazzName
{
    NSString *kvoClazzName = [kCMYKVOClassPrefix stringByAppendingString:originalClazzName];
    Class self_class = NSClassFromString(kvoClazzName);
    
    if (self_class) {
        return self_class;
    }
    
    // 对象如果不存在就创建
    Class originalClass = object_getClass(self);
    Class kvoClass = objc_allocateClassPair(originalClass, kvoClazzName.UTF8String, 0);
    
    // 获得对象方法的签名并使用
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    const char *types = method_getTypeEncoding(classMethod);
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, types);
    
    objc_registerClassPair(kvoClass);
    
    return kvoClass;
}


- (BOOL)hasSelector:(SEL)selector
{
    Class self_class = object_getClass(self);
    unsigned int methodCount = 0;
    Method* methodList = class_copyMethodList(self_class, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}


@end

