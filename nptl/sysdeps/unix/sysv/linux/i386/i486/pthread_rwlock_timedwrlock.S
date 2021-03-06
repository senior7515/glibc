/* Copyright (C) 2002-2013 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

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

#include <sysdep.h>
#include <lowlevellock.h>
#include <lowlevelrwlock.h>
#include <pthread-errnos.h>
#include <kernel-features.h>
#include <hle.h>

#ifdef PIC
#define MO(x) x##@GOTOFF(%edx)
#else
#define MO(x) x
#endif

	.text

	.globl	pthread_rwlock_timedwrlock
	.type	pthread_rwlock_timedwrlock,@function
	.align	16
pthread_rwlock_timedwrlock:
	cfi_startproc
	pushl	%esi
	cfi_adjust_cfa_offset(4)
	pushl	%edi
	cfi_adjust_cfa_offset(4)
	pushl	%ebx
	cfi_adjust_cfa_offset(4)
	pushl	%ebp
	cfi_adjust_cfa_offset(4)
	cfi_offset(%esi, -8)
	cfi_offset(%edi, -12)
	cfi_offset(%ebx, -16)
	cfi_offset(%ebp, -20)
	subl	$8, %esp
	cfi_adjust_cfa_offset(8)

	movl	28(%esp), %ebp
	movl	32(%esp), %edi

#ifdef PIC
	SETUP_PIC_REG(dx)
	addl $_GLOBAL_OFFSET_TABLE_,%edx
#endif

	cmpl  $0,MO(__elision_available)
	jz    not_elided_twrlock
	
	cmpb  $0,ELIDING(%ebp)
	js    not_elided_twrlock
	jnz   try_trans_wrlock
	/* zero: use default */

	cmpl	$0,MO(__rwlock_rtm_enabled)
	jz	not_elided_twrlock

try_trans_wrlock:
	XBEGIN abort_twrlock

	/* Lock writer free? */
	cmpl  $0,WRITER(%ebp)
	jnz   1f
	cmpl  $0,NR_READERS(%ebp)
	jnz   1f

	/* Lock is free. Run with transaction */
	xor   %eax,%eax

	jmp   77f

	/* Lock is not free. Run */
1:	XABORT 0xff
	jmp   not_elided_twrlock

	/* Abort happened. */
abort_twrlock:
	cmpl  $0,MO(__tsx_abort_hook)
	jz    1f
	push  %eax
	cfi_adjust_cfa_offset(4)
	call  *MO(__tsx_abort_hook)
	pop   %eax
	cfi_adjust_cfa_offset(-4)
	mov   32(%esp), %edi
#ifdef PIC
	SETUP_PIC_REG(bx)
	addl $_GLOBAL_OFFSET_TABLE_,%edx
#endif

1:
	/* Otherwise we just fall back directly to the lock.
	   Here's the place to add more adaptation. */

not_elided_twrlock:

	/* Get the lock.  */
	movl	$1, %edx
	xorl	%eax, %eax
	LOCK
#if MUTEX == 0
	cmpxchgl %edx, (%ebp)
#else
	cmpxchgl %edx, MUTEX(%ebp)
#endif
	jnz	1f

2:	movl	WRITER(%ebp), %eax
	testl	%eax, %eax
	jne	14f
	cmpl	$0, NR_READERS(%ebp)
	je	5f

	/* Check the value of the timeout parameter.  */
3:	cmpl	$1000000000, 4(%edi)
	jae	19f

	addl	$1, WRITERS_QUEUED(%ebp)
	je	4f

	movl	WRITERS_WAKEUP(%ebp), %esi

	LOCK
#if MUTEX == 0
	subl	$1, (%ebp)
#else
	subl	$1, MUTEX(%ebp)
#endif
	jne	10f

	/* Get current time.  */
11:	movl	%esp, %ebx
	xorl	%ecx, %ecx
	movl	$__NR_gettimeofday, %eax
	ENTER_KERNEL

	/* Compute relative timeout.  */
	movl	4(%esp), %eax
	movl	$1000, %edx
	mul	%edx		/* Milli seconds to nano seconds.  */
	movl	(%edi), %ecx
	movl	4(%edi), %edx
	subl	(%esp), %ecx
	subl	%eax, %edx
	jns	15f
	addl	$1000000000, %edx
	subl	$1, %ecx
15:	testl	%ecx, %ecx
	js	16f		/* Time is already up.  */

	/* Futex call.  */
	movl	%ecx, (%esp)	/* Store relative timeout.  */
	movl	%edx, 4(%esp)

	movl	%esi, %edx
#ifdef __ASSUME_PRIVATE_FUTEX
	movzbl	PSHARED(%ebp), %ecx
	xorl	$FUTEX_PRIVATE_FLAG|FUTEX_WAIT, %ecx
#else
	movzbl	PSHARED(%ebp), %ecx
# if FUTEX_WAIT != 0
	orl	$FUTEX_WAIT, %ecx
# endif
	xorl	%gs:PRIVATE_FUTEX, %ecx
#endif
	movl	%esp, %esi
	leal	WRITERS_WAKEUP(%ebp), %ebx
	movl	$SYS_futex, %eax
	ENTER_KERNEL
	movl	%eax, %esi
17:

	/* Reget the lock.  */
	movl	$1, %edx
	xorl	%eax, %eax
	LOCK
#if MUTEX == 0
	cmpxchgl %edx, (%ebp)
#else
	cmpxchgl %edx, MUTEX(%ebp)
#endif
	jnz	12f

13:	subl	$1, WRITERS_QUEUED(%ebp)
	cmpl	$-ETIMEDOUT, %esi
	jne	2b

18:	movl	$ETIMEDOUT, %edx
	jmp	9f


5:	xorl	%edx, %edx
	movl	%gs:TID, %eax
	movl	%eax, WRITER(%ebp)
9:	LOCK
#if MUTEX == 0
	subl	$1, (%ebp)
#else
	subl	$1, MUTEX(%ebp)
#endif
	jne	6f

7:	movl	%edx, %eax

77:	addl	$8, %esp
	cfi_adjust_cfa_offset(-8)
	popl	%ebp
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%ebp)
	popl	%ebx
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%ebx)
	popl	%edi
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%edi)
	popl	%esi
	cfi_adjust_cfa_offset(-4)
	cfi_restore(%esi)
	ret

	cfi_adjust_cfa_offset(24)
	cfi_offset(%esi, -8)
	cfi_offset(%edi, -12)
	cfi_offset(%ebx, -16)
	cfi_offset(%ebp, -20)
1:
#if MUTEX == 0
	movl	%ebp, %edx
#else
	leal	MUTEX(%ebp), %edx
#endif
	movzbl	PSHARED(%ebp), %ecx
	call	__lll_lock_wait
	jmp	2b

14:	cmpl	%gs:TID, %eax
	jne	3b
20:	movl	$EDEADLK, %edx
	jmp	9b

6:
#if MUTEX == 0
	movl	%ebp, %eax
#else
	leal	MUTEX(%ebp), %eax
#endif
	movzbl	PSHARED(%ebp), %ecx
	call	__lll_unlock_wake
	jmp	7b

	/* Overflow.  */
4:	subl	$1, WRITERS_QUEUED(%ebp)
	movl	$EAGAIN, %edx
	jmp	9b

10:
#if MUTEX == 0
	movl	%ebp, %eax
#else
	leal	MUTEX(%ebp), %eax
#endif
	movzbl	PSHARED(%ebp), %ecx
	call	__lll_unlock_wake
	jmp	11b

12:
#if MUTEX == 0
	movl	%ebp, %edx
#else
	leal	MUTEX(%ebp), %edx
#endif
	movzbl	PSHARED(%ebp), %ecx
	call	__lll_lock_wait
	jmp	13b

16:	movl	$-ETIMEDOUT, %esi
	jmp	17b

19:	movl	$EINVAL, %edx
	jmp	9b
	cfi_endproc
	.size	pthread_rwlock_timedwrlock,.-pthread_rwlock_timedwrlock
