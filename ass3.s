CODEP	equ	0	     ; offset of pointer to co-routine function in co-routine struct 
SPP	    equ	4	     ; offset of pointer to co-routine stack in co-routine struct 
STKSIZE  equ 16*1024 		;16 Kb
;Max_Short equ 65535
;MAX_INT equ 2147483647
Board_Size equ 100

section .bss
    global number_Of_Drones, number_Of_Targets, number_Of_Steps, Beta, Distance, Seed
    global CORS_Pointer, CORS_Details, STKS_Pointer
    CORS_Pointer: resb 4
    STKS_Pointer: resb 4
    CURR_STK_PTR: resb 4
    CORS_Details: resb 4
    number_Of_Drones: resb 4 ;/* N */
    number_Of_Targets: resb 4 ;/* T */
    number_Of_Steps: resb 4 ;/* K */
    Beta: resb 4 ;/* beta */
    Distance: resb 4 ;/* D */
    Seed: resb 4 ;/* seed */
    CURR:	resd	1
    SPT:	resd	1   ; temporary stack pointer
    SPMAIN:	resd	1   ; stack pointer of main
    STK_target:	resb	STKSIZE
    STK_scheduler:	resb	STKSIZE
    STK_printer:	resb	STKSIZE

section .data
    global CO_scheduler, CO_target, CO_printer, X_target, Y_target
    temp: dd 0
    curr_co: dd 0

    ; Structure for target co-routine
    CO_target:	dd	createTarget
            	dd	STK_target+STKSIZE
    X_target:   dd 0
    Y_target:   dd 0

    ; Structure for scheduler co-routine
    CO_scheduler:	dd	scheduler_Function
                	dd	STK_scheduler+STKSIZE

    ; Structure for printer co-routine
    CO_printer:	dd	printer_Function
            	dd	STK_printer+STKSIZE

    scale_1: dd 0
    scale_2: dd 0
    Max_Short: dd 65535

section .rodata
    println: db 10,0
    format_decimal: db "%d", 0	;format string
    format_float: db "%f", 0	;format string

section .text
    align 16
    global main
    global do_resume
    global resume
    global endCo
    extern printf 
    extern fprintf
    extern sscanf
    extern malloc 
    extern free 
    extern drone_func
    extern createTarget
    extern scheduler_Function
    extern printer_Function

%macro cmp_jmp 4 
	cmp		%1, %2
	%3		%4
%endmacro

%macro scan_number 3
    pushad
    push dword %1           ;target
    push dword %2           ;format
    push dword %3           ;input source
    call sscanf
    add esp, 12 ; remove parameters
    popad
%endmacro



%macro generate_random_number 1
    pushad
    mov ecx, 16
    mov eax, [Seed]
    
    %%loop_generate:
    and eax, 1                          ;check index 0 (16)
    mov ebx, [Seed]
    and ebx, 4                          ;check index 2 (14)
    shr ebx, 2                          ;aligning eax and ebx
    xor eax, ebx                        ;eax saves the result

    mov edi, [Seed]
    and edi, 8                          ;check index 3 (13)
    shr edi, 3
    xor eax, edi                        ;eax saves the result

    mov edx, [Seed]
    and edx, 32                          ;check index 5 (11)
    shr edx, 5
    xor eax, edx

    shl eax, 15
    mov ebx, [Seed]
    shr ebx, 1
    or eax, ebx                         ;result in eax
    mov dword [Seed], eax               ;update the seed

    loop %%loop_generate, ecx

    mov dword %1, eax

    popad
%endmacro


%macro scale 1
    pushad
    finit
    fild dword %1
    fild dword [Max_Short]                       ;input number
    fdivp               ;input / Max_Short
    fild dword [scale_2]
    fild dword [scale_1]
    fsubp
    fmulp                                    ;(input/Max_Short) * range
    fild dword [scale_1]
    faddp                                ;((input/Max_Short) * range) + left_border
    fstp dword %1
    ffree
    popad
%endmacro



main:
    push ebp
    mov ebp, esp
    pushad
    pushfd
    
    mov ecx, dword [ebp+12] ;ebp+12 holds the address of argv
    mov dword [number_Of_Drones], 0
    scan_number number_Of_Drones, format_decimal, [ecx+4]
    scan_number number_Of_Targets, format_decimal, [ecx+8]
    scan_number number_Of_Steps, format_decimal, [ecx+12]
    scan_number Beta, format_float, [ecx+16]
    scan_number Distance, format_float, [ecx+20]
    scan_number Seed, format_decimal, [ecx+24]

    init_free_STKi:
    mov ebx, [number_Of_Drones]
    shl ebx, 2                  ;multiply by 4
    push ebx
    call malloc     ;allocate memory for STKS pointers array
    add esp,4

    mov [STKS_Pointer], eax     ;holds the address of the array of the STKS to be freed
    mov [CURR_STK_PTR], eax     ;holds the address of the current STK to be freed

    init_target:
    generate_random_number [X_target]           ;check if X_target or [X_target]
    mov dword [scale_1], 0
    mov dword [scale_2], 100
    scale [X_target]
    generate_random_number [Y_target]
    scale [Y_target]

    init_drones_structs_array:
    mov ebx, [number_Of_Drones]
    shl ebx, 2                  ;multiply by 4
    push ebx
    call malloc     ;allocate memory for drones array
    add esp,4

    mov [CORS_Pointer], eax     ;holds the address of the array of CO-is

    mov ecx, [number_Of_Drones]
    mov esi, [CORS_Pointer]

    loop_init_co_i:
    pushad
    push 8                          ;allocate 8 bytes for funci and SPi
    call malloc
    add esp, 4

    mov [esi], eax                  ;co-i received new memory aloocation of 8 bytes for Funci, SPi
    popad
    mov eax, [esi]                  ;eax holds the start of the 8bytes struct (Funci+ SPi)
    
    mov dword [eax+CODEP], drone_func           ;init funci

    add eax, SPP
    mov [temp], eax                 ;[temp] holds the SPi location
    
    init_stack_i:
    pushad
    push STKSIZE
    call malloc
    add esp, 4
        mov ebx, [CURR_STK_PTR]         ;recieve curr array cell
        mov [ebx], eax                  ;saves the stk in the array
        add ebx, 4                      ;inc to the next cell
        mov dword [CURR_STK_PTR], ebx   ;update curr stk
    mov ebx, [temp]
    add dword eax, STKSIZE
    mov dword [ebx], eax        ;holds the pointer to the top of the stack
    mov dword [temp], eax       ;[temp] holds the top of the STKi
    popad
    
    init_push_STKi:
    mov [SPT], esp              ;saves the esp
    mov esp, [temp]
    mov ebx, eax                ;saves the 
    sub eax, 4                  ;pointer to func-i
    mov eax, [eax]              ;eax holds func-i
    push eax                    ;push func-i
    pushfd
    pushad
    mov [ebx], esp              ; save new SPi value (after all the pushes)
    mov esp, [SPT]              ; restore ESP value

    add esi, 4                  ;increment the position of esi in the co-i array

    dec ecx
    cmp_jmp ecx, dword 0, jne, loop_init_co_i

    init_CO_scheduler:
    mov [SPT], esp              ;saves the esp
    mov esp, [CO_scheduler+SPP]
    mov eax, [CO_scheduler]     ;pointer to func-i- scheduler func
    push eax                    ;push func-i
    pushfd
    pushad
    mov [CO_scheduler+SPP], esp     ;save new SPi value (after all the pushes)
    mov esp, [SPT]              ;restore ESP value

    init_CO_printer:
    mov [SPT], esp              ;saves the esp
    mov esp, [CO_printer+SPP]
    mov eax, [CO_printer]       ;pointer to func-i- scheduler func
    push eax                    ;push func-i
    pushfd
    pushad
    mov [CO_printer+SPP], esp       ;save new SPi value (after all the pushes)
    mov esp, [SPT]              ;restore ESP value

    init_CO_target:
    mov [SPT], esp              ;saves the esp
    mov esp, [CO_target+SPP]
    mov eax, [CO_target]        ;pointer to func-i- scheduler func
    push eax                    ;push func-i
    pushfd
    pushad
    mov [CO_target+SPP], esp        ;save new SPi value (after all the pushes)
    mov esp, [SPT]              ;restore ESP value

    


    create_x_y_alpha_score_array:
    pushad
    mov eax, [number_Of_Drones]
    shl eax, 4                      ;multiply by 16 - 4 byte for each field
    push eax
    call malloc
    add esp,4 
    mov [CORS_Details], eax
    popad

    mov ecx, [number_Of_Drones]
    mov esi, [CORS_Details]

    init_drones_Details:
    mov dword [temp], 0
    generate_random_number [temp]
    ccc1:
    mov dword [scale_1], 0
    mov dword [scale_2], 100
    scale [temp]            ;scale x_cordinate
    mov edi, [temp]
    mov [esi], edi

    add esi, 4
    generate_random_number [temp]
    ccc2:
    
    scale [temp]            ;scale y_cordinate
    mov edi, [temp]
    mov [esi], edi

    add esi, 4
    generate_random_number [temp]
    ccc3:
    
    mov dword [scale_1], 0
    mov dword [scale_2], 360
    scale [temp]            ;scale alpha
    mov edi, [temp]
    mov [esi], edi

    add esi, 4
    mov dword [esi], 0              ;insert number of targets destroys = 0

    add esi, 4                      ;increment the position of esi in the details array
    ;loop init_drones_Details, ecx
    dec ecx
    cmp_jmp ecx, dword 0, jne, init_drones_Details



startCo:
	pushad			; save registers of main ()
	mov [SPMAIN], ESP		; save ESP of main ()
    mov ebx, CO_scheduler
    ;mov ebx, CO_printer

	jmp do_resume			; resume a scheduler co-routine


resume:	; save state of current co-routine
	pushfd
	pushad
	mov EDX, [CURR]
	mov [EDX+SPP], ESP   ; save current ESP
	
do_resume:  ; load ESP for resumed co-routine
	mov ESP, [EBX+SPP]
	mov [CURR], EBX
	popad  ; restore resumed co-routine state
	popfd
	ret        ; "return" to resumed co-routine

endCo:
	mov	ESP, [SPMAIN]              	; restore ESP of main()
	popad				; restore registers of main()

popfd
popad	
mov esp, ebp	
pop ebp
ret
