/*
 * USB serial connectivity tester
 *
 * based on: http://lists.uclibc.org/pipermail/uclibc/2008-January/039683.html
 * see: http://marc.info/?l=linux-serial&m=120661887111805&w=2
 */
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <linux/serial.h>
#include <linux/termios.h>

static int serial_fd;
static char* serial_dev;
static int baud_rate;

typedef enum SET_SPEED_RESULT {
	SSR_OK = 0, SSR_IO_GET, SSR_IO_SET, SSR_IO_MGET, SSR_IO_MSET1, SSR_IO_MSET2
} SET_SPEED_RESULT;

/* based on setSerialSpeed in UltiFi */
static int setPortSpeed(int fd, int speed) {
	int rv;
	struct termios2 options;
	int modemBits;

	if (ioctl(fd, TCGETS2, &options) < 0) return SSR_IO_GET;

	cfmakeraw(&options);

	// Enable the receiver
	options.c_cflag |= CREAD;

	// Clear handshake, parity, stopbits and size
	options.c_cflag &= ~CLOCAL;
	options.c_cflag &= ~CRTSCTS;
	options.c_cflag &= ~PARENB;
	options.c_cflag &= ~CSTOPB;
	options.c_cflag &= ~CSIZE;

	//set speed
	options.c_ospeed = options.c_ispeed = speed;
	options.c_cflag &= ~CBAUD;
	options.c_cflag |= BOTHER;

	options.c_cflag |= CS8;
	options.c_cflag |= CLOCAL;

	if (ioctl(fd, TCSETS2, &options) < 0) return SSR_IO_SET;

	//toggle DTR
	if (ioctl(fd, TIOCMGET, &modemBits) < 0) return SSR_IO_MGET);
	modemBits |= TIOCM_DTR;
	if (ioctl(fd, TIOCMSET, &modemBits) < 0) return SSR_IO_MSET1);
	usleep(100 * 1000);
	modemBits &=~TIOCM_DTR;
	if (ioctl(fd, TIOCMSET, &modemBits) < 0) return SSR_IO_MSET2);

	return SSR_OK;
}

int main(int argc, char** argv) {
	SET_SPEED_RESULT spdResult;

	if (argc < 2) {
		fprintf(stderr, "%s: please supply a port name, optionally followed by the port speed\n", argv[0]);
		exit(1);
	}

	serial_dev = argv[1];

	if (argc >= 3) {
		baud_rate = strtol(argv[2], NULL, 10);
	} else {
		baud_rate = 115200;
	}

	serial_fd = open(serial_dev, O_RDWR);
	if (serial_fd == -1) {
		fprintf(stderr, "%s: could not open port %s (%s)\n", argv[0], portname, strerror(errno));
		exit(2);
	}

	printf("using port %s with speed %i\n", serial_dev, baud_rate);

	spdResult = setPortSpeed(baud_rate);
	switch (spdResult) {
	case SSR_OK:
		printf("port opened ok\n");
		break;
	case SSR_IO_GET: fprintf(stderr, "ioctl error in setPortSpeed() on TCGETS2 (%s)\n", strerror(errno));
	case SSR_IO_SET: fprintf(stderr, "ioctl error in setPortSpeed() on TCSETS2 (%s)\n", strerror(errno));
	case SSR_IO_MGET: fprintf(stderr, "ioctl error in setPortSpeed() on TIOCMGET (%s)\n", strerror(errno));
	case SSR_IO_MSET1: fprintf(stderr, "ioctl error in setPortSpeed() on TIOCMSET1 (%s)\n", strerror(errno));
	case SSR_IO_MSET2: fprintf(stderr, "ioctl error in setPortSpeed() on TIOCMSET2 (%s)\n", strerror(errno));

		exit(1);
		break;
	}

	//TODO: rename this program to something like 'usb_serial_tester' (also change in Makefile etc.)
	//TODO: make existing code above compile and behave as intended
	//TODO: (maybe): add timing messages to detect how long everything takes and when (if) things get stuck
	//TODO: periodically send message and check if it is returned (by tiny program on arduino which echoes everything back)

	close(serial_fd);
	exit(0);
}
