X_tab equ 0
Y_tab equ 4
alpha_tab equ 8
score_tab equ 12

section .bss
    extern Seed
    extern CORS_Details
    extern CORS_Pointer
    extern STKS_Pointer
    extern number_Of_Targets
    extern number_Of_Drones
    extern Beta
    extern Distance

section .data
    extern CO_scheduler
    extern CO_target
    extern X_target
    extern Y_target
    extern drone_index
    scale_d1: dd 0
    scale_d2: dd 0
    delta_alpha: dd 0
    delta_distance: dd 0
    number_360: dd 360.0
    number_180: dd 180.0
    number_100: dd 100.0
    temp_no_use: dd 0.0
    gamma: dd 0.0
    Max_Short: dd 65535

section .rodata		
    format_winner: db "Drone id %d: I am a winner", 10, 0	;winner printing

section .text
    align 16
	extern resume
    global drone_func
    extern printf
    extern free

%macro cmp_jmp 4 
	cmp		%1, %2
	%3		%4
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
    fild dword [scale_d2]
    fild dword [scale_d1]
    fsubp
    fmulp                                    ;(input/Max_Short) * range
    fild dword [scale_d1]
    faddp                                ;((input/Max_Short) * range) + left_border
    fstp dword %1
    ffree
    popad
%endmacro


drone_func:

calculate_angel:                        ;generate a random number in range [-60,60] degrees, with 16 bit resolution
    mov dword [delta_alpha], 0
    checkd1:
    generate_random_number [delta_alpha]
    mov dword [scale_d1], -60
    mov dword [scale_d2], 60
    checkd2:
    scale [delta_alpha]                  ;scale
    
    mov dword [delta_distance], 0       ;generate random number in range [0,50], with 16 bit resolution        
    generate_random_number [delta_distance]
    mov dword [scale_d1], 0
    mov dword [scale_d2], 50
    scale [delta_distance]                  ;scale


    mov eax, [CORS_Details]
    ;mov eax, [eax]                      ;eax holds the start of the CORS_Details array
    mov ebx, [drone_index]
    ;mov ebx, [ebx]                     ;maybe drone index instead of [drone_index]
    shl ebx, 4
    add eax, ebx
    checkd3:
    finit
    fld dword [eax+alpha_tab]          ;load alpha
    fld dword [delta_alpha]            ;load delta
    faddp                              ;alpha+Delta_alpha -> new alpha
    fldz
    fcomi                              ;compare
    ja below_zero                       ;if 0 > alpha jmp below_zero
    
        check_greater_then_360:             ;because alpha>0
        faddp                               ;add number+0
        fld dword [number_360]
        fcomi                               ;if 360 => alpha jmp end_calc
        jae end_calc_alpha_remove_360
        fsubp                              ;reverse substraction and pop
        jmp end_calc_alpha

        below_zero:
        fld dword [number_360]
        faddp                               ;add 360+0
        faddp                               ;add (negative angel+360)
        jmp end_calc_alpha

        end_calc_alpha_remove_360:
        fstp dword [temp_no_use]
        
        end_calc_alpha:
        fstp dword [eax+alpha_tab]                    ;update the new alpha
    
    
    ;; cos(a) = (x'-x)/d  =>  d*cos(a) = x'-x  =>  x' = d*cos(a) + x
    ;; sin(a) = (y'-y)/d  =>  d*sin(a) = y'-y  =>  y' = d*sin(a) + y
    x_change_to_radians:
    finit
    fld dword [eax+alpha_tab]
    fldpi                               ;load pi
    fmulp
    fld dword [number_180]
    fdivp                               ;(alpha*pie)/180
    
        calc_new_x:
        fcos                                    ;overwrite st(0) and stores cos(alpha)
        fld dword [delta_distance]
        fmulp
        fld dword [eax+X_tab]                     ;load old x_value
        faddp                               
        fstp dword [eax+X_tab]                    ;stores new x value

        y_change_to_radians:
        finit
        fld dword [eax+alpha_tab]
        fldpi                               ;load pi
        fmulp
        fld dword [number_180]
        fdivp                               ;(alpha*pie)/180
        
        calc_new_y:
        fsin                                    ;overwrite st(0) and stores sin(alpha)
        fld dword [delta_distance]
        fmulp
        fld dword [eax+Y_tab]                     ;load old y_value
        faddp                               
        fstp dword [eax+Y_tab]                    ;stores new y value

            check_x_lower_then_zero:
            finit
            fld dword [eax+X_tab]                       ;load new x value
            fldz                                        ;load zero
            fcomi
            ja x_below_zero                             ;if 0>x jmp below_zero
            ;x>=0
            faddp                                       ;removes zero
            fld dword [number_100]
            fcomi                                       ;if 100> x jmp end
            ja x_end_distance_calc_remove_100
            x_greater_then_100:
            fsubp                                      ;x is greater then 100 so x-> x-100
            jmp x_end_distance_calc

            x_below_zero:
            faddp                                       ;removes zero
            fld dword [number_100]
            faddp                                       ;adds the negative x value+100
            jmp x_end_distance_calc

            x_end_distance_calc_remove_100:             ;0<=x<=100
            fstp dword [temp_no_use]                    ;removes 100

            x_end_distance_calc:
            fstp dword [eax+X_tab]

            check_y_values:

            check_y_lower_then_zero:
            finit
            fld dword [eax+Y_tab]                       ;load new y value
            fldz                                        ;load zero
            fcomi
            ja y_below_zero                             ;if 0>y jmp y_below_zero
            ;y>=0
            faddp                                       ;removes zero
            fld dword [number_100]
            fcomi                                       ;if 100>y jmp to end
            ja y_end_distance_calc_remove_100
            y_greater_then_100:
            fsubp                                      ;y is greater then 100 so y-> y-100
            jmp y_end_distance_calc

            y_below_zero:
            faddp                                       ;removes zero
            fld dword [number_100]
            faddp                                       ;adds the negative y value+100
            jmp y_end_distance_calc

            y_end_distance_calc_remove_100:             ;0<=y<=100
            fstp dword [temp_no_use]                    ;removes 100

            y_end_distance_calc:
            fstp dword [eax+Y_tab]

    call mayDestroy
    cmp dword eax, 1
    jne resume_scheduler

    ;may Destory
    mov eax, [CORS_Details]             ;eax holds the start of the CORS_Details array                     
    mov ebx, [drone_index]
    shl ebx, 4
    add eax, ebx
    inc dword [eax+score_tab]           ;check!
    mov dword ecx, [number_Of_Targets]
    cmp_jmp dword [eax+score_tab], ecx, jne, not_a_winner
    
    winner:
        mov dword ecx, [drone_index]
        inc ecx
        push ecx
        push format_winner
        call printf
        add esp, 8

        free_STKS:
        mov dword eax, [STKS_Pointer]
        mov dword ebx, [number_Of_Drones]

        loop_free_STKS:
        mov ecx, [eax]                  ;ecx holds the pointer to the STK
        pushad
        push ecx
        call free
        add esp, 4
        popad
        dec ebx
        add eax, 4

        cmp_jmp dword ebx, 0, jne, loop_free_STKS

        free_STKS_pointer:
        mov dword eax, [STKS_Pointer]
        push eax
        call free
        add esp, 4

        free_CORS_Details:
        mov dword eax, [CORS_Details]
        push eax
        call free
        add esp, 4

        free_CORS_Pointer_structs:
        mov dword eax, [CORS_Pointer]
        mov dword ebx, [number_Of_Drones]

        loop_8byte_struct:
        mov ecx, [eax]                  ;ecx holds the 8byte struct
        pushad
        push ecx
        call free
        add esp, 4
        popad
        add eax, 4
        dec ebx

        cmp_jmp dword ebx, 0, jne, loop_8byte_struct

        free_CORS_Pointer:
        mov dword eax, [CORS_Pointer]
        push eax
        call free
        add esp, 4


        exit:
        mov eax, 1                      ;exit system call
        mov ebx, 0                      ;exit(0)
        int 0x80


    
    not_a_winner:
    mov ebx, CO_target 
    call resume 
    jmp drone_func


mayDestroy:
    ;eax holds the current drone position

    ;mov edx, [Beta]                       ;Beta is in degrees
    finit
    fld dword [Y_target]                ;load y1
    fld dword [eax+Y_tab]               ;load y2
    fsubp
    fld dword [X_target]                ;load x1
    fld dword [eax+X_tab]               ;load x2
    fsubp
    fpatan                              ;arctan result is in radians
    fld dword [number_180]
    fmulp                               ;(gamma * 180)
    fldpi                               ;load pi
    fdivp                               ;(gamma * 180)/pie
    fstp dword [gamma]                   ;saves gamma in degrees
    
    check_abs_alpha_gamme:
    finit
    fld dword [gamma]                   ;load gamma
    fld dword [eax+alpha_tab]           ;load alpha in degrees
    fsubp
    fabs                                ;abs(gamma-alpha)
    fld dword [number_180]
    fcomi
    jae continue                        ;if abs(alpha-gamma) <= 180
    check_if_alpha_is_greater:
    fld dword [eax+alpha_tab]           ;load alpha in degrees
    fld dword [gamma]                   ;load gamma
    fcomi
    ja gamma_is_greater                 ;if gamma > alpha
    alpha_is_greater:                   ;add 360 to gamma
    fld dword [number_360]
    faddp
    fstp dword [gamma]                  ;update gamma
    jmp check_abs_alpha_gamme

    gamma_is_greater:
    fstp dword [temp_no_use]
    fld dword [number_360]
    faddp
    fstp dword [eax+alpha_tab]           ;update alpha
    jmp check_abs_alpha_gamme


    continue:
    fstp dword [temp_no_use]            ;remove number_180
    fld dword [Beta]
    fcomi
    jbe cant_destory                    ;if beta <= abs(alpha-gamma) jmp to cant destory

    check_sqrt:
    finit
    fld dword [eax+Y_tab]               ;load y2
    fld dword [Y_target]                ;load y1
    fsubp
    fst dword [temp_no_use]             ;save y2-y1 without popping
    fld dword [temp_no_use]             ;insert y2-y1
    fmulp                               ;(y2-y1)^2

    fld dword [eax+X_tab]               ;load x2
    fld dword [X_target]                ;load x1
    fsubp
    fst dword [temp_no_use]             ;save x2-x1 without popping
    fld dword [temp_no_use]             ;insert x2-x1
    fmulp                               ;(x2-x1)^2
    faddp
    fsqrt
    fld dword [Distance]
    fcomi
    jbe cant_destory                    ;if distance <= sqrt(^2+^2) jmp to cant destroy


    mov eax, 1                              ;value 1 = may destory
    ret
    
    cant_destory:
    mov eax, 0                              ;value 0 = fail to destroy
    ret


resume_scheduler:
    mov ebx, CO_scheduler 
    call resume 
    jmp drone_func

