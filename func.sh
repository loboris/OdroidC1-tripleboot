
#------------------------------------------------------------------------------------
map_image() {
	kpartx -l ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR testing kpartx"
		return 1
	fi
	loop_dev=`kpartx -l $sdcard | grep 49152 | sed s/"\// "/g | awk '{print $6}'`
	loop_mapp="/dev/mapper/${loop_dev}p"
        sleep 1
	kpartx -a -s ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR mapping with kpartx"
		kpartx -d -s ${sdcard} > /dev/null 2>&1
		dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
		losetup -d /dev/${loop_dev} > /dev/null 2>&1
		return 1
	fi
	sleep 1
}
#------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------
unmap_image() {
        sync
        sleep 1
	kpartx -d -s ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR unmapping with kpartx"
		dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
		losetup -d /dev/${loop_dev} > /dev/null 2>&1
		return 1
	fi
	dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
	losetup -d /dev/${loop_dev} > /dev/null 2>&1
	return 0
}
#------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------
format_image_part() {
	kpartx -l ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR testing kpartx"
		return 1
	fi
	loop_dev=`kpartx -l $sdcard | grep 49152 | sed s/"\// "/g | awk '{print $6}'`
	loop_mapp="/dev/mapper/${loop_dev}p${1}"
        sleep 1
        
	kpartx -a -s ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR mapping with kpartx"
		return 1
	fi
        sleep 1
	
	if [ "${2}" = "vfat" ]; then
		mkfs -t $2 -n $3 ${loop_mapp} > /dev/null 2>&1
	elif [ "${2}" = "btrfs" ]; then
	    mkfs.btrfs -f -L $3 ${loop_mapp} > /dev/null 2>&1
	elif [ "${2}" = "ext4" ]; then
	    mkfs -F -t ext4 -L $3 ${loop_mapp} > /dev/null 2>&1
	elif [ "${2}" = "swap" ]; then
	    mkswap -L $3 ${loop_mapp} > /dev/null 2>&1
	else
	    echo "WRONG FORMAT TYPE $2."
	fi
	if [ $? -ne 0 ]; then
		echo "ERROR formating $3 partition."
		kpartx -d -s ${sdcard} > /dev/null 2>&1
		dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
		losetup -d /dev/${loop_dev} > /dev/null 2>&1
		return 1
	fi
	sync
	sleep 1
	
	kpartx -d -s ${sdcard} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR unmapping with kpartx"
		dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
		losetup -d /dev/${loop_dev} > /dev/null 2>&1
		return 1
	fi
	sleep 1
	dmsetup remove /dev/mapper/${loop_dev}p* > /dev/null 2>&1
	losetup -d /dev/${loop_dev} > /dev/null 2>&1
	return 0
}
#------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------
check_sdcard() {
    _isimage="no"
    _ddopt=""
    if [ -b $sdcard ]; then
	# we are working with block device
	# Test if requested drive is removable
	ISREMOVABLE=`udevadm info -a -n ${sdcard} | grep -o "ATTR{removable}==\"1\""`
	if [ ! "${ISREMOVABLE}" = "ATTR{removable}==\"1\"" ] ; then
		echo "${sdcard} IS NOT REMOVABLE DRIVE !, Exiting."
		return 1
	fi

	local _sdok=`fdisk -l $sdcard  2> /dev/null | grep Disk`
	if [ "$_sdok" = "" ]; then
		echo "${sdcard} NOT FOUND !, Exiting."
		return 1
	fi
    else
	if [ "${1}" = "noimage" ]; then
	    echo "${sdcard} NOT FOUND !, Exiting."
	    return 1
	fi	
	if [ ! -f $sdcard ]; then
	    # image file does not exist
	    if [ "${1}" = "create" ]; then
		echo -n "${sdcard} NOT FOUND !, Create image file (y/N)? "
		read -n 1 ANSWER

		if [ ! "${ANSWER}" = "y" ] ; then
		    echo "."
		    echo "Canceled.."
		    return 2
		fi
		echo ""
		echo ""
		echo "Creating sdcard image file..."
		dd if=/dev/zero of=${sdcard} bs=1M count=${sdcard_size} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "${sdcard} NOT FOUND !, Exiting."
			return 1
		fi
	    else
		echo "${sdcard} NOT FOUND !, Exiting."
		return 1
	    fi
	fi
	# we are working with image file
	_isimage="yes"
	_ddopt="conv=notrunc"
	return 0
    fi
}
#------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------
check_bootfiles() {
    if [ ! -f $bkpdir/bl1.img ] || [ ! -f $bkpdir/u-boot.img ] \
	    || [ ! -f $bkpdir/u-boot-env.img ] || [ ! -f $bkpdir/dtb.img ]\
	    || [ ! -f $bkpdir/boot.img ] || [ ! -f $bkpdir/recovery.img ]\
	    || [ ! -f $bkpdir/logo.img ] || [ ! -f $bkpdir/reserved.img ]; then
	    echo "Boot files not found in $bkpdir !"
	    return 1
    else
	    return 0
    fi
}
#------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------
write_uboot_section() {
    echo "Saving android boot section ..."
    # BL1 / MBR
    dd of=${sdcard} if=$bkpdir/bl1.img bs=1 count=442 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing bl1."
	return 1
    fi
    sync
    dd of=${sdcard} if=$bkpdir/bl1.img bs=512 skip=1 seek=1 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing bl1."
	return 1
    fi
    sync

    # U-Boot
    dd of=${sdcard} if=$bkpdir/u-boot.img bs=512 seek=64 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing u-boot."
	return 1
    fi
    sync

    # U-Boot Environment
    dd of=${sdcard} if=$bkpdir/u-boot-env.img bs=512 skip=1024 count=64 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing u-boot."
	return 1
    fi
    sync

    # DTB
    dd of=${sdcard} if=$bkpdir/dtb.img bs=512 seek=1088 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing dtb."
	return 1
    fi
    sync

    # BOOT
    dd of=${sdcard} if=$bkpdir/boot.img bs=512 seek=1216 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing boot."
	return 1
    fi
    sync

    # RECOVERY
    dd of=${sdcard} if=$bkpdir/recovery.img bs=512 seek=17600 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing recovery."
	return 1
    fi
    sync

    # LOGO
    dd of=${sdcard} if=$bkpdir/logo.img bs=512 seek=33984 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing logo."
	return 1
    fi
    sync

    # RESERVED
    dd of=${sdcard} if=$bkpdir/reserved.img bs=512 seek=46272 $_ddopt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR installing reserved."
	return 1
    fi
    sync
    return 0
}
#------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------
read_uboot_section() {
    # BL1 / MBR
    dd if=${sdcard} of=${bkpdir}/bl1.img bs=512 count=64 > /dev/null 2>&1

    # U-Boot
    dd if=${sdcard} of=${bkpdir}/u-boot.img bs=512 skip=64 count=960 > /dev/null 2>&1

    # U-Boot Environment
    dd if=${sdcard} of=${bkpdir}/u-boot-env.img bs=512 skip=1024 count=64 > /dev/null 2>&1

    # DTB
    dd if=${sdcard} of=${bkpdir}/dtb.img bs=512 skip=1088 count=128 > /dev/null 2>&1

    # BOOT
    dd if=${sdcard} of=${bkpdir}/boot.img bs=512 skip=1216 count=16384 > /dev/null 2>&1

    # LOGO
    dd if=${sdcard} of=${bkpdir}/logo.img bs=512 skip=33984 count=12288 > /dev/null 2>&1

    # RECOVERY
    dd if=${sdcard} of=${bkpdir}/recovery.img bs=512 skip=17600 count=16384 > /dev/null 2>&1

    # RESERVED
    dd if=${sdcard} of=${bkpdir}/reserved.img bs=512 skip=46272 count=2880 > /dev/null 2>&1
    sync
    return 0
}
#------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------
get_partstruct() {
    echo ""
    echo "Analyzing sd card ..."
    ncache="4"

    dualb=`fdisk -l $sdcard | grep ${sdcard}5 | awk '{print $2}'`

    # Calculate partitions offsets and sizes
    sdcard_part=`fdisk -l $sdcard | grep Linux | awk '{print $1}'`
    sdcard_sect=`fdisk -l $sdcard | grep "Disk $sdcard" | awk '{print $7}'`
    if [ "${sdcard_sect}" = "" ]; then
	sdcard_sect=`fdisk -l $sdcard | grep total | awk '{print $8}'`
    fi
    sdcard_end=$(expr $sdcard_sect - 1024)

    storage_start=`fdisk -l $sdcard | grep ${sdcard}1 | awk '{print $2}'`
    storage_end=`fdisk -l $sdcard | grep ${sdcard}1 | awk '{print $3}'`
    storage_size=$(( ($storage_end - $storage_start + 1) / 2048 ))
    kstorage_size=$(( ($storage_end - $storage_start + 1) / 2 ))

    system_start=`fdisk -l $sdcard | grep ${sdcard}2 | awk '{print $2}'`
    system_end=`fdisk -l $sdcard | grep ${sdcard}2 | awk '{print $3}'`
    system_size=$(( ($system_end - $system_start + 1) / 2048 ))
    ksystem_size=$(( ($system_end - $system_start + 1) / 2 ))

    userdata_start=`fdisk -l $sdcard | grep ${sdcard}3 | awk '{print $2}'`
    userdata_end=`fdisk -l $sdcard | grep ${sdcard}3 | awk '{print $3}'`
    userdata_size=$(( ($userdata_end - $userdata_start + 1) / 2048 ))
    kuserdata_size=$(( ($userdata_end - $userdata_start + 1) / 2 ))

    if [ "${dualb}" = "" ]; then
	    cache_start=`fdisk -l $sdcard | grep ${sdcard}4 | awk '{print $2}'`
	    cache_end=`fdisk -l $sdcard | grep ${sdcard}4 | awk '{print $3}'`
    else
	    cache_start=`fdisk -l $sdcard | grep ${sdcard}5 | awk '{print $2}'`
	    cache_end=`fdisk -l $sdcard | grep ${sdcard}5 | awk '{print $3}'`
	    
	    oelec_start=`fdisk -l $sdcard | grep ${sdcard}6 | awk '{print $2}'`
	    oelec_end=`fdisk -l $sdcard | grep ${sdcard}6 | awk '{print $3}'`
	    oelec_size=$(( ($oelec_end - $oelec_start + 1) / 2048 ))
	    koelec_size=$(( ($oelec_end - $oelec_start + 1) / 2 ))

	    linux_start=`fdisk -l $sdcard | grep ${sdcard}7 | awk '{print $2}'`
	    linux_end=`fdisk -l $sdcard | grep ${sdcard}7 | awk '{print $3}'`
	    linux_size=$(( ($linux_end - $linux_start + 1) / 2048 ))
	    klinux_size=$(( ($linux_end - $linux_start + 1) / 2 ))
	    ncache="5"
    fi
    cache_size=$(( ($cache_end -$cache_start + 1) / 2048 ))
    kcache_size=$(( ($cache_end -$cache_start + 1) / 2 ))

    echo ""
    echo "  SDCard size: $sdcard_sect blocks, $(expr $sdcard_sect / 2048 ) M"
    echo "------------------------------------------------"
    printf "%26s" "first block"; printf "%12s" "last block"; printf "%10s\n" "size"
    printf "%14s" "storage part:"; printf "%12s" $storage_start; printf "%12s" $storage_end; printf "%10s\n" "$storage_size M"
    printf "%14s" "system part:"; printf "%12s" $system_start; printf "%12s" $system_end; printf "%10s\n" "$system_size M"
    printf "%14s" "userdata part:"; printf "%12s" $userdata_start; printf "%12s" $userdata_end; printf "%10s\n" "$userdata_size M"
    printf "%14s" "cache part:"; printf "%12s" $cache_start; printf "%12s" $cache_end; printf "%10s\n" "$cache_size M"
    if [ ! "${dualb}" = "" ]; then
	if [ ! "${skip_OpenELEC}" = "yes" ]; then
	    printf "%14s" "OpenELEC part:"; printf "%12s" $oelec_start; printf "%12s" $oelec_end; printf "%10s\n" "$oelec_size M"
	else
	    printf "%14s" "swap part:"; printf "%12s" $oelec_start; printf "%12s" $oelec_end; printf "%10s\n" "$oelec_size M"
	fi
	printf "%14s" "linux part:"; printf "%12s" $linux_start; printf "%12s" $linux_end; printf "%10s\n" "$linux_size M"
    fi
    echo "------------------------------------------------"
    echo ""
}
#------------------------------------------------------------------------------------
