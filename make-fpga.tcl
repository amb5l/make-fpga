set tool [lindex $argv 0]
switch $tool {
	vivado -
	radiant {
		set cmd [lindex $argv 1]
		set args [lrange $argv 2 end]
		switch $cmd {
			script {
				set script [join $args " "]
				set r [eval $script]
				puts $r
				return $r
			}
			default {
				error {Unknown command: $cmd}
			}
		}
	
	}
	default {
		error {Unknown tool: $tool}
	}
}
