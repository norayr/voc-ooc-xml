/* 	$Id: OS_ProcessParameters.c,v 1.1.1.2 2000/07/10 20:31:49 mva Exp $	 */
#include "__oo2c.h"

#include <unistd.h>
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include "__mini_gc.h"

/* begin -  #include "OS:ProcessParameters.d" */
#include "OS_ProcessParameters.h"
#include "CharClass.h"
#include "LongStrings.h"

/* local definitions */
typedef struct OS_ProcessParameters__ErrorContextDesc {
  Msg__StringPtr id;
} OS_ProcessParameters__ErrorContextDesc;
typedef struct OS_ProcessParameters__ErrorContextDesc* OS_ProcessParameters__ErrorContext;
static OS_ProcessParameters__ErrorContext OS_ProcessParameters__errorContext;

/* function prototypes */

/* module and type descriptors */
static const struct {
  int length;
  void* pad;
  const char name[21];
} _n0 = {21, NULL, {"OS:ProcessParameters"}};
static struct _MD OS_ProcessParameters_md = {
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
} _n1 = {17, NULL, {"ErrorContextDesc"}};
static const struct {
  int length;
  void* pad;
  _Type btypes[2];
} OS_ProcessParameters__ErrorContextDesc_tdb = {
  2, 
  NULL, 
  {
    &Msg__ContextDesc_td.td, 
    &OS_ProcessParameters__ErrorContextDesc_td.td
  }
};
static const struct {
  int length;
  void* pad;
  const void* tbprocs[1];
} _tb0 = {1, NULL, {
  (void*)Msg__ContextDesc_GetTemplate
}};
struct _TD OS_ProcessParameters__ErrorContextDesc_td = {
  NULL,
  &Types__TypeDesc_td.td,
  {
    OS_ProcessParameters__ErrorContextDesc_tdb.btypes,
    _tb0.tbprocs,
    (const unsigned char*)_n1.name,
    &OS_ProcessParameters_md.md,
    1, 
    '0', '1',
    sizeof(OS_ProcessParameters__ErrorContextDesc),
    NULL
  }
};

/* local strings */

/* end -  #include "OS:ProcessParameters.d" */

static _ModId _mid;


void OS_ProcessParameters__ErrorContextDesc_GetTemplate(OS_ProcessParameters__ErrorContext context, Msg__Msg msg, Msg__LString templ, LONGINT templ_0d) {
  char *str;
  LONGINT res = msg->code;
  
  if (res == OS_ProcessParameters__invalidBuffer) {
    str = "Internal error: Buffer for `getcwd' is empty";
  } else if (res == OS_ProcessParameters__cwdTooLong) {
    str = "Current working directory does not fit into buffer";
  } else if (res == OS_ProcessParameters__accessDenied) {
    str = "Access denied to component of current working directory";
  }

  _string_copy2l(templ, str, templ_0d);
  if (msg->attribList) {
    Msg__Attribute attr;
    LONGCHAR eol[2] = {(LONGCHAR)CharClass__eol, (LONGCHAR)0};
    LONGCHAR str16[Msg__sizeAttrName+1];
    
    attr = msg->attribList;
    while (attr) {
      LongStrings__Append(eol, 2, templ, templ_0d);
      _string_copy2l(str16, (char*)attr->name, strlen((char*)attr->name)+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _string_copy2l(str16, "=${", 4);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _string_copy2l(str16, (char*)attr->name, strlen((char*)attr->name)+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _string_copy2l(str16, "}", 2);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      attr = attr->nextAttrib;
    }
  }
}


static Msg__Msg get_error() {
  Msg__Msg msg;
  LONGINT code;
  
  switch (errno) {
  case EINVAL: code = OS_ProcessParameters__invalidBuffer; break;
  case ERANGE: code = OS_ProcessParameters__cwdTooLong; break;
  case EACCES: code = OS_ProcessParameters__accessDenied; break;
  }
  
  msg = Msg__New((Msg__Context)OS_ProcessParameters__errorContext, code);
#if HAVE_STRERROR
  DYN_TBCALL(Msg,MsgDesc,SetStringAttrib,msg,
	     (msg, (const Msg__String)"errstr", 7, (CHAR*)strerror(errno)));
#endif
  DYN_TBCALL(Msg,MsgDesc,SetIntAttrib,msg,
	     (msg, (const Msg__String)"errno", 6, (LONGINT)errno));
  return msg;
}


void OS_ProcessParameters__getcwd(OS_ProcessParameters__Path buffer, LONGINT buffer_0d, Msg__Msg *res) {
  if (getcwd((char*)buffer, buffer_0d)) {
    *res = OS_ProcessParameters__done;
  } else {
    *res = get_error();
  }
}


void OS_ProcessParameters_init(void) {
  _mid = _register_module(&OS_ProcessParameters_md.md, &OS_ProcessParameters__ErrorContextDesc_td.td);

  NEW_REC(OS_ProcessParameters__errorContext,OS_ProcessParameters__ErrorContextDesc);
  Msg__InitContext((Msg__Context)OS_ProcessParameters__errorContext, 
		   (const Msg__String)"OS:ProcessParameters", 21);
}
