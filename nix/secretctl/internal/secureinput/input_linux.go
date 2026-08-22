//go:build linux

package secureinput

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"unsafe"
)

func Read(prompt string) ([]byte, error) {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return nil, fmt.Errorf("open terminal: %w", err)
	}
	defer tty.Close()

	original, err := getTermios(tty.Fd())
	if err != nil {
		return nil, fmt.Errorf("read terminal settings: %w", err)
	}
	hidden := *original
	hidden.Lflag &^= syscall.ECHO
	if err := setTermios(tty.Fd(), &hidden); err != nil {
		return nil, fmt.Errorf("hide terminal input: %w", err)
	}

	var restoreOnce sync.Once
	var restoreErr error
	restore := func() {
		restoreOnce.Do(func() {
			restoreErr = setTermios(tty.Fd(), original)
		})
	}
	defer restore()

	done := make(chan struct{})
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
	var signalHandler sync.WaitGroup
	signalHandler.Add(1)
	go func() {
		defer signalHandler.Done()
		select {
		case received := <-signals:
			restore()
			signal.Reset(received)
			process, err := os.FindProcess(os.Getpid())
			if err == nil {
				_ = process.Signal(received)
			}
		case <-done:
		}
	}()

	if _, err := fmt.Fprint(tty, prompt); err != nil {
		return nil, err
	}
	value, readErr := bufio.NewReader(tty).ReadBytes('\n')
	signal.Stop(signals)
	close(done)
	signalHandler.Wait()
	restore()
	if readErr != nil {
		return nil, readErr
	}
	if restoreErr != nil {
		return nil, fmt.Errorf("restore terminal settings: %w", restoreErr)
	}
	if _, err := fmt.Fprintln(tty); err != nil {
		return nil, err
	}
	return bytes.TrimSuffix(bytes.TrimSuffix(value, []byte{'\n'}), []byte{'\r'}), nil
}

func getTermios(fd uintptr) (*syscall.Termios, error) {
	var termios syscall.Termios
	_, _, errno := syscall.Syscall6(syscall.SYS_IOCTL, fd, syscall.TCGETS, uintptr(unsafe.Pointer(&termios)), 0, 0, 0)
	if errno != 0 {
		return nil, errno
	}
	return &termios, nil
}

func setTermios(fd uintptr, termios *syscall.Termios) error {
	_, _, errno := syscall.Syscall6(syscall.SYS_IOCTL, fd, syscall.TCSETS, uintptr(unsafe.Pointer(termios)), 0, 0, 0)
	if errno != 0 {
		return errno
	}
	return nil
}
