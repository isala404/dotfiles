package unlock

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/isala404/dotfiles/secretctl/internal/app"
)

const maxMessageSize = 2 << 20

func SocketPath() string {
	return filepath.Join(os.TempDir(), "secretctl-"+strconv.Itoa(os.Getuid()), "full-unlock.sock")
}

func Send(ctx context.Context, request app.Request) (app.Response, error) {
	dialer := net.Dialer{}
	connection, err := dialer.DialContext(ctx, "unix", SocketPath())
	if err != nil {
		return app.Response{}, err
	}
	defer connection.Close()
	if err := json.NewEncoder(connection).Encode(request); err != nil {
		return app.Response{}, err
	}
	var response app.Response
	if err := json.NewDecoder(io.LimitReader(connection, maxMessageSize)).Decode(&response); err != nil {
		return app.Response{}, err
	}
	return response, nil
}

func Available() bool {
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	connection, err := (&net.Dialer{}).DialContext(ctx, "unix", SocketPath())
	if err != nil {
		return false
	}
	connection.Close()
	return true
}

func Serve(ctx context.Context, handler func(context.Context, app.Request) app.Response) error {
	path := SocketPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	if err := os.Chmod(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	if Available() {
		return fmt.Errorf("secretctl full access is already unlocked")
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		return err
	}
	defer listener.Close()
	defer os.Remove(path)
	if err := os.Chmod(path, 0o600); err != nil {
		return err
	}

	go func() {
		<-ctx.Done()
		listener.Close()
	}()

	for {
		connection, err := listener.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) || ctx.Err() != nil {
				return nil
			}
			return err
		}
		err = serveConnection(ctx, connection, handler)
		connection.Close()
		if err != nil {
			continue
		}
	}
}

func serveConnection(ctx context.Context, connection net.Conn, handler func(context.Context, app.Request) app.Response) error {
	var request app.Request
	if err := json.NewDecoder(io.LimitReader(connection, maxMessageSize)).Decode(&request); err != nil {
		return err
	}
	return json.NewEncoder(connection).Encode(handler(ctx, request))
}
