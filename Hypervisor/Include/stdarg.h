#ifndef __STDARG_H
#define __STDARG_H

#include <va_list.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define STACKITEM   int

#define VA_SIZE(TYPE)       \
    ((sizeof(TYPE) + sizeof(STACKITEM) -1) \
        & ~(sizeof(STACKITEM) - 1))

#define va_start(AP, LASTARG)   \
    (AP=((va_list)&(LASTARG) + VA_SIZE(LASTARG)))

#define va_end(AP)

#define va_arg(AP, TYPE)    \
    (AP += VA_SIZE(TYPE),  *((TYPE*)(AP - VA_SIZE(TYPE))))

#ifdef __cplusplus
}
#endif

#endif