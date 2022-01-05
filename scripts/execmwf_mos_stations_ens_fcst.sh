#!/bin/sh

##########################################################################
#  Purpose: To extract multiple parameters from each member of the ECMWF 
#           Ensemble model output GRIB file and interpolate the parameters 
#           to MDL's fine grid. Uses wgrib and copygb utilities.
#
#     History: June 20, 2013 - Adopted from GFS Prep Scripts that were
#                              Transitioned to WCOSS (Linux).
#              Sept 09, 2016 - Added error checking to grib utilities
##########################################################################

echo MDLLOG: `date` - Begin job execmmos_stnfcst.sh.ecf
set -x

export PERT=$1

########################################
# Establish Subdirectories to make thread safe
########################################
export DATAsub=$DATA/$(printf %02d $PERT)
mkdir $DATAsub
cd $DATAsub

cpreq $DATA/ncepdate $DATAsub/ncepdate

Ref_date=`echo $PDY | cut -c 5-8`$cyc
PDYcycz=$PDY$cyc

##########################################################################
#   EXTRACT EACH PERTURBATION'S DATA AND PLACE IT INTO ITS OWN GRIB1 FILE
#   BEFORE PROCESSING EACH FILE.
##########################################################################

cpreq --preserve=mode,ownership $DCOMIN/DCE${Ref_date}00*001* .

ecmwf_ensemble_list=`ls DCE${Ref_date}00*001*`

for eachfile in $ecmwf_ensemble_list; do

##################################################################
#    CREATE A WGRIB INVENTORY OF THE GRIB1 FILE BEING PROCESSED.
##################################################################
   export pgm=wgrib

   $WGRIB -s -4yr $eachfile > $eachfile.inv 2>errfile
   export err=$?; err_chk

   if [[ $PERT == "0" ]]; then

   # FOR THE CONTROL FORECASTS.

      . prep_step
      startmsg
      grep "Control forecast 0:" < $eachfile.inv | $WGRIB -i $eachfile -grib -o $eachfile.$PERT >> $pgmout 2>errfile
      export err=$?; err_chk

   else

   # FOR THE MEMBER FORECASTS.

      pert=`printf "%01d" $PERT`
      let pert=$pert

      . prep_step
      startmsg
      grep "Perturbed forecast $pert:" < $eachfile.inv | $WGRIB -i $eachfile -grib -o $eachfile.$PERT 2>errfile
      export err=$?; err_chk

   fi

done

######################################################
#   CONCATENATE EACH MEMBER FILE FOR ALL PROJECTIONS.
######################################################

ensfile=`ls DCE${Ref_date}00*.$PERT`
for eachfile in $ensfile; do
   cat $eachfile >> ecmwf_ensemble.${Ref_date}00.$PERT
   chgrp rstprod ecmwf_ensemble.${Ref_date}00.$PERT
   chmod 640 ecmwf_ensemble.${Ref_date}00.$PERT
done

grid=`cat $FIXmdl/mdl_finegds47.grib1`
g1=ecmwf_ensemble.${Ref_date}00.$PERT

$WGRIB $g1 > wgrib.out 2>errfile
export err=$?; err_chk

###############################################
#  RUN COPYGB ON THE NON-PRECIPITATION FIELDS.
###############################################
export pgm=copygb

. prep_step
startmsg
grep -f $FIXmdl/mdl_ecmwf_ensemble_xprecip_wgrib wgrib.out |\
   $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid" -i0 -x $g1 \
   ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT >> $pgmout 2>errfile
export err=$?; err_chk

###########################################
#  RUN COPYGB ON THE PRECIPITATION FIELDS.
###########################################

. prep_step
startmsg
grep -f $FIXmdl/mdl_ecmwf_ensemble_precip_wgrib wgrib.out |\
   $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid" -i3 -x $g1 \
   ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT >> $pgmout 2>errfile
export err=$?; err_chk

##############################
# GET INDICES AND INVENTORY.
##############################

$GRBINDEX ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT.pgrbi 2>errfile
export err=$?; err_chk
chgrp rstprod ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT.pgrbi
chmod 640 ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT.pgrbi

###########################################################
# USING GRIB2TOMDLPK TO CONVERT GRIB2 FILE INTO TDLPACK.
###########################################################
export IOBUF_PARAMS='*:count=4:size=64M:sync'

export pgm=mdl_gribtomdlpk
. prep_step
export FORT10="ncepdate"
export FORT20="ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT"
export FORT21="ecmwf.ensemble.${PDY}${cyc}.pgrb1.$PERT.pgrbi"
export FORT27="mdl_ecmpkd_ensemble.$PERT.$cycle"
export FORT28="$FIXmdl/mdl_ecmens_grbtomdlp.lst"
export FORT29="$FIXmdl/mdl_gridlst"
export FORT30="$FIXmdl/mdl_mos2000id.tbl"
echo MDLLOG: `date` - Program mdl_gribtomdlpk has begun.
startmsg

$EXECmos_shared/mdl_gribtomdlpk < $PARMmdl/mdl_gribtomdlpk.cn >> $pgmout 2>errfile
export err=$?; err_chk

chgrp rstprod mdl_ecmpkd_ensemble.$PERT.$cycle
chmod 640 mdl_ecmpkd_ensemble.$PERT.$cycle
#######################################################################
#    RUN OBSPREP
#    EVEN IF OBS ARE MISSING, WE NEED TO PRODUCE PKOBS FILE
#######################################################################

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
export FORT70="pkobs.$obhr1"
startmsg
$EXECmos_shared/mdl_obsprep < $PARMmdl/mdl_ecmobsprep.cn >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
#!!!NOTE: AN ERROR HERE IS OK; OBS ARE NOT ESSENTIAL TO MOS FORECASTS!!
#
#######################################################################
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH 
#                    CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                    CODE IS USED TO CREATE THE OPERATIONAL MOS
#                    FORECAST FILE.
#######################################################################

echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE

export pgm=mdl_racreate
. prep_step
export FORT50="mdl_ecmmos.$PERT.$cycle"
startmsg
$EXECmos_shared/mdl_racreate < $PARMmdl/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended 

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
export FORT49="mdl_ecmmos.$PERT.$cycle"
startmsg
$EXECmos_shared/mdl_rainit < $PARMmdl/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended 

##############################################################################
#  RUN U202 BECAUSE THE CURRENT PREDICTORS REQUIRE THE 300 MB FIELD WHICH IS 
#  NOT SUPPLIED BY THE ECMWF ENSEMBLE MODEL FILES.
#############################################################################

#echo MDLLOG: `date` - begin job GRIDPOST 
#export pgm=mdl_gridpost
#. prep_step
#export FORT10="ncepdate"
#export FORT24="mdl_ecmpkd_ensemble.$PERT.$cycle"
#export FORT26="$FIXmdl/mdl_station.lst"
#export FORT27="$FIXmdl/mdl_station.tbl"
#export FORT28="$FIXmdl/mdl_ecegrpost.$cycle"
#export FORT29="$FIXmdl/mdl_mos2000id.tbl"
#export FORT20="mdl_ecmmos.$PERT.seq.$cycle"
#startmsg
#$EXECmos_shared/mdl_gridpost < $PARMmdl/mdl_gridpost.cn >> $pgmout 2>errfile
#export err=$?; err_chk
#echo MDLLOG: `date` -  First use of MOSPRED ended

#chgrp rstprod mdl_ecmmos.$PERT.seq.$cycle
#chmod 640 mdl_ecmmos.$PERT.seq.$cycle
#######################################################################
#    FIRST EXECUTION OF PROGRAM MOSPRED 
#    MOSPRED - USED TO INTERPOLATE TO STATIONS FROM TDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
#export FORT23="mdl_ecmmos.$PERT.seq.$cycle"
export FORT24="mdl_ecmpkd_ensemble.$PERT.$cycle"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmensprd.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT44="$FIXmdl/mdl_griddedconstants"
export FORT45="$FIXmdl/mdl_conststa"
export FORT60="ecmmodel.ensemble.${PDY}${cyc}"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmenspredmdl.cn >> $pgmout 2>errfile
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
export FORT80="pkobs.$obhr1"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_ecmprd.obs"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT61="mdl_ecmobs.$cycle"
startmsg
$EXECmos_shared/mdl_mospred < $PARMmdl/mdl_ecmpredobs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  Second use of MOSPRED ended 

#######################################################################
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT23="mdl_ecmobs.$cycle"
export FORT24="ecmmodel.ensemble.${PDY}${cyc}"
export FORT26="$FIXmdl/mdl_station.lst"
export FORT27="$FIXmdl/mdl_station.tbl"
export FORT28="$FIXmdl/mdl_predtofcst"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT30="$FIXmdl/mdl_ecmwind.04010930.$cycle"
export FORT31="$FIXmdl/mdl_ecmwind.10010331.$cycle"
export FORT32="$FIXmdl/mdl_ecmmxmntd84.04010930.$cycle"
export FORT33="$FIXmdl/mdl_ecmmxmntd84.10010331.$cycle"
export FORT36="$FIXmdl/mdl_ecmpopqpf84.04010930.$cycle"
export FORT37="$FIXmdl/mdl_ecmpopqpf84.10010331.$cycle"
export FORT60="$FIXmdl/mdl_ecmxwind.04010930.$cycle"
export FORT61="$FIXmdl/mdl_ecmxwind.10010331.$cycle"
export FORT62="$FIXmdl/mdl_ecmxmxmntd.04010930.$cycle"
export FORT63="$FIXmdl/mdl_ecmxmxmntd.10010331.$cycle"
export FORT64="$FIXmdl/mdl_ecmxpopqpf.04010930.$cycle"
export FORT65="$FIXmdl/mdl_ecmxpopqpf.10010331.$cycle"
export FORT49="mdl_ecmmos.$PERT.$cycle"
startmsg
$EXECmos_shared/mdl_eqneval < $PARMmdl/mdl_ecmenseval.cn.$cycle >> $pgmout 2>errfile
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
export FORT28="$FIXmdl/mdl_ecmenspost.$cycle"
export FORT29="$FIXmdl/mdl_mos2000id.tbl"
export FORT45="$FIXmdl/mdl_conststa"
export FORT47="$FIXmdl/mdl_threshold"
export FORT49="mdl_ecmmos.$PERT.$cycle"
export FORT50="mdl_ecmmos.$PERT.$cycle.seq"
startmsg
$EXECmos_shared/mdl_fcstpost < $PARMmdl/mdl_ecmpost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

PERT_STR=`printf "%02d" $PERT`

##################################################################################
#   CHANGE DD'S SO THAT A MEAN VALUE CAN BE CALCULATED FOR SELECTED 
#   WEATHER ELEMENTS.
###################################################################################

echo MDLLOG: `date` - begin util script itdlp  
export pgm=itdlp
. prep_step
export FORT20="mdl_ecmmos.${PERT}.${cycle}.seq"
export FORT21="mdl_ecmmos.${PERT}.${cycle}.seq.newid"
startmsg

$EXECmos_shared/itdlp $FORT20 -change-dd 01 ${PERT_STR} -tdlp $FORT21 >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG: `date` - itdlp ended

##################################################################################
#  PLACE THE SEQUENTIAL TDLPACK FILE WITH THE NEW DD VALUE (CORRESPONDING TO THE 
#  PETURBATION NUMBER) INTO A COMMON DIRECTORY FOR FURTHER PROCESSING.
##################################################################################

cpreq mdl_ecmmos.${PERT}.$cycle.seq.newid $COMOUT/.

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job execemos_stnfcst.sh.ecf has ended.

exit 0
