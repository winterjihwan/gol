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

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	;; for j in range 0..rows
	.L3:
	cmp 			rbx, rows
	je 				.L4

	;; most inner body
	mov 			r8, rax
	imul 			r8, rows
	add 			r8, rbx 		;; row_len * i + j
	mov 			r9, plane
	add 			r8, r9 			;; plane[row_len * i + j]

	mov 			QWORD [r8], 2Eh	;; plane[row_len * i + j] = '.'

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
	imul 			r8, rows
	mov 			r9, plane
	add 			r8, r9 			;; plane[row_len * i]

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

;; rsi - col index
;; rdi - row index
%macro alloc_one 2 
	mov 			rsi, %1
	mov 			rdi, %2
	call 			_alloc_one
%endmacro

_alloc_one:
	imul 			rsi, rows
	add 			rsi, rdi 			;; row_len * i + j
	mov 			rdi, plane
	add 			rsi, rdi 			;; plane[row_len * i + j]

	mov 			BYTE [rsi], 2Ah		;; plane[row_len * i + j] = '.'

	ret

entry:
	call 			plane_init

	alloc_one 2, 3
	alloc_one 2, 4
	alloc_one 3, 4
	alloc_one 5, 4

	call 			plane_dump

	exit 			0

_main:
	call entry
