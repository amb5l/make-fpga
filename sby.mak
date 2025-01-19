################################################################################
# sby.mak - support for formal verification of VHDL design units with SymbiYosys
# See https://github.com/amb5l/make-fpga
################################################################################
# TODO: unit specific mode, depth etc
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
.PHONY: sby_default sby_force
sby_default: sby
sby_force:
SBY_DIR?=sby

# checks
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
# Visual Studio Code

ifneq (0,$(SBY_EDIT))

SBY_EDIT_DIR=edit/sby

define rr_sby_symlink

$$(SBY_EDIT_DIR)/$1/$$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
	
endef
$(foreach u,$(SBY_UNIT),$(foreach s,$(SBY_SRC.$u),$(eval $(call rr_sby_symlink,$u,$s))))

define rr_sby_edit

edit:: $$(addprefix $$(SBY_EDIT_DIR)/$1/,$$(notdir $$(SBY_SRC.$1)))
	@cd $$(SBY_EDIT_DIR)/$1 && $$(if $$(filter,Windows_NT,$$(OS)),start )start code .

endef
$(foreach u,$(SBY_UNIT),$(eval $(call rr_sby_edit,$u)))

endif

################################################################################

help::
	$(call print_col,col_fi_cyn,  sby.mak)
	$(call print_col,col_fi_wht,  Support for formal verification with SymbiYosys and GHDL.)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fg_wht,    Goals:)
	$(call print_col,col_fi_grn,      sby       $(col_fg_wht)- run formal verification)
	$(call print_col,col_fi_grn,      edit      $(col_fg_wht)- create and open Visual Studio Code workspace directory for each unit)
	$(call print_col,col_fg_wht, )

################################################################################

clean::
	@rm -rf $(SBY_DIR)
