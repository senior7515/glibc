#define MUTEX_TYPE PTHREAD_MUTEX_INIT_NP(PTHREAD_MUTEX_TIMED_NP|PTHREAD_MUTEX_NO_ELISION_NP)
#include "tst-abstime.c"