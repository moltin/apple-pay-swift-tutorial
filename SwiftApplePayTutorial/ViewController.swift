//
//  ViewController.swift
//  SwiftApplePayTutorial
//
//  Created by Dylan McKee on 16/01/2016.
//  Copyright © 2016 moltin. All rights reserved.
//

import UIKit
import Moltin
import Stripe
import PassKit


class ViewController: UIViewController, PKPaymentAuthorizationViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Set up Moltin SDK for store
        // TODO: Fill in your Moltin Public store ID here
        Moltin.sharedInstance().setPublicId("YOUR_PUBLIC_STORE_ID_HERE")
        
        // Set up Stripe SDK to handle Apple Pay
        // TODO: Fill in your Stripe publishable key here
        Stripe.setDefaultPublishableKey("YOUR_STRIPE_PUBLISHALBE_KEY_HERE")
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buyButtonTapped() {
        Moltin.sharedInstance().product.listingWithParameters(nil, success: { (response) -> Void in
            // The array of products is at the "result" key
            let objects = response["result"]! as! [AnyObject]
            
            // Let's buy the first product we come to...
            if let productToBuy = objects.first {
                let productId:String = productToBuy["id"] as! String
                
                // Add it to the cart...
                Moltin.sharedInstance().cart.insertItemWithId(productId, quantity: 1, andModifiersOrNil: nil, success: { (response) -> Void in
                    // Added to cart - now let's check-out!
                    print("Added \(productId) to the cart - now going to check-out")
                    self.checkOut()
                    }, failure: { (response, error) -> Void in
                        print("Something went wrong! \(error)")

                })
                
            }
            
            }, failure: { (response, error) -> Void in
                print("Something went wrong! \(error)")
        })
    }
    
    func checkOut() {
        let request = PKPaymentRequest()
        
        // Moltin and Stripe support all the networks! 😀
        let supportedPaymentNetworks = [PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex]
        
        // TODO: Fill in your merchant ID here from the Apple Developer Portal
        let applePaySwagMerchantID = "YOUR_MERCHANT_ID_HERE"
        
        request.merchantIdentifier = applePaySwagMerchantID
        request.supportedNetworks = supportedPaymentNetworks
        request.merchantCapabilities = PKMerchantCapability.Capability3DS
        request.requiredShippingAddressFields = PKAddressField.All
        request.requiredBillingAddressFields = PKAddressField.All

        // TODO: Change these for your country!
        request.countryCode = "GB"
        request.currencyCode = "GBP"
        
        // In production apps, you'd get this from what's currently in the cart, but for now we're just hardcoding it
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Moltin Swag", amount: 0.53)
        ]
        
        let applePayController = PKPaymentAuthorizationViewController(paymentRequest: request)
        applePayController.delegate = self
        self.presentViewController(applePayController, animated: true, completion: nil)

        
    }
    
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: ((PKPaymentAuthorizationStatus) -> Void)) {
        // Payment authorised, now send the data to Stripe to get a Stripe token...
        
        Stripe.createTokenWithPayment(payment) { (token, error) -> Void in
            let tokenValue = token?.tokenId
            // We can now pass tokenValue up to Moltin to charge - let's do the moltin checkout.
            
            // TODO: Enter your store's default shipping option slug (if it's not 'free_shipping')!
            var orderParameters = [
                "shipping": "free_shipping",
                "gateway": "stripe",
                "ship_to": "bill_to"
                ] as [String: AnyObject]
            
            // In production apps, these values should be checked/validated first...
            var customerDict = Dictionary<String, String>()
            customerDict["first_name"] = payment.billingContact!.name!.givenName!
            customerDict["last_name"] = payment.billingContact!.name!.familyName!
            customerDict["email"] = payment.shippingContact!.emailAddress!
            orderParameters["customer"] = customerDict
            
            var billingDict = Dictionary<String, String>()
            billingDict["first_name"] = payment.billingContact!.name!.givenName!
            billingDict["last_name"] = payment.billingContact!.name!.familyName!
            billingDict["address_1"] = payment.billingContact!.postalAddress!.street
            billingDict["city"] = payment.billingContact!.postalAddress!.city
            billingDict["country"] = payment.billingContact!.postalAddress!.ISOCountryCode.uppercaseString
            billingDict["postcode"] = payment.billingContact!.postalAddress!.postalCode
            orderParameters["bill_to"] = billingDict

            Moltin.sharedInstance().cart.orderWithParameters(orderParameters, success: { (response) -> Void in
                // Order succesful
                print("Order succeeded: \(response)")
                
                // Extract the Order ID so that it can be used in payment too...
                let orderId = (response as NSDictionary).valueForKeyPath("result.id") as! String
                
                print("Order ID: \(orderId)")
                
                // Now, pay using the Stripe token...
                let paymentParameters = ["token": tokenValue!] as [NSObject: AnyObject]
                
                Moltin.sharedInstance().checkout.paymentWithMethod("purchase", order: orderId, parameters: paymentParameters, success: { (response) -> Void in
                    // Payment successful...
                    print("Payment successful: \(response)")
                    completion(PKPaymentAuthorizationStatus.Success)

                    }, failure: { (response, error) -> Void in
                        // Payment error
                        print("Payment error: \(error)")
                        completion(PKPaymentAuthorizationStatus.Failure)

                })
                
                }, failure: { (response, error) -> Void in
                    // Order failed
                    print("Order error: \(error)")
                    completion(PKPaymentAuthorizationStatus.Failure)

            })
            
        }
        
    }
    
    func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }

}

