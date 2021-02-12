#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(CfdjsWasm, NSObject)

RCT_EXTERN_METHOD(initCfd:(NSString *)modId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(callCfd:(NSString *)modId funcName:(NSString *)name arguments:(NSString *)args resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
