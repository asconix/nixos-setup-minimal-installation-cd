# NixOS 19.09beta minimal custom installer

This repository contains a build script to create a custom NixOS minimal installation ISO image. We already use NixOS 19.09 beta in production since at the time of writing (5th October 2019) we expect NixOS 19.09 to be released in few weeks. Compared to the original Nixos minimal installation ISO image, our custom ISO image contains following modifications:

- initial copy of the NixOS channel is provided so that the user doesn't need to run "nix-channel --update" first
- package `dialog` is installed since it is required by our custom installer
- SSH daemon is running and accepting logins for `root`
- password for root is set to `changeme`

To create a custom NixOS installation image we either need an existing NixOS 19.09 environment or at least VirtualBox on our machine.

## Existing NixOS environment

If we already have access to a a NixOS 19.09 instance, we just need to clone the Git repository:

```
# cd ~
# git clone https://github.com/cpilka/nixos-setup-minimal-installation-cd.git
```

... and build the ISO image by launching the following command:

```
NIX_PATH=nixpkgs=channel:nixos-19.09:nixos-config=./iso.nix nix-build --no-out-link '<nixpkgs/nixos>' -A config.system.build.isoImage
```

## VirtualBox

In case we don't have access to a NixOS 19.09 instance, the easiest way is to run the build in a virtual machine. To achieve this we need VirtualBox installed.

First of all download the appropriate VirtualBox appliance. You find the latest build at [https://nixos.org/channels/nixos-19.09](https://nixos.org/channels/nixos-19.09):

```
$ cd /tmp
$ curl -O https://releases.nixos.org/nixos/19.09/nixos-19.09beta606.3ba0d9f75cc/nixos-19.09beta606.3ba0d9f75cc-x86_64-linux.ova
```

Next check if the SHA256 checksum matches:

```
$ sha256sum nixos-19.09beta606.3ba0d9f75cc-x86_64-linux.ova
```

The calculated SHA256 hash should be:

```
6d777b59d3b10f8ba4c0da87176189c3b9d24a2c69304c135d71ef839780fc38  nixos-19.09beta606.3ba0d9f75cc-x86_64-linux.ova
```

... and should be same as listed at [https://nixos.org/channels/nixos-19.09](https://nixos.org/channels/nixos-19.09).


Next start Virtualbox and import the OVA file for the downloaded VirtualBox appliance via `File` -> `Import Appliance`.

Next go into `Machine` -> `Settings`, then `System` and set `Base memory` to 4096 MB. We will need a decent portion of memory to rebuild our system.

Next go into `Machine` -> `Settings`, then `Network` -> `Adapter 1`  and set `Attached to` to `Bridged adapter`. Next go to `Advanced` and set `Adapter type` to `Intel PRO/1000 MT Desktop (82540EM)`. Also ensure that `Cable Connected` is checked.

Next start the virtual machine. It's not required to login, Plasma 5 is launched automatically as user `demo`. Whenever required (e.g. for a `sudo`), the default password for this user is also `demo`. When the desktop appears, open a terminal and launch the following commands:
 
```
$ sudo su -
# nixos-generate-config --force
```

The command above creates two configuration files `/etc/nixos/configuration.nix` and `/etc/nixos/hardware-configuration.nix`.
 
We need to make few changes in the configuration file `/etc/nixos/configuration.nix`. First of all we need to define on which partition we want to install GRUB. To achieve this uncomment the line 20:

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
# passwd
```

Finally we need to rebuild our NixOS instance and activate it:

```
# nixos-rebuild switch
```

After NixOS has been rebuilt and restarted automatically, we need to login as root and install git manually:

```
# nix-env -iA nixos.gitMinimal
```

Next clone the Git repository that contains the custom image builder:

```
# cd ~
# git clone https://github.com/cpilka/nixos-setup-minimal-installation-cd.git
```

Finally build the custom install image by launching the following command:

```
# cd nixos-setup-minimal-installation-cd
# NIX_PATH=nixpkgs=channel:nixos-19.09:nixos-config=./iso.nix nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage
```

The NixOS image will be stored in `/nix/store`, in our case in `/nix/store/c6pg4y3v0rln1rcvf44bj3zxnmki50cg-nixos-19.09beta603.8e1ce32f491-x86_64-linux.iso/iso/nixos-19.09beta603.8e1ce32f491-x86_64-linux.iso`.

# Create USB flash drive

Next we need to create a bootable USB flash drive. I assume, our USB disk is assigned to `/dev/disk3`. Please check your device file by executing:

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