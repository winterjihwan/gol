%macro exit 1
	mov rax, 0x02000001
	mov rdi, %1
	syscall
%endmacro

%define state_dead  2Eh
%define state_alive 2Ah

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
;;
;; No ret
print:
	push 			rax
	mov 			rax, 0x02000004
	mov 			rdi, 1
	syscall
	pop 			rax
	ret

;; No args
;;
;; No ret
plane_init:
	mov 			rax, 0 			;; i = 0
	mov 			rbx, 0 			;; j = 0

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	mov 			rdx, rax
	imul 			rdx, rows 		;; row_len * i

	;; for j in range 0..rows
	.L3:
	cmp 			rbx, rows
	je 				.L4

	;; most inner body
	mov 			rcx, plane
	add 			rcx, rdx
	add 			rcx, rbx 								;; plane[row_len * i + j]

	mov 			qword [rcx], state_dead	;; plane[row_len * i + j] = '.'

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
;;
;; No ret
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

;; %1 - col index
;; %2 - row index
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

	mov 			byte [rsi], state_alive		;; plane[row_len * i + j] = '.'

	ret

;; No args
;;
;; No ret
plane_advance:
	push 			rbp
	mov 			rbp, rsp

	sub 			rsp, 4 						;; 1 local var
	mov 			dword [rsp-4], 0 	;; l0 = 0

	mov 			rax, 0 			;; i = 0
	mov 			rbx, 0 			;; j = 0

	;; for i in 0..cols
	.L1:
	cmp 			rax, cols
	je 				.L2

	mov 			rdx, rax
	imul 			rdx, rows 		;; row_len * i

	;; for j in range 0..rows
	.L3:
	cmp 			rbx, rows
	je 				.L4

	;; most inner body
	mov 			rcx, plane
	add 			rcx, rdx
	add 			rcx, rbx 					;; plane[row_len * i + j]

	mov 			cl, byte [rcx]
	cmp 			cl, state_dead
	jne 			.L5

	;; is alive

	je 				.L6
	.L5:

	;; is dead

	.L6:

	inc 			rbx
	jmp				.L3
	.L4:

	;; reset j
	mov 			rbx, 0

	inc 			rax
	jmp				.L1
	.L2:

	mov 			rsp, rbp
	pop 			rbp
	ret

%macro IF_GTZ 2
	cmp 			%2, 0
	jle 			.L_%1
%endmacro

%macro IF_EQ 3
	cmp 			%2, %3
	jle 			.L_%1
%endmacro

%macro ENDIF 1
	.L_%1:
	%undef 		ENDIF_NAME
%endmacro

;; %1 	- col index
;; %2 	- row index
;; rax 	- nb_count
%macro ADDIF_NB_ALIVE 3
	push 			rcx
	push 			rdx

	mov 			rdx, %2
	imul 			rdx, rows 		;; row_len * i
	mov 			rcx, plane
	add 			rcx, rdx
	add 			rcx, %3 			;; plane[row_len * i + j]

	mov 			cl, byte [rcx]
	IF_EQ			%1, cl, state_dead
		inc 			rax
	ENDIF			%1

	pop 			rdx
	pop 			rcx
%endmacro

;; rsi - col index
;; rdi - row index
;;
;; rax - neighbours_count
neighbours:
	mov 			rax, 0

	dec 			rsi
	dec 			rdi 	;; plane[i-1][j-1]

	IF_GTZ 		lu_s, rsi
	IF_GTZ 		lu_d, rdi
	ADDIF_NB_ALIVE 	lu_a, rsi, rdi
	ENDIF			lu_s
	ENDIF			lu_d

	inc 			rdi 	;; plane[i-1][j]
	IF_GTZ 		u_s, rsi
	IF_GTZ 		u_d, rdi
	ADDIF_NB_ALIVE u_a, rsi, rdi
	ENDIF 		u_s
	ENDIF 		u_d

	inc 			rdi 	;; plane[i-1][j+1]
	IF_GTZ 		ru_s, rsi
	IF_GTZ 		ru_d, rdi
	ADDIF_NB_ALIVE ru_a, rsi, rdi
	ENDIF			ru_s
	ENDIF			ru_d

	inc 			rsi 	;; plane[i][j+1]
	IF_GTZ 		r_s, rsi
	IF_GTZ 		r_d, rdi
	ADDIF_NB_ALIVE r_a, rsi, rdi
	ENDIF			r_s
	ENDIF			r_d

	dec 			rdi 	;; plane[i][j]
	IF_GTZ 		o_s, rsi
	IF_GTZ 		o_d, rdi
	ADDIF_NB_ALIVE o_a, rsi, rdi
	ENDIF			o_s
	ENDIF			o_d

	dec 			rdi 	;; plane[i][j-1]
	IF_GTZ 		l_s, rsi
	IF_GTZ 		l_d, rdi
	ADDIF_NB_ALIVE 	l_a, rsi, rdi
	ENDIF			l_s
	ENDIF			l_d

	inc 			rsi 	;; plane[i+1][j-1]
	IF_GTZ 		ld_s, rsi
	IF_GTZ 		ld_d, rdi
	ADDIF_NB_ALIVE 	ld_a, rsi, rdi
	ENDIF			ld_s
	ENDIF			ld_d

	inc 			rdi 	;; plane[i+1][j]
	IF_GTZ 		d_s, rsi
	IF_GTZ 		d_d, rdi
	ADDIF_NB_ALIVE 	d_a, rsi, rdi
	ENDIF			d_s
	ENDIF			d_d

	inc 			rdi 	;; plane[i+1][j+1]
	IF_GTZ 		rd_s, rsi
	IF_GTZ 		rd_d, rdi
	ADDIF_NB_ALIVE 	rd_a, rsi, rdi
	ENDIF			rd_s
	ENDIF			rd_d

	xor 			rsi, rsi
	xor 			rdi, rdi
	ret

entry:
	call 			plane_init

	alloc_one 2, 3
	alloc_one 2, 4
	alloc_one 3, 4
	alloc_one 5, 4

	call 			plane_dump
	call 			plane_advance

	exit 			0

_main:
	call entry
