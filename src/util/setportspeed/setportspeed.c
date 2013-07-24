/*
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

/* these includes are for ioctl() and cfmakeraw() but disabled to avoid conflicts with asm/* includes */
//#include <sys/ioctl.h>
//#include <termios.h>

#include <asm/ioctls.h>
#include <asm/termios.h>

int main(int argc, char** argv) {
	struct termios2 options2;
	int modemBits;
	int serialfd = -1;
	int ultiFiEnabled = 0;
	int r;
	const char* portname = NULL;
	int baudrate = -1;

	if (argc < 3) {
		fprintf(stderr, "%s: please supply a port name followed by the port speed, optionally followed by '-ultifi'\n", argv[0]);
		exit(1);
	}

	portname = argv[1];
	baudrate = strtol(argv[2], NULL, 10);

	if (argc >= 4 && strcmp(argv[3], "-ultifi") == 0) {
		ultiFiEnabled = 1;
		printf("%s: UltiFi-like bits will be set\n", argv[0]);
	}

	serialfd = open(portname, O_RDWR);
	if (serialfd == -1) {
		fprintf(stderr, "%s: could not open port %s (%s)\n", argv[0], portname, strerror(errno));
		exit(2);
	}

	r = ioctl(serialfd, TCGETS2, &options2);

	if (r == -1) {
		fprintf(stderr, "%s: ioctl error on port %s (%s)\n", argv[0], portname, strerror(errno));
		close(serialfd);
	}

	/***** START from UltiFi *****/
	if (ultiFiEnabled == 1) {
		//tcgetattr(fd, &options); //done using ioctl() above
		cfmakeraw(&options2);

		// Enable the receiver
		options2.c_cflag |= CREAD;
		// Clear handshake, parity, stopbits and size
		options2.c_cflag &= ~CLOCAL;
		options2.c_cflag &= ~CRTSCTS;
		options2.c_cflag &= ~PARENB;
		options2.c_cflag &= ~CSTOPB;
		options2.c_cflag &= ~CSIZE;

		options2.c_cflag |= CS8;
		options2.c_cflag |= CLOCAL;
	}
	/***** END from UltiFi *****/

	options2.c_ospeed = options2.c_ispeed = baudrate;
	options2.c_cflag &= ~CBAUD;
	options2.c_cflag |= BOTHER;
	r = ioctl(serialfd, TCSETS2, &options2);

	if (r == -1) {
		fprintf(stderr, "%s: ioctl error on port %s (%s)\n", argv[0], portname, strerror(errno));
		close(serialfd);
	}

	/***** START from UltiFi *****/
	if (ultiFiEnabled == 1) {
		ioctl(serialfd, TIOCMGET, &modemBits);
		modemBits |= TIOCM_DTR;
		ioctl(serialfd, TIOCMSET, &modemBits);
		usleep(100 * 1000);
		modemBits &= ~TIOCM_DTR;
		ioctl(serialfd, TIOCMSET, &modemBits);
	}
	/***** END from UltiFi *****/

	close(serialfd);
	exit(0);
}
