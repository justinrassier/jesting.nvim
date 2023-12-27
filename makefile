test:
	echo "===> Testing"
	nvim --headless --noplugin -u scripts/tests/minimal.vim \
        -c "PlenaryBustedDirectory lua/jesting/test/ {minimal_init = 'scripts/tests/minimal.vim'}"
