Prepare Odroid-C1 tripleboot SDCard/Image
=========================================

- Script(s) must be run on Linux PC, tested on Ubuntu 14.04, 14.10, 15.04.
- to work with sd card images you must have kpartx installed (`sudo apt-get install kpartx`)
- to prepare OpenElec por triple boot must have u-boot-tools installed (`sudo apt-get install u-boot-tools`)

You will need:

- working Android SD Card (odroid Self-installation Image after initialization)
- Linux SD Card or image.
- OpenElec sd card or image.

**BUILDING PROCEDURE:**

Extract Android:

- Insert Odroid-C1 Android sd card into USB reader
- Change directory to the script directory
- Edit "params.sh", set your sdcard block device (/dev/sdX) and desired output directory
- Run the script: `sudo ./extract_android`
- This will extract android u-boot section and system, userdata, cache and storage partitions to your output directory.

Extract Linux (Ubuntu/Debian):

- You can skip this step, and create only dualboot Android/OpenELEC sd card if you want.
- If you also skip OpenELEC you will have only Android, without multiboot.
- Insert Odroid-C1 Linux sd card into USB reader if not using sd card image
- Change directory to the script directory
- Edit "params.sh", set your sdcard block device (/dev/sdX) or image name and desired output directory
- Run the script: `sudo ./extract_linux`
- This will extract fat and linux (ext4) partitions to your output directory.

Extract OpenELEC:

- You can skip this step, and create only dualboot Android/Linux sd card if you want.
- If you also skip Linux you will have only Android, without multiboot.
- Insert OpenElec sd card into USB reader if not using sd card image (recommended)
- Change directory to the script directory
- Edit "params.sh", set your sdcard block device (/dev/sdX) or image name and desired output directory
- Run the script: `sudo ./extract_openelec`
- This will extract OpenELEC partitions to your output directory and prepare them for triple-boot.

Prepare SD Card:

- Insert SD Card to be used for triple boot (or prepare sdcard image)
- SD card must be at least 8 GB (4 GB is enough for minimal linux/android system).
- Edit "params.sh", set your sdcard block device (/dev/sdX) or image file name, source directory and desired partition sizes.
- "linux" partition will allways be extended to the end of sd card (remaining space after allocating android and OpenElec partitions)
- You can set option to format linux partition as btrfs. Partition will be mounted with compress option and you can save up to 40% in sd card space.
- If you want to create dual boot Android/Linux, set skip_OpenELEC to "yes"
- Run the script: `sudo ./create_tripleboot_sd`
- It is possible to create sd card image, instead to format physical sd card.

New partition layout is now:

- storage (android internal sdcard) (mmcblk0p1)
- system (mmcblk0p2)
- userdata (mmcblk0p3)
- EXTENDED PARTITION
- cache (mmcblk0p5)
- openElec (mmcblk0p6)
- linux (mmcblk0p7)

After sd card is created, you can edit bootandroid.ini, bootlinux.ini and bootoelec.ini in STORAGE partition to se desired boot parameters (resolution, UHS, etc)

Copy (restore) saved Android/linux/openElec partitions to sd card:

- Edit "params.sh", set your sdcard block device (/dev/sdX) or image file name and source directory
- Run the script: `sudo ./copy_to_sdcard`
- It is possible to write to the card image, instead to sd card.

Your sd card is now ready for triple boot Android/Linux/OpenELEC on your Odroid-C1.

**Notes:**

- boot.ini, uImage, uInitrd and meson8b_odroidc.dtb (from linux directory) and OpenELEC files will be placed on your storage (android internal sdcard) partition (mmcblk0p1, FAT32)
- fstab.odroidc in android system partition will be modified to enable cache partition mounting from partition mmcblk0p5
- boot.ini will be created in a way to enable boot menu and booting from linux partition mmcblk0p6
- storage partition (android internal sdcard) is accessible under linux in /media/android
- on boot you are presented with boot menu to select boot to android, linux or OpenELEC (if used)
- edit bootsel.ini to select your default OS and boot timeout
- you can mount linux partition (mmcblk0p7) from android, but it is not default
- You can upgrade OpenElec simply by coppying SYSTEM, INITRD & KERNEL files from OpenELEC upgrade package to STORAGE (FAT32) partition
- First sd card partition is FAT32 formated and is readable under windows
- If your SD Card is large enough (16 or 32 GB) the scripts can be easily adapted to boot android + more the one linux instalation !
- **WARNING:** do not delete any of the files in the root of the FAT (STORAGE) partition !
- After upgrading linux kernel, don't forget to copy uImage, uInitrd and meson8b_odroidc.dtb to /media/android (FAT partition)

**Additional scripts:**

- "update_uboot" to update android boot section (u-boot and others) without erasing sd card
- "backup_from_sdcard" to backup your sd card to directory
- "restore_to_sdcard" to restore your sd card from backup
- You can use backup/restore scripts to move your installation to larger/smaller sd card or to change partitions sizes.

