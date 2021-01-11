# NixOS 20.09 minimal custom installer

This repository contains a build script to create a custom NixOS 20.09 minimal installation ISO image. Compared to the original NixOS minimal installation ISO image, our custom ISO image contains following modifications:

- initial copy of the NixOS 20.09 channel is provided so that the user doesn't need to run "nix-channel --update" first
- package `dialog` is installed since it is required by our custom installer
- SSH daemon is running and accepting logins for `root`
- password for root is set to `changeme`

To create a custom NixOS installation image we either need an existing NixOS 20.09 environment or at least VirtualBox on our machine.

## Existing NixOS environment

If we already have access to a a NixOS 20.09 instance, we just need to clone the Git repository:

```
# cd ~
# git clone https://github.com/cpilka/nixos-setup-minimal-installation-cd.git
```

... and build the ISO image by launching the following command:

```
NIX_PATH=nixpkgs=channel:nixos-20.09:nixos-config=./iso.nix nix-build --no-out-link '<nixpkgs/nixos>' -A config.system.build.isoImage
```

## VirtualBox

In case we don't have access to a NixOS 20.09 instance, the easiest way is to run the build in a virtual machine. To achieve this we need VirtualBox installed.

First of all download the appropriate VirtualBox appliance. You find the latest build at [https://nixos.org/channels/nixos-20.09](https://nixos.org/channels/nixos-20.09):

```
$ cd /tmp
$ curl -O https://releases.nixos.org/nixos/20.09/nixos-20.09.2555.41dddb12837/nixos-20.09.2555.41dddb12837-x86_64-linux.ova
```

Next check if the SHA256 checksum matches:

```
$ sha256sum nixos-20.09.2555.41dddb12837-x86_64-linux.ova
```

The calculated SHA256 hash should be:

```
ae24edd673d43aed99bb9422591ce15dd322b52c8c49248239cdd01d6200f113  nixos-20.09.2555.41dddb12837-x86_64-linux.ova
```

... and should be same as listed at [https://nixos.org/channels/nixos-20.09](https://nixos.org/channels/nixos-20.09).

Next start Virtualbox and import the OVA file for the downloaded VirtualBox appliance via `File` -> `Import Appliance`.

Next go into `Machine` -> `Settings`, then `System` and set `Base memory` to 4096 MB. We will need a decent portion of memory to rebuild our system.

Next go into `Machine` -> `Settings`, then `Network` -> `Adapter 1`  and set `Attached to` to `Bridged adapter`. Next go to `Advanced` and set `Adapter type` to `Intel PRO/1000 MT Desktop (82540EM)`. Also ensure that `Cable Connected` is checked.

Next start the virtual machine. It's not required to login, Plasma 5 is launched automatically as user `demo`. Whenever required (e.g. for a `sudo`), the default password for this user is also `demo`. When the desktop appears, open a terminal and launch the following commands (root PW is: 'demo'):
 
```
$ sudo su -
# nixos-generate-config --force
```

The command above creates two configuration files `/etc/nixos/configuration.nix` and `/etc/nixos/hardware-configuration.nix`.
 
We need to make few changes in the configuration file `/etc/nixos/configuration.nix`. First of all we need to define on which partition we want to install GRUB. To achieve this uncomment the line 20:

```
boot.loader.grub.device = "/dev/sda";
``` 
 
To login later via SSH into our virtual machine we need to enable SSH daemon in `/etc/nixos/configuration.nix`. First of all add the `lib` namespace as attribute in line 5:
 
```
{ config, lib, pkgs, ...}:
```
 
Next uncomment line 89:

```
services.openssh.enable = true;
```

... and add two new lines 90-91:

```
services.openssh.permitRootLogin = "yes";
systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];
```

Next change root password to `changeme`:

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
# git clone https://github.com/asconix/nixos-setup-minimal-installation-cd.git
```

Finally build the custom install image by launching the following command:

```
# cd nixos-setup-minimal-installation-cd
# NIX_PATH=nixpkgs=channel:nixos-20.03:nixos-config=./iso.nix nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage
```

The NixOS ISO image is stored in `/nix/store/` and symlinked to `result/iso`, in our case we find the ISO image in `/root/nixos-setup-minimal-installation-cd/result/iso/nixos-20.03.2411.30fb4e1e206-x86_64-linux.iso`.

# Create USB flash drive

Next we need to create a bootable USB flash drive. First of all copy the created ISO image from our VM to our host:

```
$ scp root@IP_OF_OUR_VM:/root/nixos-setup-minimal-installation-cd/result/iso/nixos-20.03.2411.30fb4e1e206-x86_64-linux.iso .
```

Next plug in a USB flash drive that will be used for our custom installation image and check on our host (macOS) which device filename has been assigned to:

```
# diskutil list
```

I assume, our USB drive is assigned to `/dev/disk2`:

```
/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *15.5 GB    disk2
   1:                       0xEF                         22.0 MB    disk2s2
```

First of all we need to wipe all existing data on our flash drive:

```
$ diskutil eraseDisk FAT32 NIXOS_ISO MBRFormat /dev/disk2
```

You should get a feedback message similar to:

```
Started erase on disk2
Unmounting disk
Creating the partition map
Waiting for partitions to activate
Formatting disk2s1 as MS-DOS (FAT32) with name NIXOS_ISO
512 bytes per physical sector
/dev/rdisk2s1: 30186672 sectors in 1886667 FAT32 clusters (8192 bytes/cluster)
bps=512 spc=16 res=32 nft=2 mid=0xf8 spt=32 hds=255 hid=2048 drv=0x80 bsec=30216192 bspf=14740 rdcl=2 infs=1 bkbs=6
Mounting disk
Finished erase on disk2
```

Next unmount the USB stick:

```
$ diskutil unmountDisk /dev/disk2
```

... which should return:

```
Unmount of all volumes on disk2 was successful
```

Next copy blockwise the custom minimal installation ISO image to our USB flash drive:

```
$ sudo dd bs=4m if=nixos-20.03.2411.30fb4e1e206-x86_64-linux.iso of=/dev/rdisk2
```

After the password has been entered, the file is copied:

```
138+1 records in
138+1 records out
579862528 bytes transferred in 103.871480 secs (5582500 bytes/sec)
```

Finally we have created an USB flash drive that is bootable by any computer. We will use this USB drive to bootstrap our NixOS machines. In the end our USB drive should have a partition schema similar to:

```
/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *15.5 GB    disk2
   1:                       0xEF                         22.0 MB    disk2s2
```

You find the ISO image in the [release section](https://github.com/asconix/nixos-setup-minimal-installation-cd/releases) of the Git repository.

