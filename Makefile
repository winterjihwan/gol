FLAGS=-static
LIBS=print_n.o
# -e _start

a: a.s
	nasm -gdwarf -f macho64 a.s -o a.o
	ld -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib \
		-L/usr/local/lib -lSystem $(LIBS) a.o -o a

a_static: a.s
	nasm -gdwarf -f macho64 a.s -o a.o
	ld $(FLAGS) a.o -o a
	
