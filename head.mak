################################################################################
# head.mak
# See https://github.com/amb5l/make-fpga
################################################################################

.PHONY: all clean

toplevel=$(call xpath,$(shell git rev-parse --show-toplevel))

space:=$(subst x, ,x)
comma:=,
col_rst:=\033[0m
col_bg_blk:=\033[0;100m
col_bg_red:=\033[0;101m
col_bg_grn:=\033[0;102m
col_bg_yel:=\033[0;103m
col_bg_blu:=\033[0;104m
col_bg_mag:=\033[0;105m
col_bg_cyn:=\033[0;106m
col_bg_wht:=\033[0;107m
col_fg_blk:=\033[1;30m
col_fg_red:=\033[1;31m
col_fg_grn:=\033[1;32m
col_fg_yel:=\033[1;33m
col_fg_blu:=\033[1;34m
col_fg_mag:=\033[1;35m
col_fg_cyn:=\033[1;36m
col_fg_wht:=\033[1;37m

xpath=$(if $(filter Windows_NT,$(OS)),$(shell cygpath -m "$1"),$1)
check_defined=$(if $($1),,$(error $1 is undefined))
check_defined_alt=$(if $(foreach a,$1,$($a)),,$(error none of $1 are undefined))
check_option=$(if $(filter $2,$($1)),,$(error $1 should be one of: $2))
check_shell_error=$(if $(filter 0,$(.SHELLSTATUS)),,$(error $1))

define banner
@bash -c " \
	printf '$(col_bg_wht)$(col_fg_blu)*******************************************************************************$(col_rst)\n'; \
	printf '$(col_bg_wht)$(col_fg_blu) %-78s$(col_rst)\n' '$1'; \
	printf '$(col_bg_wht)$(col_fg_blu)*******************************************************************************$(col_rst)\n'; \
	"
endef
