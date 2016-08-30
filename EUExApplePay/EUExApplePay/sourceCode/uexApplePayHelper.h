/**
 *
 *	@file   	: uexApplePayHelper.h  in EUExApplePay Project .
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

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>



extern NSString *const kUexApplePayMerchantIdentifierKey;
extern NSString *const kUexApplePayCountryCodeKey;
extern NSString *const kUexApplePayCurrencyCodeKey;
extern NSString *const kUexApplePayNetworksKey;
extern NSString *const kUexApplePayPaymentKey;
extern NSString *const kUexApplePayItemsKey;
extern NSString *const kUexApplePayLabelKey;
extern NSString *const kUexApplePayPriceKey;
extern NSString *const kUexApplePayDetailKey;
extern NSString *const kUexApplePayIdentifierKey;
extern NSString *const kUexApplePayPayeeKey;
extern NSString *const kUexApplePayTotalPriceKey;
extern NSString *const kUexApplePayShippingMethodsKey;
extern NSString *const kUexApplePayShippingTypeKey;
extern NSString *const kUexApplePayShippingContactRequiredFlagKey;
extern NSString *const kUexApplePayBillingContactRequiredFlagKey;
extern NSString *const kUexApplePayMerchantCapabilityKey;



typedef NS_ENUM(NSInteger,uexApplePayStatus) {
    uexApplePayStatusAvailable = 0,
    uexApplePayStatusSystemNotSupport,
    uexApplePayStatusDeviceNotSupport,
    uexApplePayStatusAccountNotSupport,
};

@interface uexApplePayHelper : NSObject

+ (PKPaymentRequest *)requestWithInfoDictionary:(NSDictionary *)info;
+ (NSArray<PKShippingMethod *> *)shippingMethodsWithInfoDictionary:(NSDictionary *)info;
+ (NSArray<PKPaymentSummaryItem *> *)itemsWithInfoDictionary:(NSDictionary *)info;
+ (NSArray *)paymentNetworksWithInfoDictionary:(NSDictionary *)info;

+ (uexApplePayStatus)payStatusWithInfo:(NSDictionary *)info;
+ (NSDictionary *)paymentMethodInfo:(PKPaymentMethod *)paymentMethod;
+ (NSDictionary *)shippingMethodInfo:(PKShippingMethod *)shippingMethod;
+ (NSDictionary *)contactInfo:(PKContact *)contact;
+ (NSDictionary *)paymentInfo:(PKPayment *)payment;





@end
