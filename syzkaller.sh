# default username is apache/hadoop/spark/kafka...
# references: https://www.apache.org/index.html#projects-list

if [ $# -ne 2 ]; then
  echo "Usage ./syzkaller.sh bash/zsh"
  exit 1
fi

ssh-keygen

sudo apt-get update
sudo apt-get upgrade -y 
sudo apt-get install -y zsh supervisor python-is-python3 proxychains-ng python3-pip curl flex bc build-essential libc6-dbg lib32stdc++6 g++-multilib gcc vim net-tools curl libffi-dev libssl-dev tmux glibc-source cmake strace ltrace nasm socat wget gdb gdb-multiarch socat git patchelf gawk file zsh bison gcc-multilib binwalk libseccomp-dev libseccomp2 unzip seccomp openssh-server lrzsz fd-find fzf silversearcher-ag mosh qemu-system qemu-user qemu-user-static debootstrap libelf-dev neofetch ninja-build htop neofetch libncurses-dev netcat-openbsd pigz proxychains rsyslog neovim --fix-missing 

echo "maybe build new qemu/gcc/kernel"
sudo apt-get install -y pkg-config libglib2.0-dev libpixman-1-dev bison libgmp3-dev libmpc-dev
sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

## install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc
## Bracketed paste support
# bash
# set enable-bracketed-paste on
# zsh
# zle -N bracketed-paste bracketed-paste-magic
# source ~/.zshrc
## change to zsh
# sudo chsh -s /bin/zsh

## config tmux
echo "set -g display-time 3000
set -g escape-time 0
set -g history-limit 65535
set -g base-index 0
set -g pane-base-index 0
set -g prefix ^q
bind a send-prefix
bind - splitw -v
bind y select-layout even-horizontal
unbind %
bind | splitw -h # horizontal split (prefix |)
bind k selectp -U # above (prefix k)
bind j selectp -D # below (prefix j)
bind h selectp -L # left (prefix h)
bind l selectp -R # right (prefix l)
bind -r ^k resizep -U 10 # upward (prefix Ctrl+k)
bind -r ^j resizep -D 10 # downward (prefix Ctrl+j)
bind -r ^h resizep -L 10 # to the left (prefix Ctrl+h)
bind -r ^l resizep -R 10 # to the right (prefix Ctrl+l)
bind ^u swapp -U
bind ^d swapp -D
bind q killp
bind ^q killw
bind [ copy-mode
bind ^p pasteb
bind r source ~/.tmux.conf
setw -g mode-keys vi
setw -g automatic-rename on
set -g mouse on
setw -g monitor-activity on
setw -g automatic-rename on
set-option -g @shell_mode 'vi'
set -g default-terminal screen-256color
set-option -ga terminal-overrides \",*256col*:Tc\"
set -g status-left-length 100" > .tmux.conf

## install go
wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz

mkdir $HOME/.go
echo "export GOROOT=\"/usr/local/go/\"" >> ~/.zshrc
echo "export GOPATH=\"$HOME/.go\"" >> ~/.zshrc
echo "export PATH=\"/usr/local/go/bin\":\$PATH" >> ~/.zshrc
echo "export PATH=\$GOPATH/bin:\$PATH" >> ~/.zshrc
source ~/.zshrc

go env -w GO111MODULE=on 
go env -w GOPROXY=https://goproxy.cn,direct
## install syzkaller
git clone https://github.com/google/syzkaller
cd syzkaller
make all
cd -

# create image
RELEASE=bullseye
IMAGE=$HOME/$RELEASE # match the create-image.sh script if you change the dist
mkdir $IMAGE
cd $IMAGE
wget https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh
bash create-image.sh
sudo rm -rf chroot
cd -

# vim
# curl https://raw.githubusercontent.com/wklken/vim-for-server/master/vimrc > ~/.vimrc
# sed -i 's/shiftwidth=4/shiftwidth=2/g' .vimrc
# sed -i 's/tabstop=4/tabstop=2/g' .vimrc
# sed -i 's/softtabstop=4/softtabstop=2/g' .vimrc

## 设置交换空间，防止编译内核或者syzkaller时OOM，设置8G交换空间
# VPS一般都没有交换空间swap，导致经常OOM
sudo swapon -s
sudo fallocate -l 8G /swapfile
sudo dd if=/dev/zero of=/swapfile bs=1024 count=8388608
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
sudo swapon --show
sudo free -h

# clone and build linux-kernel (Tips: config need to be notice)
KERNEL=$HOME/linux
git clone https://github.com/torvalds/linux.git $HOME/linux
cd $HOME/linux
make clean

# !!!manual config!!!
# https://syzkaller.appspot.com/text?tag=KernelConfig&x=b55c7ca2258f24ba
# cp dashboard/config/linux/upstream-apparmor-kasan.config ~/linux/.config
# make defconfig
# make kvmconfig

curl https://syzkaller.appspot.com/text\?tag\=KernelConfig\&x\=b55c7ca2258f24ba > .config

# KCOV DEBUG_INFO CONFIGFS SECURITYFS enableing
sed -i 's/\# CONFIG_KCOV is not set/CONFIG_KCOV=y/g' .config
sed -i 's/\# CONFIG_KASAN is not set/CONFIG_KASAN=y/g' .config
sed -i 's/\# CONFIG_KASAN_INLINE is not set/CONFIG_KASAN_INLINE=y/g' .config
sed -i 's/\# CONFIG_KCOV_INSTRUMENT_ALL is not set/CONFIG_KCOV_INSTRUMENT_ALL=y/g' .config
sed -i 's/\# CONFIG_KCOV_ENABLE_COMPARISONS is not set/CONFIG_KCOV_ENABLE_COMPARISONS=y/g' .config


sed -i 's/\# CONFIG_DEBUG_INFO is not set/CONFIG_DEBUG_INFO=y/g' .config
sed -i 's/\# CONFIG_CONFIGFS_FS is not set/CONFIG_CONFIGFS_FS=y/g' .config
sed -i 's/\# CONFIG_SECURITYFS is not set/CONFIG_SECURITYFS=y/g' .config
sed -i 's/\# CONFIG_DEBUG_FS is not set/CONFIG_DEBUG_FS=y/g' .config
sed -i 's/\# CONFIG_DEBUG_INFO is not set/CONFIG_DEBUG_INFO=y/g' .config
sed -i 's/\# CONFIG_KALLSYMS is not set/CONFIG_KALLSYMS=y/g' .config
sed -i 's/\# CONFIG_KALLSYMS_ALL is not set/CONFIG_KALLSYMS_ALL=y/g' .config
sed -i 's/\# CONFIG_DEBUG_INFO is not set/CONFIG_DEBUG_INFO=y/g' .config
sed -i 's/\# CONFIG_DEBUG_VM is not set/CONFIG_DEBUG_VM=y/g' .config
sed -i 's/\# CONFIG_DEBUG_INFO_DWARF4 is not set/CONFIG_DEBUG_INFO_DWARF4=y/g' .config

# net configure for kernel
sed -i 's/\# CONFIG_VIRTIO_NET is not set/CONFIG_VIRTIO_NET=y/g' .config
sed -i 's/\# CONFIG_E1000 is not set/CONFIG_E1000=y/g' .config
sed -i 's/\# CONFIG_E1000E is not set/CONFIG_E1000E=y/g' .config
sed -i 's/\# CONFIG_CMDLINE_BOOL is not set/CONFIG_CMDLINE_BOOL=y/g' .config


make oldconfig # save the config file
echo "Making the kernel..."
# OOM
make -j`nproc -all`

RELEASE=bullseye
KERNEL=$HOME/linux
IMAGE=$HOME/$RELEASE

echo "qemu-system-x86_64 \\
  -kernel $KERNEL/arch/x86/boot/bzImage \\
  -append \"console=ttyS0 root=/dev/sda debug earlyprintk=serial slub_debug=QUZ net.ifnames=0\" \\
  -hda $IMAGE/bullseye.img \\
  -net user,hostfwd=tcp::2333-:22 -net nic \\
  -enable-kvm \\
  -nographic \\
  -m 2G \\
  -smp 2 \\
	-no-reboot \\
  -pidfile vm.pid \\
  2>&1 | tee vm.log" > run.sh

chmod u+x run.sh
sudo chmod 777 /dev/kvm

# working dir
mkdir workdir

# check kvm status
sudo usermod -a -G kvm $(whoami)

echo "./run.sh to check"
# corpus.db mv

RELEASE=bullseye
KERNEL=$HOME/linux
IMAGE=$HOME/$RELEASE

echo "{
	\"target\": \"linux/amd64\",
	\"http\": \"0.0.0.0:56741\",
	\"workdir\": \"$HOME/workdir\",
	\"kernel_obj\": \"$KERNEL\",
	\"image\": \"$IMAGE/bullseye.img\",
	\"sshkey\": \"$IMAGE/bullseye.id_rsa\",
	\"syzkaller\": \"$HOME/syzkaller\",
	\"procs\": 16,
	\"reproduce\": false,
	\"type\": \"qemu\",
	\"max_crash_logs\": 20,
	\"preserve_corpus\": true,
	\"cover\": true,
	\"vm\": {
		\"count\": 4,
		\"kernel\": \"$KERNEL/arch/x86/boot/bzImage\",
		\"cpu\": 2,
		\"mem\": 4096
	}
}" > my.cfg

## test with qemu-system
echo 'run syz-manager -config=$HOME/my.cfg'

# update kernel and /bin/zsh
# reboot
