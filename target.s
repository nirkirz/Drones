
section .data
    extern CO_scheduler
    extern X_target
    extern Y_target
    scale_t1: dd 0
    scale_t2: dd 0
    Max_Short: dd 65535

section .bss
    extern Seed

section .text
    align 16
	global createTarget
	extern resume

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
    fild dword [Max_Short]                  ;input number
    fdivp                                   ;input / Max_Short
    fild dword [scale_t2]
    fild dword [scale_t1]
    fsubp
    fmulp                                   ;(input/Max_Short) * range
    fild dword [scale_t1]
    faddp                                   ;((input/Max_Short) * range) + left_border
    fstp dword %1
    ffree
    popad
%endmacro

createTarget:
    generate_random_number [X_target]       ;check if X_target or [X_target]
    t1t1:
    mov dword [scale_t1], 0
    mov dword [scale_t2], 100
    scale [X_target]
    generate_random_number [Y_target]
    t2t2:
    scale [Y_target]

resume_scheduler:
    mov ebx, CO_scheduler 
    call resume 
    jmp createTarget
