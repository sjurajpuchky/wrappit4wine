#!/bin/bash
#
# @author Juraj Puchký - Devtech <sjurajpuchky@seznam.cz>
# @see Tool for preparing wrapper for wine libraries
# @copy (c) 2014 Juraj Puchky - Devtech
# @license GPLv3
# @version 1.0.1
#

if [ -z "$4" ] || [ "$1" == "help" ]; then
 cat << _EOF_
Wrappit4wine 
============
Version 1.0.1

 Usage: $0 [original windows dll file] [Wrapper prefix] [Lookup Headers] [Lookup Libraries] [DEF]
 Legend:
	Wrapper prefix 		- Functions prefix
	Lookup headers 		- Path where are wrapped headers stored
	Lookup libraries 	- Path where are wrapped libraries stored
	DEF:optional	 	- conditional compilation up on definition
 Sample:
	$0 burn.dll BURN_ /usr/include /usr/lib
 Commands:
	help - print this usage screen
 Requirements:
	winedump
	sed
	tr
	grep
	dialog
	Header files or development package be installed
	Original windows dll
	Wrapped libraries
 Env:
	AUTHOR  - who generate wrapper
	SEE     - what is wrapper about
	LICENSE - what license you use
	COPY	- copyright notice
	DATE	- when you create
	WWW	- home page of project
	NOTEDIT	- do not edit environmentals before process empty or set
	NOPROGRESS	- do not display progress
_EOF_
 exit 1;
fi

function CleanUpTemps() {
 rm -f "/tmp/$1.*";
}

function lookupForSourceDefinition() {
find "$SOURCEPATHS" -type f -iname "*.h" -exec grep "$1 *(.*) *;" {} +|sed -e "s/;$//g"|cut -d: -f1|sort|uniq|while read fh
do
  cat "$fh"|sed -e 's/\/\*.*\*\///g'|sed ':a;N;$!ba;s/, *\n/, /g'|sed -e 's/ \+/ /g'|grep "$1 *("
done
}

function lookupForWrappedSourceDefinition() {
find "$SOURCEPATHS" -type f -iname "*.h" -exec grep "$1 *(.*) *;" {} +|sed -e "s/;$//g"|cut -d: -f1|sort|uniq|while read fh
do
  cat "$fh"|sed -e 's/\/\*.*\*\///g'|sed -e 's/\/\/.*$//g'|sed ':a;N;$!ba;s/, *\n/, /g'|sed -e 's/ \+/ /g'|grep -e "$1 *(.*) *;"|grep -v "__device__"|grep -v "__global__"|sed -e "s/$1/$PREFIX$1/g"|grep "extern"|sed -e 's/extern//g'|sed -e 's/__host__//g'|sed -e 's/__.*builtin__//g'|sed -e 's/ [A-Z]\+API / WINAPI /gi'|sed -e 's/^ *//g'|grep -v "^return"
done
}

function lookupForSourceDeps() {
 eSOURCEPATHS=`echo "$SOURCEPATHS"|sed -e 's/\//\\\\\//g'`;
 find "$SOURCEPATHS" -type f -iname "*.h" -exec grep "$1 *(.*) *;" {} +|sed -e "s/;$//g"|cut -d: -f1|sort|uniq|while read dh
 do
  dhf=`echo "$dh"|sed -e "s/$eSOURCEPATHS\///g"`;
  echo "#include <$dhf>";
 done
}

function lookupForLibDeps() {
 find "$LIBPATHS" -type f -iname "*.so*" -exec grep -a "$1" {} +|cut -d: -f1|while read dl
 do
  isf=`strings "$dl"|grep "^$1$"`;
  if [ -n "$isf" ]; then
   dlf=`basename $dl|cut -d\. -f1`;
   libname=`echo "$dlf"|sed -e 's/^lib//g'`;
   echo "-l$libname";
  fi
 done
}

function lookupForLibDepPaths() {
 find "$LIBPATHS" -type f -iname "*.so*" -exec grep -a "$1" {} +|cut -d: -f1|sort|uniq|while read dl
 do
  isf=`strings "$dl"|grep "^$1$"`;
  if [ -n "$isf" ]; then
   dlf=`basename $dl`;
   libpath=`echo "$dl"|sed -e "s/\/$dlf//g"`;
   echo "-L $libpath";
  fi
 done
}

function lookupPassParamsFromSourceDef() {
sed -e "s/$1 *(/\#/g"|sed -e "s/);/\#/g"|cut -d\# -f2|sed -e "s/,/\n/g"|awk -F" " '{print $(NF)}'|while read pl
do
  echo -n ", $pl";
done|sed -e 's/^, //g'
}

function prepareSpecParamsFromSourceDef() {
sed -e "s/$1 *(/\#/g"|sed -e "s/);/\#/g"|cut -d\# -f2|sed -e "s/,/\n/g"|awk -F" " '{print $(NF)}'|while read pl
do
  echo "$pl";
done|while read param
do
 case "$param" in
 *\**)
	echo -n " ptr ";
 ;;
 *)
	echo -n " long ";
 ;;
 esac
done
} 

# Lookup for depencies
if [ ! -f "/usr/bin/dialog" ]; then
 echo "ERROR: You have to install dialog with ncurses support.";
 exit 2;
fi

if [ ! -f "/usr/bin/winedump" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to install winedump from wine.\Zn" 6 35
 exit 2;
fi

if [ ! -f "/bin/sed" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to install sed.\Zn" 6 35
 exit 2;
fi

if [ ! -f "/usr/bin/tr" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to install tr.\Zn" 6 35
 exit 2;
fi

if [ ! -f "/bin/grep" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to install grep.\Zn" 6 35
 exit 2;
fi


if [ ! -f "$1" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1Specified library $1 does not exists.\Zn" 6 35
 exit 2;
fi

if [ ! -d "$3" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to specify existing headers folder.\Zn" 6 35
 exit 2;
fi

if [ ! -d "$4" ]; then
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1You have to specify existing library folder.\Zn" 6 35
 exit 2;
fi

# Initialize
dllname=`basename "$1"`;
dirname=`echo "$dllname"|cut -d\. -f1`;

if [ -z "$DATE" ]; then
 DATE=`date`;
fi
if [ -z "$AUTHOR" ]; then
 AUTHOR=`whoami`;
fi
if [ -z "$SEE" ]; then
 SEE="Wrapped $dllname library for wine";
fi
if [ -z "$LICENSE" ]; then
 LICENSE="GPLv3";
fi
if [ -z "$COPY" ]; then
 YEAR=`date +%Y`;
 COPY="(c) $YEAR $AUTHOR";
fi
if [ -z "$WWW" ]; then
 WWW="http://";
fi

TS=`date +%s%N`;
PREFIX="$2";

if [ -z "$NOTEDIT" ]; then
dialog --colors --backtitle "wrappit4wine" --title "Enviromentals" --form "Setup your needs" 25 60 8 "Author:" 1 1 "$AUTHOR" 1 25 25 50 "Date:" 2 1 "$DATE" 2 25 25 50 "See:" 3 1 "$SEE" 3 25 25 255 "License:" 4 1 "$LICENSE" 4 25 25 80 "Copy:" 5 1 "$COPY" 5 25 25 160 "Home:" 6 1 "$WWW" 6 25 25 160 2>"/tmp/$TS.form"
AUTHOR=`cat "/tmp/$TS.form"|head -1|tail -1`;
DATE=`cat "/tmp/$TS.form"|head -2|tail -1`;
SEE=`cat "/tmp/$TS.form"|head -3|tail -1`;
LICENSE=`cat "/tmp/$TS.form"|head -4|tail -1`;
COPY=`cat "/tmp/$TS.form"|head -5|tail -1`;
HOME=`cat "/tmp/$TS.form"|head -6|tail -1`;
fi

if [ ! -d "$dirname" ]; then
 mkdir "$dirname"
 cp "$1" "$dirname"
 cd "$dirname" && winedump spec "$dllname"|grep -e ".*'.*'.*"|cut -d\' -f2 > "$dirname.func" && rm -f "$dllname"
 rm *.c 2> /dev/null
 rm *.h 2> /dev/null
 rm Makefile.in 2> /dev/null
 mv "$dirname.spec" "$dirname.spec.orig"
else
 dialog --colors --backtitle "wrappit4wine" --title "Error" --infobox "\n\Z1Folder \Zn\Zb$dirname\ZB \Z1for \Zn\Zb$dllname\ZB \Z1already exists.\Zn" 6 35
 exit 2;
fi

SPEC="$dirname.spec.orig";
SPEC_TARGET="$dirname.spec";
C_TARGET="$dirname.c";
H_TARGET="$dirname.h";
CONDDEF="$5";
SOURCEPATHS="$3";
LIBPATHS="$3";
TMP_HLIST="/tmp/$TS.hlist";
TMP_SLIST="/tmp/$TS.slist";
TMP_FPLIST="/tmp/$TS.fplist";
TMP_FPPLIST="/tmp/$TS.fpplist";
TMP_FLIST="/tmp/$TS.flist";
TMP_DEPS="/tmp/$TS.deps";
TMP_LIBDEPS="/tmp/$TS.libs";
TMP_LIBDEPPATHS="/tmp/$TS.libpaths";
TMP_WRAPED_DEFS="/tmp/$TS.wrappeddefs";

# Initialize depencies
c=0;
cmax=`cat "$dirname.func"|wc -l`;
cprocent=`expr $cmax / 100`;
cat "$dirname.func"|while read funcName
do
 lookupForLibDeps "$funcName" >> "$TMP_LIBDEPS"
 lookupForLibDepPaths "$funcName" >> "$TMP_LIBDEPPATHS"
 lookupForSourceDeps "$funcName" >> "$TMP_DEPS"
 lookupForWrappedSourceDefinition "$funcName" >> "$TMP_WRAPED_DEFS"
 c=`expr $c + 1`;
 p=`expr $c / $cprocent`
 expr $p % 100
done|if [ -z "$NOPROGRESS" ]; then dialog --colors --backtitle "wrappit4wine" --gauge "Preparing depencies..." 10 35 0;fi
clear

# Fixing header file
cat > "$H_TARGET" <<_EOF_
/*
 * @author $AUTHOR
 * @date $DATE
 * @see Header file $SEE
 * @license $LICENSE
 * @copy $COPY
 * @home $WWW
 */

#include "config.h"
#include <stdarg.h>
#include "windef.h"
#include "winbase.h"
#include "wine/debug.h"

WINE_DEFAULT_DEBUG_CHANNEL(cudart);

_EOF_
cat "$TMP_DEPS"|sort|uniq >> "$H_TARGET";
echo >> "$H_TARGET";
cat "$TMP_WRAPED_DEFS" >> "$H_TARGET";

# TODO: Fix breacked lines
cat "$H_TARGET"|grep -v "/\*.*\*/" |grep -v " *\#"|grep -v "^ *[/*]\+"|grep -v "^ *$" > "$TMP_HLIST"
cat "$SPEC"|grep "^[0-9]\+"|cut -d" " -f3- > "$TMP_SLIST"
cat "$TMP_HLIST"|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2|cut -d\( -f1|sort|uniq > "$TMP_FLIST"
cat "$TMP_HLIST"|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2|cut -d\; -f1|sort|uniq > "$TMP_FPLIST"
cat "$TMP_HLIST"|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2-|cut -d\; -f1|sort|uniq|while read f; do echo "$PREFIX$f"; done > "$TMP_FPPLIST"

# Fixing source file
cat > "$C_TARGET" <<_EOF_
/*
 * @author $AUTHOR
 * @date $DATE
 * @see Source file $SEE
 * @license $LICENSE
 * @copy $COPY
 * @home $WWW
 */

#include "$dirname.h"

// DllMain definition
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    TRACE("(%p, %u, %p)\n", instance, reason, reserved);

    switch (reason)
    {
        case DLL_WINE_PREATTACH:
            return FALSE;
        case DLL_PROCESS_ATTACH:
            DisableThreadLibraryCalls(instance);
            break;
    }

    return TRUE;
}

_EOF_

cat "$TMP_HLIST"|while read def
do
 funcName=`echo $def|sed -e "s/$PREFIX/\#/g"|cut -d\# -f2|cut -d\( -f1`;
 sdef=`lookupForSourceDefinition "$funcName"`;
 sourceDefinition="$sdef";
 passParams=`echo "$sdef"|lookupPassParamsFromSourceDef "$funcName"|sed -e 's/\*//g'|sed -e 's/\&//g'`;
 isnoreturnreq=`echo "$sdef"|cut -d\( -f1|grep "void *[^\*]"`;
 callprefix=`echo "$SPEC_DEF"|sed -e 's/@ */__/g'`;
 echo -n "$callprefix$sdef"|sed -e "s/;$//g"|sed -e "s/$funcName/$PREFIX$funcName/g";
 echo " {";
 if [ -z "$isreturnreq" ]; then
  echo -ne "\t";
  echo "return $funcName($passParams);";
 else
  echo -ne "\t";
  echo "$funcName($passParams);";
 fi
 echo "}";
 echo
done >> "$C_TARGET"

# Fixing deps

# Fixing spec file
SPEC_DEF="@";
cat "$TMP_SLIST"|while read l
do
 isparametrized=`echo "$l"|grep "("`; 
 if [ -n "$isparametrized" ]; then 
   echo "$l"|cut -d")" -f1|while read pf
   do
    echo "$pf )";
   done
 else
   echo "$l"; 
 fi
done|while read specFunc
do
 funcName=`echo "$specFunc"|cut -d"(" -f1`;
 substFunc=`cat "$TMP_FPPLIST"|grep "^$PREFIX$funcName("|cut -d"(" -f1`;
 specParams=`cat "$TMP_HLIST"|grep "$PREFIX$funcName"|prepareSpecParamsFromSourceDef`;
 if [ -n "$substFunc" ]; then
  echo "$SPEC_DEF $specFunc($specParams) $substFunc";
 else
  echo "# $PREFIX$funcName not implemented yet";
 fi
done > "$SPEC_TARGET"

#cat "$TMP_DEPS"|sort|uniq;
#cat "$TMP_LIBDEPS"|sort|uniq
#cat "$TMP_LIBDEPPATHS"|sort|uniq

cd ..
CleanUpTemps "$TS";
if [ -z "$NOPROGRESS" ]; then dialog --colors --backtitle "wrappit4wine" --title "About" --infobox "\ZbYour wrapper was generated successfully.\ZB\n\n\ZnYou welcome for using wrapper4wine\nwriten by Juraj Puchky - Devtech.\n\n\Z5\"I would like to see your smile\nwhen you will use wrappit for wine.\"\Zn\n\n\Z4http://www.devtech.cz/opensource/wrappit4wine\Zn" 11 50; fi
