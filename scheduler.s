CODEP	equ	0	     ; offset of pointer to co-routine function in co-routine struct 
SPP	    equ	4	     ; offset of pointer to co-routine stack in co-routine struct 
section .bss
	extern number_Of_Drones
	extern number_Of_Targets
	extern number_Of_Steps
	extern Beta
	extern Distance
	extern Seed
	extern CORS_Pointer


section .data
    global drone_index
	drone_index: dd 0
	print_index: dd 0
	extern CO_printer
	

section .text
    align 16
    global scheduler_Function
	extern resume
	


%macro cmp_jmp 4 
	cmp		%1, %2
	%3		%4
%endmacro

;init_scheduler_Function:
scheduler_Function:
	mov eax, [drone_index]
	shl eax, 2			;mult eax 4
	mov ebx, [CORS_Pointer]
	add ebx, eax		;ebx hold the address of CO_i
	mov ebx, [ebx]		;ebx holds co_1 CODEP
	call resume
	;end of drone func
	inc dword [drone_index]
	inc dword [print_index]
	mov dword edi, [print_index]
	cmp_jmp edi, [number_Of_Steps], jne, check_index
	;equal = print
	print:
	mov dword[print_index], 0		;reset printer index to 1
	mov ebx, CO_printer 
    ;mov ebx, [ebx] ; ebx = scheduler co struct
    call resume ; resume scheduler


	check_index:
	mov dword edi, [drone_index]
	cmp_jmp edi, [number_Of_Drones], jne, scheduler_Function
	mov dword [drone_index], 0			;reset drones inedx to 0
	
	jmp scheduler_Function


; 	(*) start from i=1
; (*) switch to the i’s drone co-routine
; (*) i++
; (*) if i == K there is a time to print the game board
;     (*) switch to the printer co-routine
