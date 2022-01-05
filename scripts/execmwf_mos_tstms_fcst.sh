#!/bin/sh
#######################################################################
#  Job Name: execmmos_tstms_fcst.sh.ecf
#  Purpose: To run all steps necessary to create short range ECMWF MOS 
#           fcsts for thunderstorms.  This script creates one set of 
#           forecasts on a 40km grid and another one on a 80-km grid.
#  Remarks: 
#  HISTORY: Jul 10, 2014      - Created from operational gfs_mos.v3.10.1
#                               exgfsmos_tstms_fcst.sh.ecf
#           Jun 13, 2016      - Configured for MPMD on Cray 
#           Sep  9, 2016  SDS - Copy over ra_template_large instead of
#                               using racreate (ra_large seems to be 
#                               required for iobuf)
#
#######################################################################
#
echo MDLLOG: `date` - Begin job execmmos_tstms_fcst.sh.ecf
set -x

cd $DATA/tstms
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
# COPY MODEL FILES TO TEMP SPACE
#######################################################################
cpreq $COMIN/mdl_ecmpkd.$cycle pkecmraw.$DAT

# Copy over ra template file
cpreq $FIXmos_shared/mdl_rafile_template_large mdl_ecmtsvr40.$cycle 

######################################################################
#  now copy the random access file to a 20km, 80km and an AK 47 for
#  tsvr and a 20km one for conv
######################################################################
cpreq mdl_ecmtsvr40.$cycle mdl_ecmtsvr80.$cycle

#######################################################################
#  Note:  This first set of rainit through fcstpost is for the 40 km
#         forecasts.  They will be stored in the file ecmtsvr40
#######################################################################

#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 40km TSVR RANDOM ACCESS FORECAST FILE
#  (U351)
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT49="mdl_ecmtsvr40.$cycle"
startmsg
$EXECmos_shared/mdl_rainit < $PARMmdl/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

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
export FORT25="pkecmraw.$DAT"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT28="$FIXmdl/mdl_ecmtsvr40prd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_constgrd40"
#  Output file follows
export FORT60="tsvrprd40.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR 40km TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprd40.$DAT"
export FORT26="$FIXmdl/mdl_tsvr40sta.lst"
export FORT27="$FIXmdl/mdl_tsvr40sta.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmtsvr40km.07011015.$cycle"
export FORT31="$FIXmdl/mdl_ecmtsvr40km.10160315.$cycle"
export FORT32="$FIXmdl/mdl_ecmtsvr40km.03160630.$cycle"
#  Output random access file below containing raw forecasts
export FORT49="mdl_ecmtsvr40.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmevaltsvr.cn >> $pgmout 2>errfile
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
export FORT28="$FIXmdl/mdl_ecmposttsvr40.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
#  Input and Output random access file containing raw and processed forecasts
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

#######################################################################
#  Note:  This second set of rainit through fcstpost is for the 80 km
#         forecasts.  They will be stored in the file ecmtsvr80
#######################################################################

#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 80km TSVR RANDOM ACCESS FORECAST FILE
#  (U351)
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT49="mdl_ecmtsvr80.$cycle"
startmsg
$EXECmos_shared/mdl_rainit < $PARMmdl/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

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
export FORT25="pkecmraw.$DAT"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT28="$FIXmdl/mdl_ecmtsvr80prd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_constgrd80"
#  Output file follows
export FORT60="tsvrprd80.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredmdl.cn >> $pgmout 2>errfile
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
export FORT24="tsvrprd80.$DAT"
export FORT26="$FIXmdl/mdl_tsvr80sta.lst"
export FORT27="$FIXmdl/mdl_tsvr80sta.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmtsvr80km.07011015.$cycle"
export FORT31="$FIXmdl/mdl_ecmtsvr80km.10160315.$cycle"
export FORT32="$FIXmdl/mdl_ecmtsvr80km.03160630.$cycle"
#  Output random access file below containing raw forecasts
export FORT49="mdl_ecmtsvr80.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmevaltsvr.cn >> $pgmout 2>errfile
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
export FORT28="$FIXmdl/mdl_ecmposttsvr80.$cycle"
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
echo MDLLOG: `date` - Job execmmos_tstms_fcst has ended.
#######################################################################
