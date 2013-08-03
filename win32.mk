DMD=dmd
F=alarm

$F.exe: $F.d win.def
	$(DMD) -of$F $^
