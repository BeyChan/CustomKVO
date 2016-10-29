//
//  NSObject+KVOHelp.h
//  CustomKVO
//
//  Created by Melody Chan on 16/10/29.
//  Copyright © 2016年 canlife. All rights reserved.
//

#import <Foundation/Foundation.h>

//创建一个block
typedef void(^CMY_ObservingBlock)(id observedObject, NSString *observedKey, id oldValue, id newValue);

@interface NSObject (KVOHelp)

/*
 *key 设置成NSStringFromSelector(@selector(text))
 */
- (void)CMY_addObserver:(NSObject *)observer
                forKey:(NSString *)key
             withBlock:(CMY_ObservingBlock)block;

- (void)CMY_removeObserver:(NSObject *)observer forKey:(NSString *)key;


@end
