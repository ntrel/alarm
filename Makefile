F=alarm

all:
	dmd -w -of$F $F.d win.def
