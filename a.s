%macro exit 1
	mov rax, 0x02000001
	mov rdi, %1
	syscall
%endmacro

%macro print 2
	mov rax, 0x02000004
	mov rdi, 1
	mov rsi, %1
	mov rdx, %2
	syscall
%endmacro

section .bss
	plane 		resq cols * rows

section .data
	cols			equ 4
	rows			equ 4

section .text
	global 		_main

plane_init:
	mov 			rax, 0 			;; i = 0
	mov 			rbx, 0 			;; j = 0

	;; dev purposes
	mov 			rcx, 0
	mov 			rdx, 0

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	;; for j in range 0..rows
	.L3:
	cmp 			rbx, rows
	je 				.L4

	;; dev purposes
	mov 			rcx, rax
	mov 			rdx, rbx

	;; most inner body
	mov 			r8, rax
	imul 			r8, 4
	add 			r8, rbx 		;; 4i + j
	mov 			r9, plane
	add 			r8, r9 			;; plane[4i + j]

	mov 			QWORD [r8], 30h	;; plane[4i + j] = 'a'

	inc 			rbx
	jmp				.L3
	.L4:

	;; reset j
	mov 			rbx, 0

	inc 			rax
	jmp				.L1
	.L2:

	ret

plane_dump:
	mov 			rax, 0 			;; i = 0

	;; dev purposes
	mov 			rcx, 0

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	;; most inner body
	mov 			r8, rax
	imul 			r8, 4
	mov 			r9, plane
	add 			r8, r9 			;; plane[4i]

	print 		r8, cols

	mov 			r8, '10'
	print 		r8, 1

	inc 			rax
	jmp				.L1

	.L2:
	ret


entry:
	call 			plane_init
	call 			plane_dump

	exit 			0

_main:
	call entry
