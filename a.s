%macro exit 1
	mov rax, 0x02000001
	mov rdi, %1
	syscall
%endmacro

section .bss
	plane 		resq cols * rows

section .data
	cols			equ 16
	rows			equ 16
	nl 				db 0Ah

section .text
	global 		_main

;; rsi - str
;; rdx - len
print:
	push 			rax
	mov 			rax, 0x02000004
	mov 			rdi, 1
	syscall
	pop 			rax
	ret

;; No args
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

	mov 			QWORD [r8], 2Eh	;; plane[4i + j] = '.'

	inc 			rbx
	jmp				.L3
	.L4:

	;; reset j
	mov 			rbx, 0

	inc 			rax
	jmp				.L1
	.L2:

	ret

;; No args
plane_dump:
	mov 			rax, 0 			;; i = 0

	;; dev purposes
	mov 			rcx, 0

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	mov 			r8, rax
	imul 			r8, 4
	mov 			r9, plane
	add 			r8, r9 			;; plane[4i]

	mov 			rsi, r8
	mov 			rdx, cols
	call 			print 			;; print plane[ri]

	mov 			rsi, nl
	mov 			rdx, 1
	call 			print				;; print '\n'

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
