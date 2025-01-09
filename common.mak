################################################################################
# common.mak
# See https://github.com/amb5l/make-fpga
################################################################################

ifndef _common_mak_

define newline


endef
space      =$(subst x, ,x)
comma      =,
col_rst    =\033[0m
col_bg_blk =\033[0;100m
col_bg_red =\033[0;101m
col_bg_grn =\033[0;102m
col_bg_yel =\033[0;103m
col_bg_blu =\033[0;104m
col_bg_mag =\033[0;105m
col_bg_cyn =\033[0;106m
col_bg_wht =\033[0;107m
col_fg_blk =\033[0;30m
col_fg_red =\033[0;31m
col_fg_grn =\033[0;32m
col_fg_yel =\033[0;33m
col_fg_blu =\033[0;34m
col_fg_mag =\033[0;35m
col_fg_cyn =\033[0;36m
col_fg_wht =\033[0;37m
col_fi_blk =\033[1;30m
col_fi_red =\033[1;31m
col_fi_grn =\033[1;32m
col_fi_yel =\033[1;33m
col_fi_blu =\033[1;34m
col_fi_mag =\033[1;35m
col_fi_cyn =\033[1;36m
col_fi_wht =\033[1;37m

check_defined     = $(if $($1),,$(error $1 is undefined))
check_defined_alt = $(if $(foreach a,$1,$($a)),,$(error none of $1 are undefined))
check_option      = $(if $(filter $2,$($1)),,$(error $1 should be one of: $2))
check_shell_error = $(if $(filter 0,$(.SHELLSTATUS)),,$(error $1))
rest              = $(wordlist 2,$(words $1),$1)
chop              = $(wordlist 1,$(words $(call rest,$1)),$1)
src_dep           = $1<=$2
pairmap           = $(and $(strip $2),$(strip $3),$(call $1,$(firstword $2),$(firstword $3)) $(call pairmap,$1,$(call rest,$2),$(call rest,$3)))
nodup             = $(if $1,$(firstword $1) $(call nodup,$(filter-out $(firstword $1),$1)))
get_src_file      = $(foreach x,$1,$(word 1,$(subst =, ,$(word 1,$(subst ;, ,$x)))))
get_src_lib       = $(foreach x,$1,$(if $(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$2))
get_src_lang      = $(word 1,$(word 2,$(subst ;, ,$1)))
get_src_lrm       = $(if $(findstring VHDL-,$(call get_src_lang,$1)),$(word 2,$(subst -, ,$(call get_src_lang,$1))),$2)
get_src_lrm2      = $(if $(findstring 1987,$(call get_src_lrm,$1,$2)),87,$(if $(findstring 1993,$(call get_src_lrm,$1,$2)),93,$(if $(findstring 2002,$(call get_src_lrm,$1,$2)),02,$(if $(findstring 2008,$(call get_src_lrm,$1,$2)),08,$(if $(findstring 2019,$(call get_src_lrm,$1,$2)),19,?)))))
get_run_name      = $(foreach x,$1,$(word 1,$(subst =, ,$x)))
get_run_lib       = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 1,$(subst :, ,$(word 2,$(subst =, ,$1)))),$2)
get_run_unit      = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 2,$(subst :, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))),$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))
get_run_gen       = $(subst $(comma), ,$(word 2,$(subst ;, ,$1)))
banner            = @printf "$(col_bg_wht)$(col_fg_blu)-------------------------------------------------------------------------------$(col_rst)\n$(col_bg_wht)$(col_fg_blu) %-78s$(col_rst)\n$(col_bg_wht)$(col_fg_blu)-------------------------------------------------------------------------------$(col_rst)\n" "$1"
print_col         = @printf "$($1)$2$(if $3,$(comma)$3)$(if $4,$(comma)$4)$(if $5,$(comma)$5)$(col_rst)\n"

ifeq ($(OS),Windows_NT)
create_symlink=cmd /C "mklink $(subst /,\,$1) $(subst /,\,$2)"
MKDIR=$(XILINX_VIVADO)\gnuwin\bin\mkdir.exe
else
create_symlink=ln $2 $1
MKDIR=mkdir
endif

help::
	$(call print_col,col_fg_wht,)
	$(call print_col,col_fi_yel,make-fpga)
	$(call print_col,col_fi_wht,Support for driving FPGA synthesis, implementation and simulation from)
	$(call print_col,col_fi_wht,makefiles. See $(col_fi_blu)https://github.com/amb5l/make-fpga)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fg_wht,This makefile includes the following $(col_fi_yel)make-fpga$(col_rst) components.)
	$(call print_col,col_fg_wht,See inside each file for details of user variables.)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fi_wht,SPECIFY ONE OR MORE OF THE GOALS BELOW ON THE $(col_fi_mag)make$(col_fi_wht) COMMAND LINE.)
	$(call print_col,col_fg_wht, )

_common_mak_:=defined

endif
