#!/bin/sh

##############################################################################
#    Dave Rudack:  August 8, 2013 - Adopted from exgfsmos.sh.ecf 
#
#    Purpose: To run all steps necessary to create short range ECMWF MOS fcsts.
#
#    History:
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jun 13, 2016 SDS  - Configured for MPMD on Cray
#           Sep  9, 2016 SDS  - Use large ra template instead of racreate
#
###############################################################################
 
echo MDLLOG: `date` - Begin job exgfsmos_metar_fcst

set -x

cd $DATA/metar
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

cpreq $COMIN/mdl_ecmpkd.$cycle mdl_ecmpkd.$cycle

################################################################
#    RUN OBSPREP
#    EVEN IF OBS ARE MISSING, WE NEED TO PRODUCE PKOBS FILE
################################################################

if test $cyc -eq '00'
then
   obhr1=03
   cpreq $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
elif test $cyc -eq '12'
then
   obhr1=15
   cpreq $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
fi

if [ ! -f sfctbl.$obhr1 ]
   then touch sfctbl.$obhr1
fi

export pgm=mdl_obsprep
. prep_step
export FORT10="ncepdate"
export FORT20="sfctbl.$obhr1"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT70="pkobs.$DAT"
startmsg
$EXECmos_shared/mdl_obsprep < $PARMmdl/mdl_ecmobsprep.cn >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
#!!!NOTE: AN ERROR HERE IS OK; OBS ARE NOT ESSENTIAL TO MOS FORECASTS!!!
#######################################################################

# Copy over rafile_template_large
cpreq $FIXmos_shared/mdl_rafile_template_large mdl_ecmmos.$cycle

#######################################################################
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS MOS FORECAST
#                   FILE WITH STATION CALL LETTERS,
#                   ELEVATION, LATITUDE, AND LONGITUDE
#######################################################################

export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_rainit < $PARMmdl/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended 

#######################################################################
#    FIRST EXECUTION OF PROGRAM MOSPRED 
#    MOSPRED - USED TO INTERPOLATE TO STATIONS FROM TDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="mdl_ecmpkd.$cycle"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmprd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_conststa"
export FORT60="ecmmodel.$DAT"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#######################################################################
#    SECOND EXECUTION OF PROGRAM MOSPRED
#    MOSPRED - USED TO CREATE OBSERVED PREDICTORS FROM THE MDL  
#              OBSERVATIONAL TABLES.
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - CREATE OBSERVATIONAL PREDICTORS
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT80="pkobs.$DAT"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmprd.obs"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT61="mdl_ecmobs.$cycle"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredobs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  Second use of MOSPRED ended 

################################################
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT23="mdl_ecmobs.$cycle"
export FORT24="ecmmodel.$DAT"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmwind.04010930.$cycle"
export FORT31="$FIXmdl/mdl_ecmwind.10010331.$cycle"
export FORT32="$FIXmdl/mdl_ecmgust.04010930.$cycle"
export FORT33="$FIXmdl/mdl_ecmgust.10010331.$cycle"
export FORT34="$FIXmdl/mdl_ecmmxmntd84.04010930.$cycle"
export FORT35="$FIXmdl/mdl_ecmmxmntd84.10010331.$cycle"
export FORT36="$FIXmdl/mdl_ecmpopqpf84.04010930.$cycle"
export FORT37="$FIXmdl/mdl_ecmpopqpf84.10010331.$cycle"
export FORT52="$FIXmdl/mdl_ecmopqcld.04010930.$cycle"
export FORT53="$FIXmdl/mdl_ecmopqcld.10010331.$cycle"
export FORT54="$FIXmdl/mdl_ecmptype84.09010831.$cycle"
export FORT55="$FIXmdl/mdl_ecmsnow.09010831.$cycle"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmeval.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

######################################################
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS
######################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmpost.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT47="$FIXmdl/mdl_threshold"
export FORT49="mdl_ecmmos.$cycle"
export FORT50="mdl_ecmmossq.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
   cpreq mdl_ecmobs.$cycle $COMOUT
   cpreq ecmmodel.$DAT $COMOUT/mdl_ecmprdpkd.$cycle
   cpreq mdl_ecmmos.$cycle $COMOUT
   cpreq mdl_ecmmossq.$cycle $COMOUT
   cpreq pkobs.$DAT $COMOUT/mdl_ecmobspkd.$cycle
fi

#######################################################################
echo MDLLOG: `date` - Job execmmos_metar_fcst.sh has ended.
#######################################################################

exit 0
