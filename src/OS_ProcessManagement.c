/* 	$Id: OS_ProcessManagement.c,v 1.3 2000/10/09 19:33:44 mva Exp $	 */
#include "__oo2c.h"

#include <unistd.h>
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include "__mini_gc.h"

/* begin -  #include "OS:ProcessManagement.d" */
#include "OS_ProcessManagement.h"

/* local definitions */
typedef struct OS_ProcessManagement__ErrorContextDesc {
  Msg__StringPtr id;
} OS_ProcessManagement__ErrorContextDesc;
typedef struct OS_ProcessManagement__ErrorContextDesc* OS_ProcessManagement__ErrorContext;
static OS_ProcessManagement__ErrorContext OS_ProcessManagement__errorContext;

/* function prototypes */

/* module and type descriptors */
static const struct {
  int length;
  void* pad;
  const char name[22];
} _n0 = {22, NULL, {"OS:ProcessManagement"}};
static struct _MD OS_ProcessManagement_md = {
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
} OS_ProcessManagement__ErrorContextDesc_tdb = {
  2, 
  NULL, 
  {
    &Msg__ContextDesc_td.td, 
    &OS_ProcessManagement__ErrorContextDesc_td.td
  }
};
static const struct {
  int length;
  void* pad;
  const void* tbprocs[1];
} _tb0 = {1, NULL, {
  (void*)Msg__ContextDesc_GetTemplate
}};
struct _TD OS_ProcessManagement__ErrorContextDesc_td = {
  NULL,
  &Types__TypeDesc_td.td,
  {
    OS_ProcessManagement__ErrorContextDesc_tdb.btypes,
    _tb0.tbprocs,
    (const unsigned char*)_n1.name,
    &OS_ProcessManagement_md.md,
    1, 
    '0', '1',
    sizeof(OS_ProcessManagement__ErrorContextDesc),
    NULL
  }
};

/* local strings */

/* end -  #include "OS:ProcessManagement.d" */

static _ModId _mid;


void OS_ProcessManagement__ErrorContextDesc_GetTemplate(OS_ProcessManagement__ErrorContext context, Msg__Msg msg, Msg__LString templ, LONGINT templ_0d) {
  char *str;
/*
  LONGINT res = msg->code;
  
  if (res == OS_ProcessManagement__invalidBuffer) {
    str = "Internal error: Buffer for `getcwd' is empty";
  } else if (res == OS_ProcessManagement__cwdTooLong) {
    str = "Current working directory does not fit into buffer";
  } else if (res == OS_ProcessManagement__accessDenied) {
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
*/
}


/*
static Msg__Msg get_error() {
  Msg__Msg msg;
  LONGINT code;
  
  switch (errno) {
  case EINVAL: code = OS_ProcessManagement__invalidBuffer; break;
  case ERANGE: code = OS_ProcessManagement__cwdTooLong; break;
  case EACCES: code = OS_ProcessManagement__accessDenied; break;
  }
  
  msg = Msg__New((Msg__Context)OS_ProcessManagement__errorContext, code);
#if HAVE_STRERROR
  DYN_TBCALL(Msg,MsgDesc,SetStringAttrib,msg,
	     (msg, (const Msg__String)"errstr", 7, (OOC_CHAR*)strerror(errno)));
#endif
  DYN_TBCALL(Msg,MsgDesc,SetIntAttrib,msg,
	     (msg, (const Msg__String)"errno", 6, (LONGINT)errno));
  return msg;
}
*/

int OS_ProcessManagement__system(const OOC_CHAR* command, int command_0d) {
  return system((const char*)command);
}


void OS_ProcessManagement_init(void) {
  _mid = _register_module(&OS_ProcessManagement_md.md, &OS_ProcessManagement__ErrorContextDesc_td.td);

  NEW_REC(OS_ProcessManagement__errorContext,OS_ProcessManagement__ErrorContextDesc);
  Msg__InitContext((Msg__Context)OS_ProcessManagement__errorContext, 
		   (const Msg__String)"OS:ProcessManagement", 21);
}
