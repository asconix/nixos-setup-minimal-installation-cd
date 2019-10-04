# NixOS 19.09beta minimal custom installer

This repository contains a build script that creates a custom NixOS installation ISO image. Here we already use NixOS 19.09 beta in production since (at the time of writing which is 4th October 2019) it is predictable that NixOS 19.09 will be released in the next 3-4 weeks. Compared to the original installation ISO image, our custom ISO image just contains `dialog` on top since it is required by our custom installer.

To create a custom NixOS install image we either need an existing NixOS 19.09 environment or at least VirtualBox on our machine.

## Existing NixOS environment

If you already run a NixOS instance, just launch the following command:

```
NIX_PATH=nixpkgs=channel:nixos-19.09:nixos-config=./custom.nix nix-build --no-out-link '<nixpkgs/nixos>' -A config.system.build.isoImage
```

## VirtualBox

If you don't have access to a NixOS 19.09 instance, the easiest way is to run the build in a virtual machine. To achieve this you need VirtualBox installed.

First of all download the appropriate VirtualBox appliance:

```
curl -O https://releases.nixos.org/nixos/19.09/nixos-19.09beta596.77b5a1965fc/nixos-19.09beta596.77b5a1965fc-x86_64-linux.ova
```

Next start Virtualbox and import the OVA file for the downloaded VirtualBox appliance via `File` -> `Import Appliance`.

Next go into `Machine` -> `Settings`, then `System` and set `Base memory` to 4096 MB. We will need a decent portion of memory to rebuild our system.

Next go into `Machine` -> `Settings`, then `Network` -> `Adapter 1`  and set `Attached to` to `Bridged adapter`. Next go to `Advanced` and set `Adapter type` to `Intel PRO/1000 MT Desktop (82540EM)`. Also ensure that `Cable Connected` is checked.

Next start the machine, and wait for it to boot. It doesn't require to login, Plasma 5 is launched automatically as user `demo`. When the desktop appears, open a terminal and launch the following commands:
 
```
sudo su -
nixos-generate-config --force
```

The command above writes two configuration files `/etc/nixos/configuration.nix` and `/etc/nixos/hardware-configuration.nix`.
 
We need to make two changes in the configuration file `/etc/nixos/configuration.nix`. First of all we need to define on which partition we want to install Grub. To achieve this uncomment the line 20:

```
boot.loader.grub.device = "/dev/sda";
``` 
 
To login later via SSH into our virtual machine we need to enable SSH daemon in `/etc/nixos/configuration.nix`. First of all add the `lib` namespace in line 5:
 
```
{ config, lib, pkgs, ...}:
```
 
Next uncomment line 53:

```
services.openssh.enable = true;
```

... and add two new lines 54-55:

```
services.openssh.permitRootLogin = "yes";
systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];
```

Next change root password:

```
passwd
```

Finally we need to rebuild our NixOS instance and activate it:

```
nixos-rebuild switch
```

After NixOS has been rebuilt, we need to install git manually:

```
nix-env -iA nixos.gitMinimal
```

Next clone the Git repository that contains the custom image builder:

```
git clone https://github.com/cpilka/nixos-minimal-installer-zfs-unstable.git
```

Finally build the custom install image by launching the following command:

```
cd nixos-minimal-installer-zfs-unstable
NIX_PATH=nixpkgs=channel:nixos-19.09:nixos-config=./custom.nix nix-build --no-out-link '<nixpkgs/nixos>' -A config.system.build.isoImage
```

The NixOS image will be stored in `/nix/store`, in our case in `/nix/store/c6pg4y3v0rln1rcvf44bj3zxnmki50cg-nixos-19.09beta603.8e1ce32f491-x86_64-linux.iso/iso/nixos-19.09beta603.8e1ce32f491-x86_64-linux.iso`.

# Create USB stick

Next we need to create a bootable USB stick. I assume, our USB disk is assigned to `/dev/disk3`. Please check your device file by executing:

```
$ diskutil list
```

In our case we get some partition details as feedback:

```
/dev/disk3 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *128.8 GB   disk3
   1:               Windows_NTFS                         128.8 GB   disk3s1
```

Create the USB stick by wiping all existing data:

```
$ diskutil eraseDisk FAT32 NIXOS_ISO MBRFormat /dev/disk3
```

You should get a feedback message similar to:

```
Started erase on disk3
Unmounting disk
Creating the partition map
Waiting for partitions to activate
Formatting disk3s1 as MS-DOS (FAT32) with name NIXOS_ISO
512 bytes per physical sector
/dev/rdisk3s1: 251596736 sectors in 3931199 FAT32 clusters (32768 bytes/cluster)
bps=512 spc=64 res=32 nft=2 mid=0xf8 spt=32 hds=255 hid=2 drv=0x80 bsec=251658238 bspf=30713 rdcl=2 infs=1 bkbs=6
Mounting disk
Finished erase on disk3
```

Next unmount the USB stick:

```
$ diskutil unmountDisk /dev/disk3
```

... which should return:

```
Unmount of all volumes on disk3 was successful
```

Next copy blockwise the ISO image to the USB stick:

```
$ sudo dd bs=4m if=nixos-19.09beta603.8e1ce32f491-x86_64-linux.iso of=/dev/rdisk3
```

After the password has been entered, the file is copied:

```
130+0 records in
130+0 records out
545259520 bytes transferred in 9.411540 secs (57935208 bytes/sec)
```

At this point we have created an USB thumb drive that is bootable by any computer. We will use this USB stick to bootstrap our NixOS machines.

See the ISO image in the [release section](https://github.com/cpilka/nixos-minimal-installer-zfs-unstable/releases) of the Git repository. It contains the most recent and downloadable version of the NixOS 19.09 beta installer at time of writing this README (4th October 2019).
