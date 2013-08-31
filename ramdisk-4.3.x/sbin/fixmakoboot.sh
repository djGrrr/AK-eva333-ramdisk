#!/sbin/bb/busybox sh
#
# AK Boot Configurations
# Anarkia1976
#

bb=/sbin/bb/busybox;

# Stop mpDecision at boot
stop mpdecision

$bb mount -o rw,remount /system;

# Enable Snake Charmer at boot - Limit Max Freq
#$bb insmod /system/lib/modules/cpufreq_limit.ko

# create init.d folder
if [ ! -d /system/etc/init.d ]; then
  $bb echo "Making Init.d Directory ...";
  $bb mkdir /system/etc/init.d;
  $bb chown -R root.root /system/etc/init.d;
  $bb chmod -R 755 /system/etc/init.d;
else
 $bb echo "Init.d Directory Exist ...";
fi;

$bb mount -o ro,remount /system;

# set cgroup_timer_slack for bg_non_interactive tasks
$bb echo 100000000 > /dev/cpuctl/apps/bg_non_interactive/timer_slack.min_slack_ns
$bb echo 91 > /dev/cpuctl/apps/bg_non_interactive/cpu.shares
$bb echo 400000 > /dev/cpuctl/apps/bg_non_interactive/cpu.rt_runtime_us

# disable sysctl.conf to prevent ROM interference
if [ -e /system/etc/sysctl.conf ]; then
  $bb mount -o remount,rw /system;
  $bb mv /system/etc/sysctl.conf /system/etc/sysctl.conf.fkbak;
  $bb mount -o remount,ro /system;
fi;

# disable debugging
echo "0" > /sys/module/wakelock/parameters/debug_mask;
echo "0" > /sys/module/userwakelock/parameters/debug_mask;
echo "0" > /sys/module/earlysuspend/parameters/debug_mask;
echo "0" > /sys/module/alarm/parameters/debug_mask;
echo "0" > /sys/module/alarm_dev/parameters/debug_mask;
echo "0" > /sys/module/binder/parameters/debug_mask;

# vm tweaks
echo 2884 > /proc/sys/vm/min_free_kbytes;
echo 4 > /proc/sys/vm/min_free_order_shift;
echo 3 > /proc/sys/vm/page-cluster;
echo 100 > /proc/sys/vm/vfs_cache_pressure;
echo 1 > /proc/sys/vm/overcommit_memory

# lmk tweaks
minfree=6144,8192,12288,16384,24576,40960;
lmk=/sys/module/lowmemorykiller/parameters/minfree;
minboot=`cat $lmk`;
while sleep 1; do
  if [ `cat $lmk` != $minboot ]; then
    [ `cat $lmk` != $minfree ] && echo $minfree > $lmk || exit;
  fi;
done&

# fs tweaks
echo 10 > /proc/sys/fs/lease-break-time;

# entropy tweaks
echo 128 > /proc/sys/kernel/random/read_wakeup_threshold;
echo 256 > /proc/sys/kernel/random/write_wakeup_threshold;

# general queue tweaks
for i in /sys/block/*/queue; do
  echo 128 > $i/read_ahead_kb;
  echo 0 > $i/iostats
  echo 0 > $i/nomerges;
  echo 0 > $i/rotational;
done;

$bb echo 0 > /sys/block/mmcblk0/queue/add_random
$bb echo 256 > /sys/block/mmcblk0/queue/max_sectors_kb
$bb echo 256 > /sys/block/mmcblk0/queue/nr_requests
$bb echo 256 > /sys/block/mmcblk0/queue/read_ahead_kb
$bb echo 2 > /sys/block/mmcblk0/queue/rq_affinity

# wait for systemui and increase its priority
while $bb sleep 1; do
  if [ `$bb pidof com.android.systemui` ]; then
    systemui=`pidof com.android.systemui`;
    $bb renice -18 $systemui;
    $bb echo -17 > /proc/$systemui/oom_adj;
    $bb chmod 100 /proc/$systemui/oom_adj;
    exit;
  fi;
done&

# lmk whitelist for common launchers and increase launcher priority
list="com.android.launcher org.adw.launcher org.adwfreak.launcher com.anddoes.launcher com.android.lmt com.chrislacy.actionlauncher.pro com.cyanogenmod.trebuchet com.gau.go.launcherex com.mobint.hololauncher com.mobint.hololauncher.hd com.teslacoilsw.launcher com.tsf.shell org.zeam";
while $bb sleep 60; do
  for class in $list; do
    if [ `$bb pgrep $class` ]; then
      launcher=`$bb pgrep $class`;
      $bb echo -17 > /proc/$launcher/oom_adj;
      $bb chmod 100 /proc/$launcher/oom_adj;
      $bb renice -18 $launcher;
    fi;
  done;
  exit;
done&
