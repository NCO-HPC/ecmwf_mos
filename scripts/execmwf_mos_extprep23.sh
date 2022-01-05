#!/bin/sh
#######################################################################
#  Purpose: To extract multiple parameters from the ECMWF deterministic 
#           model output GRIB file for one projection and interpolate 
#           the parameters to MDL's fine grid. Uses wgrib and copygb
#           utilities.
#
#     Dave Rudack:  August 8, 2013 - Adopted from GFS Prep Scripts that
#                                    were transitioned to WCOSS (Linux).
#  Scott Scallion:  Sept. 22, 2016 - Only loop through available 
#                                    projections passed from J-Job.
#######################################################################

cd $DATA

########################################
set -x
msg="Begin job for $job"
postmsg "$jlogfile" "$msg"
########################################

echo MDLLOG: `date` - Begin execmmos_extprep23.sh.ecf

Ref_date=`echo $PDY | cut -c 5-8`$cyc
PDYcycz=$PDY$cyc

#######################################################################
# LOOP THROUGH PROJECTIONS (99 to 144 at 3-hour intervals and 150 to 240 at 6-hour intervals)
#######################################################################
for tau in $foundproj
do
#######################################################################
#     CALCULATE THE VALID DATA AND TIME OF THE PARTICULAR PROJECTION 
#     BEING PROCESSED.
#######################################################################

   Valid_date=`$NDATE +${tau} ${PDYcycz}`
   Valid_time=`echo $Valid_date | cut -c5-10`

   grid=`cat $FIXmdl/mdl_finegds23.grib1`
   if [ "$tau" != "00" ]; then
      g1=$DCOMIN/U1D${Ref_date}00${Valid_time}001
   else
      g1=$DCOMIN/U1D${Ref_date}00${Valid_time}011
   fi
   g1_nogrib2=`basename $g1`
   g1_nogrib2=${g1_nogrib2}.nogrib2

   $WGRIB $g1 > wgrib.out 2>errfile
   export err=$?; err_chk
   cat wgrib.out | $WGRIB -i $g1 -grib -o $g1_nogrib2
   export err=$?; err_chk

   export pgm=copygb
   if [ "$tau" != "00" ]; then
      . prep_step
      startmsg
      grep -f $FIXmdl/mdl_ecmwf_xprecip_wgrib wgrib.out |\
         $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid" -i0 -x $g1_nogrib2 \
         mdl_ecmwf.${cyc}z.pgrb1.f${tau} >> $pgmout 2>errfile
      export err=$?; err_chk
   else
      . prep_step
      startmsg
      grep -f $FIXmdl/mdl_ecmwf_xprecip_analysis_wgrib wgrib.out |\
         $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid" -i0 -x $g1_nogrib2 \
         mdl_ecmwf.${cyc}z.pgrb1.f${tau} >> $pgmout 2>errfile
      export err=$?; err_chk
   fi

   # Run copygb on the precipitation fields.

   if [ "$tau" != "00" ]; then
      . prep_step
      startmsg
      grep -f $FIXmdl/mdl_ecmwf_precip_wgrib wgrib.out |\
         $COPYGB -a -N $FIXmdl/mdl_namelist -kw -g"$grid" -i3 -x $g1_nogrib2 \
         mdl_ecmwf.${cyc}z.pgrb1.f${tau} >> $pgmout 2>errfile
      export err=$?; err_chk
   fi

   chgrp rstprod mdl_ecmwf.${cyc}z.pgrb1.f${tau}
   chmod 640 mdl_ecmwf.${cyc}z.pgrb1.f${tau}
done

###################################################################################
#  CAT ALL THE GRIB1 FILES SO THAT IT CAN BE TURNED INTO A TDLPACK SEQUENTIAL FILE.
###################################################################################

cat mdl_ecmwf.${cyc}z.pgrb1.f* >> mdl_xpcp+pcpx.$cycle.pgrb

#######################################################################
# GET INDICES AND INVENTORY
#######################################################################

$GRBINDEX mdl_xpcp+pcpx.$cycle.pgrb mdl_xpcp+pcpx.$cycle.pgrbi 2>errfile
export err=$?; err_chk
chgrp rstprod mdl_xpcp+pcpx.$cycle.pgrb mdl_xpcp+pcpx.$cycle.pgrbi
chmod 640 mdl_xpcp+pcpx.$cycle.pgrb mdl_xpcp+pcpx.$cycle.pgrbi

#######################################################################
# USING GRIBTOMDLPK TO CONVERT GRIB FILE INTO TDLPACK.
#######################################################################

export pgm=mdl_gribtomdlpk
. prep_step
export FORT10="ncepdate"
export FORT20="mdl_xpcp+pcpx.$cycle.pgrb"
export FORT21="mdl_xpcp+pcpx.$cycle.pgrbi"
export FORT27="mdl_ecmxpkd23.$cycle"
export FORT28="$FIXmdl/mdl_ecmxprep23_grbtomdlp.lst"
export FORT29="$FIXmdl/mdl_gridlst"
export FORT30="$FIXmdl/mdl_mos2000id.tbl"
echo MDLLOG: `date` - Program mdl_gribtomdlpk has begun.
startmsg

$EXECmos_shared/mdl_gribtomdlpk < $PARMmdl/mdl_gribtomdlpk.cn >> $pgmout 2>errfile
export err=$?; err_chk

chgrp rstprod mdl_ecmxpkd23.$cycle
chmod 640 mdl_ecmxpkd23.$cycle
#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpreq --preserve=mode,ownership mdl_ecmxpkd23.$cycle $COMOUT/mdl_ecmxpkd23.$cycle
  cpreq --preserve=mode,ownership mdl_xpcp+pcpx.$cycle.pgrb $COMOUT/mdl_xpcp+pcpx_23km.$cycle.pgrb
  cpreq --preserve=mode,ownership mdl_xpcp+pcpx.$cycle.pgrbi $COMOUT/mdl_xpcp+pcpx_23km.$cycle.pgrbi
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job execmmos_extprep23.sh.ecf has ended.

#######################################################################
