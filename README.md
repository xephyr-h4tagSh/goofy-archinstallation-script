# goofy-archinstallation-script
oh dear use my bad arch installation script
this script is an installation script to install ArchLinux inside of its .iso environment.

to use, when you get into your arch installation, connect to the internet, and run these commands:

pacman -Sy git
(may require additional confirmation, updates package databases and installs git)

git clone https://github.com/xephyr-h4tagSh/goofy-archinstallation-script/
(downloads this github repository using git)

cd goofy-archinstallation-script
(changes the directory to the repository)

chmod +x arch_installation.sh
(makes the installation script executable)

./arch_installation.sh
(runs the script)
