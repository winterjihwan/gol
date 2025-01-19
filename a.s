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
	cols			equ 4
	rows			equ 4
	nl 				db 0Ah
	rm 				db "Read me", 0, 10

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

%macro IF_BETZ 3
	cmp 			%2, 0
	jl 				.L_%1

	cmp 			%2, %3
	jge 			.L_%1
%endmacro

%macro IF_EQ 3
	cmp 			%2, %3
	jle 			.L_%1
%endmacro

%macro IF_LT 3
	cmp 			%2, %3
	jge 			.L_%1
%endmacro

%macro ENDIF 1
	.L_%1:
	%undef 		ENDIF_NAME
%endmacro

;; %1 - state
;; %2 - col index
;; %3 - row index
%macro STATE_CHG 3
	push 			rdx
	push 			rcx
	
	mov 			rdx, %2
	imul 			rdx, rows 		;; row_len * i
	mov 			rcx, plane
	add 			rcx, rdx
	add 			rcx, %3 			;; plane[row_len * i + j]

	mov 			byte [rcx], %1

	pop 			rcx
	pop 			rdx
%endmacro

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

	;; for j in range 0..rows
	.L3:
	cmp 			rbx, rows
	je 				.L4

	;; most inner body
	push 			rax 				;; clobber - fn neighbour

	mov 			rsi, rax
	mov 			rdi, rbx
	call 			neighbours

	IF_LT 		lt_2, rax, 2
		STATE_CHG	state_dead, rax, rbx
	ENDIF 		lt_2

	pop 			rax 				;; clobber - fn neighbour
	;; inner body end

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

;; %1 - name
%macro NB_OFFSET 1 
	IF_BETZ 	%1_s, rsi, cols
		IF_BETZ 	%1_d, rdi, rows
			ADDIF_NB_ALIVE 	%1_a, rsi, rdi
		ENDIF			%1_s
	ENDIF			%1_d
%endmacro

%macro R2_PUSH 2
	push %1
	push %2
%endmacro

%macro R2_POP 2
	pop %1
	pop %2
%endmacro

;; rsi - col index
;; rdi - row index
;;
;; rax - neighbours_count
neighbours:
	mov 			rax, 0

	R2_POP 		rdi, rsi
	dec 			rsi
	dec 			rdi 	;; plane[i-1][j-1]
	NB_OFFSET lu
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	dec 			rsi 	;; plane[i-1][j]
	NB_OFFSET u
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	dec 			rsi
	inc 			rdi 	;; plane[i-1][j+1]
	NB_OFFSET ru
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	inc 			rdi 	;; plane[i][j+1]
	NB_OFFSET r
	R2_PUSH 	rsi, rdi

	NB_OFFSET o 		;; plane[i][j]

	R2_POP 		rdi, rsi
	dec 			rdi 	;; plane[i][j-1]
	NB_OFFSET l
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	inc 			rsi
	dec 			rdi 	;; plane[i+1][j-1]
	NB_OFFSET ld
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	inc 			rsi 	;; plane[i+1][j]
	NB_OFFSET d
	R2_PUSH 	rsi, rdi

	R2_POP 		rdi, rsi
	inc 			rsi
	inc 			rdi 	;; plane[i+1][j+1]
	NB_OFFSET rd
	R2_PUSH 	rsi, rdi

	xor 			rsi, rsi
	xor 			rdi, rdi
	ret

entry:
	call 			plane_init

	alloc_one 2, 3

	call 			plane_dump
	call 			plane_advance
	call 			plane_dump

	exit 			0

_main:
	call entry
