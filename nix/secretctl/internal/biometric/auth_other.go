//go:build !darwin || !cgo

package biometric

import "fmt"

func Available() bool { return false }

func Authenticate(string) error {
	return fmt.Errorf("user-presence authentication is not implemented on this platform")
}
