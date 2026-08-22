//go:build darwin && cgo

package biometric

/*
#cgo CFLAGS: -fblocks
#cgo LDFLAGS: -framework Foundation -framework LocalAuthentication
#include <stdlib.h>
#include "auth_darwin.h"
*/
import "C"

import (
	"fmt"
	"unsafe"
)

func Available() bool { return true }

func Authenticate(reason string) error {
	cReason := C.CString(reason)
	defer C.free(unsafe.Pointer(cReason))
	var message *C.char
	if C.secretctl_authenticate(cReason, &message) == 0 {
		return nil
	}
	if message == nil {
		return fmt.Errorf("Touch ID authentication failed")
	}
	defer C.secretctl_authentication_free(unsafe.Pointer(message))
	return fmt.Errorf("Touch ID authentication failed: %s", C.GoString(message))
}
