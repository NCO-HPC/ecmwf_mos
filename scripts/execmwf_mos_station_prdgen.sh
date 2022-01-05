#!/bin/sh
##############################################################################
#    Dave Rudack:  August 8, 2013: Adapted from exgfsmos_station_prdgen.sh.ecf 
#   
#     Purpose: To run all steps necessary to create short range ECMWF-based
#              MOS station-based products.  
#
#     History: Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                                  all 'XLFUNIT_  ' env vars to 'FORT  '
#              Jul 14, 2014  SDS - Adding tstms/svr
##############################################################################
 
echo MDLLOG: `date` - Begin job execmmos_station_prdgen

set -x

cd $DATA

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################

cpreq $COMIN/mdl_ecmmos.$cycle mdl_ecmmos.$cycle
cpreq $COMIN/mdl_ecmtsvr80.$cycle mdl_ecmtsvr80.$cycle
cpreq $COMIN/mdl_ecmtsvr40.$cycle mdl_ecmtsvr40.$cycle

#######################################################################
#
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#      3/2006 - THIS STEP GETS THE 40KM TSTM TO THE MOS SITES
#               FOR 6-, 12-, AND 24-HR TSTM FORECASTS.
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_mos2grd_40.tbl"
export FORT28="$FIXmdl/mdl_ecmtsvr40comb.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT48="mdl_ecmtsvr40.$cycle"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#      3/2006 - THIS STEP GETS THE 48KM SVR TO THE MOS SITES
#               FOR 6- AND 12-HR (C/U)SVR FORECASTS.
#     12/2009 - CHANGED TO PUT THE 80KM SVR TO THE MOS SITES
#               FOR 6- AND 12-HR (C/U)SVR FORECASTS.
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_mos2grd_80.tbl"
export FORT28="$FIXmdl/mdl_ecmposttsvraw.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT48="mdl_ecmtsvr80.$cycle"
export FORT49="mdl_ecmmos.$cycle"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
# COPY FILES TO COM 
#######################################################################
if test $SENDCOM = 'YES'
then
  cpreq mdl_ecmmos.$cycle $COMOUT
fi

#######################################################################
#  CREATE ALL OF OUR TEXT PRODUCTS, COPY THEM TO COM AND SEND OUT
#######################################################################

#######################################################################
# ECCMOSTX
# GENERATE SHORT-RANGE ECM MOS MESSAGE CODE
#######################################################################

export pgm=mdl_ecmmostx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT48="mdl_ecmmos.$cycle"
export FORT60="mdl_ecstxt.$cycle"
export FORT65="mdl_ecstxt.$cycle.tran"
startmsg
$EXECmos_shared/mdl_ecmmostx < $PARMmdl/mdl_ecmecstx.dat.$cycle >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# COPY FILES TO COM & SEND OUT MESSAGE
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq mdl_ecstxt.$cycle $COMOUT
  cpreq mdl_ecstxt.$cycle.tran $COMOUT
  cp mdl_ecstxt.$cycle.tran $pcom/txt.ecmwf.$cycle.mos_ecs.na
  if [ $? -ne 0 ]; then
     msg="WARNING: File could not be copied to $pcom."
     postmsg $jlogfile "$msg"
  fi  
fi

if test $SENDDBN = 'YES'
then
    if test $SENDDBN_NTC = 'YES'; then
    #Omit alerting restricted data to public unless in production.
        $DBNROOT/bin/dbn_alert TEXT ecmwf_mos $job $pcom/txt.ecmwf.$cycle.mos_ecs.na
    fi
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecstxt.$cycle.tran
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecstxt.$cycle
fi

echo MDLLOG: `date` - Job execmmos_station_prdgen.sh.ecf has ended.

exit 0
