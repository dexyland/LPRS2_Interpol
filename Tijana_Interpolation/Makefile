#
###############################################################################
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Build interpolation.
#
###############################################################################

.PHONY: default test all clean

default: test

###############################################################################
# Private vars.

BUILD_OS=$(shell uname)
ifneq (,$(findstring MINGW,$(BUILD_OS)))
	BUILD_OS=WINNT
endif
ifneq (,$(findstring MSYS,$(BUILD_OS)))
	BUILD_OS=WINNT
endif

ifeq (${BUILD_OS},WINNT)
	EXE=.exe
else
	EXE=.elf
endif

CC=gcc

###############################################################################
# Rules.

interpolation${EXE}: interpolation.o
	${CXX} -o $@ $^ ${LDFLAGS} ${LIBS}

all: interpolation${EXE}
	
test: interpolation${EXE}
	./interpolation${EXE}

###############################################################################
# House keeping.

clean:
	rm -rf interpolation${EXE} *.o

dist: clean
	cd ../ && zip -9r \
		interpolation-$$(date +%F-%T | sed 's/:/-/g').zip interpolation
		
###############################################################################
