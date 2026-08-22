//go:build (!darwin && !linux) || (darwin && !cgo)

package secureinput

import "fmt"

func Read(string) ([]byte, error) {
	return nil, fmt.Errorf("hidden terminal input is not implemented on this platform")
}
