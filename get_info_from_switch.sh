#!/usr/bin/expect
set timeout 1
set host [lindex $argv 0]
set mode [lindex $argv 1]
set port [lindex $argv 2]
set cmd [lindex $argv 3]
set userLogin "login\r"
set userPass "password\r"
set switch 0
set comp_e [string first e $port 0]
set comp_c [string first c $port 0]
set comp_l [string first l $port 0]

proc send_ctrl_c {} {
	send \003
}
proc send_n {} {
	send \156
}
proc send_space {} {
	send \040
}
proc send_esc {} {
	send \033
}
proc send_a {} {
	send \141
}
spawn telnet $host

expect {
  "***************** User Access Login ********************" { send "admin\r"; send "bonOdrib\r" }
  "User" { send $userLogin; send $userPass }
}
sleep 0.5
expect { 
    "Incorrect Login/Password" { send "admin\r"; send "bonOdrib\r" }
    "Fail!" { send "admin\r"; send "bonOdrib\r" ; expect { "Fail!" { send "admin\r"; send "solekam1\r" } } }
    "Username:" { send "admin\r"; send "bonOdrib\r"; expect { "Username:" { send "admin\r"; send "solekam1\r" } } }
    "Login invalid" { send "admin\r"; send "bonOdrib\r" }
}
sleep 0.5
expect { 
    DES-3200-26 { set switch 'des'; send "enable admin\r"; send "rhtgjcnm\r" }
    oper# { set switch 'des'; send "enable admin\r"; send "bonOdrib\r" }
    :4# { set switch 'des'; send "enable admin\r"; send "bonOdrib\r" }
    ECS35 { set switch 'edgecore'; send "enable\r"; send "bonOdrib\r"; send "solekam1\r"; send "rhtgjcnm\r" }
    ES35 { set switch 'edgecore'; send "enable\r"; send "bonOdrib\r"; send "solekam1\r"; send "rhtgjcnm\r" }
    ZyXEL { set switch 'ZyXEL'; send "enable\r"; send "bonOdrib\r" }
    TPLINK2600 { set switch 4; send "enable\r" }
}
if { $mode <= {26} && $switch == {'des'} } {
	send "show fdb port $mode\r"
    if { $comp_e >= {0} } {
        send "show error port $mode\r"
        send_ctrl_c }
    if { $comp_c >= {0} } {
        send "cable_diag ports $mode\r"
        send_ctrl_c }
    if { $comp_l >= {0} } {
        send "show log\r"
for {set i 1} {$i<=4} {incr i} {send_n}
        send_ctrl_c }
	interact
} elseif {  $mode <= {26} && $switch == {'edgecore'} } {
		send "show mac-address-table int eth 1/$mode\r"
    if { $comp_e >= {0} } {
        send "show interfaces counters eth 1/$mode\r"
        send_a }
    if { $comp_c >= {0} } {
        send "show cable-diagnostics int eth 1/$mode\r"
        }
    if { $comp_l >= {0} } {
        send "show log ram\r"
        send_space
        send_space
        send_space
        send_space
        send_ctrl_c }
		interact
} elseif { $mode <= {26} && $switch == {'ZyXEL'} } {
		send "show mac address-table port $mode\r"
    if { $comp_e >= {0} } {
        send "show int $mode\r";
        send_space ;
        }
    if { $comp_c >= {0} } {
        send "cable-diagnostics $mode\r";
        }
    if { $comp_l >= {0} } {
        send "show logging ram\r"
        send_space
        send_space
        send_space
        send_space
        send_esc
        send_ctrl_c}
		interact
} elseif { $mode <= {28} && $switch == {4} } {
		send "show mac address-table interface gigabitEthernet 1/0/$mode\r"
    if { $comp_e >= {0} } {
        send "show error port $mode\r"
        send_ctrl_c }
    if { $comp_c >= {0} } {
        send "cable_diag ports $mode\r"
        send_ctrl_c }
    if { $comp_l >= {0} } {
        send "show log\r"
        send_n
        send_n
        send_n
        send_n
        send_ctrl_c }
		interact
} else {
	interact
}
