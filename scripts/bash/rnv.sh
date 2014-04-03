#!/bin/bash
## Unified Approach to Speech Synthesis and Recognition
## - Rollback/verify and nightly build tool for dLabPro and UASR
##
## AUTHOR  : Matthias Wolff, Frank Duckhorn
## PACKAGE : uasr/scripts/bash

## TODO    : Adjust for GIT repositories!  
##
## UASR/dLabPro maintenance script. Warning: this script overwrites ALL
## local modifications of the working copies!'
##
## USAGE:
##   rnv.sh (-a|-d <date>|-k|-r <uasr-revision> <dlabpro-revision> <vm.de-revision>|-u)
##
## OPTIONS:
##   -a: Automatic mode: verify HEAD revisions and send email if failed
##   -d: Verify UASR/dLabPro revisions specified by date
##   -k: Verify current UASR/dLabPro revision (no roll-back/update)
##   -r: Verify UASR/dLabPro revisions specified by numbers
##   -u: Only update UASR and dLabPro and build dLabPro (no verification)
##
## REMARKS on automatic mode:
##   The automatic mode (-a) is used for nightly build and verification of dLabPro. 
##   It sends mails containing changes (svn.log) to all involved authors if build 
##   or verify experiment fails. The MAINTAINER (see variable below) gets this mail 
##   in any case (notice of successful completion or svn log).
##
##   A cronjob is used to run this script every night. 
##   The file /erk/daten2/uasr-maintanance/.crontab can be used for this purpose.
##   It contains the following job entry (as of 2010-01-07):
##
##   5 23 * * *       exec bash -login /erk/daten2/uasr-maintenance/uasr/scripts/bash/rnv.sh -a > /erk/daten2/uasr-maintenance/maintenance.log 2>&1
##
##   See man cronjob and man -S 5 cronjob for more information.
##
## Copyright 2013-2014 UASR contributors (see COPYRIGHT file)
## - Chair of System Theory and Speech Technology, TU Dresden
## - Chair of Communications Engineering, BTU Cottbus
##
## This file is part of UASR.
##
## UASR is free software: you can redistribute it and/or modify it under the
## terms of the GNU Lesser General Public License as published by the Free
## Software Foundation, either version 3 of the License, or (at your option)
## any later version.
##
## UASR is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
## details.
##
## You should have received a copy of the GNU Lesser General Public License
## along with UASR. If not, see <http://www.gnu.org/licenses/>.

## Maintainer gets notification in any case
MAINTAINER=matthias.wolff@tu-cottbus.de

## Uasr common data directory for vm database
UASR_DATA_VM_COMMON= ~/uasr-data-common/vm.de/common

UASR_HOME="$0"
[ "${UASR_HOME#/}" = "$UASR_HOME" ] && UASR_HOME=`pwd`"/$UASR_HOME"
UASR_HOME=${UASR_HOME%rnv.sh}
UASR_HOME=${UASR_HOME%uasr/*}
UASR_HOME=${UASR_HOME%uasr}uasr
export UASR_HOME
export DLABPRO_HOME=${UASR_HOME%uasr}dLabPro
export PATH=$DLABPRO_HOME/bin.release:$PATH
export RECOGNIZER_SUBDIR=
DLABPRO=${UASR_HOME%uasr}dLabPro/bin.release/dlabpro
RECOGNIZER=${UASR_HOME%uasr}dLabPro/bin.release/recognizer


UR="HEAD"
DR="HEAD"
VR="HEAD"
RR="HEAD"
SR="HEAD"
if [ "X$1" = 'X-a' ]; then
	echo; echo "// ROLLBACK AND VERIFY //////////////////////////////////////////////////"
	RM="yes"
	export SEND_EMAIL="yes"
elif [ "X$1" = 'X-u' ]; then
	echo "   - to head"
	export UPDATE_ONLY="yes"
elif [ "X$1" = 'X-d' ]; then
	if [ $# -lt 2 ]; then
		echo 'Missing arguments, type "rnv.sh" for help'
		echo 'Stop'
		exit 1
	fi
	echo "   - to date $2"
	UR="{$2}"
	DR="{$2}"
	VR="{$2}"
	RR="{$2}"
	SR="{$2}"
elif [ "X$1" = 'X-r' ]; then
	if [ $# -lt 4 ]; then
		echo 'Missing arguments, type "rnv.sh" for help'
		echo 'Stop'
		exit 1
	fi
	echo "   - to revision UASR $2 / dLabPro $3 / vm.de $4 / recognizer $5 / synthesizer $6"
	UR="$2"
	DR="$3"
	VR="$4"
	RR="$5"
	SR="$6"
elif [ "X$1" = 'X-k' ]; then
	echo "   - keep current revision (UASR `svnversion $UASR_HOME` / dLabPro `svnversion $UASR_HOME/../dLabPro` / vm.de `svnversion $UASR_HOME-data/vm.de`)"
	export UPDATE_NO="yes"
else
	echo
	echo 'UASR/dLabPro maintenance script. Warninig: this script overwrites ALL'
	echo 'local modifications of the working copies!'
	echo
	echo 'USAGE:'
	echo '  rnv.sh (-a|-d <date>|-k|-r <uasr-revision> <dlabpro-revision> <vm.de-revision> <recognizer-revision> <synthesizer-revision>|-u)'
	echo
	echo 'OPTIONS:'
	echo '  -a: Automatic mode: verify HEAD revisions and send email if failed'
	echo '  -d: Verify UASR/dLabPro revisions specified by date'
	echo '  -k: Verify current UASR/dLabPro revision (no rollback/update)'
	echo '  -r: Verify UASR/dLabPro revisions specified by numbers'
	echo '  -u: Only update UASR and dLabPro and build dLabPro (no verification)'
	echo
	exit 1
fi

[ "X$1" != "X-k" -o "X$2" != "Xself" ] && ERRTXT=""

echo "   - \$UASR_HOME: $UASR_HOME"

function check_error
{
	RET="$1"
	TXT="$2"
	[ "$RET" = 0 ] && return
	echo "ERROR: $TXT failed"
	ERRTXT=$ERRTXT"ERROR: $TXT failed\n"
}

function svn_log
{
	NAME=$1
	DIR=$2
	echo; echo "// $NAME SVN log ------------------------------------------------------"
	DATE=`date -d yesterday "+%F"`
	REV=`svn info -r "{$DATE}" "$DIR" | sed -e '/^Revision:/!d;s/^.*: *//'`
	svn log -v -r "$[REV+1]:BASE" "$DIR" 2>/dev/null
}

function send_email
{
	[ "$SEND_EMAIL" != "yes" ] && return
	HEAD="$1"
	SVNLOG=${UASR_HOME%uasr}svn.log
	if [ ! "$ERRTXT" ]; then
		RECIPIENTS=$MAINTAINER
		>"$SVNLOG"
	else
		{
			echo; echo "// RNV script errors ----------------------------------------------------"
			echo $HEAD
			echo -e $ERRTXT
			svn_log dLabPro $DLABPRO_HOME
			svn_log UASR    $UASR_HOME
			svn_log VM      $UASR_HOME-data/vm.de
			echo; echo "r0 | $MAINTAINER | MAINTAINER"
		} >"$SVNLOG"
		RECIPIENTS=`grep '^r[0-9]*\ |' $SVNLOG | cut -d '|' -f 2 | tr -d ' ' | sort -u | tr '\n' ' '`
	fi
    echo -e "\n\nMailing log to $RECIPIENTS \n\n"
    for RECIPIENT in $RECIPIENTS ; do
       echo "Send svn.log to $RECIPIENT"
	   mailx -n -s "$HEAD" $RECIPIENT <"$SVNLOG"
    done
}

function finalize_error
{
	if [ ! "$ERRTXT" ]; then
		HEAD="RNV script run successful"
	else
		HEAD="RNV script failed"
	fi
	echo; echo "// Finalize error log ---------------------------------------------------"
	echo $HEAD
	echo -e $ERRTXT
	send_email "$HEAD"

	[ ! "$ERRTXT" ]
	exit $?
}

function svn_update
{
	NAME="$1"
	DIR="$2"
	URL="$3"
	REV="$4"
	[ "$REV" ] || return
	echo "   - Updating to $NAME ${UR}..."
	if [ "$RM" = "yes" ]; then
		mkdir -p "$DIR"
		rm -rf "$DIR"
		[ -e "$DIR" ] && check_error 1 "SVN Remove $NAME"
		svn co -r "$REV" "$URL" "$DIR"
		check_error $? "SVN Checkout $NAME"
	else
		svn cleanup "$DIR"
		check_error $? "SVN Cleanup $NAME"
		svn revert -R "$DIR"
		check_error $? "SVN Revert $NAME"
		svn up -r "$REV" "$DIR"
		check_error $? "SVN Update $NAME"
	fi
}

function lnk_vm
{
	[ ! -e "$UASR_HOME-data/vm.de/common/sig"     ] && ln -sf "$UASR_DATA_VM_COMMON/sig"     "$UASR_HOME-data/vm.de/common/"
	[ ! -e "$UASR_HOME-data/vm.de/common/sig-wav" ] && ln -sf "$UASR_DATA_VM_COMMON/sig-wav" "$UASR_HOME-data/vm.de/common/"
	[ ! -e "$UASR_HOME-data/vm.de/common/lab"     ] && ln -sf "$UASR_DATA_VM_COMMON/lab"     "$UASR_HOME-data/vm.de/common/"
}

function prj_build
{
	NAME="$1"
	DIR="$2"
	echo "   - Building $NAME in $DIR ..."
	cd "$DIR"
	make -s CLEANALL
	make -s RELEASE
	check_error $? "Build of $NAME"
}

function run_xtp
{
	$DLABPRO "$UASR_HOME/scripts/dlabpro/$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	check_error $? "$1"
}

function run_reco
{
	$RECOGNIZER "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
	check_error $? "$1"
}


if [ "$UPDATE_NO" != "yes" ]; then
	echo; echo "// Checking out revisions -----------------------------------------------"
	svn_update dLabPro         $DLABPRO_HOME             https://github.com/matthias-wolff/dLabPro/trunk             $DR
	svn_update UASR            $UASR_HOME                https://github.com/matthias-wolff/UASR/trunk                $UR
	svn_update vm.de           $UASR_HOME-data/vm.de     https://github.com/matthias-wolff/uasr-data-vm.de/trunk     $VR
#	svn_update synthesizer_hmm $DLABPRO_HOME-synthesizer svn+ssh://eakss1.et.tu-dresden.de/dLabPro-synthesizer/trunk $SR
	lnk_vm
fi

[ "$UPDATE_ONLY" = "yes" ] && finalize_error

echo; echo "// Building -------------------------------------------------------------"
rm -rf $DLABPRO_HOME/bin.*
prj_build dcg              $DLABPRO_HOME/programs/dcg
prj_build dlapro           $DLABPRO_HOME/programs/dlabpro
prj_build recognizer       $DLABPRO_HOME/programs/recognizer
#prj_build synthesizer_hmm  $DLABPRO_HOME-synthesizer/hmm-diphone

echo; echo "// Running VMV feature extraction and verify experiment -----------------"
run_xtp "VMV Feature extraction" FEA.xtp ana $UASR_HOME-data/vm.de/common/info/VMV.cfg \
  -Pexp=VMV_RNV -Pdir.flists=$UASR_HOME-data/vm.de/VMV/flists \
  -Pdir.fea=$UASR_HOME-data/vm.de/VMV_RNV/fea
run_xtp "VMV Verify experiment"  HMM.xtp trn $UASR_HOME-data/vm.de/common/info/VMV.cfg \
  -Pexp=VMV_RNV -Pdir.flists=$UASR_HOME-data/vm.de/VMV/flists \
  -Pdir.fea=$UASR_HOME-data/vm.de/VMV_RNV/fea \
  -Pam.train.split=1

echo; echo "// Running command recognition verify experiment -----------------"
run_xtp "Command recognition verify experiemnt #1" HMM.xtp evl $UASR_HOME-data/ssmg/common/info/SAMURAI_0.cfg \
	-Pdir.model=$UASR_HOME-data/vm.de/VMV_RNV/model \
	-Pam.model=1_5 \
	-Pam.eval.wrd.ite-1_-1=0.956,0.936,1.013
run_xtp "Command recognition verify experiemnt #2" HMM.xtp evl $UASR_HOME-data/ssmg/common/info/MYUSE_0.cfg \
	-Pdir.model=$UASR_HOME-data/vm.de/VMV_RNV/model \
	-Pam.model=1_5 \
	-Pam.eval.wrd.ite-1_-1=0.951,0.943,1.002

echo; echo "// Running recognizer verify experiment -----------------"
cd $UASR_HOME-data/pcus11
rm -rf log
run_xtp "Recognizer pack data" tools/REC_PACKDATA.xtp rec PCUS11.cfg -Pout=log
run_reco "Recognizer verify experiment" \
	-data.feainfo log/feainfo.object \
	-data.gmm log/1_5.gmm \
	-data.sesinfo log/sesinfo.object \
	-data.vadinfo "" \
	PCUS11_test.flst


finalize_error

## EOF
