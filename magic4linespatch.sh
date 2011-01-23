#!/bin/sh
set -e

test "$(/usr/bin/id -u)" = 0 ||
    {
        echo "I want to be root!!"
        exit 1
    }

grep -q 4linespatch /etc/rc.local /etc/profile &&
    {
        echo "4linespatch seems to be installed"
        exit 2
    }

echo "Saving a backup of /etc/rc.local in /etc/rc.local.back"
cp /etc/rc.local /etc/rc.local.back

echo "Editing /etc/rc.local"
awk '
    BEGIN{
        error = 1
    }
    !/^exit 0$/{
        print $0
    }
    /^exit 0$/{
        print "#<4linespatch>"
        print "mkdir -p /dev/cgroup/cpu"
        print "mount -t cgroup cgroup /dev/cgroup/cpu -o cpu"
        print "mkdir -m 0777 /dev/cgroup/cpu/user"
        printf "echo \"/usr/local/sbin/cgroup_clean\""
        print "> /dev/cgroup/cpu/release_agent"
        print "#</4linespatch>"
        print
        print $0
        error = 0
    }
    END{
        exit error
    }
' /etc/rc.local.back > /etc/rc.local

echo "Setting /etc/rc.local executing flags"
chmod 755 /etc/rc.local

echo "Saving a backup of /etc/profile in /etc/profile.back"
cp /etc/profile /etc/profile.back

echo "Editing /etc/profile"
awk '
    /./
    END{
        print "#<4linespatch>"
        print "if [ \"$PS1\" ] ; then"
        print "  mkdir -p -m 0700 /dev/cgroup/cpu/user/$$ > /dev/null 2>&1"
        print "  echo $$ > /dev/cgroup/cpu/user/$$/tasks"
        print "  echo \"1\" > /dev/cgroup/cpu/user/$$/notify_on_release"
        print "fi"
        print "#</4linespatch>"
    }
' /etc/profile.back > /etc/profile

echo "Writing /usr/local/sbin/cgroup_clean"
awk '
    BEGIN{
        print "#!/bin/sh"
        print "#4linespatch"
        print "rmdir /dev/cgroup/cpu/$*"
        exit
    }
' > /usr/local/sbin/cgroup_clean

echo "Setting /usr/local/sbin/cgroup_clean executing flags"
chmod 755 /usr/local/sbin/cgroup_clean

echo "Starting cgroup"
/etc/rc.local

echo "Ready xD, you should restart your session to apply changes."
