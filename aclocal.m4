dnl $Id: aclocal.m4,v 1.1 2000/08/30 08:14:44 mva Exp $
dnl The most current version of this file can be found in the OOC source
dnl distribution (ooc-*-rcs.tar.gz or ooc-*-norcs.tar.gz) in the directory
dnl   ooc/backend/ansi-c/distrib/library_autoconf
dnl In the same directory are also sample files configure.in and Makefile.in,
dnl both taken from an early VO distribution.  For additional examples check
dnl other OOC library distributions, like libadt.


dnl OOC_PROG_OOC()
dnl Finds OOC compiler and store its name in $OOC.  If output variable `OFLAGS'
dnl is not already set, it is set to `-O'.  Should be called before the C 
dnl compiler is invoked.
AC_DEFUN(OOC_PROG_OOC,
[AC_CHECK_PROG(OOC, oo2c, oo2c)
if test -z "$OOC"; then
  AC_MSG_ERROR([Could not find Oberon-2 compiler.])
fi
ooc_test_OFLAGS="${OFLAGS+set}"
ooc_save_OFLAGS="$OFLAGS"
if test "$ooc_test_OFLAGS" = set; then
  OFLAGS="$ooc_save_OFLAGS"
else
  OFLAGS="-O"
fi
AC_SUBST(OFLAGS)
OOC_GET_VALUE(CC,OPTIONS,cc)
OOC_GET_VALUE(CFLAGS,OPTIONS,cflags)
OOC_GET_VALUE(LDFLAGS,OPTIONS,ldflags)
OOC_GET_VALUE(ooc_LIBS,OPTIONS,libs)
ooc_test_LIBS="${LIBS+set}"
if test "$ooc_test_LIBS" = set; then
  LIBS="$LIBS $ooc_LIBS"
else
  LIBS="$ooc_LIBS"
fi])


dnl OOC_PATH_INIT()
dnl Determines the name of the primary initialization file of compiler $OOC.
dnl The file name is written to OOC_INIT.
dnl Calls AC_SUBST for OOC_INIT.
AC_DEFUN(OOC_PATH_INIT,
[AC_REQUIRE([OOC_PROG_OOC])
AC_MSG_CHECKING(initialization file)
AC_CACHE_VAL(ooc_cv_path_ooc_init,
[$OOC $OFLAGS --write-config | grep "^# initialization file: " | sed -e "s/^# initialization file: //g" >conftest
dnl putting the above pipe into the following assignment does not work under SunOS 5.6
ooc_cv_path_ooc_init="`cat conftest`"
rm -f conftest])dnl
AC_MSG_RESULT($ooc_cv_path_ooc_init)
OOC_INIT="$ooc_cv_path_ooc_init"
AC_SUBST(OOC_INIT)
])

dnl OOC_PATH_LIBDIR()
dnl Stores the name of the installation directory of the compiler $OOC
dnl in $OOC_LIBDIR.  The script is aborted if no path is found.
dnl Calls AC_SUBST for OOC_LIBDIR.
AC_DEFUN(OOC_PATH_LIBDIR,
[AC_REQUIRE([OOC_PATH_INIT])
AC_MSG_CHECKING(installation directory)
AC_CACHE_VAL(ooc_cv_path_ooc_libdir,
[ooc_test_OOC_LIBDIR="${OOC_LIBDIR+set}"
if test "$ooc_test_OOC_LIBDIR" = set; then
  ooc_cv_path_ooc_libdir="$OOC_LIBDIR"
else
  ooc_cv_path_ooc_libdir="`grep '##PATHS:OOC:LIB##' "$OOC_INIT" | head -1 | sed -e 's/^[ 	]*//' -e 's/[; 	]*##PATHS:OOC:LIB##.*$//'`"
  ooc_cv_path_ooc_libdir="`dirname "$ooc_cv_path_ooc_libdir"`"
fi])dnl
AC_MSG_RESULT($ooc_cv_path_ooc_libdir)
if test -z "$ooc_cv_path_ooc_libdir"; then
  AC_MSG_ERROR([Could not determine installation directory.])
fi
OOC_LIBDIR="$ooc_cv_path_ooc_libdir"
if test "x$prefix" = xNONE; then
  prefix="`dirname \"\`dirname $OOC_LIBDIR\`\"`"
fi
AC_SUBST(OOC_LIBDIR)
])

dnl OOC_PROG_OOCONFIG()
dnl Looks for configuration tool ooconfig in current directory, or the
dnl installation directory of the compiler, and stores the result in $OOCONFIG.
dnl This macro also creates an empty file $ooc_config, which is filled by
dnl OOC_CHECK_LIB with commands that must be applied to the OOC compiler's
dnl configuration file.
AC_DEFUN(OOC_PROG_OOCONFIG,
[AC_REQUIRE([OOC_PATH_LIBDIR])
AC_MSG_CHECKING(for ooconfig)
AC_CACHE_VAL(ooc_cv_prog_ooconfig,
[ooc_test_OOCONFIG="${OOCONFIG+set}"
if test "$ooc_test_OOCONFIG" = set; then
  ooc_cv_prog_ooconfig="$OOCONFIG"
elif test -x ./ooconfig || test ! -x "$OOC_LIBDIR/ooconfig"; then
  ooc_cv_prog_ooconfig="./ooconfig"
else
  ooc_cv_prog_ooconfig="$OOC_LIBDIR/ooconfig"
fi])dnl
AC_MSG_RESULT($ooc_cv_prog_ooconfig)
OOCONFIG="$ooc_cv_prog_ooconfig"
AC_SUBST(OOCONFIG)
ooc_config=config.ooc
rm -f $ooc_config
touch $ooc_config])



dnl OOC_SUPPORTS_LIBS()
dnl Determines whether the compiler $OOC supports the --make-lib command.
dnl The result is written to ooc_have_libs.  This test can be overidden by
dnl passing --disable-libs to configure, forcing all modules to be build as
dnl standalone object files, which in turn are linked statically.
dnl Calls AC_SUBST for ooc_have_libs.
AC_DEFUN(OOC_SUPPORTS_LIBS,
[AC_REQUIRE([OOC_PROG_OOC])
AC_MSG_CHECKING(for library support)
AC_CACHE_VAL(ooc_cv_ooc_have_libs,
[AC_ARG_ENABLE(libs,
[  --disable-libs          do not build any static or shared library],
ooc_cv_ooc_have_libs="$enable_libs",
[if $OOC $OFLAGS --write-config | grep "^  libtoolCmd := \"..*\"" >/dev/null; then
  ooc_cv_ooc_have_libs=yes
else
  ooc_cv_ooc_have_libs=no
fi])])
AC_MSG_RESULT($ooc_cv_ooc_have_libs)
ooc_have_libs="$ooc_cv_ooc_have_libs"
AC_SUBST(ooc_have_libs)
])


dnl OOC_CHECK_LIB_X11()
dnl Checks if the compiler was installed with interface module X11.Mod.
dnl The result is written to have_x11.
dnl Calls AC_SUBST for have_x11.
AC_DEFUN(OOC_CHECK_LIB_X11,
[AC_REQUIRE([OOC_PATH_LIBDIR])
AC_MSG_CHECKING(for module X11.Mod)
AC_CACHE_VAL(ooc_cv_ooc_have_x11,
[OOC_TRY_LINK(X11,XOpenDisplay,,ooc_cv_ooc_have_x11=yes,ooc_cv_ooc_have_x11=no)]
)dnl
AC_MSG_RESULT($ooc_cv_ooc_have_x11)
have_x11="$ooc_cv_ooc_have_x11"
AC_SUBST(have_x11)
])


dnl OOC_CHECK_LIB(LIBRARY, FUNCTION [, OTHER-LIBRARIES 
dnl                [, IMPORTS [, CANDIDATE-LPATHS]]] 
dnl Attempts to link against FUNCTION in LIBRARY.  The argument OTHER-LIBRARIES
dnl is a list of -lfoo options that links in all libraries used by LIBRARY, and
dnl (possibly) -Lbar options to extend the library search path for the -lfoo's
dnl in OTHER-LIBRAIES (but not LIBRARY itself).  IMPORTS is a list of module
dnl names, separated by spaces.  They are imported by the generated main
dnl module.  
dnl   If linking fails, all options -LXXX in CANDIDATE-LPATHS are tried in 
dnl turn, the first successful one being stored in $ooc_(LIBRARY)_prefix.  On 
dnl success, the variable $have_lib(LIBRARY) is set to "yes", otherwise to 
dnl "no".
dnl   This macro also appends commands into config.ooc that transfers the
dnl results into the pragma variable HAVE_LIB(LIBRARY), and sets the option 
dnl variable Lib(LIBRARY)Prefix.
AC_DEFUN(OOC_CHECK_LIB,
[AC_MSG_CHECKING("for $2 in -l$1")
AC_CACHE_VAL(ooc_cv_have_lib$1,
[OOC_TEST_LIB($1, $2, ooc_cv_have_lib$1=yes, ooc_cv_have_lib$1=no, $3, $4)
ooc_cv_lib_$1_prefix=""
if test $ooc_cv_have_lib$1 = no; then
  ooc_lpath="$LIBS $5"
  OOC_TEST_LIB($1, $2, ooc_cv_have_lib$1=yes, ooc_cv_have_lib$1=no, $ooc_lpath $3, $4)
  if test $ooc_cv_have_lib$1 = yes; then
    for i in foo $ooc_lpath; do
      case "$i" in
      -L*)
        OOC_TEST_LIB($1, $2, ooc_cv_have_lib$1=yes, ooc_cv_have_lib$1=no, $i $3, $4)
        if test $ooc_cv_have_lib$1 = yes; then
          ooc_cv_lib_$1_prefix="$i"; 
          break
        fi
    	;;
      *)
	;;
      esac
    done
  fi
fi])
ooc_$1_prefix="$ooc_cv_lib_$1_prefix"
have_lib$1=$ooc_cv_have_lib$1
if test -z "$ooc_$1_prefix"; then
  AC_MSG_RESULT($have_lib$1)
else
  AC_MSG_RESULT([$have_lib$1, $ooc_cv_lib_$1_prefix])
fi
ooc_cap_name=`echo $1 | sed -e 's/[^a-zA-Z0-9_]/_/g' \
    -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`
ooc_pragma_name=PRAGMAS:LIB:HAVE_LIB$ooc_cap_name
echo "--remove-line $ooc_pragma_name" >>$ooc_config
echo "--define $ooc_pragma_name $have_lib$1" >>$ooc_config
ooc_option_name=OPTIONS:LIB:${ooc_cap_name}_PREFIX
echo "--remove-line $ooc_option_name" >>$ooc_config
echo "--append-line $ooc_option_name DEFINE\ Lib$1Prefix:=\\\"$ooc_$1_prefix\\\";" >>$ooc_config
AC_SUBST(ooc_$1_prefix)
AC_SUBST(have_lib$1)
])


dnl Support Macros
dnl ========================================================================

dnl OOC_GET_VALUE(DEST-VAR,SECTION,VAR-NAME)
dnl Gets the value of variable VAR-NAME in section SECTION, and stores the
dnl result in DEST-VAR.  If the variable denotes a string, enclosing `"' 
dnl are removed.
AC_DEFUN(OOC_GET_VALUE,
[cat >conftest.sed <<"EOF"
/^$2$/,/^END$/{
/^  $3 := /{
s/^  $3 := \(.*\)$/\1/
p
}
}
EOF
cat >conftest2.sed <<'EOF'
s/;$//
s/^"\(.*\)"$/\1/
EOF
dnl using two sed is probably overkill, but this seems to work even under SunOS 5.6
$1="`$OOC $OFLAGS --write-config | sed -n -f conftest.sed | sed -f conftest2.sed`"
rm -f conftest.sed conftest2.sed
])


dnl OOC_TEST_LIB(LIBRARY, FUNCTION [, ACTION-IF-FOUND [, ACTION-IF-NOT-FOUND
dnl              [, OTHER-LIBRARIES [, IMPORT]]]])
dnl Similar to AC_CHECK_LIB.  The additional argument IMPORT is a list of
dnl Oberon-2 module names, separated by spaces.
AC_DEFUN(OOC_TEST_LIB,
[
dnl Use a cache variable name containing both the library and function name,
dnl because the test really is for library $1 defining function $2, not
dnl just for library $1.  Separate tests with the same $1 and different $2s
dnl may have different results.
ac_lib_var=`echo $1['_']$2 | sed 'y%./+-%__p_%'`
OOC_TRY_LINK($6,$2,-l$1 $5,
             eval "ooc_lib_$ac_lib_var=yes",
	     eval "ooc_lib_$ac_lib_var=no")
dnl)
if eval "test \"`echo '$ooc_lib_'$ac_lib_var`\" = yes"; then
  ifelse([$3], ,
[changequote(, )dnl
  ac_tr_lib=HAVE_LIB`echo $1 | sed -e 's/[^a-zA-Z0-9_]/_/g' \
    -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`
changequote([, ])dnl
  AC_DEFINE_UNQUOTED($ac_tr_lib)
], [$3])
else
ifelse([$4], , , [$4
])dnl
fi
])


dnl OOC_TRY_LINK(IMPORT, FUNCTION, LIBS,
dnl             [ACTION-IF-FOUND [, ACTION-IF-NOT-FOUND]])
dnl Used by OOC_TEST_LIB.  Creates module (both .Mod and .c) and tries to
dnl link it by invoking the OOC compiler.  IMPORT is a list of Oberon-2
dnl modules, separates by spaces.  The value LIBS is passd to the compiler
dnl option --libs.
AC_DEFUN(OOC_TRY_LINK,
[ooc_ext=Mod
ooc_link='$OOC -Mv $OFLAGS --libs ["$3"] conftest.$ooc_ext 1>&AC_FD_CC'
ooc_import="dummy:=Strings"
ooc_save_i="$i"
for i in Strings $1; do
  ooc_import="$ooc_import, $i"
done
i="$ooc_save_i"
cat > conftest.$ac_ext <<EOF
[#]line __oline__ "configure"
ifelse([$2], [main], ,
char $2();
int test_fct() {
$2(); return 0; }
)
EOF
changequote(<<<, >>>)
cat > conftest.$ooc_ext <<EOF
MODULE conftest [INTERFACE "C"; LINK FILE "conftest.$ac_ext" END];
IMPORT $ooc_import;
END conftest.
EOF
changequote([, ])
if AC_TRY_EVAL(ooc_link) && test -s conftest; then
  ifelse([$4], , :, [rm -rf *conftest* sym/conftest* obj/conftest*
  $4])
else
  echo "configure: failed program was:" >&AC_FD_CC
  cat conftest.$ac_ext >&AC_FD_CC
  cat conftest.$ooc_ext >&AC_FD_CC
ifelse([$5], , , [  rm -rf *conftest* sym/conftest* obj/conftest*
  $5
])dnl
fi
rm -f *conftest* sym/conftest* obj/conftest*])
