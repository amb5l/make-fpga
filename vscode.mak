################################################################################
# vscode.mak
# See https://github.com/amb5l/make-fpga
################################################################################

# defaults
VSCODE_DIR?=vscode
ifndef VSCODE_LIB
VSCODE_LIB=work
VSCODE_SRC.work?=$(VSCODE_SRC)
endif

# checks
$(call check_defined,VSCODE_TOP)
$(call check_defined,VSCODE_LIB)
$(foreach l,$(VSCODE_LIB),$(call check_defined,VSCODE_SRC.$l))

################################################################################
# rules and recipes

# workspace directory
$(VSCODE_DIR):
	@bash -c "mkdir -p $@"

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(VSCODE_LIB),$(eval $l: $(addprefix $$(VSCODE_DIR)/$l/,$(notdir $(VSCODE_SRC.$l)))))

# symbolic links to library/source files
ifeq ($(OS),Windows_NT)
define rr_srclink
$$(VSCODE_DIR)/$1/$(notdir $2): $2
	@bash -c "mkdir -p $$(dir $$@)"
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
endef
else
define rr_srclink
$$(VSCODE_DIR)/$1/$(notdir $2): $2
	@mkdir -p $$(dir $$@)
	@ln $$< $$@
endef
endif
$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
ifeq ($(OS),Windows_NT)
define rr_auxlink	
$$(VSCODE_DIR)/$(notdir $1): $1
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
endef
else
define rr_auxlink
$$(VSCODE_DIR)/$(notdir $1): $1
	@ln $$< $$@
endef
endif
$(foreach a,$(VSCODE_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(VSCODE_DIR)/config.v4p: force $(VSCODE_LIB)
	@echo "[libraries]" > $@
	@$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),echo "$l/$(notdir $s)=$l" >> $@;))
	@echo "[settings]" >> $@
	@echo "V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(VSCODE_TOP))" >> $@

################################################################################
# goals	

.PHONY: edit

edit: $(VSCODE_DIR)/config.v4p $(addprefix $(VSCODE_DIR)/,$(VSCODE_LIB)) $(foreach x,$(VSCODE_XDC),$(VSCODE_DIR)/$(notdir $(word 1,$(subst =, ,$x)))) $(addprefix $(VSCODE_DIR)/,$(notdir $(VSCODE_AUX)))
	@code $(VSCODE_DIR)

clean::
	@rm -rf $(VSCODE_DIR)
