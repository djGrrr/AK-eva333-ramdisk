#!/sbin/sh

# allow play store apps that require usb host
if ! ( grep -q ro.usb.host=1 /system/build.prop ); then
	echo Modifying /system/build.prop...
	echo ro.usb.host=1 >> /system/build.prop
fi

# workaround to allow writing to usb drives
perm_begin=$(grep -n -m 1 'WRITE_EXTERNAL_STORAGE" >' /system/etc/permissions/platform.xml | cut -d: -f1)
perm_end=$(tail -n +$perm_begin /system/etc/permissions/platform.xml | grep -n -m 1 '</permission>' | cut -d: -f1)
tail -n +$perm_begin /system/etc/permissions/platform.xml | head -n $perm_end | grep '<group gid="media_rw" />' > /dev/null
if [ $? -gt 0 ]; then
	if ! [ -f /system/etc/permissions/platform.xml.1 ]; then
		echo Creating backup /system/etc/permissions/platform.xml.1...
		cp /system/etc/permissions/platform.xml /system/etc/permissions/platform.xml.1
	fi
	echo Modifying /system/etc/permissions/platform.xml...
	sed -e '/WRITE_EXTERNAL_STORAGE" >$/N;s/\n\(\([ \t]*\)<group gid="sdcard_rw".*$\)/\n\2<group gid="media_rw" \/>\n\1/' -i /system/etc/permissions/platform.xml
fi

# patch precompiled storage_list.xml and inject to framework-res.apk for settings->storage->usb storage
if ! [ -f /system/framework/framework-res.apk.1 ]; then
	echo Creating backup /system/framework/framework-res.apk.1...
	cp /system/framework/framework-res.apk /system/framework/framework-res.apk.1
fi
cd /tmp/otgmod
echo Modifying /system/framework/framework-res.apk...
cp /system/framework/framework-res.apk.1 .
./zip -Fq framework-res.apk.1 --out framework-res.apk
unzip -q framework-res.apk resources.arsc
unzip -p framework-res.apk res/xml/storage_list.xml > storage_list.xml

internal=$(od -x storage_list.xml | cut -b 13-72 | tr '\n' ' ' | sed "s/ //g" | grep -o '00080100....' | head -n 1 | cut -b 9-12)
internala=$(echo $internal | cut -b 1-2)
internalb=$(echo $internal | cut -b 3-4)

internala_dec=$(printf "%d" 0x$internala)
internalb_dec=$(printf "%d" 0x$internalb)
dist_dec=$(strings resources.arsc | sed '/^storage_internal/,/storage_usb$/!d' | wc -l)
dist_dec=`expr $dist_dec - 1`
usbb_dec=`expr $internalb_dec + $dist_dec`

if [ "$usbb_dec" -gt "255" ]; then
	usba_dec=`expr $internala_dec + 1`
	usbb_dec=`expr $usbb_dec - 256`
else
	usba_dec=$internala_dec
fi

usba=$(printf "%x" $usba_dec)
usbb=$(printf "%x" $usbb_dec)

printf "\x$internalb\x$internala" | dd of=res/xml/storage_list.xml bs=1 seek=412 count=2 conv=notrunc > /dev/null 2>&1
printf "\x$usbb\x$usba" | dd of=res/xml/storage_list.xml bs=1 seek=572 count=2 conv=notrunc > /dev/null 2>&1

./zip -r /system/framework/framework-res.apk res

# cleanup
cd ..
rm -rf otgmod

exit 0
