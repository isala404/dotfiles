//go:build darwin && cgo

package secureinput

/*
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

static int secretctl_read_secret(const char *prompt, char **value_out, char **error_out) {
	int fd = open("/dev/tty", O_RDWR);
	if (fd == -1) {
		*error_out = strdup(strerror(errno));
		return -1;
	}
	struct termios original;
	if (tcgetattr(fd, &original) == -1) {
		*error_out = strdup(strerror(errno));
		close(fd);
		return -1;
	}
	struct termios hidden = original;
	hidden.c_lflag &= ~(ECHO);
	if (tcsetattr(fd, TCSAFLUSH, &hidden) == -1) {
		*error_out = strdup(strerror(errno));
		close(fd);
		return -1;
	}
	dprintf(fd, "%s", prompt);
	FILE *stream = fdopen(fd, "r+");
	char *line = NULL;
	size_t capacity = 0;
	ssize_t length = getline(&line, &capacity, stream);
	tcsetattr(fd, TCSAFLUSH, &original);
	dprintf(fd, "\n");
	fclose(stream);
	if (length < 0) {
		free(line);
		*error_out = strdup("failed to read secret input");
		return -1;
	}
	if (length > 0 && line[length - 1] == '\n') line[--length] = '\0';
	*value_out = line;
	return 0;
}
*/
import "C"

import (
	"fmt"
	"unsafe"
)

func Read(prompt string) ([]byte, error) {
	cPrompt := C.CString(prompt)
	defer C.free(unsafe.Pointer(cPrompt))
	var value *C.char
	var message *C.char
	if C.secretctl_read_secret(cPrompt, &value, &message) != 0 {
		if message == nil {
			return nil, fmt.Errorf("read secret input")
		}
		defer C.free(unsafe.Pointer(message))
		return nil, fmt.Errorf("read secret input: %s", C.GoString(message))
	}
	defer C.free(unsafe.Pointer(value))
	return []byte(C.GoString(value)), nil
}
