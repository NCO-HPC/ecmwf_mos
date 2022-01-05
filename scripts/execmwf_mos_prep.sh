#!/bin/sh
#######################################################################
#  Purpose: To extract multiple parameters from the ECMWF deterministic 
#           model output GRIB file for one projection and interpolate 
#           the parameters to MDL's fine grid. Uses wgrib and copygb
#           utilities.
#
#     Dave Rudack:  August 8, 2013 - Adopted from GFS Prep Scripts that
#                                    were transitioned to WCOSS (Linux).
#  Scott Scallion:  Sept.  9, 2016 - Added error checking to grib 
#                                    utilities.
#######################################################################

cd $DATA

########################################
set -x
msg="Begin job for $job"
postmsg "$jlogfile" "$msg"
########################################

echo MDLLOG: `date` - Begin execmmos_prep.sh.ecf 47km

Ref_date=`echo $PDY | cut -c 5-8`$cyc
PDYcycz=$PDY$cyc

#######################################################################
# LOOP THROUGH PROJECTIONS (0 to 96 hours at 6-hour intervals)
#######################################################################
for tau in $(seq -f "%02g" 0 6 96)
do
#######################################################################
#     CALCULATE THE VALID DATA AND TIME OF THE PARTICULAR PROJECTION
#     BEING PROCESSED.
#######################################################################

   Valid_date=`$NDATE +${tau} ${PDYcycz}`
   Valid_time=`echo $Valid_date | cut -c5-10`

   grid47=`cat $FIXmdl/mdl_finegds47.grib1`
   g1=$DCOMIN/DCD${Ref_date}00${Valid_time}001

   $WGRIB $g1 > wgrib.out 2>errfile
   export err=$?; err_chk

   export pgm=copygb

   . prep_step
   startmsg
   grep -f $FIXmdl/mdl_ecmwf_xprecip_wgrib wgrib.out |\
      $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid47" -i0 -x $g1 \
      mdl_ecmwf.${cyc}z.pgrb1.f${tau} >> $pgmout 2>errfile
   export err=$?; err_chk

   # Run copygb on the precipitation fields.

   . prep_step
   startmsg
   grep -f $FIXmdl/mdl_ecmwf_precip_wgrib wgrib.out |\
      $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid47" -i3 -x $g1 \
      mdl_ecmwf.${cyc}z.pgrb1.f${tau} >> $pgmout 2>errfile
   export err=$?; err_chk

   chgrp rstprod mdl_ecmwf.${cyc}z.pgrb1.f${tau}
   chmod 640 mdl_ecmwf.${cyc}z.pgrb1.f${tau}
done

###################################################################################
#  CAT ALL THE GRIB1 FILES SO THAT IT CAN BE TURNED INTO A TDLPACK SEQUENTIAL FILE.
###################################################################################

cat mdl_ecmwf.${cyc}z.pgrb1.f* >> mdl_xpcp+pcp.$cycle.pgrb

#######################################################################
# GET INDICES AND INVENTORY
#######################################################################

$GRBINDEX mdl_xpcp+pcp.$cycle.pgrb mdl_xpcp+pcp.$cycle.pgrbi 2>errfile
export err=$?; err_chk
chgrp rstprod mdl_xpcp+pcp.$cycle.pgrb mdl_xpcp+pcp.$cycle.pgrbi
chmod 640 mdl_xpcp+pcp.$cycle.pgrb mdl_xpcp+pcp.$cycle.pgrbi

#######################################################################
# USING GRIB2TOMDLPK TO CONVERT GRIB2 FILE INTO TDLPACK (DD=06).
#######################################################################

export pgm=mdl_gribtomdlpk
. prep_step
export FORT10="ncepdate"
export FORT20="mdl_xpcp+pcp.$cycle.pgrb"
export FORT21="mdl_xpcp+pcp.$cycle.pgrbi"
export FORT27="mdl_ecmpkd.$cycle"
export FORT28="$FIXmdl/mdl_ecmprep47_grbtomdlp.lst"
export FORT29="$FIXmdl/mdl_gridlst"
export FORT30="$FIXmdl/mdl_mos2000id.tbl"
echo MDLLOG: `date` - Program mdl_gribtomdlpk has begun.
startmsg

$EXECmos_shared/mdl_gribtomdlpk < $PARMmdl/mdl_gribtomdlpk.cn >> $pgmout 2>errfile
export err=$?; err_chk

chgrp rstprod mdl_ecmpkd.$cycle
chmod 640 mdl_ecmpkd.$cycle
#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq --preserve=mode,ownership mdl_ecmpkd.$cycle $COMOUT/mdl_ecmpkd.$cycle
  cpreq --preserve=mode,ownership mdl_xpcp+pcp.$cycle.pgrb $COMOUT
  cpreq --preserve=mode,ownership mdl_xpcp+pcp.$cycle.pgrbi $COMOUT
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job execmmos_prep.sh.ecf 47km has ended.

#######################################################################
