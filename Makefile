FLAGS=-static
LIBS=
# -e _start

gol: gol.s
	nasm -gdwarf -f macho64 gol.s -o gol.o
	ld -w -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib \
		-L/usr/local/lib -lSystem $(LIBS) gol.o -o gol
