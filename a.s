%macro exit 1
	mov rax, 0x02000001
	mov rdi, %1
	syscall
%endmacro

section .bss

section .data
	cols			equ 16
	rows			equ 16
	plane 		dq cols * rows

section .text
	global 		_main

entry:
	mov rax, 1
	int3
	mov rbx, 1
	exit 			0

_main:
	call entry
