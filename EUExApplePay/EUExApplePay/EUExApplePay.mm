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
#import "UPAPayPlugin.h"


typedef NS_ENUM(NSInteger,uexApplePayStartPayResult){
    uexApplePayStartPayResultSuccess = 0,
    uexApplePayStartPayResultParameterError,
    uexApplePayStartPayResultPaymentNotAvailable,
    uexApplePayStartPayResultUnknownError,
};

typedef NS_ENUM(NSInteger,uexApplePayOnPayFinishResult){
    uexApplePayOnPayFinishResultSuccess = 0,
    uexApplePayOnPayFinishResultFailure,
    uexApplePayOnPayFinishResultCancel,
};

@interface EUExApplePay()<PKPaymentAuthorizationViewControllerDelegate,UPAPayPluginDelegate>


@property (nonatomic,strong) NSArray<PKPaymentSummaryItem *> *items;
@property (nonatomic,strong) NSArray<PKShippingMethod *> *shippingMethods;
@property (nonatomic,assign) PKPaymentAuthorizationStatus status;
@property (nonatomic,assign) BOOL isPostalAddressInvalid;
@property (nonatomic,strong) NSMutableDictionary<NSString *,PKPaymentButton *> *buttons;
@property (nonatomic,assign) uexApplePayOnPayFinishResult payResult;
@end

NSString * kUexApplePayOrderInfoKey = @"orderInfo";
NSString * kUexApplePayModeKey = @"mode";
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
    self.payResult = uexApplePayOnPayFinishResultCancel;
}

- (void)dealloc{
    [self reset];
    
}


- (NSDictionary<NSString *,PKPaymentButton *> *)buttons{
    if (!_buttons) {
        _buttons = [NSMutableDictionary dictionary];
    }
    return _buttons;
}

#pragma mark - API
#pragma mark - Check
- (NSNumber *)canMakePayment:(NSMutableArray *)inArguments{
    id info = nil;
    if([inArguments count] > 0){
        info = [inArguments[0] JSONValue];
    }
    uexApplePayStatus status = [uexApplePayHelper payStatusWithInfo:info];
    [self callbackJSONWithFunction:@"cbCanMakePayment" object:@{@"status":@(status)}];
    return @(status);
}

#pragma mark - 中国银联的快捷支付接口


- (NSNumber *)startChinaUnionPay:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return [self cbStartChinaUnionPay:uexApplePayStartPayResultParameterError];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbStartChinaUnionPay:uexApplePayStartPayResultParameterError];
    }
    if ([uexApplePayHelper payStatusWithInfo:@{kUexApplePayNetworksKey:@[@"ChinaUnionPay"]}] != uexApplePayStatusAvailable) {
        return [self cbStartChinaUnionPay:uexApplePayStartPayResultPaymentNotAvailable];
    }
    if(!UEX_DICT_CONTAIN_STRING_VALUE(info, kUexApplePayMerchantIdentifierKey) ||
       !UEX_DICT_CONTAIN_STRING_VALUE(info, kUexApplePayOrderInfoKey) ||
       !UEX_DICT_CONTAIN_STRING_VALUE(info, kUexApplePayModeKey)){
        return [self cbStartChinaUnionPay:uexApplePayStartPayResultParameterError];
    }
    
    
    
    BOOL isSuccess = [UPAPayPlugin startPay:info[kUexApplePayOrderInfoKey] mode:info[kUexApplePayModeKey] viewController:[EUtility brwCtrl:self.meBrwView] delegate:self andAPMechantID:info[kUexApplePayMerchantIdentifierKey]];
    if (!isSuccess) {
        return [self cbStartChinaUnionPay:uexApplePayStartPayResultUnknownError];
    }
    return [self cbStartChinaUnionPay:uexApplePayStartPayResultSuccess];
    
}

- (NSNumber *)cbStartChinaUnionPay:(uexApplePayStartPayResult)result{
    [self callbackJSONWithFunction:@"cbStartChinaUnionPay" object:@{kUexApplePayResultKey:@(result)}];
    return @(result);
}

-(void) UPAPayPluginResult:(UPPayResult *) payResult{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(payResult.paymentResultStatus) forKey:kUexApplePayResultKey];
    [dict setValue:payResult.errorDescription forKey:@"errorInfo"];
    [dict setValue:payResult.otherInfo forKey:@"otherInfo"];
    [self callbackJSONWithFunction:@"onChinaUnionPayFinish" object:dict];
}
#pragma mark - Apple Pay



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
    if (isPaymentSuccess) {
        self.status = PKPaymentAuthorizationStatusSuccess;
        self.payResult = uexApplePayOnPayFinishResultSuccess;
    }else{
        self.status = PKPaymentAuthorizationStatusFailure;
        self.payResult = uexApplePayOnPayFinishResultFailure;
    }

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


#pragma mark - Apple Pay Button




- (NSNumber *)addButton:(NSMutableArray *)inArguments{

    if([inArguments count] < 1){
        return [self cbAddButtonWithResult:NO identifier:nil];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbAddButtonWithResult:NO identifier:nil];
    }
    if (!UEX_DICT_CONTAIN_STRING_VALUE(info, @"id") || !info[@"width"] || !info[@"height"] || !info[@"x"] || !info[@"y"]) {
        return [self cbAddButtonWithResult:NO identifier:nil];
    }
    NSString *identifier = info[@"id"];
    if ([self.buttons.allKeys containsObject:identifier]) {
        return [self cbAddButtonWithResult:NO identifier:identifier];
    }
    PKPaymentButtonType type = (PKPaymentButtonType)(info[@"type"] ? [info[@"type"] integerValue] : PKPaymentButtonTypePlain);
    PKPaymentButtonStyle style = (PKPaymentButtonStyle)(info[@"style"] ? [info[@"style"] integerValue] : PKPaymentButtonStyleBlack);
    PKPaymentButton *button = [PKPaymentButton buttonWithType:type style:style];
    button.frame = CGRectMake([info[@"x"] floatValue], [info[@"y"] floatValue], [info[@"width"] floatValue], [info[@"height"] floatValue]);
    [self.buttons setValue:button forKey:identifier];
    [button addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    BOOL isScroll = info[@"scrollWithWeb"] ? [info[@"scrollWithWeb"] boolValue] : NO;
    if (isScroll) {
        [EUtility brwView:self.meBrwView addSubviewToScrollView:button];
    }else{
        [EUtility brwView:self.meBrwView addSubview:button];
    }
    return [self cbAddButtonWithResult:YES identifier:identifier];
}

- (NSNumber *)cbAddButtonWithResult:(BOOL)isSuccess identifier:(NSString *)identifier{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setValue:@(isSuccess) forKey:@"cbAddButton"];
    [result setValue:identifier?:@"" forKey:@"id"];
    [self callbackJSONWithFunction:@"cbAddButton" object:result];
    return @(isSuccess);
}

- (NSNumber *)removeButton:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return [self cbRemoveButtonWithResult:NO identifier:nil];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self cbRemoveButtonWithResult:NO identifier:nil];
    }
    if (!UEX_DICT_CONTAIN_STRING_VALUE(info, @"id")) {
        return [self cbRemoveButtonWithResult:NO identifier:nil];
    }
    NSString *identifier = info[@"id"];
    if (!self.buttons[identifier]) {
        return [self cbRemoveButtonWithResult:NO identifier:identifier];
    }
    PKPaymentButton *button = self.buttons[identifier];
    
    [button removeFromSuperview];
    [self.buttons removeObjectForKey:identifier];
    return [self cbRemoveButtonWithResult:YES identifier:identifier];;
}


- (NSNumber *)cbRemoveButtonWithResult:(BOOL)isSuccess identifier:(NSString *)identifier{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setValue:@(isSuccess) forKey:@"cbAddButton"];
    [result setValue:identifier?:@"" forKey:@"id"];
    [self callbackJSONWithFunction:@"cbRemoveButton" object:result];
    return @(isSuccess);
}

- (void)onButtonClick:(id)sender{
    if (![sender isKindOfClass:[PKPaymentButton class]]) {
        return;
    }
    [self.buttons enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, PKPaymentButton * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj == sender) {
            [self callbackJSONWithFunction:@"onButtonClick" object:@{@"id":key}];
            *stop = YES;
        }
    }];
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
        
        [self callbackJSONWithFunction:@"onPayFinish" object:@{@"result":@(self.payResult)}];
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

    [EUtility uexPlugin:@"uexApplePay"
         callbackByName:functionName
             withObject:object
                andType:uexPluginCallbackWithJsonString
               inTarget:self.meBrwView];
    
}

@end
