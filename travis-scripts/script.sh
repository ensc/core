#!/bin/sh
INSTDIR=$HOME/cf_install
cd $TRAVIS_BUILD_DIR || return 1

# if [ "$JOB_TYPE" = style_check ]
# then
#     # sh tests/misc/style_check.sh
#     exit 0
# fi

# Unshallow the clone. Fetch the tags from upstream even if we are on a
# foreign clone. Needed for determine-version.py to work, specifically
# `git describe --tags HEAD` was failing once the last tagged commit
# became too old.
git fetch --unshallow
git remote add upstream https://github.com/cfengine/core.git  \
    && git fetch upstream 'refs/tags/*:refs/tags/*'

if [ "$TRAVIS_OS_NAME" = osx ]
then
    # On osx the default gcc is actually LLVM
    export CC=gcc-7
    NO_CONFIGURE=1 ./autogen.sh
    ./configure --enable-debug --prefix=$INSTDIR --bindir=$INSTDIR/var/cfengine/bin --with-init-script --with-lmdb=/usr/local/Cellar/lmdb
else
    NO_CONFIGURE=1 ./autogen.sh
    ./configure --enable-debug --with-tokyocabinet --prefix=$INSTDIR --with-init-script
fi

make dist

DIST_TARBALL=`echo cfengine-*.tar.gz`
export DIST_TARBALL

if [ "$JOB_TYPE" = compile_only ]
then
     make CFLAGS=-Werror
elif [ "$JOB_TYPE" = compile_and_unit_test ]
then
    make CFLAGS=-Werror  &&
    make -C tests/unit check
    return
else
    make
fi

cd tests/acceptance || return 1
chmod -R go-w .

if [ "$JOB_TYPE" = acceptance_tests_common ]
then
    ./testall --tests=common
    return
fi

  # WARNING: the following job runs the selected tests as root!
if [ "$JOB_TYPE" = acceptance_tests_unsafe_serial_network_etc ]
then
    ./testall --gainroot=sudo --tests=timed,slow,errorexit,libxml2,libcurl,serial,network,unsafe
    return
fi
