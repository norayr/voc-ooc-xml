/*	$Id: IO_Select.c,v 1.2 2000/09/12 09:19:04 mva Exp $	*/
/*  Wrapper around the select() function.
    Copyright (C) 2000  Michael van Acken

    This module is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public License
    as published by the Free Software Foundation; either version 2 of
    the License, or (at your option) any later version.

    This module is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with OOC. If not, write to the Free Software Foundation,
    59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <stddef.h>
#include <errno.h>

#include "__oo2c.h"
#include "__mini_gc.h"
#include "__StdTypes.h"
#include "__config.h"


/* --- begin #include "IO:Select.d" */
#include "IO_Select.h"
#include "C.h"

/* function prototypes */

/* module and type descriptors */
static const struct {
  int length;
  void* pad;
  const char name[10];
} _n0 = {10, NULL, {"IO:Select"}};
static struct _MD IO_Select_md = {
  NULL, 
  &Kernel__ModuleDesc_td.td, 
  {
    NULL, 
    (const unsigned char*)_n0.name, 
    -1, 
    NULL
  }
};

static const struct {
  int length;
  void* pad;
  const char name[17];
} _n1 = {17, NULL, {"FileDescrSetDesc"}};
static const struct {
  int length;
  void* pad;
  _Type btypes[1];
} IO_Select__FileDescrSetDesc_tdb = {
  1, 
  NULL, 
  {
    &IO_Select__FileDescrSetDesc_td.td
  }
};
static const struct {
  int length;
  void* pad;
  const void* tbprocs[5];
} _tb0 = {5, NULL, {
  (void*)IO_Select__FileDescrSetDesc_Zero, 
  (void*)IO_Select__FileDescrSetDesc_Set, 
  (void*)IO_Select__FileDescrSetDesc_Clear, 
  (void*)IO_Select__FileDescrSetDesc_IsSet, 
  (void*)IO_Select__FileDescrSetDesc_Copy
}};
struct _TD IO_Select__FileDescrSetDesc_td = {
  NULL,
  &Types__TypeDesc_td.td,
  {
    IO_Select__FileDescrSetDesc_tdb.btypes,
    _tb0.tbprocs,
    (const unsigned char*)_n1.name,
    &IO_Select_md.md,
    0, 
    '0', '1',
    sizeof(IO_Select__FileDescrSetDesc),
    NULL
  }
};

/* local strings */

/* --- end #include "IO:Select.d" */

int IO_Select__FD_SETSIZE = FD_SETSIZE;

static _ModId _mid;

IO_Select__FileDescrSet IO_Select__NewSet(void) {
  IO_Select__FileDescrSet set;

  NEW_REC(set, IO_Select__FileDescrSetDesc);
  set->fd_set = (void*)GC_malloc(sizeof(fd_set));
  return set;
}

void IO_Select__FileDescrSetDesc_Zero(IO_Select__FileDescrSet fdSet) {
  FD_ZERO((fd_set*)(fdSet->fd_set));
}

void IO_Select__FileDescrSetDesc_Set(IO_Select__FileDescrSet fdSet, int fd) {
  FD_SET(fd, (fd_set*)(fdSet->fd_set));
}

void IO_Select__FileDescrSetDesc_Clear(IO_Select__FileDescrSet fdSet, int fd) {
  FD_CLR(fd, (fd_set*)(fdSet->fd_set));
}

unsigned char IO_Select__FileDescrSetDesc_IsSet(IO_Select__FileDescrSet fdSet, int fd) {
  return FD_ISSET(fd, (fd_set*)(fdSet->fd_set));
}

void IO_Select__FileDescrSetDesc_Copy(IO_Select__FileDescrSet fdSet, IO_Select__FileDescrSet dest) {
  *(fd_set*)(dest->fd_set) = *(fd_set*)(fdSet->fd_set);
}

int IO_Select__Select(IO_Select__FileDescrSet read,
                      IO_Select__FileDescrSet write,
                      IO_Select__FileDescrSet except,
		      int sec, int usec) {
  struct timeval tv;
  struct timeval* tvptr;
  int res;
  
  if (sec >= 0) {
    tv.tv_sec = sec;
    tv.tv_usec = usec;
    tvptr = &tv;
  } else {
    tvptr = NULL;
  }
  
  do {
    res = select(FD_SETSIZE,
		 read ? (fd_set*)(read->fd_set) : NULL,
		 write ? (fd_set*)(write->fd_set) : NULL,
		 except ? (fd_set*)(except->fd_set) : NULL,
		 tvptr);
  } while ((res == -1) && (errno == EINTR));
  /* ... bug: EINTR must adjust the timeout! */
  return res;
}

void IO_Select_init(void) {
  _mid = _register_module(&IO_Select_md.md, &IO_Select__FileDescrSetDesc_td.td);
}
