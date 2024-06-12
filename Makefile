# repology Makefile

PREFIX ?=	/usr/local
MANDIR ?=	${PREFIX}

DMD ?=		dmd
DFLAGS ?=	-O -release -inline

PROG =	repology

all:
	${DMD} ${DFLAGS} ${PROG}.d

install:
	install -c -s -m 755 ${PROG} ${DESTDIR}${PREFIX}/bin
	install -c -m 444 ${PROG}.1 ${DESTDIR}${MANDIR}/man/man1

uninstall:
	rm -f ${PREFIX}/bin/${PROG} ${PREFIX}/man/man1/${PROG}.1

test:
	@echo No tests.

clean:
	rm -f ${PROG} ${PROG}.o ${PROG}.core
