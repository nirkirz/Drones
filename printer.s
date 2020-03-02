X_tab equ 0
Y_tab equ 4
alpha_tab equ 8
score_tab equ 12

section .data
    index_printer: dd 0
    loop_counter: dd 0
    extern X_target
    extern Y_target
    extern CO_scheduler

section .rodata
    println: db 10,0
    format_x_y: db "%.2f,%.2f", 10, 0	;format x,y
    format_drone: db "%d,%.2f,%.2f,%.2f,%d", 10, 0 ;drones format

section .bss
	extern CORS_Pointer
    extern CORS_Details
    extern number_Of_Drones

section .text
    align 16
    global printer_Function
	extern resume
    extern printf

%macro cmp_jmp 4 
	cmp		%1, %2
	%3		%4
%endmacro

printer_Function:
    mov dword edi, [number_Of_Drones]
    mov dword [loop_counter], edi
    mov dword [index_printer], 0
    mov dword eax, X_target
    mov dword ebx, Y_target

    finit
    sub esp, 8
    fld dword [ebx]               ;y coordinate
    fstp qword [esp]

    sub esp, 8
    fld dword [eax]               ;x coordinate]
    fstp qword [esp]

    push format_x_y 
    call printf
    add esp, 20                 ; clear the stack args for printf

    ;mov ecx, number_Of_Drones

print_loop:

    mov eax, CORS_Details
    mov eax, [eax]
    mov ebx, [index_printer]
    shl ebx, 4
    add eax, ebx
    ;pushad
    finit

    mov edx, [eax + score_tab]
    push edx                                   ;score

    sub esp, 8
    fld dword [eax + alpha_tab]                 ;alpha
    fstp qword [esp]

    sub esp, 8
    fld dword [eax + Y_tab]                     ;y
    fstp qword [esp]

    sub esp, 8
    fld dword [eax + X_tab]                     ;x
    fstp qword [esp]

    inc dword [index_printer]
    mov edx, [index_printer]
    push edx                                    ;drone index

    push format_drone
    call printf
    add esp, 36

    ffree ;?
    ;popad
    dec dword [loop_counter]
    cmp_jmp dword [loop_counter], 0, jne, print_loop

    
    ;loop print_loop, ecx
p_resume_scheduler:
    mov ebx, CO_scheduler 
    ;mov ebx, [ebx]                              ;ebx = scheduler
    call resume 
    jmp printer_Function
