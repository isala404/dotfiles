#include <stddef.h>

int secretctl_authenticate(const char *reason, char **error_out);
void secretctl_authentication_free(void *value);
