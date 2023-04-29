# Bootstrap my Raspberry Pi using Terraform

## What is it?

A baseline configuration provisioner for Raspberry Pi on Arch Linux, using Terraform. This is a run-once provisioner: subsequent runs will likely introduce problems.

The aim is to automate a bootstrap configuration for a headless system runnning Arch Linux. The setup process includes the configuration of a static network address, installation or replacement of a number of basic packages, *some* Rpi-specific optimizations, and a new user with sudo permissions (wheel), accessible by SSH.  

## Pre-requisites

* Terraform (v1.4 or newer)
* A Raspberry Pi freshly flashed with the aarch64 flavor of Arch Linux (as described here [here](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-3))

Note: the deployment process relies on an SSH connection and expects the account and password to be the default ones of Arch Linux systems.

## Usage 

* Edit a `tfvars` configuration file with target settings for the new system.  
An example configuration file is as follows. Copy in `newsystem.tfvars` and set all values adequately.
```
raspberrypi_ip     = "192.168.1.100"
new_hostname       = "raspberrypi"
static_ip_and_mask = "192.168.1.2/24"
static_router      = "192.168.1.254"
static_dns         = "1.1.1.1"
new_user           = "john"
new_user_uid       = "1001"
new_user_sshkey    = "ssh-ed25519 AAAAC3BAFAOEAaera[...]geaz john@theweb"
new_password       = "$6$2ezfAZEA[...]bdkmze"
timezone           = "Europe/Paris"
```

* Run terraform init (for the first run)

* Apply
```
terraform apply -var-file=newsystem.tfvars
```

* ssh to the new user account (the )
```
ssh john@192.168.1.100
```

* Verify and reboot if satisfied
```
sudo shutdown -r +0
```

* After reboot, ssh back to the new system and delete the default user 
```
ssh john@192.168.1.2
sudo userdel -r alarm 
```