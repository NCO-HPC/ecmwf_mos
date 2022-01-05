#!/bin/sh
#######################################################################
#  Job Name: execmmos_tstms_extfcst.sh.ecf
#  Purpose: To run all steps necessary to create extended-range ECMWF MOS
#           fcsts for thunderstorms and severe weather.  This script
#           adds the extended projections to the tsvr random access
#           file created in the short-range job, execmmos_tstms_fcst.
#  Remarks:
#  HISTORY: Jul 11, 2014      - Created from operational gfs_mos.v3.10.1
#                               exgfsmos_tstms_extfcst.sh.ecf.
#           Jun 13, 2016      - Configured for MPMD on Cray.
#
#######################################################################
#
echo MDLLOG: `date` - Begin job execmmos_tstms_extfcst
set -x

cd $DATA/tstms
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILES FIRST CREATED IN THE
#    EXECUTION OF EXECM_TSVRMOS.  CHECK IF THE FILES
#    MDL_ECMTSVR40.TXXZ AND MDL_ECMTSVR80.TXXZ EXIST IN COM/ECM.  
#    IF THEY DO, COPY THE FILES TO THE WORK SPACE.
#    IF THEY DO NOT EXIST, THE SCRIPT WILL ABORT.  EXECM_EXTTSVRMOS
#    WILL NOT WORK UNLESS EXECM_TSVRMOS HAS ALREADY RUN SUCCESSFULLY.
#
#######################################################################
#
#######################################################################
#  CREATE THE 40KM EXTENDED RANGE THUNDERSTORM FORECASTS
#  AT 0000 AND 1200 UTC CYCLES
#
#  THEN CREATE THE 80KM THUNDERSTORMS AT 0000 AND 1200
#
#######################################################################

if [ ! -f $COMIN/mdl_ecmtsvr40.$cycle ]
        then echo 'need successful run of ecmmos_tstms_fcst to run properly' >> $pgmout
        export err=1; err_chk
fi

cpreq $COMIN/mdl_ecmtsvr40.$cycle .

#######################################################################
# COPY MODEL FILES TO TEMP SPACE
#######################################################################
cpreq $COMIN/mdl_ecmpkd.$cycle pkecmraw.$DAT
cpreq $COMIN/mdl_ecmxpkd.$cycle pkecmxraw.$DAT

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkecmraw.$DAT"
export FORT25="pkecmxraw.$DAT"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT28="$FIXmdl/mdl_ecmxtsvr40prd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_constgrd40"
#   Output predictors
export FORT60="tsvrprdx40.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmxpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprdx40.$DAT"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmxtsvr40km.07011015.$cycle"
export FORT31="$FIXmdl/mdl_ecmxtsvr40km.10160315.$cycle"
export FORT32="$FIXmdl/mdl_ecmxtsvr40km.03160630.$cycle"
#  Output random access raw forecast file below
export FORT49="mdl_ecmtsvr40.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmxevaltsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#    (U910/U710)
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS TSVR FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT28="$FIXmdl/mdl_ecmxposttsvr40.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
#  Input and Output random access raw and processed forecast file below
export FORT49="mdl_ecmtsvr40.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq mdl_ecmtsvr40.$cycle $COMOUT
fi
#######################################################################

if [ ! -f $COMIN/mdl_ecmtsvr80.$cycle ]
        then echo 'need successful run of ecmmos_tstms_fcst to run properly' >> $pgmout
        export err=1; err_chk
fi

cpreq $COMIN/mdl_ecmtsvr80.$cycle .

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkecmraw.$DAT"
export FORT25="pkecmxraw.$DAT"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT28="$FIXmdl/mdl_ecmxtsvr80prd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_constgrd80"
#  Output file follows
export FORT60="tsvrprdx80.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmxpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR 80km TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprdx80.$DAT"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmxtsvr80km.07011015.$cycle"
export FORT31="$FIXmdl/mdl_ecmxtsvr80km.10160315.$cycle"
export FORT32="$FIXmdl/mdl_ecmxtsvr80km.03160630.$cycle"
#  Output random access file below containing raw forecasts
export FORT49="mdl_ecmtsvr80.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmxevaltsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#    (U910/U710)
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS TSVR FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT28="$FIXmdl/mdl_ecmxposttsvr80.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
#  Input and Output random access file containing raw and processed forecasts
export FORT49="mdl_ecmtsvr80.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM 
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq mdl_ecmtsvr80.$cycle $COMOUT
fi

#######################################################################
echo MDLLOG: `date` - Job execmmos_tstms_extfcst has ended.
#######################################################################
