/* Return arc tangent of complex long double value.
   Copyright (C) 1997-2013 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@cygnus.com>, 1997.

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

#include <complex.h>
#include <math.h>
#include <math_private.h>


__complex__ long double
__catanl (__complex__ long double x)
{
  __complex__ long double res;
  int rcls = fpclassify (__real__ x);
  int icls = fpclassify (__imag__ x);

  if (__builtin_expect (rcls <= FP_INFINITE || icls <= FP_INFINITE, 0))
    {
      if (rcls == FP_INFINITE)
	{
	  __real__ res = __copysignl (M_PI_2l, __real__ x);
	  __imag__ res = __copysignl (0.0, __imag__ x);
	}
      else if (icls == FP_INFINITE)
	{
	  if (rcls >= FP_ZERO)
	    __real__ res = __copysignl (M_PI_2l, __real__ x);
	  else
	    __real__ res = __nanl ("");
	  __imag__ res = __copysignl (0.0, __imag__ x);
	}
      else if (icls == FP_ZERO || icls == FP_INFINITE)
	{
	  __real__ res = __nanl ("");
	  __imag__ res = __copysignl (0.0, __imag__ x);
	}
      else
	{
	  __real__ res = __nanl ("");
	  __imag__ res = __nanl ("");
	}
    }
  else if (__builtin_expect (rcls == FP_ZERO && icls == FP_ZERO, 0))
    {
      res = x;
    }
  else
    {
      long double r2, num, den;

      r2 = __real__ x * __real__ x;

      den = 1 - r2 - __imag__ x * __imag__ x;

      __real__ res = 0.5 * __ieee754_atan2l (2.0 * __real__ x, den);

      num = __imag__ x + 1.0;
      num = r2 + num * num;

      den = __imag__ x - 1.0;
      den = r2 + den * den;

      __imag__ res = 0.25 * __ieee754_logl (num / den);
    }

  return res;
}
weak_alias (__catanl, catanl)
