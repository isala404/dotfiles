//go:build darwin && cgo

package securestore

/*
#cgo LDFLAGS: -framework Foundation -framework Security
#include <stdlib.h>
#include "keychain_darwin.h"
*/
import "C"

import (
	"fmt"
	"unsafe"
)

type keychainStore struct{}

func New() Store {
	return keychainStore{}
}

func (keychainStore) Set(account string, value []byte) error {
	cAccount := C.CString(account)
	defer C.free(unsafe.Pointer(cAccount))
	var cValue unsafe.Pointer
	if len(value) > 0 {
		cValue = C.CBytes(value)
		defer C.free(cValue)
	}
	var cError *C.char
	status := C.secretctl_keychain_set(cAccount, cValue, C.size_t(len(value)), &cError)
	return keychainError(status, cError)
}

func (keychainStore) Get(account, reason string) ([]byte, error) {
	cAccount := C.CString(account)
	cReason := C.CString(reason)
	defer C.free(unsafe.Pointer(cAccount))
	defer C.free(unsafe.Pointer(cReason))
	var cValue unsafe.Pointer
	var cLength C.size_t
	var cError *C.char
	status := C.secretctl_keychain_get(cAccount, cReason, &cValue, &cLength, &cError)
	if status == 1 {
		return nil, ErrNotFound
	}
	if err := keychainError(status, cError); err != nil {
		return nil, err
	}
	defer C.secretctl_keychain_free(cValue)
	return C.GoBytes(cValue, C.int(cLength)), nil
}

func (keychainStore) Exists(account string) (bool, error) {
	cAccount := C.CString(account)
	defer C.free(unsafe.Pointer(cAccount))
	var exists C.int
	var cError *C.char
	status := C.secretctl_keychain_exists(cAccount, &exists, &cError)
	if err := keychainError(status, cError); err != nil {
		return false, err
	}
	return exists == 1, nil
}

func (keychainStore) Delete(account string) error {
	cAccount := C.CString(account)
	defer C.free(unsafe.Pointer(cAccount))
	var cError *C.char
	status := C.secretctl_keychain_delete(cAccount, &cError)
	return keychainError(status, cError)
}

func keychainError(status C.int, message *C.char) error {
	if message != nil {
		defer C.secretctl_keychain_free(unsafe.Pointer(message))
	}
	if status == 0 {
		return nil
	}
	if message == nil {
		return fmt.Errorf("Keychain operation failed")
	}
	return fmt.Errorf("%s", C.GoString(message))
}
