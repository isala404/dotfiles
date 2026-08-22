#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <stdlib.h>
#include <string.h>

#include "keychain_darwin.h"

static NSString *const service = @"dev.isala.secretctl";

static int fail(char **error_out, NSString *message) {
    if (error_out != NULL) {
        *error_out = strdup(message.UTF8String);
    }
    return -1;
}

static NSMutableDictionary *base_query(const char *account) {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: [NSString stringWithUTF8String:account],
    } mutableCopy];
}

int secretctl_keychain_set(const char *account, const void *value, size_t value_len, char **error_out) {
    @autoreleasepool {
        NSData *data = [NSData dataWithBytes:value length:value_len];
        NSMutableDictionary *lookup = base_query(account);
        OSStatus status = SecItemUpdate(
            (__bridge CFDictionaryRef)lookup,
            (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: data}
        );
        if (status == errSecSuccess) {
            return 0;
        }
        if (status != errSecItemNotFound) {
            return fail(error_out, [NSString stringWithFormat:@"update Keychain item: %@", SecCopyErrorMessageString(status, NULL)]);
        }

        NSMutableDictionary *item = base_query(account);
        item[(__bridge id)kSecValueData] = data;
		item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
		status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        if (status != errSecSuccess) {
            return fail(error_out, [NSString stringWithFormat:@"add Keychain item: %@", SecCopyErrorMessageString(status, NULL)]);
        }
        return 0;
    }
}

int secretctl_keychain_get(const char *account, const char *reason, void **value_out, size_t *value_len_out, char **error_out) {
    @autoreleasepool {
		(void)reason;
        NSMutableDictionary *query = base_query(account);
        query[(__bridge id)kSecReturnData] = @YES;
        query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (status == errSecItemNotFound) return 1;
        if (status != errSecSuccess) {
            return fail(error_out, [NSString stringWithFormat:@"read Keychain item: %@", SecCopyErrorMessageString(status, NULL)]);
        }
        NSData *data = CFBridgingRelease(result);
        void *copy = malloc(data.length);
        if (copy == NULL && data.length != 0) {
            return fail(error_out, @"allocate Keychain result");
        }
        memcpy(copy, data.bytes, data.length);
        *value_out = copy;
        *value_len_out = data.length;
        return 0;
    }
}

int secretctl_keychain_exists(const char *account, int *exists_out, char **error_out) {
    @autoreleasepool {
        NSMutableDictionary *query = base_query(account);
        query[(__bridge id)kSecReturnAttributes] = @YES;
        query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (result != NULL) CFRelease(result);
        if (status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecAuthFailed) {
            *exists_out = 1;
            return 0;
        }
        if (status == errSecItemNotFound) {
            *exists_out = 0;
            return 0;
        }
        return fail(error_out, [NSString stringWithFormat:@"inspect Keychain item: %@", SecCopyErrorMessageString(status, NULL)]);
    }
}

int secretctl_keychain_delete(const char *account, char **error_out) {
    @autoreleasepool {
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)base_query(account));
        if (status == errSecSuccess || status == errSecItemNotFound) return 0;
        return fail(error_out, [NSString stringWithFormat:@"delete Keychain item: %@", SecCopyErrorMessageString(status, NULL)]);
    }
}

void secretctl_keychain_free(void *value) {
    free(value);
}
