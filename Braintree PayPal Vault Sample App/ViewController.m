//
//  ViewController.m
//  Braintree PayPal Vault Sample App
//
//  Created by Orcun on 21/02/2016.
//  Copyright © 2016 Orcun. All rights reserved.
//

#import "ViewController.h"
#import "BraintreePayPal.h"
#import "BTDataCollector.h"


@interface ViewController () <BTAppSwitchDelegate, BTViewControllerPresentingDelegate>
@property (weak, nonatomic) IBOutlet UIButton *ppButton;

@property (nonatomic, strong) BTAPIClient *braintreeClient;
@property (nonatomic, strong) BTPayPalDriver *payPalDriver;

// Retain your `BTDataCollector` instance for your entire application lifecycle.
@property (nonatomic, strong) BTDataCollector *dataCollector;



@end

@implementation ViewController

NSString *resultCheck;
NSString *clientMetadataId;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    NSURL *clientTokenURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/BTOrcun/tokenGen.php"];
    NSMutableURLRequest *clientTokenRequest = [NSMutableURLRequest requestWithURL:clientTokenURL];
    [clientTokenRequest setValue:@"text/plain" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:clientTokenRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // TODO: Handle errors
        NSString *clientToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // Log the client token to confirm that it is returned from the server
        NSLog(@"%@",clientToken);
        self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
        // As an example, you may wish to present our Drop-in UI at this point.
        // Continue to the next section to learn more...
    }] resume];
    
    self.dataCollector = [[BTDataCollector alloc]
                          initWithEnvironment:BTDataCollectorEnvironmentSandbox];
    
    clientMetadataId = [BTDataCollector payPalClientMetadataId];
    NSLog(@"Send this device data to your server: %@", clientMetadataId);
}

- (IBAction)payWithPayPalTapped:(id)sender {
    // Invoke startCheckout function to start PayPal Vault payment flow
    [self startCheckout];
}

- (void)startCheckout {

    BTPayPalDriver *payPalDriver = [[BTPayPalDriver alloc] initWithAPIClient:self.braintreeClient];
    payPalDriver.viewControllerPresentingDelegate = self;
    payPalDriver.appSwitchDelegate = self; // Optional
    
    [payPalDriver authorizeAccountWithCompletion:^(BTPayPalAccountNonce * _Nullable tokenizedPayPalAccount, NSError * _Nullable error) {
        if (tokenizedPayPalAccount) {
            NSLog(@"Got a nonce: %@", tokenizedPayPalAccount.nonce);
            // Send payment method nonce to your server to create a transaction
            [self postNonceToServer:tokenizedPayPalAccount.nonce];
        } else if (error) {
            // Handle error here...
        } else {
            // Buyer canceled payment approval
        }
    }];
}

- (void)postNonceToServer:(NSString *)paymentMethodNonce {
    double price = 9.99;
    
    // I’m using my own server URL here. As you can see it’s not a HTTPS URL so I had to set an exception in Info.plist file, or else the POST request fails
    NSURL *paymentURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/BTOrcun/iosPayment.php"];
    
    // Let’s construct our POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:paymentURL];
    
    // I’m sending the payment nonce, amount and device data
    request.HTTPBody = [[NSString stringWithFormat:@"amount=%ld&payment_method_nonce=%@&device_data=%@", (long)price,paymentMethodNonce,clientMetadataId] dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPMethod = @"POST";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSString *paymentResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        // Logging the HTTP request so we can see what is being sent to the server side
        NSLog(@"Request body %@", [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding]);
        
        // Trimming the response for success/failure check so it takes less time to determine the result
        NSString *trimResult =[paymentResult substringToIndex:50];
        
        // Log the transaction result
        NSLog(@"%@",paymentResult);
        
        // I’m going to display the result in an alert controller so I’m using the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Checking the result for the string "Successful" for updating the alert controller
            if ([trimResult containsString:@"Successful"]) {
                NSLog(@"Transaction is successful!");
                resultCheck = @"Transaction successful";
                
            } else {
                NSLog(@"Transaction failed! Contact Mat!");
                resultCheck = @"Transaction failed!Contact Mat!";
            }
            
            // Create an alert controller to display the transaction result
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:resultCheck
                                                                           message:paymentResult
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:
                                            UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                
                                            }];
            
            [alert addAction:defaultAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        });
    }] resume];
    
    
}




#pragma mark - BTViewControllerPresentingDelegate

// Required
- (void)paymentDriver:(id)paymentDriver
requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

// Required
- (void)paymentDriver:(id)paymentDriver
requestsDismissalOfViewController:(UIViewController *)viewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - BTAppSwitchDelegate

// Optional - display and hide loading indicator UI
- (void)appSwitcherWillPerformAppSwitch:(id)appSwitcher {
    [self showLoadingUI];
    
    // You may also want to subscribe to UIApplicationDidBecomeActiveNotification
    // to dismiss the UI when a customer manually switches back to your app since
    // the payment button completion block will not be invoked in that case (e.g.
    // customer switches back via iOS Task Manager)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideLoadingUI:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)appSwitcherWillProcessPaymentInfo:(id)appSwitcher {
    [self hideLoadingUI:nil];
}

#pragma mark - Private methods

- (void)showLoadingUI {
   
}

- (void)hideLoadingUI:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
   
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
