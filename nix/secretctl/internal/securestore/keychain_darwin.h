#ifndef SECRETCTL_KEYCHAIN_DARWIN_H
#define SECRETCTL_KEYCHAIN_DARWIN_H

#include <stddef.h>

int secretctl_keychain_set(const char *account, const void *value, size_t value_len, char **error_out);
int secretctl_keychain_get(const char *account, const char *reason, void **value_out, size_t *value_len_out, char **error_out);
int secretctl_keychain_exists(const char *account, int *exists_out, char **error_out);
int secretctl_keychain_delete(const char *account, char **error_out);
void secretctl_keychain_free(void *value);

#endif
