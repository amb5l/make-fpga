################################################################################
# sby.mak - support for formal verification of VHDL design units with SymbiYosys
# See https://github.com/amb5l/make-fpga
################################################################################
# TODO: unit specific mode, depth etc
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

SBY_DIR?=sby
$(call check_defined,SBY_UNIT)
$(foreach u,$(SBY_UNIT),$(call check_defined,SBY_SRC.$u))
$(foreach u,$(SBY_UNIT),$(call check_defined,SBY_MODE.$u))
$(foreach u,$(SBY_UNIT),$(call check_defined,SBY_DEPTH.$u))
$(foreach u,$(SBY_UNIT),$(call check_defined,SBY_ENGINE.$u))

define rr_sby

$$(SBY_DIR)/$1:
	$(MKDIR) -p $$@

$$(SBY_DIR)/$1.sby: $$(SBY_SRC.$1) $$(MAKEFILE_LIST) | $$(SBY_DIR)/$1
	$$(file >$$@,[options])
	$$(file >>$$@,mode $$(SBY_MODE.$1))
	$$(file >>$$@,depth $$(SBY_DEPTH.$1))
	$$(file >>$$@,$$(newline))
	$$(file >>$$@,[engines])
	$$(file >>$$@,$$(SBY_ENGINE.$1))
	$$(file >>$$@,$$(newline))
	$$(file >>$$@,[script])
	$$(file >>$$@,ghdl -fpsl --std=08 $$(SBY_SRC.$1) -e $1)
	$$(file >>$$@,prep -top $1)
	$$(file >>$$@,$$(newline))
	$$(file >>$$@,[files])
	$$(file >>$$@,$$(subst $$(space),$$(newline),$$(SBY_SRC.$1)))

$$(SBY_DIR)/$1/PASS: $$(SBY_DIR)/$1.sby
	@cd $$(dir $$<) && sby --yosys "yosys -m ghdl" -f $1.sby

sby:: $$(SBY_DIR)/$1/PASS

endef
$(foreach u,$(SBY_UNIT),$(eval $(call rr_sby,$u)))

################################################################################

help::
	$(call print_col,col_fi_cyn,  sby.mak)
	$(call print_col,col_fi_wht,  Support for formal verification with SymbiYosys and GHDL.)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fg_wht,    Goals:)
	$(call print_col,col_fi_grn,      sby       $(col_fg_wht)- run formal verification)
	$(call print_col,col_fg_wht, )

################################################################################

clean::
	@rm -rf $(SBY_DIR)
