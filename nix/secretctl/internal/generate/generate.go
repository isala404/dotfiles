package generate

import (
	"crypto/rand"
	"fmt"
)

const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"

func Value(length int) (string, error) {
	if length < 16 || length > 4096 {
		return "", fmt.Errorf("generated secret length must be between 16 and 4096")
	}
	raw := make([]byte, length)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	for i := range raw {
		raw[i] = alphabet[int(raw[i])%len(alphabet)]
	}
	return string(raw), nil
}
