/**
 *
 *	@file   	: uexApplePayQueueLock.m  in EUExApplePay Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/2/26.
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "uexApplePayQueueLock.h"
#import <libkern/OSAtomic.h>
@interface uexApplePayQueueLock()
@property (nonatomic,assign)NSInteger lockCount;
@property (nonatomic,strong)dispatch_queue_t queue;
@property (nonatomic,strong)dispatch_semaphore_t lockSemaphore;
@property (nonatomic,assign)OSSpinLock spinLock;
@end
@implementation uexApplePayQueueLock

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    NSParameterAssert(identifier && identifier.length > 0);
    self = [super init];
    if (self) {
        _lockCount = 0;
        _queue = dispatch_queue_create([identifier UTF8String], DISPATCH_QUEUE_SERIAL);
        _spinLock = OS_SPINLOCK_INIT;
        _lockSemaphore = dispatch_semaphore_create(0);
        
    }
    return self;
}

- (void)lock{
    OSSpinLockLock(&_spinLock);
    self.lockCount ++;
    dispatch_async(self.queue, ^{
        dispatch_semaphore_wait(self.lockSemaphore,DISPATCH_TIME_FOREVER);
    });
    OSSpinLockUnlock(&_spinLock);
}

- (void)unlock{
    OSSpinLockLock(&_spinLock);
    if (self.lockCount > 0) {
        self.lockCount--;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_semaphore_signal(self.lockSemaphore);
        });
    }
    OSSpinLockUnlock(&_spinLock);
}
- (void)reset{
    while (self.lockCount > 0) {
        [self unlock];
    }
}
- (void)addTask:(dispatch_block_t)taskBlock{
    dispatch_async(self.queue, taskBlock);
}
@end
