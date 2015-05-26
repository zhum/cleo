# usage:
# 	make `uname -s`		to build for your platform or
# 	make			to build for *BSD or Linux
#
include ../Makefile.conf

CC:=gcc

LDFLAGS=-L/lib64 -L/usr/lib64

THEBINDIR=$(BASEDIR)/$(BINDIR)
THESBINDIR=$(BASEDIR)/$(SBINDIR)
THEMANDIR=$(BASEDIR)/$(MANDIR)

all:
	$(CC) -o empty-cleo empty-cleo.c $(LDFLAGS) $(RPM_OPT_FLAGS) -lutil 
	cp empty-cleo ../ready	

FreeBSD:	all
NetBSD:		all
OpenBSD:
	$(CC) -o empty-cleo empty-cleo.c -DOpenBSD $(LDFLAGS) $(RPM_OPT_FLAGS) -lutil

Linux:		all

SunOS:				
	# gcc compiler under i386
	$(CC) $(LDFLAGS) -o empty-cleo empty-cleo.c -Dsvr4

UnixWare:
	# Native UnixWare 7.1.x compiler
	cc $(LDFLAGS) -o empty-cleo empty-cleo.c -Dsvr4
OpenUNIX:	UnixWare

# -----------------------------------------------------------------------------
install:
	strip empty-cleo
	cp empty-cleo $(THEBINDIR)
	cp empty-cleo.1 $(THEMANDIR)
deinstall:
	rm $(THEBINDIR)/empty-cleo
	rm $(THEMANDIR)/empty-cleo.1
uninstall:	deinstall

clean:
	rm empty-cleo *.o
