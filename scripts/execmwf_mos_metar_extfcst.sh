#!/bin/sh

############################################################################
#    Dave Rudack:  August 8, 2013 - Adopted from exgfsmos.sh.ecf
#
#    Purpose: To run all steps necessary to create short range ECMWF MOS fcsts.
#
#    History:
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jun 13, 2016 SDS  - Configured for MPMD on Cray.
#
############################################################################
 
echo MDLLOG: `date` - Begin job execmmos_metar_extfcst.sh

set -x

cd $DATA/metar
cpreq $DATA/ncepdate .

export DAT="$PDY$cyc"

cpreq $COMIN/mdl_ecmobs.$cycle mdl_ecmobs.$cycle
cpreq $COMIN/mdl_ecmprdpkd.$cycle ecmmodel.$DAT
cat $COMIN/mdl_ecmpkd.$cycle $COMIN/mdl_ecmxpkd.$cycle > pkecmraw.$cycle
cpreq $COMIN/mdl_ecmmos.$cycle mdl_ecmmos.$cycle

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA

##################################
#  INTERPOLATE MODEL DATA
##################################

export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkecmraw.$cycle"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmxprd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_conststa"
export FORT60="ecmxmodel.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#######################################################################
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"

export FORT23="mdl_ecmobs.$cycle"
export FORT20="ecmmodel.$DAT"
export FORT24="ecmxmodel.$DAT"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmxwind.04010930.$cycle"
export FORT31="$FIXmdl/mdl_ecmxwind.10010331.$cycle"
export FORT32="$FIXmdl/mdl_ecmxgust.04010930.$cycle"
export FORT33="$FIXmdl/mdl_ecmxgust.10010331.$cycle"
export FORT34="$FIXmdl/mdl_ecmxmxmntd.04010930.$cycle"
export FORT35="$FIXmdl/mdl_ecmxmxmntd.10010331.$cycle"
export FORT36="$FIXmdl/mdl_ecmxpopqpf.04010930.$cycle"
export FORT37="$FIXmdl/mdl_ecmxpopqpf.10010331.$cycle"
export FORT38="$FIXmdl/mdl_ecmxopqcld.04010930.$cycle"
export FORT39="$FIXmdl/mdl_ecmxopqcld.10010331.$cycle"
export FORT52="$FIXmdl/mdl_ecmxopqcld12.04010930.$cycle"
export FORT53="$FIXmdl/mdl_ecmxopqcld12.10010331.$cycle"
export FORT54="$FIXmdl/mdl_ecmptype192.09010831.$cycle"
export FORT55="$FIXmdl/mdl_ecmxptype.09010831.$cycle"
export FORT56="$FIXmdl/mdl_ecmxsnow.09010831.$cycle"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmxeval.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

#######################################################################
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmxpost.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT47="$FIXmdl/mdl_threshold"
export FORT49="mdl_ecmmos.$cycle"
export FORT50="mdl_ecmxmossq.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
#    PROGRAM SEQ2RA - WRITES VECTOR SEQUENTIAL TO STATION RANDOM ACCESS
#    THIS GETS THE PRISM NORMALS FROM THE U201 OUTPUT AND WRITES 
#    THEM TO THE FORECAST FILE FOR USE BY MEX CODE.
#######################################################################

echo MDLLOG: `date` - begin job SEQ2RA - PACKS PRISM NORMALS
export pgm=mdl_seq2ra
. prep_step

export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT20="ecmxmodel.$DAT"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_seq2ra < $PARMmdl/mdl_seq2ra.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  SEQ2RA ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
   cpreq mdl_ecmmos.$cycle $COMOUT
   cpreq mdl_ecmxmossq.$cycle $COMOUT
   cpreq ecmxmodel.$DAT $COMOUT/mdl_ecmxprdpkd.$cycle
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job execmmos_metar_extfcst.sh.ecf has ended.

#######################################################################

exit 0
