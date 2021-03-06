/* Copyright (C) 2004-2013 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <pthreadP.h>
#include <stdlib.h>
#include <tls.h>
#include <unistd.h>

/* Default stack size.  */
size_t __default_stacksize attribute_hidden
#ifdef SHARED
;
#else
  = PTHREAD_STACK_MIN;
#endif

/* Flag whether the machine is SMP or not.  */
int __is_smp attribute_hidden;

#ifndef TLS_MULTIPLE_THREADS_IN_TCB
/* Variable set to a nonzero value either if more than one thread runs or ran,
   or if a single-threaded process is trying to cancel itself.  See
   nptl/descr.h for more context on the single-threaded process case.  */
int __pthread_multiple_threads attribute_hidden;
#endif

/* Table of the key information.  */
struct pthread_key_struct __pthread_keys[PTHREAD_KEYS_MAX]
  __attribute__ ((nocommon));
hidden_data_def (__pthread_keys)
