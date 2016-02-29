/**
 *
 *	@file   	: uexApplePayHelper.m  in EUExApplePay Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/2/25.
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

#import "uexApplePayHelper.h"

#define UEX_DICT_CONTAIN_STRING_VALUE(dict,key) \
    (dict[key] && [dict[key] isKindOfClass:[NSString class]])

#define UEX_DICT_CONTAIN_ARRAY_VALUE(dict,key) \
    (dict[key] && [dict[key] isKindOfClass:[NSArray class]])

#define UEX_DICT_CONTAIN_DICTIONARY_VALUE(dict,key) \
    (dict[key] && [dict[key] isKindOfClass:[NSDictionary class]])

#define UEX_STRING_VALUE_FOR_KEY(dict,key,defaultValue)\
    (UEX_DICT_CONTAIN_STRING_VALUE(dict,key) ? dict[key] : defaultValue)


NSString *const kUexApplePayMerchantIdentifierKey = @"merchantIdentifier";
NSString *const kUexApplePayCountryCodeKey = @"countryCode";
NSString *const kUexApplePayCurrencyCodeKey = @"currencyCode";
NSString *const kUexApplePayNetworksKey = @"networks";
NSString *const kUexApplePayPaymentKey = @"payment";
NSString *const kUexApplePayItemsKey = @"items";
NSString *const kUexApplePayLabelKey = @"label";
NSString *const kUexApplePayPriceKey = @"price";
NSString *const kUexApplePayDetailKey = @"detail";
NSString *const kUexApplePayIdentifierKey = @"identifier";
NSString *const kUexApplePayPayeeKey = @"payee";
NSString *const kUexApplePayTotalPriceKey = @"totalPrice";
NSString *const kUexApplePayShippingMethodsKey = @"shippingMethods";
NSString *const kUexApplePayShippingTypeKey = @"shippingType";
NSString *const kUexApplePayShippingContactRequiredFlagKey = @"shippingContactRequiredFlag";
NSString *const kUexApplePayBillingContactRequiredFlagKey = @"billingContactRequiredFlag";
NSString *const kUexApplePayMerchantCapabilityKey = @"merchantCapability";



@implementation uexApplePayHelper



+ (PKPaymentRequest *)requestWithInfoDictionary:(NSDictionary *)info{
    PKPaymentRequest *request = [[PKPaymentRequest alloc]init];
    if (!request) {
        return nil;
    }
    request.currencyCode = UEX_STRING_VALUE_FOR_KEY(info, kUexApplePayCurrencyCodeKey, @"CNY");
    request.countryCode = UEX_STRING_VALUE_FOR_KEY(info, kUexApplePayCountryCodeKey, @"CN");
    request.supportedNetworks = [self paymentNetworksWithInfoDictionary:info];
    request.merchantCapabilities = [self getMerchantCapabilityFromDict:info forKey:kUexApplePayMerchantCapabilityKey];
    if (!UEX_DICT_CONTAIN_STRING_VALUE(info, kUexApplePayMerchantIdentifierKey)) {
        return nil;
    }
    request.merchantIdentifier = info[kUexApplePayMerchantIdentifierKey];
    NSArray<PKPaymentSummaryItem *> *items = [self itemsWithInfoDictionary:info];
    if (!items) {
        return nil;
    }
    request.paymentSummaryItems = items;

    NSArray<PKShippingMethod *> *shippingMethods = [self shippingMethodsWithInfoDictionary:info];
    if (shippingMethods) {
        request.shippingMethods = shippingMethods;
        request.shippingType = [self shippingTypeWithInfoDictionary:info];
    }
    request.requiredShippingAddressFields = [self getAddressFieldFromDict:info forKey:kUexApplePayShippingContactRequiredFlagKey];
    request.requiredBillingAddressFields = [self getAddressFieldFromDict:info forKey:kUexApplePayBillingContactRequiredFlagKey];
    if (UEX_DICT_CONTAIN_STRING_VALUE(info, @"applicationData")) {
        request.applicationData = [info[@"applicationData"] dataUsingEncoding:NSUTF8StringEncoding];
    }
    return request;
}

+ (NSArray<PKShippingMethod *> *)shippingMethodsWithInfoDictionary:(NSDictionary *)info{
    NSMutableArray *methods = [NSMutableArray array];
    if (!UEX_DICT_CONTAIN_ARRAY_VALUE(info,kUexApplePayShippingMethodsKey)) {
        return nil;
    }
    NSArray *methodsArray = info[kUexApplePayShippingMethodsKey];
    for (NSInteger i = 0; i < methodsArray.count; i++) {
        PKShippingMethod *method = [self getShippingMethodFromDict:methodsArray[i]];
        if (method) {
            [methods addObject:method];
        }
    }
    if (!methods || methods.count == 0) {
        return nil;
    }
    return methods;
}

+ (NSArray<PKPaymentSummaryItem *> *)itemsWithInfoDictionary:(NSDictionary *)info{
    if (!UEX_DICT_CONTAIN_DICTIONARY_VALUE(info, kUexApplePayPaymentKey)) {
        return nil;
    }
    NSDictionary *paymentDict = info[kUexApplePayPaymentKey];
    
    if (!UEX_DICT_CONTAIN_STRING_VALUE(paymentDict, kUexApplePayPayeeKey)) {
        return nil;
    }
    NSString *payee = paymentDict[kUexApplePayPayeeKey];
    NSDecimalNumber *totalPrice = [NSDecimalNumber zero];
    NSMutableArray<PKPaymentSummaryItem *> *items = [NSMutableArray array];
    if (UEX_DICT_CONTAIN_ARRAY_VALUE(paymentDict, kUexApplePayItemsKey)) {
        NSArray *itemArray = paymentDict[kUexApplePayItemsKey];
        for (NSInteger i = 0; i < itemArray.count ; i++) {
            PKPaymentSummaryItem *aItem = [self getItemFromDict:itemArray[i]];
            if (aItem) {
                totalPrice = [totalPrice decimalNumberByAdding:aItem.amount];
                [items addObject:aItem];
            }
        }
    }
    if (paymentDict[kUexApplePayTotalPriceKey]) {
        totalPrice = [self priceFromValue:paymentDict[kUexApplePayTotalPriceKey]];
    }else if(items.count == 0) {
        return nil;
    }
    PKPaymentSummaryItem *totalItem = [PKPaymentSummaryItem summaryItemWithLabel:payee amount:totalPrice];
    [items addObject:totalItem];
    return items;
}

+ (NSArray *)paymentNetworksWithInfoDictionary:(NSDictionary *)info{
    if(!info ||
       ![info isKindOfClass:[NSDictionary class]] ||
       !UEX_DICT_CONTAIN_ARRAY_VALUE(info, kUexApplePayNetworksKey)){
        return [[self availablePKPaymentNetworks] allValues];
    }
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < [info[kUexApplePayNetworksKey] count]; i++) {
        NSString *network = info[kUexApplePayNetworksKey][i];
        if (![network isKindOfClass:[NSString class]]) {
            continue;
        }
        network = [network stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
        if ([self availablePKPaymentNetworks][network]) {
            [array addObject:[self availablePKPaymentNetworks][network]];
        }
        
    }
    return array;
}

+ (PKShippingType)shippingTypeWithInfoDictionary:(NSDictionary *)info{
    PKShippingType type = PKShippingTypeShipping;
    NSInteger shippingType = info[kUexApplePayShippingTypeKey] ? [info[kUexApplePayShippingTypeKey] integerValue] : 0;
    switch (shippingType) {
        case 1:{
            type = PKShippingTypeDelivery;
            break;
        }
        case 2:{
            type = PKShippingTypeStorePickup;
            break;
        }
        case 3:{
            type = PKShippingTypeServicePickup;
            break;
        }
        default:{
            break;
        }
    }
    return type;
}


+ (PKAddressField)getAddressFieldFromDict:(NSDictionary *)dict forKey:(NSString *)key{
    PKAddressField addressField = PKAddressFieldNone;
    if (!dict[key]) {
        return addressField;
    }
    NSInteger flag = [dict[key] integerValue];
    addressField = flag & PKAddressFieldAll;
    return addressField;
}

+ (PKMerchantCapability)getMerchantCapabilityFromDict:(NSDictionary *)dict forKey:(NSString *)key{
    PKMerchantCapability capability = PKMerchantCapability3DS | PKMerchantCapabilityEMV | PKMerchantCapabilityDebit | PKMerchantCapabilityCredit;
    if (!dict[key]) {
        return capability;
    }
    NSInteger flag = [dict[key] integerValue];
    capability &= flag;
    return capability;
}

+ (PKPaymentSummaryItem *)getItemFromDict:(NSDictionary *)dict{
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if (!UEX_DICT_CONTAIN_STRING_VALUE(dict, kUexApplePayLabelKey)) {
        return nil;
    }
    NSString *label = dict[kUexApplePayLabelKey];
    NSDecimalNumber *price = [NSDecimalNumber zero];
    PKPaymentSummaryItemType type = PKPaymentSummaryItemTypePending;
    if (dict[kUexApplePayPriceKey]) {
        price = [self priceFromValue:dict[kUexApplePayPriceKey]];
        type = PKPaymentSummaryItemTypeFinal;
    }
    return [PKPaymentSummaryItem summaryItemWithLabel:label amount:price type:type];
}

+ (PKShippingMethod *)getShippingMethodFromDict:(NSDictionary *)dict{
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    PKShippingMethod *method = [[PKShippingMethod alloc]init];
    if (!UEX_DICT_CONTAIN_STRING_VALUE(dict, kUexApplePayIdentifierKey) ||
        !dict[kUexApplePayPriceKey] ||
        !UEX_DICT_CONTAIN_STRING_VALUE(dict, kUexApplePayLabelKey)) {
        return nil;
    }
    method.identifier = dict[kUexApplePayIdentifierKey];
    method.amount = [self priceFromValue:dict[kUexApplePayPriceKey]];
    method.label = dict[kUexApplePayLabelKey];
    method.detail = dict[kUexApplePayDetailKey];
    return method;
}

+ (NSDecimalNumber *)priceFromValue:(id)value{
    NSDecimalNumber *price = [NSDecimalNumber zero];
    if ([value isKindOfClass:[NSString class]]) {
        price = [NSDecimalNumber decimalNumberWithString:value];
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        price = [NSDecimalNumber decimalNumberWithString:[value stringValue]];
    }
    return price;
                 
}


#pragma mark - Util
+ (NSDictionary *)availablePKPaymentNetworks{
    static NSMutableDictionary *allNetWorks = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allNetWorks = [NSMutableDictionary dictionary];
        [allNetWorks setValue:PKPaymentNetworkAmex forKey:@"amex"];
        [allNetWorks setValue:PKPaymentNetworkMasterCard forKey:@"mastercard"];
        [allNetWorks setValue:PKPaymentNetworkVisa forKey:@"visa"];
        if (iOS9_2) {
            [allNetWorks setValue:PKPaymentNetworkDiscover forKey:@"discover"];
            [allNetWorks setValue:PKPaymentNetworkChinaUnionPay forKey:@"chinaunionpay"];
            [allNetWorks setValue:PKPaymentNetworkPrivateLabel forKey:@"privatelabel"];
            [allNetWorks setValue:PKPaymentNetworkInterac forKey:@"interac"];
        }
    });
    return allNetWorks;
}





+ (uexApplePayStatus)payStatusWithInfo:(NSDictionary *)info{
    if (!iOS9_2) {
        return uexApplePayStatusSystemNotSupport;
    }
    if (![PKPaymentAuthorizationViewController canMakePayments]) {
        return uexApplePayStatusDeviceNotSupport;
    }
    
    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[self paymentNetworksWithInfoDictionary:info]]) {
        return uexApplePayStatusAccountNotSupport;
    }
    return uexApplePayStatusAvailable;
}

+ (NSDictionary *)paymentMethodInfo:(PKPaymentMethod *)paymentMethod{
    if (!paymentMethod) {
        return @{};
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(paymentMethod.type) forKey:@"type"];
    [dict setValue:paymentMethod.displayName forKey:@"displayName"];
    [dict setValue:paymentMethod.network forKey:@"network"];
    return dict;
    
}
+ (NSDictionary *)shippingMethodInfo:(PKShippingMethod *)shippingMethod{
    if (!shippingMethod) {
        return @{};
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:shippingMethod.identifier forKey:kUexApplePayIdentifierKey];
    [dict setValue:shippingMethod.detail forKey:kUexApplePayDetailKey];
    [dict setValue:shippingMethod.amount.stringValue forKey:kUexApplePayPriceKey];
    [dict setValue:shippingMethod.label forKey:kUexApplePayLabelKey];
    return dict;
    
}
+ (NSDictionary *)contactInfo:(PKContact *)contact{
    if (!contact) {
        return @{};
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:contact.emailAddress forKey:@"emailAddress"];
    [dict setValue:contact.phoneNumber.stringValue forKey:@"phoneNumber"];
    [dict setValue:[self nameComponentsInfo:contact.name] forKey:@"nameInfo"];
    [dict setValue:[self postalAddressInfo:contact.postalAddress] forKey:@"addressInfo"];
    return dict;
}

+ (NSDictionary *)postalAddressInfo:(CNPostalAddress *)address{
    if (!address) {
        return nil;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:address.city forKey:@"city"];
    [dict setValue:address.street forKey:@"street"];
    [dict setValue:address.postalCode forKey:@"postalCode"];
    [dict setValue:address.state forKey:@"state"];
    [dict setValue:address.country forKey:@"country"];
    [dict setValue:address.ISOCountryCode forKey:@"ISOCounrtyCode"];
    return dict;
}
+ (NSDictionary *)nameComponentsInfo:(NSPersonNameComponents *)components{
    if (!components) {
        return nil;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:components.namePrefix forKey:@"namePrefix"];
    [dict setValue:components.nameSuffix forKey:@"nameSuffix"];
    [dict setValue:components.givenName forKey:@"givenName"];
    [dict setValue:components.middleName forKey:@"middleName"];
    [dict setValue:components.familyName forKey:@"familyName"];
    [dict setValue:components.nickname forKey:@"nickname"];
    return dict;
}
+ (NSDictionary *)paymentInfo:(PKPayment *)payment{
    if (!payment) {
        return nil;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[self shippingMethodInfo:payment.shippingMethod] forKey:@"shippingMethod"];
    [dict setValue:[self contactInfo:payment.billingContact] forKey:@"billingContact"];
    [dict setValue:[self contactInfo:payment.shippingContact] forKey:@"shippingContact"];
    [dict setValue:[self tokenInfo:payment.token] forKey:@"paymentInfo"];

    
    return dict;
}

+ (NSDictionary *)tokenInfo:(PKPaymentToken *)token{
    if (!token) {
        return nil;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[self paymentMethodInfo:token.paymentMethod] forKey:@"paymentMethod"];
    [dict setValue:token.transactionIdentifier forKey:@"transactionIdentifier"];
    NSError *error = nil;
    NSDictionary *tokenDict = [NSJSONSerialization JSONObjectWithData:token.paymentData options:NSJSONReadingMutableContainers error:&error];
    [dict setValue:tokenDict forKey:@"token"];
    return dict;
}
@end
