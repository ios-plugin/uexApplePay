/**
 *
 *	@file   	: EUExApplePay.m  in EUExApplePay Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/2/24.
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

#import "EUExApplePay.h"
#import <PassKit/PassKit.h>
#import "EUtility.h"
#import "JSON.h"
#import "uexApplePayHelper.h"
#import "uexApplePayQueueLock.h"
#import <Security/Security.h>


typedef NS_ENUM(NSInteger,uexApplePayStartPayResult){
    uexApplePayStartPayResultSuccess = 0,
    uexApplePayStartPayResultParameterError,
    uexApplePayStartPayResultPaymentNotAvailable,
    uexApplePayStartPayResultUnknownError,
};



@interface EUExApplePay()<PKPaymentAuthorizationViewControllerDelegate>


@property (nonatomic,strong) NSArray<PKPaymentSummaryItem *> *items;
@property (nonatomic,strong) NSArray<PKShippingMethod *> *shippingMethods;
@property (nonatomic,assign) PKPaymentAuthorizationStatus status;
@property (nonatomic,assign) BOOL isPostalAddressInvalid;
@end


NSString * kUexApplePayIsPostalAddressInvalidKey = @"isPostalAddressInvalid";
NSString * kUexApplePayResultKey = @"result";

typedef NS_ENUM(NSInteger,uexApplePayCommitType) {
    uexApplePayCommitAuthorizedResult = 0,
    uexApplePayCommitShippingMethodChange,
    uexApplePayCommitPaymentMethodChange,
    uexApplePayCommitShippingContactChange,
};


@implementation EUExApplePay

static uexApplePayQueueLock *paymentMethodLock,*shippingMethodLock,*shippingContactLock,*authorizationLock;

#pragma mark - Life Cycle

+ (void)initialize{

    if ([self class] == [EUExApplePay class]) {
        paymentMethodLock = [[uexApplePayQueueLock alloc]initWithIdentifier:@"uexApplePayPaymentMethodLock"];
        shippingMethodLock = [[uexApplePayQueueLock alloc]initWithIdentifier:@"uexApplePayShippingMethodLockLock"];
        shippingContactLock = [[uexApplePayQueueLock alloc]initWithIdentifier:@"uexApplePayShippingContactLockLock"];
        authorizationLock = [[uexApplePayQueueLock alloc]initWithIdentifier:@"uexApplePayAuthorizationLockLock"];
    }
}

- (instancetype)initWithBrwView:(EBrowserView *)eInBrwView{
    self=[super initWithBrwView:eInBrwView];
    if(self){
        
    }
    return self;
}

- (void)reset{

    self.items = nil;
    self.shippingMethods = nil;
    self.status = PKPaymentAuthorizationStatusSuccess;
    self.isPostalAddressInvalid = NO;
}

- (void)dealloc{
    [self reset];
    
}



#pragma mark - API

- (NSNumber *)canMakePayments:(NSMutableArray *)inArguments{
    id info = nil;
    if([inArguments count] > 0){
        info = [inArguments[0] JSONValue];
    }
    uexApplePayStatus status = [uexApplePayHelper payStatusWithInfo:info];
    [self callbackJSONWithFunction:@"cbCanMakePayments" object:@{@"status":@(status)}];
    return @(status);
}

- (NSNumber *)startPay:(NSMutableArray *)inArguments{
    [self reset];
    if([inArguments count] < 1){
        return [self cbStartPay:uexApplePayStartPayResultParameterError];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbStartPay:uexApplePayStartPayResultParameterError];
    }
    if ([uexApplePayHelper payStatusWithInfo:info] != uexApplePayStatusAvailable) {
        return [self cbStartPay:uexApplePayStartPayResultPaymentNotAvailable];
    }
    PKPaymentRequest *request = [uexApplePayHelper requestWithInfoDictionary:info];
    if (!request) {
        return [self cbStartPay:uexApplePayStartPayResultParameterError];
    }
    PKPaymentAuthorizationViewController *viewController = [[PKPaymentAuthorizationViewController alloc]initWithPaymentRequest:request];
    viewController.delegate = self;
    self.items = request.paymentSummaryItems;
    self.shippingMethods = request.shippingMethods;
    UIViewController *meBrowserController = [EUtility brwCtrl:self.meBrwView];
    [meBrowserController presentViewController:viewController animated:YES completion:^{
        
    }];
    return [self cbStartPay:uexApplePayStartPayResultSuccess];
    
}

- (NSNumber *)cbStartPay:(uexApplePayStartPayResult)result{
    [self callbackJSONWithFunction:@"cbStartPay" object:@{kUexApplePayResultKey:@(result)}];
    return @(result);
}

- (NSNumber *)commitAuthorizedResult:(NSMutableArray *)inArguments{
    uexApplePayCommitType type = uexApplePayCommitAuthorizedResult;
    if([inArguments count] < 1){
        return [self cbCommitWithResult:NO commitType:type];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbCommitWithResult:NO commitType:type];
    }
    if (!info[kUexApplePayResultKey]) {
        return [self cbCommitWithResult:NO commitType:type];
    }
    BOOL isPaymentSuccess = [info[kUexApplePayResultKey] boolValue];
    self.status = isPaymentSuccess ? PKPaymentAuthorizationStatusSuccess : PKPaymentAuthorizationStatusFailure;
    return [self cbCommitWithResult:YES commitType:uexApplePayCommitAuthorizedResult];
    
}

- (NSNumber *)commitPaymentMethodChange:(NSMutableArray *)inArguments{
    uexApplePayCommitType type = uexApplePayCommitPaymentMethodChange;
    if([inArguments count] < 1){
        return [self cbCommitWithResult:YES commitType:type];;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbCommitWithResult:YES commitType:type];
    }
    if (info[kUexApplePayPaymentKey]) {
         NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return [self cbCommitWithResult:NO commitType:type];
        }
    }
    return [self cbCommitWithResult:YES commitType:type];
}

- (NSNumber *)commitShippingMethodChange:(NSMutableArray *)inArguments{
    uexApplePayCommitType type = uexApplePayCommitShippingMethodChange;
    if([inArguments count] < 1){
        return [self cbCommitWithResult:YES commitType:type];;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbCommitWithResult:YES commitType:type];
    }
    if (info[kUexApplePayPaymentKey]) {
        NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return [self cbCommitWithResult:NO commitType:type];
        }
    }
    return [self cbCommitWithResult:YES commitType:type];
}

- (NSNumber *)commitShippingContactChange:(NSMutableArray *)inArguments{
    uexApplePayCommitType type = uexApplePayCommitShippingContactChange;
    if([inArguments count] < 1){
        return [self cbCommitWithResult:YES commitType:type];;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbCommitWithResult:YES commitType:type];
    }
    if (info[kUexApplePayIsPostalAddressInvalidKey] && [info[kUexApplePayIsPostalAddressInvalidKey] boolValue]) {
        self.isPostalAddressInvalid = YES;
    }
    
    if (info[kUexApplePayPaymentKey]) {
        NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return [self cbCommitWithResult:NO commitType:type];
        }
    }
    if (info[kUexApplePayShippingMethodsKey]) {
        NSArray<PKShippingMethod *> *shippingMethods = [uexApplePayHelper shippingMethodsWithInfoDictionary:info];
        if (shippingMethods) {
            self.shippingMethods = shippingMethods;
        }else{
            return [self cbCommitWithResult:NO commitType:type];
        }
    }
    return [self cbCommitWithResult:YES commitType:type];
}

- (NSNumber *)cbCommitWithResult:(BOOL)result commitType:(uexApplePayCommitType)commitType{
    uexApplePayQueueLock *lock;
    switch (commitType) {
        case uexApplePayCommitAuthorizedResult: {
            lock = authorizationLock;
            break;
        }
        case uexApplePayCommitShippingMethodChange: {
            lock = shippingMethodLock;
            break;
        }
        case uexApplePayCommitPaymentMethodChange: {
            lock = paymentMethodLock;
            break;
        }
        case uexApplePayCommitShippingContactChange: {
            lock = shippingContactLock;
            break;
        }
    }
    
    if (result) {
        [lock unlock];
    }else{
        [self callbackJSONWithFunction:@"onCommitError" object:@{@"type":@(commitType)}];
    }
    return @(result);
}





- (NSNumber *)test:(NSMutableArray *)inArguments{
    

    NSLog(@"tttt1");
    if([inArguments count] < 1){
        return @(NO);
    }
    NSLog(@"tttt2");
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return @(NO);
    }
    NSLog(@"tttt3");
    return @(YES);

    //[paymentMethodLock unlock];
    
    /*
    for (int i = 0; i < 3; i ++) {
        for (int j = 0;j<3 ; j ++) {
            CGRect r = CGRectMake(50, 70 * (3*i+j)+30, 200, 60);
            [self addbuttonWithType:i style:j frame:r];
        }
    }*/
}


- (void)addbuttonWithType:(PKPaymentButtonType)type style:(PKPaymentButtonStyle)style frame:(CGRect)frame{
    
    PKPaymentButton *button = [PKPaymentButton buttonWithType:type style:style];
    button.frame = frame;
    [EUtility brwView:self.meBrwView addSubview:button];
}




#pragma mark - PKPaymentAuthorizationViewControllerDelegate

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion{
    [authorizationLock lock];
    [self callbackJSONWithFunction:@"onPaymentAuthorized" object:[uexApplePayHelper paymentInfo:payment]];
    [authorizationLock addTask:^{
        completion(self.status);
    }];
    
}
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    
    [controller dismissViewControllerAnimated:YES completion:^{
        [self reset];
    }];
     
}


- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingContact:(PKContact *)contact
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    self.isPostalAddressInvalid = NO;
    [shippingContactLock lock];
    [self callbackJSONWithFunction:@"onShippingContactChange" object:[uexApplePayHelper contactInfo:contact]];
    [shippingContactLock addTask:^{
        PKPaymentAuthorizationStatus status = PKPaymentAuthorizationStatusSuccess;
        if (self.isPostalAddressInvalid) {
            status = PKPaymentAuthorizationStatusInvalidShippingPostalAddress;
        }
        completion(status,self.shippingMethods ,self.items);
    }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    [shippingMethodLock lock];
    [self callbackJSONWithFunction:@"onShippingMethodChange" object:[uexApplePayHelper shippingMethodInfo:shippingMethod]];
    [shippingMethodLock addTask:^{
        completion(PKPaymentAuthorizationStatusSuccess,self.items);
    }];
    
    
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                    didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod
                                completion:(void (^)(NSArray<PKPaymentSummaryItem *> *summaryItems))completion{
    [paymentMethodLock lock];
    [self callbackJSONWithFunction:@"onPaymentMethodChange" object:[uexApplePayHelper paymentMethodInfo:paymentMethod]];
    [paymentMethodLock addTask:^{
        completion(self.items);
    }];

}


#pragma mark - JSON Callback

- (void)callbackJSONWithFunction:(NSString *)functionName object:(id)object{
    SecKeyEncrypt
    [EUtility uexPlugin:@"uexApplePay"
         callbackByName:functionName
             withObject:object
                andType:uexPluginCallbackWithJsonString
               inTarget:self.meBrwView];
    
}

@end
