#!/bin/sh

#######################################################################
#  Job Name:  ecmos_ensemble_stats.ecf
#  Purpose:   Gathers the member forecast sequential files, converts the
#             sequential files to random access files, calculates the 
#             statistics written out to the text bulletins, and merges 
#             the determinsitic random access file with the ecmwf ensemble 
#             mos statistics random access file.
#
#  HISTORY:   August 8,  Dave Rudack - Created
#######################################################################

echo ECMOSLOG: `date` - begin job execemos_stats.sh.ecf

set -x

#######################################################################
#  COPY DETERMINISTIC FORECAST FILES FROM COMIN
#######################################################################
cpreq $COMIN/mdl_ecmmos.$cycle $DATA/.
cpreq $COMIN/mdl_ecmmos.$cycle.deterministic $DATA/.
cpreq $COMIN/mdl_ecmmos.*.$cycle.seq.newid $DATA/.

#######################################################################
#  CONCATENATE THE SEQUENTIAL FILES.  THIS FILE WILL BE USED FOR DABMA 
#  PROCESSING.
#######################################################################

cat $COMIN/mdl_ecmmos.*.$cycle.seq.newid > mdl_ecmmos_all_pert.seq.$PDY$cyc
cpreq mdl_ecmmos_all_pert.seq.$PDY$cyc $COMOUT/.

###########################################################################
#  COPY THE SQ FILES WITH ALL THE MEMBER FORECASTS. LOOP OVER DD'S 0 TO 50.
###########################################################################

let dd=0
while [[ $dd -le 50 ]]
do

  memdd=`printf "%02d" $dd`
  
########################################################################
#  PROGRAM SEQ2RA  - CONVERTS A TDLPACK SEQUENTIAL AND TO AN RA 
#                    FILE. ALL THE MEMBER FORECASTS ARE IN SEPARATE SEQ
#                    FILES BUT WE NEED A SINGLE RA FILE TO MAKE THE CDF. 
########################################################################

  echo ECMOSLOG: `date` - begin job SEQ2RA - CONVERT ECMOS FORECAST FILES
  export pgm=mdl_seq2ra
  . prep_step
  export FORT26="$FIXmdl/mdl_station.lst"
  export FORT27="$FIXmdl/mdl_station.tbl"
  export FORT49="mdl_ecmmos.$cycle"
  export FORT20="mdl_ecmmos.$dd.$cycle.seq.newid"
#  export FORT20="mdl_ecmmos_all_pert.seq.$PDY$cyc"
  startmsg
  sed "s/DD/$memdd/g" $PARMmdl/mdl_seq2ra_stats_template.cn.$cycle > mdl_seq2ra_stats.cn
  $EXECmos_shared/mdl_seq2ra < mdl_seq2ra_stats.cn >> $pgmout 2>errfile
  export err=$?; err_chk


  echo ECMOSLOG: `date` -  SEQ2RA ended

  dd=$((dd+1))

done

############################################################################
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FIND MAX/MIN, 
#                       SD, LOW AND HIGH ECMWF ENSEMBLE MOS VALUES.
############################################################################
#   NOTE: UNIT NUMBER'S 45 AND 47 ARE NOT USED BUT THEY WERE LEFT IN AS NOT
#         TO HAVE TO CREATE AN ADDITIONAL FCSTPOST .CN FILE FOR OPERATIONS.
############################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmenspost_stats.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT47="$FIXmdl/mdl_threshold"
export FORT49="mdl_ecmmos.$cycle"
export FORT50="mdl_ecmmos.stats.seq.$cyc"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#    PROGRAM MAKECDF - CREATE CDF BY RANK SORTING THE ECMOS MEMBERS 
#######################################################################
echo ECMOSLOG: `date` - begin job MAKECDF - CREATE CDF OF ENS MOS FORECASTS

export pgm=ekd_makecdf
. prep_step

export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmens_makecdfid.tbl.$cycle"
export FORT30="$FIXmdl/mdl_mos2000id.tbl"
export FORT31="$FIXmdl/mdl_ecmens_cdfthresh.lst"
export FORT49="mdl_ecmmos.$cycle"
export FORT60="mdl_ecmmos.cdf.seq.$cyc"
startmsg

#echo "FORT28=$FORT28\n"
#ls -l $FORT28
$EXECmos_shared/mdl_makecdf < $PARMmdl/mdl_makecdf.cn >> $pgmout 2>errfile
export err=$?; err_chk

export err=$?; err_chk
echo MDLLOG: `date` -  MAKECDF ended

#####################################################################
#  CONCATENATE THE STATISTICS AND CDF SEQUENTIAL FILES FOR ARCHIVING.
#####################################################################

cat mdl_ecmmos.stats.seq.$cyc mdl_ecmmos.cdf.seq.$cyc > $COMOUT/mdl_ecmemos.$cycle

###############################################################################
#  SINCE THE PERTURBATION DD=06 HAS BEEN WRITTEN TO THE ORIGINAL RAF FILE, (AND 
#  OVERWRITTEN THE DERMINISTIC FORECAST OF DD=06), MERGE THE DETERMINISTIC 
#  DD=06 FORECASTS BACK ONTO THE ORGINAL FILE.
###############################################################################

echo ECMOSLOG: `date` - begin job MDL_RAMERGE - Merge deterministic and ensemble mos forecasts.

export pgm=mdl_ramerge
. prep_step

export FORT10="ncepdate"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT28="$FIXmdl/mdl_ecmensmerge.$cycle"
export FORT49="mdl_ecmmos.$cycle"
export FORT46="mdl_ecmmos.$cycle.deterministic"
startmsg

$EXECmos_shared/mdl_ramerge < $PARMmdl/mdl_ramerge.cn >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG: `date` -  RAMERGE ended

if test $SENDCOM = 'YES' 
then
  cpreq mdl_ecmmos.$cycle $COMOUT 
fi

#######################################################################
echo MDLLOG: `date` - Job execemos_stats.sh.ecf has ended.
#######################################################################

exit 0
