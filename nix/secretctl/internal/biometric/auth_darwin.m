#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>

#include "auth_darwin.h"

static int fail(char **error_out, NSString *message) {
    if (error_out != NULL) {
        *error_out = strdup(message.UTF8String);
    }
    return -1;
}

int secretctl_authenticate(const char *reason, char **error_out) {
    @autoreleasepool {
        LAContext *context = [[LAContext alloc] init];
        context.localizedReason = [NSString stringWithUTF8String:reason];

        NSError *availabilityError = nil;
        if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&availabilityError]) {
            return fail(error_out, [NSString stringWithFormat:@"Touch ID is unavailable: %@", availabilityError.localizedDescription]);
        }

        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block BOOL authenticated = NO;
        __block char *failureMessage = NULL;
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:[NSString stringWithUTF8String:reason]
                          reply:^(BOOL success, NSError *error) {
            authenticated = success;
            if (!success) {
                NSString *message = error == nil ? @"Touch ID failed" : error.localizedDescription;
                failureMessage = strdup(message.UTF8String);
            }
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        if (!authenticated) {
            if (failureMessage != NULL) {
                *error_out = failureMessage;
                return -1;
            }
            return fail(error_out, @"Touch ID failed");
        }
        if (failureMessage != NULL) {
            free(failureMessage);
        }
        return 0;
    }
}

void secretctl_authentication_free(void *value) {
    free(value);
}
