CC = gcc
DEBUG = -g
DEFINES =
CFLAGS = -Wall -Wextra -Wshadow -Wunreachable-code -Wredundant-decls \
         -Wmissing-declarations -Wold-style-definition \
         -Wmissing-prototypes -Wdeclaration-after-statement \
         -Wno-return-local-addr -Wunsafe-loop-optimizations \
         -Wuninitialized -Werror

LDFLAGS = -lssl -lcrypto -lmd

all: viktar

viktar: viktar.o
	$(CC) -o $@ $^ $(LDFLAGS)

viktar.o: viktar.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f viktar *.o *~ \#*

.PHONY: all clean

tar:
	tar cvfa viktar_${LOGNAME}.tar.gz *.[ch] [mM]akefile
