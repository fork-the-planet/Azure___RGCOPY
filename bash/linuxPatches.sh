echo "SCRIPT_DIRECTORY='$(pwd)'" 1>&2
echo "OS_KERNEL_OLD='$(uname -r)'" 1>&2
echo "$(cat /etc/os-release | grep PRETTY_NAME)" 1>&2

#--------------------------------------------------------------
function waitForPatches {
	suse=`cat /etc/os-release | grep -i suse | wc -l`
	redHat=`cat /etc/os-release | grep -i 'Red Hat' | wc -l`
	declare -i waited=0

    if [ $suse -gt 0 ]; then
		process='zypper'
    elif [ $redHat -gt 0 ]; then
		process='yum'
	else
		process='apt|dpkg'
    fi

	while [ $( ps -A -o cmd | grep -v grep | grep -iE $process | wc -l ) -gt 0 -a $waited -lt 300 ];
		do
		waited+=5
		echo "=== waiting $waited seconds for another instance of $process to finish..." 1>&2
		sleep 5
	done

}
#----------------------------------------------------------------------
waitForPatches
if [ -n "$prePatchCommand" ]; then
	eval $prePatchCommand
fi

suse=`cat /etc/os-release | grep -i suse | wc -l`
redHat=`cat /etc/os-release | grep -i 'Red Hat' | wc -l`
ubuntu=`cat /etc/os-release | grep -i Ubuntu | wc -l`
#----------------------------------------------------------------------
# patch SUSE
#----------------------------------------------------------------------
if [ $suse -gt 0 ]; then
	echo "Suse distribution found"
	echo " "

	# do not update WALinuxAgent
	waitForPatches
	zypper al WALinuxAgent

	# register and refresh
	waitForPatches
	registercloudguest --force-new
	waitForPatches
	echo "=== zypper refresh ==="
	zypper --quiet refresh --force

	# show repos
	echo "=== zypper repos --show-enabled-only ==="
	zypper repos --show-enabled-only | awk -F '|' 'NR>2 {print $3}' | sed 's/^[ \t]*//;s/[ \t]*$//'
	echo " "

	echo "=== zypper patch-check ==="
	waitForPatches
	summary=`zypper --quiet  patch-check | grep -F "security patches)"`
	# e.g.: >25 patches needed (5 security patches)
	echo $summary
	echo " "
	countAll=0
	countSec=0
	if [[ $summary =~ ([0-9]+)[^0-9]+([0-9]+) ]]; then
		countAll=${BASH_REMATCH[1]}
		countSec=${BASH_REMATCH[2]}
	fi

	# count needed patches
	if [ "$patchAll" = "true" ]; then
		updateType='updates'
		count=$countAll
	else
		updateType='security updates'
		count=$countSec
	fi

	# nothing to do
	if [ $count -eq 0 ]; then
		echo "========================================="
		echo "No $updateType found"
		echo "========================================="
		echo "REBOOT_REQUIRED='false'"
		exit 0

	# install updates
	else
		echo "========================================="
		echo "installing $count $updateType using 'zypper' ..."

		# ZYPPER_EXIT_INF_RESTART_NEEDED (zypper itself has been updated)
		exitCode=103
		while [ $exitCode -eq 103 ]; do

			waitForPatches
			if [ "$patchAll" = "true" ]; then
				zypper --non-interactive --quiet patch --with-interactive --auto-agree-with-licenses                     2>&1 1>patch.tmp
			else
				zypper --non-interactive --quiet patch --with-interactive --auto-agree-with-licenses --category=security 2>&1 1>patch.tmp
			fi
			exitCode=$?
		done

		echo "zypper exit code: $exitCode"
		echo "========================================="

		# reboot required?
		if [ $exitCode -eq 102 ]; then
			echo "REBOOT_REQUIRED='true'"

		elif [ -f /var/run/reboot-required ]; then
			echo "REBOOT_REQUIRED='true'"

		else
			zypper needs-rebooting
			needed=$?
			if [ $needed -eq 102 ]; then
				echo "REBOOT_REQUIRED='true'"
			else
				echo "REBOOT_REQUIRED='false'"
			fi
		fi

		# ignore zypper exit codes 100+
		if [ $exitCode -gt 99 ]; then
			exitCode=0
		fi
	fi

#----------------------------------------------------------------------
# patch RHEL
#----------------------------------------------------------------------
elif [ $redHat -gt 0 ]; then
	echo "RedHat distribution found"
	echo " "

	# do not update WALinuxAgent
	grep -qxF "exclude=WALinuxAgent*" /etc/yum.conf || echo 'exclude=WALinuxAgent*' >>/etc/yum.conf

	# show repos
	echo "=== yum repolist ==="
	waitForPatches
	 yum repolist | awk 'NR>1 {print $1}'
	echo " "
	
	# show needed patches
	waitForPatches
	if [ "$patchAll" = "true" ]; then
		updateType='updates'
		# echo "=== yum updateinfo list ==="
		mapfile -t patches < <(yum -q updateinfo list)
	else
		updateType='security updates'
		# echo "=== yum updateinfo list security ==="
		mapfile -t patches < <(yum -q updateinfo list security)
	fi

	# printf '%s\n' "${patches[@]}"
	count=`echo "${#patches[@]}"`
	echo " "

	# nothing to do
	if [ $count -eq 0 ]; then
		echo "========================================="
		echo "No $updateType found"
		echo "========================================="
		echo "REBOOT_REQUIRED='false'"
		exit 0

	# install updates
	else
		echo "========================================="
		echo "installing $count $updateType using 'yum' ..."

		waitForPatches
		if [ "$patchAll" = "true" ]; then
			yum -y update				2>&1 1>patch.tmp
		else
			yum -y update --security	2>&1 1>patch.tmp
		fi

		exitCode=$?
		echo "yum exit code: $exitCode"
		echo "========================================="

		# reboot required?
		needs-restarting -r 1>/dev/null
		needed=$?
		if [ $needed -eq 1 ]; then
			echo "REBOOT_REQUIRED='true'"
		else
			echo "REBOOT_REQUIRED='false'"
		fi
	fi

#----------------------------------------------------------------------
# patch UBUNTU
#--------------------------------------------------------------
elif [ $ubuntu -gt 0 ]; then

	# for UBUNTU, always install only security updates
	# (/etc/apt/apt.conf.d/50unattended-upgrades should be configured correctly)
	echo "Ubuntu distribution found"
	echo " "

	# do not update WALinuxAgent
	apt-mark hold walinuxagent

	# show repos
	echo "=== apt-cache policy | grep http ==="
	apt-cache policy | grep http
	echo " "

	waitForPatches
	apt-get update 1>/dev/null 2>/dev/null

	# show needed patches
	waitForPatches
	# echo "=== apt list --upgradable 2>/dev/null | grep -i security ==="
	mapfile -t patches < <(apt list --upgradable 2>/dev/null | grep -i security)
	# printf '%s\n' "${patches[@]}"
	count=`echo "${#patches[@]}"`
	echo " "

	# nothing to do
	if [ $count -eq 0 ]; then
		echo "========================================="
		echo "No security updates found"
		echo "========================================="
		exitCode=0

	# install security updates
	else
		echo " "
		echo "========================================="
		echo "installing $count security updates running 'unattended-upgrade' ..."
		waitForPatches
		unattended-upgrade 2>&1 1>patch.tmp

		# display result
		exitCode=$?
		echo "unattended-upgrade exit code: $exitCode"
		echo "========================================="

	fi

	# reboot required?
	if [ -f /var/run/reboot-required ]; then
		echo "REBOOT_REQUIRED='true'"
	else
		echo "REBOOT_REQUIRED='false'"
	fi

#----------------------------------------------------------------------
# unknown Linux distribution
#--------------------------------------------------------------
else
	echo "No supported Linux distribution (Suse, RedHat, Ubuntu) found"
	echo "No updates are installed"
	echo "REBOOT_REQUIRED='false'"
	exit 0
fi

#--------------------------------------------------------------
if [ $exitCode -ne 0 ]; then
	cat patch.tmp
	echo "++ exit 1"
	exit 1
fi

#--------------------------------------------------------------
if [ -n "$postPatchCommand" ]; then
	eval $postPatchCommand
fi
