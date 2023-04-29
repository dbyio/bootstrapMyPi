locals {
  default_username = "alarm"
  default_password = "alarm"
  su_cmd           = "echo root|su root -c"
}

resource "null_resource" "raspberry_pi_bootstrap" {

  connection {
    type     = "ssh"
    user     = local.default_username
    password = local.default_password
    host     = var.raspberrypi_ip
  }

  provisioner "remote-exec" {
    inline = [
      # pacman bootstrap
      "${local.su_cmd} \"pacman-key --init && pacman-key --populate archlinuxarm && pacman -Sy --noconfirm\" ",

      # install sudo
      "${local.su_cmd} \"pacman --noconfirm -S sudo\" ",

      # set sudoers
      "${local.su_cmd} \"echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL'>/etc/sudoers.d/wheel\" ",

      # set hostname
      "sudo hostnamectl set-hostname ${var.new_hostname}",
      "echo -e '127.0.1.1\t${var.new_hostname}' | sudo tee -a /etc/hosts",

      # date time config
      "sudo timedatectl set-timezone ${var.timezone}",
      "sudo timedatectl set-ntp true",

      # change default password early
      "echo '${local.default_username}:${var.new_password}' | sudo chpasswd -e",

      # networking - set static ip
      "echo -e '[Match]\nName=en*\n\n[Network]\nAddress=${var.static_ip_and_mask}\nGateway=${var.static_router}\nDNSSEC=no\nDNS=${var.static_dns}\nMulticastDNS=true' | sudo tee /etc/systemd/network/wired.network",
      "sudo rm -f /etc/systemd/network/en.network",

      # add (local) baseline packages
      "sudo pacman -Rsn --noconfirm uboot-raspberrypi linux-aarch64 iptables",
      "sudo pacman -S --noconfirm linux-rpi",
      "sudo pacman -Su --noconfirm",
      "sudo pacman -S --noconfirm nftables iptables-nft zsh chezmoi tmux btrfs-progs vim git",

      # replace vi with vim
      "sudo pacman -Rsn --noconfirm vi && sudo ln -s /usr/bin/vim /usr/local/bin/vi",

      # create local user and copy ssh key
      "sudo useradd -m ${var.new_user} --uid ${var.new_user_uid} --no-user-group -g users --groups wheel --shell /bin/zsh",
      "echo '${var.new_user}:${var.new_password}' | sudo chpasswd -e",
      "sudo mkdir -m 755 /home/${var.new_user}/.ssh && sudo chown ${var.new_user}:users /home/${var.new_user}/.ssh",
      "echo '${var.new_user_sshkey}' | sudo tee /home/${var.new_user}/.ssh/authorized_keys",
      "sudo chown ${var.new_user}:users /home/${var.new_user}/.ssh/authorized_keys",

      # locales
      "sudo sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen",
      "sudo locale-gen",
      "sudo localectl set-locale LANG=en_US.UTF-8",

      # fstab
      "echo -e '/dev/mmcblk0p2\t/\text4\tnoatime\t0\t1' | sudo tee -a /etc/fstab",

      # systemctl
      "echo 'vm.min_free_kbytes=3768' | sudo tee -a /etc/sysctl.conf",

      # journald
      "sudo mkdir /etc/systemd/journald.conf.d/",
      "echo -e '[Journal]\nSystemMaxUse=50M' | sudo tee /etc/systemd/journald.conf.d/00-journal-size.conf",
      "echo -e '[Journal]\nAudit=no' | sudo tee /etc/systemd/journald.conf.d/01-journal-audit.conf",

      # stop resolverd stub listener
      "sudo mkdir /etc/systemd/resolved.conf.d",
      "echo -e '[Resolve]\nDNS=1.1.1.1\nDNSStubListener=no' | sudo tee disable-stub.conf",

      # optimize rpi settings (low power consumption)
      "echo -e '##enable serial port\nenable_uart=1\n\n## max up USB current to 1.2A\nmax_usb_current=1\n\n## turn on/off wifi\ndtoverlay=disable-wifi\n\n## min down GPU memory\ngpu_mem=32\n\n##turn off mainboard LEDs\ndtoverlay=act-led\n\n##disable ACT LED\ndtparam=act_led_trigger=none\n\ndtparam=act_led_activelow=off\n\n##disable PWR LED\ndtparam=pwr_led_trigger=none\n\ndtparam=pwr_led_activelow=off\n\n##turn off ethernet port LEDs\ndtparam=eth_led0=4\ndtparam=eth_led1=4' | sudo tee -a /boot/config.txt",

      # install docker
      "sudo pacman -S --noconfirm docker docker-compose",
      "echo '[Unit]\nDescription=%i service with docker compose\nRequires=docker.service\nAfter=docker.service\n\n[Service]\nRestart=always\n\nWorkingDirectory=/etc/docker/compose/%i\n\n# Remove old containers, images and volumes\nExecStartPre=/bin/sleep 10\nExecStartPre=/usr/bin/docker compose down \nExecStartPre=/usr/bin/docker compose rm -f\n\n# Compose up\nExecStart=/usr/bin/docker compose up\n\n# Compose down, remove containers and volumes\nExecStop=/usr/bin/docker compose down \n\n[Install]\nWantedBy=multi-user.target\n' | sudo tee /etc/systemd/system/docker-compose@.service",

      # cleanup and reboot
      "sudo pacman -Scc --noconfirm && sync",
      #"sudo shutdown -r +0"
    ]
  }
}
