transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/Truncate.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/squeeze_mod.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/SHAKE256.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/Pad.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/KeccakF1600.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/Convert_Digest.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/Control_Unit.v}
vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/src {D:/Documents/SHAKE256/src/Absorb.v}

vlog -vlog01compat -work work +incdir+D:/Documents/SHAKE256/.gitignore/test {D:/Documents/SHAKE256/.gitignore/test/tb_Shake256.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L rtl_work -L work -voptargs="+acc"  tb_Shake256

add wave *
view structure
view signals
run -all
