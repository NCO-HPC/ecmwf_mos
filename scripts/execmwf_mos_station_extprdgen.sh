#!/bin/sh
##################################################################################
#    Dave Rudack:  August 8, 2013 - Adopted from exgfsmos_station_extprdgen.sh.ecf
#
#    Purpose: To run all steps necessary to create extended range ECM MOS fcsts.
#
#    History:
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jul 14, 2014  SDS - Adding tstms/svr
#
##################################################################################
 
echo MDLLOG: `date` - Begin job execmmos_station_extprdgen

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
export FORT28="$FIXmdl/mdl_ecmxtsvr40comb.$cycle"
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
export FORT28="$FIXmdl/mdl_ecmxposttsvraw.$cycle"
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
# RA2MDLP - ARCHIVE ECM-MOS FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#######################################################################

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmmmosarch.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT38="mdl_ecmmos.$cycle"
export FORT66="mdl_ecmmossq_arch.$cycle"
startmsg
$EXECmos_shared/mdl_ra2mdlp < $PARMmdl/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk

#######################################################################
# COPY FILES TO COM 
#######################################################################
if test $SENDCOM = 'YES'
then
  cpreq mdl_ecmmossq_arch.$cycle $COMOUT
fi

#######################################################################
#  CREATE ALL OF OUR TEXT PRODUCTS, COPY THEM TO COM AND SEND OUT
#######################################################################

#######################################################################
# ECCMOSTX
# GENERATE EXTENDED-RANGE ECM MOS MESSAGE CODE
############################################################

export pgm=mdl_xecmmostx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT38="mdl_ecmmos.$cycle"
export FORT60="mdl_ecxtxt.$cycle"
export FORT65="mdl_ecxtxt.$cycle.tran"
startmsg
$EXECmos_shared/mdl_xecmmostx < $PARMmdl/mdl_ecmecxtx.dat.$cycle >> $pgmout 2>errfile
export err=$?; err_chk

#  COPY THE 00Z ECMOS RANDOM ACCESS FILE TO COM.  THE FILE "MDL_ECMMOS.$CYCLE" WILL
#  BE USED BY THE ECMWF ENSEMBLE MOS PROCESSING STEP.  BECAUSE ONE OF THE PERTURBATIONS
#  HAS A DD=06, THE DETERMINISTIC DD=06 WILL BE OVERWRITTEN.  SO, TO RETRIEVE THE ORIGINAL
#  DETERMINSITIC FORECAST VALUES OF DD=6 FOR PRINT OUT IN THE TEXT BULLETIN, WE MERGE
#  THESE TWO FILES AT THE END OF THE ECMWF ENSEMBLE PROCESSING.  THIS WILL THEN OVERWRITE
#  THE PERTURBATION FORECASTS OF DD=06.  

#######################################################################
# COPY FILES TO COM & SEND OUT MESSAGE
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq mdl_ecxtxt.$cycle $COMOUT
  cpreq mdl_ecxtxt.$cycle.tran $COMOUT
  cp mdl_ecxtxt.$cycle.tran $pcom/txt.ecmwf.$cycle.mos_ecx.na
  if [ $? -ne 0 ]; then
     msg="WARNING: File could not be copied to $pcom."
     postmsg $jlogfile "$msg"
  fi  
  cpreq mdl_ecmmos.$cycle $COMOUT/mdl_ecmmos.$cycle.deterministic
fi

if test $SENDDBN = 'YES'
then
    if test $SENDDBN_NTC = 'YES'; then
    #Omit alerting restricted data to public unless in production.
        $DBNROOT/bin/dbn_alert TEXT ecmwf_mos $job $pcom/txt.ecmwf.$cycle.mos_ecx.na
    fi
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecxtxt.$cycle
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecxtxt.$cycle.tran
fi

echo MDLLOG: `date` - Job execmmos_station_prdgen has ended.

exit 0
