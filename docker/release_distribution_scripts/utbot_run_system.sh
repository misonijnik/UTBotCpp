#!/bin/bash

#
# Copyright (c) Huawei Technologies Co., Ltd. 2012-2021. All rights reserved.
#

# This script can launch server, cli and tests
#arguments - add MODE (server | cli | test)

# Check if arguments are correct
if [ "$1" != "cli" ] && [ "$1" != "server" ] && [ "$1" != "test" ]
then
  echo "Wrong UTBOT_MODE: expected cli|server|test"
  exit 1
fi

#set UTBot release flag
export UTBOT_RELEASE=true

# Retrieving path to $UTBOT_ALL from absolute path to current script
export UTBOT_ALL=$CURRENT_FOLDER

# Setting environment variables according to $UTBOT_ALL
export UTBOT_INSTALL_DIR=$UTBOT_ALL/install
export CC=$UTBOT_ALL/debs-install/usr/bin/gcc-9
export CXX=$UTBOT_ALL/debs-install/usr/bin/g++-9
export CPATH=$CPATH:$UTBOT_ALL/klee/include # Path for C and C++ includes
export PATH=$UTBOT_ALL/bear/bin:$UTBOT_ALL/klee/bin:$UTBOT_INSTALL_DIR/bin:$PATH
export KLEE_RUNTIME_LIBRARY_PATH=$UTBOT_ALL/klee/lib/klee/runtime/

# If the system is opensuse, variable is not empty. It is empty otherwise.
IS_SUSE="$(grep '^NAME=' /etc/os-release | tr '[:upper:]' '[:lower:]' | grep suse)"

# Setting environment variables for debian packages
export PATH=$UTBOT_ALL/debs-install/usr/bin:$PATH
export LD_LIBRARY_PATH=$UTBOT_ALL/debs-install/usr/lib/x86_64-linux-gnu:$UTBOT_ALL/debs-install/lib/x86_64-linux-gnu:$UTBOT_ALL/debs-install/usr/lib:$UTBOT_ALL/install/lib
export CPATH=$CPATH:$UTBOT_ALL/debs-install/usr/include:$UTBOT_ALL/debs-install/usr/include/x86_64-linux-gnu/
export C_INCLUDE_PATH=$C_INCLUDE_PATH:$UTBOT_ALL/debs-install/usr/include:$UTBOT_ALL/debs-install/usr/lib/gcc/x86_64-linux-gnu/9/include/
export CPLUS_INCLUDE_PATH=$UTBOT_ALL/debs-install/usr/include/c++/9:$UTBOT_ALL/debs-install/usr/include/x86_64-linux-gnu/c++/9:$UTBOT_ALL/debs-install/usr/include/c++/9/backward:$UTBOT_ALL/debs-install/usr/include
export LDFLAGS="-fuse-ld=gold -B $UTBOT_ALL/debs-install/usr/lib/gcc/x86_64-linux-gnu/9/ -L $UTBOT_ALL/debs-install/usr/lib/gcc/x86_64-linux-gnu/9/  -B $UTBOT_ALL/debs-install/usr/lib/x86_64-linux-gnu/ -L $UTBOT_ALL/debs-install/usr/lib/x86_64-linux-gnu/ -L$UTBOT_ALL/debs-install/usr/lib64/ -B $UTBOT_ALL/debs-install/usr/lib64/ -L /lib64/ -B /lib64/" # Paths for object files and libraries with which compiler should link the project
# This function moves dev version of libc into $UTBOT_ALL/debs-install directory
# Prerequisites: path/to/directory should exist
# Arguments:
#   $1 = path/to/directory  The first argument is a path to a directory dev libc package
move-libc-dev() {
  # If dev libc has already been moved, skipping
  if test -e "$UTBOT_ALL/$1"; then
    cp -r $UTBOT_ALL/$1/* $UTBOT_ALL/debs-install
    rm -rf $UTBOT_ALL/$1
  fi
}

if [ -z "$IS_SUSE" ]
then
      # If the system is not suse, use debian packages
      move-libc-dev debian-libc-dev-install
      X86_LIBS=lib/x86_64-linux-gnu
else
      # If the system is suse, use rpm packages
      move-libc-dev suse-libc-dev-install
      X86_LIBS=lib64

      # Updating libm.so so that it contains valid path to libmvec_nonshared.a
      echo "/* GNU ld script
*/
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /$X86_LIBS/libm.so.6  AS_NEEDED ( $UTBOT_ALL/debs-install/usr/$X86_LIBS/libmvec_nonshared.a /$X86_LIBS/libmvec.so.1 ) )" > $UTBOT_ALL/debs-install/usr/$X86_LIBS/libm.so

      export LDFLAGS="$LDFLAGS -L$UTBOT_ALL/debs-install/usr/lib64/ -B $UTBOT_ALL/debs-install/usr/lib64/ -L /lib64/ -B /lib64/"
fi

# Updating libc.so so that it contains valid path to libc_nonshared.a
echo "/* GNU ld script
   Use the shared library, but some functions are only in
   the static library, so try that secondarily.  */
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /$X86_LIBS/libc.so.6 $UTBOT_ALL/debs-install/usr/$X86_LIBS/libc_nonshared.a  AS_NEEDED ( /$X86_LIBS/ld-linux-x86-64.so.2 ) )" > $UTBOT_ALL/debs-install/usr/$X86_LIBS/libc.so

# Updating libpthread.so so that it contains valid path to libpthread_nonshared.a
echo "/* GNU ld script
   Use the shared library, but some functions are only in
   the static library, so try that secondarily.  */
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /$X86_LIBS/libpthread.so.0 $UTBOT_ALL/debs-install/usr/$X86_LIBS/libpthread_nonshared.a )" > $UTBOT_ALL/debs-install/usr/$X86_LIBS/libpthread.so

# Creating logs directories so that watchdog and utbot can launch
mkdir -p /home/$USER/logs/watchdog
mkdir -p /home/$USER/logs/utbot

# Path to common functions
WATCHDOG_SCRIPT_FOLDER=$UTBOT_ALL/utbot_scripts
COMMON_FUNCTIONS_SCRIPT_PATH=$WATCHDOG_SCRIPT_FOLDER/common_functions.sh
source $COMMON_FUNCTIONS_SCRIPT_PATH

if [ "$1" = "server" ]
then
  UTBOT_MODE=server
  if [ -z "$2" ]
  then
    export UTBOT_PORT=2121
  else
    export UTBOT_PORT=$2
  fi

  #Server-specific parameters
  UTBOT_EXECUTABLE_PATH=$UTBOT_BINARIES_FOLDER/$UTBOT_PROCESS_PATTERN
  UTBOT_STDOUT_LOG_FILE=$UTBOT_LOGS_FOLDER/$UTBOT_PROCESS_PATTERN-$(now).log
  UTBOT_TMP_FOLDER=$UTBOT_LOGS_FOLDER/tmp
  UTBOT_SERVER_OPTIONS="$UTBOT_MODE --port $UTBOT_PORT --log=$UTBOT_LOGS_FOLDER --tmp=$UTBOT_TMP_FOLDER"

  log "Starting a new server process; logs are written into [$UTBOT_LOGS_FOLDER] folder"
  start_process $UTBOT_PROCESS_PATTERN $UTBOT_EXECUTABLE_PATH "$UTBOT_SERVER_OPTIONS" $UTBOT_STDOUT_LOG_FILE $UTBOT_PID_FILE
fi

if [ "$1" = "cli" ]
then
  #Online-cli-specific parameters
  UTBOT_EXECUTABLE_PATH=$UTBOT_BINARIES_FOLDER/$UTBOT_PROCESS_PATTERN
  UTBOT_CLI_OPTIONS="${@:2}"

  if [ "$2" == "generate" ]
  then
    PROJECT_PATH=$4
    mkdir -p $PROJECT_PATH/build
    cd $PROJECT_PATH/build || exit
    cmake ..
    bear make
    cd $CURRENT_FOLDER || exit
  fi

  log "Run utbot-cli"
  trap 'catch $? $LINENO' ERR
  catch() {
    echo "Error $1 occurred on $2"
    exit 1
  }
  $UTBOT_EXECUTABLE_PATH $UTBOT_CLI_OPTIONS
  exit 0;
fi

if [ "$1" = "test" ]
then
  TESTS_EXECUTABLE_PATH=./UTBot_UnitTests

  log "Run tests for utbot"
  trap 'catch $? $LINENO' ERR
  catch() {
    echo "Error $1 occurred on $2"
    exit 1
  }
  cd $UTBOT_BINARIES_FOLDER
  $TESTS_EXECUTABLE_PATH $2 $3
  exit 0;
fi