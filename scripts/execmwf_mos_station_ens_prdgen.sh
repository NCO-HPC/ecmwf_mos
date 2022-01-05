#!/bin/sh
 
################################################################################
#    Dave Rudack:  August 8, 2013: Adapted from execmmos_station_extprdgen.sh.ecf
#
#     Purpose: To run all steps necessary to create extended range ECMWF-based
#              ensemble MOS station-based products.
#
#     History: Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                                  all 'XLFUNIT_  ' env vars to 'FORT  '
#################################################################################
 
echo MDLLOG: `date` - Begin job xecmos_ensemble_stats_station_prdgen.sh.sms

set -x

#######################################################################
#  COPY STATS FILE FROM COMIN
#######################################################################
cpreq $COMIN/mdl_ecmmos.$cycle $DATA/. 

##########################################
#  CREATE THE ENSEMBLE ECMOS MOS MESSAGE.
##########################################

export pgm=xecmos_stats_txt
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT38="mdl_ecmmos.$cycle"
export FORT60="mdl_ecmtxt.$cycle"
export FORT65="mdl_ecmtxt.$cycle.tran"

startmsg
$EXECmos_shared/mdl_ecemostx < $PARMmdl/mdl_ecmecmtx.dat.$cycle >> $pgmout 2>errfile
export err=$?; err_chk

if test $SENDCOM = 'YES' 
then
  cpreq mdl_ecmtxt.$cycle $COMOUT 
  cpreq mdl_ecmtxt.$cycle.tran $COMOUT
  cp mdl_ecmtxt.$cycle.tran $pcom/txt.ecmwf.$cycle.mos_ecm.na
  if [ $? -ne 0 ]; then
     msg="WARNING: File could not be copied to $pcom."
     postmsg $jlogfile "$msg"
  fi
fi

if test $SENDDBN = 'YES' 
then
    if test $SENDDBN_NTC = 'YES'; then
    #Omit alerting restricted data to public unless in production.
        $DBNROOT/bin/dbn_alert TEXT ecmwf_mos $job $pcom/txt.ecmwf.$cycle.mos_ecm.na
    fi
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecmtxt.$cycle.tran
  $DBNROOT/bin/dbn_alert MDLFCST ECMOSTXT $job $COMOUT/mdl_ecmtxt.$cycle
fi


echo MDLLOG: `date` - Job xecmos_ensemble_stats_station_prdgen.sh.sms has ended.
  
exit 0
