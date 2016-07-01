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
#import "uexApplePayHelper.h"
#import <Security/Security.h>
#import <AppCanKit/ACEXTScope.h>
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


@property (nonatomic,strong) NSMutableDictionary<NSString *,PKPaymentButton *> *buttons;
@property (nonatomic,assign) uexApplePayOnPayFinishResult payResult;




@property (nonatomic,strong) void (^onAuthorizationHandler)(PKPaymentAuthorizationStatus);
@property (nonatomic,strong) void (^didSelectShippingContactHandler)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull);
@property (nonatomic,strong) void (^didSelectShippingMethodHandler)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull);
@property (nonatomic,strong) void (^didSelectPaymentMethodHandler)(NSArray<PKPaymentSummaryItem *> *);



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



#pragma mark - Life Cycle



- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine
{
    self = [super initWithWebViewEngine:engine];
    if (self) {
    
    }
    return self;
}

- (void)clean{
    [self reset];
    for (PKPaymentButton *button in self.buttons.allValues) {
        [button removeFromSuperview];
    }
    [self.buttons removeAllObjects];
    
}

- (void)reset{
    self.payResult = uexApplePayOnPayFinishResultCancel;
    if (self.onAuthorizationHandler) {
        self.onAuthorizationHandler(PKPaymentAuthorizationStatusFailure);
        self.onAuthorizationHandler = nil;
    }
    if (self.didSelectPaymentMethodHandler) {
        self.didSelectPaymentMethodHandler = nil;
    }
    if (self.didSelectShippingMethodHandler) {
        self.didSelectShippingMethodHandler(PKPaymentAuthorizationStatusFailure,self.items);
        self.didSelectShippingMethodHandler = nil;
    }
    if (self.didSelectShippingContactHandler) {
        self.didSelectShippingContactHandler(PKPaymentAuthorizationStatusFailure,self.shippingMethods,self.items);
        self.didSelectShippingContactHandler = nil;
    }
    self.items = nil;
    self.shippingMethods = nil;
    
}

- (void)dealloc{
    [self clean];
    
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
    ACArgsUnpack(NSDictionary *info) = inArguments;
    uexApplePayStatus status = [uexApplePayHelper payStatusWithInfo:info];
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"cbCanMakePayment")
                                          arguments:ACArgsPack(@{@"status":@(status)}.ac_JSONFragment)];
    return @(status);
}

#pragma mark - 中国银联的快捷支付接口


- (NSNumber *)startChinaUnionPay:(NSMutableArray *)inArguments{
    
    __block uexApplePayStartPayResult result = uexApplePayStartPayResultParameterError;
    
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"cbStartChinaUnionPay")
                                              arguments:ACArgsPack(@{kUexApplePayResultKey:@(result)}.ac_JSONFragment)];
    };
    ACArgsUnpack(NSDictionary *info) = inArguments;
    
    if ([uexApplePayHelper payStatusWithInfo:@{kUexApplePayNetworksKey:@[@"ChinaUnionPay"]}] != uexApplePayStatusAvailable) {
        result = uexApplePayStartPayResultPaymentNotAvailable;
        return @(result);
    }
    
    NSString *orderInfo = stringArg(info[kUexApplePayOrderInfoKey]);
    NSString *mode = stringArg(info[kUexApplePayModeKey]);
    NSString *merchant = stringArg(info[kUexApplePayMerchantIdentifierKey]);
    
    if (!orderInfo || !mode || !merchant) {
        return @(result);
    }

    BOOL isSuccess = [UPAPayPlugin startPay:orderInfo mode:mode viewController:[self.webViewEngine viewController] delegate:self andAPMechantID:merchant];
    if (isSuccess) {
        result = uexApplePayStartPayResultSuccess;
    }else{
        result = uexApplePayStartPayResultUnknownError;
    }
    return @(result);
    
}



-(void) UPAPayPluginResult:(UPPayResult *) payResult{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(payResult.paymentResultStatus) forKey:kUexApplePayResultKey];
    [dict setValue:payResult.errorDescription forKey:@"errorInfo"];
    [dict setValue:payResult.otherInfo forKey:@"otherInfo"];
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onChinaUnionPayFinish")
                                          arguments:ACArgsPack(dict.ac_JSONFragment)];
}
#pragma mark - Apple Pay



- (NSNumber *)startPay:(NSMutableArray *)inArguments{
    [self reset];
    __block uexApplePayStartPayResult result = uexApplePayStartPayResultParameterError;
    
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"cbStartPay")
                                              arguments:ACArgsPack(@{kUexApplePayResultKey:@(result)}.ac_JSONFragment)];
    };

    ACArgsUnpack(NSDictionary *info) = inArguments;
    
    if (!info) {
        return @(result);
    }
    
    PKPaymentRequest *request = [uexApplePayHelper requestWithInfoDictionary:info];
    if (!request) {
        return @(result);
    }
    if ([uexApplePayHelper payStatusWithInfo:info] != uexApplePayStatusAvailable) {
        result = uexApplePayStartPayResultPaymentNotAvailable;
        return @(result);
    }
    PKPaymentAuthorizationViewController *viewController = [[PKPaymentAuthorizationViewController alloc]initWithPaymentRequest:request];
    viewController.delegate = self;
    self.items = request.paymentSummaryItems;
    self.shippingMethods = request.shippingMethods;
    [[self.webViewEngine viewController]presentViewController:viewController animated:YES completion:nil];
    result = uexApplePayStartPayResultSuccess;
    return @(result);

}


- (void)onCommitErrorWithType:(uexApplePayCommitType)type{
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onCommitError")
                                          arguments:ACArgsPack(@{@"type":@(type)}.ac_JSONFragment)];
}


- (NSNumber *)commitAuthorizedResult:(NSMutableArray *)inArguments{
    __block BOOL result = NO;
    ACArgsUnpack(NSDictionary *info) = inArguments;
    @onExit{
        if (!result) {
            [self onCommitErrorWithType:uexApplePayCommitAuthorizedResult];
        }
    };
    
    if (!info || !info[kUexApplePayResultKey]) {
        return @(result);
    }
    BOOL isPaymentSuccess = [info[kUexApplePayResultKey] boolValue];
    PKPaymentAuthorizationStatus status;
    if (isPaymentSuccess) {
        status = PKPaymentAuthorizationStatusSuccess;
        self.payResult = uexApplePayOnPayFinishResultSuccess;
    }else{
        status = PKPaymentAuthorizationStatusFailure;
        self.payResult = uexApplePayOnPayFinishResultFailure;
    }
    self.onAuthorizationHandler(status);
    self.onAuthorizationHandler = nil;
    result = YES;
    return @(result);
}

- (NSNumber *)commitPaymentMethodChange:(NSMutableArray *)inArguments{
    __block BOOL result = NO;
    ACArgsUnpack(NSDictionary *info) = inArguments;
    @onExit{
        if (!result) {
            [self onCommitErrorWithType:uexApplePayCommitPaymentMethodChange];
        }
    };
    
    if (info && info[kUexApplePayPaymentKey]) {
         NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return @(result);
        }
    }
    result = YES;
    self.didSelectPaymentMethodHandler(self.items);
    self.didSelectPaymentMethodHandler = nil;
    return @(result);
}

- (NSNumber *)commitShippingMethodChange:(NSMutableArray *)inArguments{
    
    __block BOOL result = NO;
    ACArgsUnpack(NSDictionary *info) = inArguments;
    @onExit{
        if (!result) {
            [self onCommitErrorWithType:uexApplePayCommitShippingMethodChange];
        }
    };
    
    if (info && info[kUexApplePayPaymentKey]) {
        NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return @(result);
        }
    }
    result = YES;
    self.didSelectShippingMethodHandler(PKPaymentAuthorizationStatusSuccess,self.items);
    self.didSelectShippingMethodHandler = nil;
    return @(result);
}

- (NSNumber *)commitShippingContactChange:(NSMutableArray *)inArguments{

    __block BOOL result = NO;
    ACArgsUnpack(NSDictionary *info) = inArguments;
    @onExit{
        if (!result) {
            [self onCommitErrorWithType:uexApplePayCommitShippingContactChange];
        }
    };
    PKPaymentAuthorizationStatus status = PKPaymentAuthorizationStatusSuccess;
    if (info[kUexApplePayIsPostalAddressInvalidKey] && [info[kUexApplePayIsPostalAddressInvalidKey] boolValue]) {
        status = PKPaymentAuthorizationStatusInvalidShippingPostalAddress;
    }
    
    if (info[kUexApplePayPaymentKey]) {
        NSArray<PKPaymentSummaryItem *> *items = [uexApplePayHelper itemsWithInfoDictionary:info];
        if (items) {
            self.items = items;
        }else{
            return @(result);
        }
    }
    if (info[kUexApplePayShippingMethodsKey]) {
        NSArray<PKShippingMethod *> *shippingMethods = [uexApplePayHelper shippingMethodsWithInfoDictionary:info];
        if (shippingMethods) {
            self.shippingMethods = shippingMethods;
        }else{
            return @(result);
        }
    }
    result = YES;
    self.didSelectShippingContactHandler(status,self.shippingMethods,self.items);
    self.didSelectShippingContactHandler = nil;
    return @(result);
}


#pragma mark - Apple Pay Button

- (NSNumber *)addButton:(NSMutableArray *)inArguments{
    __block BOOL result = NO;
    __block NSString *identifier = nil;
    @onExit{
        identifier = identifier?:@"";
        NSDictionary *dict = @{@"result":@(result),@"id":identifier};
        [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"cbAddButton")
                                              arguments:ACArgsPack(dict.ac_JSONFragment)];

    };
    ACArgsUnpack(NSDictionary *info) = inArguments;
    if (!info) {
        return @(result);
    }
    identifier = stringArg(info[@"id"]);
    NSNumber *widthNum = numberArg(info[@"width"]);
    NSNumber *heightNum = numberArg(info[@"height"]);
    NSNumber *xNum = numberArg(info[@"x"]);
    NSNumber *yNum = numberArg(info[@"y"]);
    
    if (!identifier || !widthNum || !heightNum || !xNum || !yNum) {
        return @(result);
    }
    
    if ([self.buttons.allKeys containsObject:identifier]) {
        return @(result);
    }
    PKPaymentButtonType type = (PKPaymentButtonType)(info[@"type"] ? [info[@"type"] integerValue] : PKPaymentButtonTypePlain);
    PKPaymentButtonStyle style = (PKPaymentButtonStyle)(info[@"style"] ? [info[@"style"] integerValue] : PKPaymentButtonStyleBlack);
    PKPaymentButton *button = [PKPaymentButton buttonWithType:type style:style];
    button.frame = CGRectMake(xNum.floatValue, yNum.floatValue, widthNum.floatValue, heightNum.floatValue);
    [self.buttons setValue:button forKey:identifier];
    [button addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    BOOL isScroll = info[@"scrollWithWeb"] ? [info[@"scrollWithWeb"] boolValue] : NO;
    if (isScroll) {
        [[self.webViewEngine webScrollView] addSubview:button];

    }else{
        [[self.webViewEngine webView] addSubview:button];

    }
    result = YES;
    return @(result);
}


- (NSNumber *)removeButton:(NSMutableArray *)inArguments{
    
    __block BOOL result = NO;
    __block NSString *identifier = nil;
    @onExit{
        identifier = identifier?:@"";
        NSDictionary *dict = @{@"result":@(result),@"id":identifier};
        [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"cbRemoveButton")
                                              arguments:ACArgsPack(dict.ac_JSONFragment)];
        
    };
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    identifier = stringArg(info[@"id"]);
    if (!identifier || !self.buttons[identifier]) {
        return @(result);
    }
    PKPaymentButton *button = self.buttons[identifier];
    [button removeFromSuperview];
    [self.buttons removeObjectForKey:identifier];
    result = YES;
    return @(result);
}




- (void)onButtonClick:(id)sender{
    if (![sender isKindOfClass:[PKPaymentButton class]]) {
        return;
    }
    [self.buttons enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, PKPaymentButton * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj == sender) {
            [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onButtonClick")
                                                  arguments:ACArgsPack(@{@"id":key}.ac_JSONFragment)];
            *stop = YES;
        }
    }];
}





#pragma mark - PKPaymentAuthorizationViewControllerDelegate

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion{

    self.onAuthorizationHandler = completion;
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onPaymentAuthorized")
                                          arguments:ACArgsPack([uexApplePayHelper paymentInfo:payment].ac_JSONFragment)];
}
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    [controller dismissViewControllerAnimated:YES completion:^{
        [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onPayFinish")
                                              arguments:ACArgsPack(@{@"result":@(self.payResult)}.ac_JSONFragment)];
        [self reset];
    }];
     
}


- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingContact:(PKContact *)contact
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    self.didSelectShippingContactHandler = completion;
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onShippingContactChange")
                                          arguments:ACArgsPack([uexApplePayHelper contactInfo:contact].ac_JSONFragment)];

}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    self.didSelectShippingMethodHandler = completion;
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onShippingMethodChange")
                                          arguments:ACArgsPack([uexApplePayHelper shippingMethodInfo:shippingMethod].ac_JSONFragment)];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                    didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod
                                completion:(void (^)(NSArray<PKPaymentSummaryItem *> *summaryItems))completion{
    self.didSelectPaymentMethodHandler = completion;
    [self.webViewEngine callbackWithFunctionKeyPath:uexApplePayFuncName(@"onPaymentMethodChange")
                                          arguments:ACArgsPack([uexApplePayHelper paymentMethodInfo:paymentMethod].ac_JSONFragment)];


}


#pragma mark - JSON Callback

static inline NSString * uexApplePayFuncName(NSString *name){
    return [NSString stringWithFormat:@"uexApplePay.%@",name];
}


@end
