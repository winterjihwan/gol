%macro exit 1
	mov rax, 0x02000001
	mov rdi, %1
	syscall
%endmacro

%define state_dead  2Eh
%define state_alive 2Ah

section .bss
	plane 		resb cols * rows
	plane_new resb cols * rows
	num_len 	resb 1

section .data
	cols			equ 16
	rows			equ 16
	nl 				db 0Ah
  clear_esc db 0x1B, '[2J', 0x1B, '[H', 0

section .text
	global 		_main
	extern 		print_n
	extern 		_usleep

;; rsi - str
;; rdx - len
;;
;; No ret
print:
	push 			rax
	mov 			rax, 02000004h
	mov 			rdi, 1
	syscall
	pop 			rax
	ret

;; rsi - str
;; rdx - len
;;
;; No ret
clear:
	push 			rax
	push 			rdx
	push 			rsi
	push 			rdi

 	mov 			rax, 02000004h
 	mov 			rdi, 1
 	lea 			rsi, [rel clear_esc]
 	mov 			rdx, 8
 	syscall

	pop 			rdi
	pop 			rsi
	pop 			rdx
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

	mov 			byte [rcx], state_dead	;; plane[row_len * i + j] = '.'

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
	jne 			.L_%1
%endmacro

%macro IF_LT 3
	cmp 			%2, %3
	jge 			.L_%1
%endmacro

%macro IF_GT 3
	cmp 			%2, %3
	jle 			.L_%1
%endmacro

%macro ENDIF 1
	.L_%1:
	%undef 		ENDIF_NAME
%endmacro

;; %1 - state
;; %2 - col index
;; %3 - row index
;;
;; important: plane_new is used
%macro STATE_CHG 3
	push 			rdx
	push 			rcx

	xor 			rcx, rcx
	xor 			rdx, rdx
	
	mov 			rdx, %2
	imul 			rdx, rows 		;; row_len * i
	mov 			rcx, plane_new
	add 			rcx, rdx
	add 			rcx, %3 			;; plane_new[row_len * i + j]

	mov 			byte [rcx], %1

	pop 			rcx
	pop 			rdx
%endmacro

;; %1 - col pos
;; %2 - row pos
%macro NL_PRINT 0
	push 			rsi
	push 			rdi
	push 			rdx
	mov 			rsi, nl
	mov 			rdx, 1
	call 			print				;; '\n'
	pop 			rdx
	pop 			rdi
	pop 			rsi
%endmacro

;; %1 - col pos
;; %2 - row pos
%macro PLANE_POS_PRINT 2
	push 			rax
	mov 			rax, %1
	call 			print_n 	;; xcord
	mov 			rax, %2
	call 			print_n 	;; ycord
	pop 			rax
%endmacro

;; %1 - src plane
;; %2 - dst plane
%macro PLANE_MOV 2
	push 			rsi
	push 			rdi
	push 			rcx

	lea 			rsi, [rel %1]
	lea 			rdi, [rel %2]
	mov 			rcx, rows * cols

	cld
	rep 			movsb

	pop 			rcx
	pop 			rdi
	pop 			rsi
%endmacro

;; No args
;;
;; No ret
plane_advance:
	PLANE_MOV	plane, plane_new
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

	mov 			r8, rax
	mov 			r9, rbx

	mov 			rsi, rax
	mov 			rdi, rbx
	call 			neighbours

	;; Rule 1
	;;
	;; Any live cell with fewer than two live neighbours dies,
	;; as if by underpopulation.
	IF_LT 		lt_2, rax, 2
		STATE_CHG				state_dead, r8, r9
	ENDIF 		lt_2

	;; Rule 3
	;;
	;; Any live cell with more than three live neighbours dies,
	;; as if by overpopulation.
	IF_GT 		gt_3, rax, 3
		STATE_CHG				state_dead, r8, r9
	ENDIF 		gt_3

	;; Rule 4
	;;
	;; Any dead cell with exactly three live neighbours becomes a live cell,
	;; as if by reproduction.
	IF_EQ 		eq_3, rax, 3
		STATE_CHG				state_alive, r8, r9
	ENDIF 		eq_3


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

	PLANE_MOV	plane_new, plane
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
	IF_EQ			%1, cl, state_alive
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

	R2_PUSH 	rdi, rsi
	dec 			rsi
	dec 			rdi 	;; plane[i-1][j-1]
	NB_OFFSET lu
	R2_POP 		rsi, rdi

	R2_PUSH 	rdi, rsi
	dec 			rsi 	;; plane[i-1][j]
	NB_OFFSET u
	R2_POP	 	rsi, rdi

	R2_PUSH 	rdi, rsi
	dec 			rsi
	inc 			rdi 	;; plane[i-1][j+1]
	NB_OFFSET ru
	R2_POP 		rsi, rdi

	R2_PUSH 	rdi, rsi
	inc 			rdi 	;; plane[i][j+1]
	NB_OFFSET r
	R2_POP 		rsi, rdi
	
	R2_PUSH 	rdi, rsi
	dec 			rdi 	;; plane[i][j-1]
	NB_OFFSET l
	R2_POP 		rsi, rdi
	
	R2_PUSH 	rdi, rsi
	inc 			rsi
	dec 			rdi 	;; plane[i+1][j-1]
	NB_OFFSET ld
	R2_POP 		rsi, rdi

	R2_PUSH 	rdi, rsi
	inc 			rsi 	;; plane[i+1][j]
	NB_OFFSET d
	R2_POP	 	rsi, rdi

	R2_PUSH 	rdi, rsi
	inc 			rsi
	inc 			rdi 	;; plane[i+1][j+1]
	NB_OFFSET rd
	R2_POP 		rsi, rdi

	ret

entry:
	call 			plane_init

	;; allocate few dummies on the plane
	alloc_one 4, 2
	alloc_one 3, 3
	alloc_one 2, 4
	alloc_one 3, 5
	alloc_one 4, 6
	alloc_one 5, 5
	alloc_one 6, 4
	alloc_one 5, 3

	.L1:
	call 			plane_dump
	call 			plane_advance
  mov 			rdi, 100000
  call 			_usleep
	call			clear
	jmp 			.L1

	exit 			0

_main:
	call entry
