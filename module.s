    GET     hdr.include
    AREA    |!!!Module$$Header|, CODE, READONLY, PIC
    IMPORT  |__RelocCode|
    ENTRY

;----------------------------------------------------------------------------
; Setting/Clearing V for errors. All other flags undefined
;----------------------------------------------------------------------------
    MACRO
    ClrErr
    cmp     R0,#0
    MEND

    MACRO
    SetErr
    cmp     R0,#1<<31
    cmnvc   R0,#1<<31
    MEND

;----------------------------------------------------------------------------
; Module Header
;----------------------------------------------------------------------------
module_base
    DCD     0                               ; Start address
    DCD     module_init     - module_base   ; Initialise code
    DCD     module_die      - module_base   ; Finalise code
    DCD     0                               ; Service call handler
    DCD     module_title    - module_base   ; Title
    DCD     module_help_str - module_base   ; Infomation string
    DCD     module_commands - module_base   ; CLI command table
    DCD     0                               ; SWI base
    DCD     0                               ; SWI handler
    DCD     0                               ; SWI names table
    DCD     0                               ; SWI decoding code
    DCD     0                               ; Messages filename
    DCD     module_flags    - module_base   ; Module flags

module_title
    DCB     "KeyMapper",0

module_help_str
    DCB     "KeyMapper",9,"1.00"
    DCB     " (":CC:("$BUILDDATE":RIGHT:11):CC:")"
    DCB     " © James Peacock",0
    ALIGN

module_flags
    DCD     1                               ; 32-bit compatible

;----------------------------------------------------------------------------
; Module initialisation
;----------------------------------------------------------------------------
; => r10 => Environment string
;    r11 =  0 or Instantiation No. or I/O base address
;    r12 => Private word
;    r13 =  Supervisor sp.
;
; <= Preserve Mode, Interrupt state, r7-r11,r13.
;    Can corrupt r0-r6,r12,r14, flags.
;    Return V set/R0=>Error block to stop module loading.

module_init
    mov     r6,r12
    ldr     ws,[r6]
    teq     ws,#0
    movne   pc,lr

    stmfd   sp!,{lr}
    bl      |__RelocCode|

    mov     r0,#6
    mov     r3,#no_keys
    swi     XOS_Module
    bvs     module_init_exit
    str     r2,[r6]
    mov     ws,r2

    mov     r0,#KeyV
    adr     r1,key_v
    swi     XOS_Claim
    bvs     module_init_failed

    bl      reset_key_map

    ClrErr

module_init_exit
    ldmfd   sp!,{pc}

module_init_failed
    mov     r5,r0
    mov     r0,#7
    mov     r2,ws
    swi     XOS_Module

    mov     r0,#0
    str     r0,[r6]

    mov     r0,r5
    SetErr
    ldmfd   sp!,{pc}

;----------------------------------------------------------------------------
; Module finalisation
;----------------------------------------------------------------------------
; => r10 =  Fatality: 0=>Non-fatal; 1=>Fatal
;    r11 =  Instantiation No.
;    r12 => Private word
;    r13 =  Supervisor sp.
;
; <= Preserve Mode, Interrupt state, r7-r11,r13.
;    Can corrupt r0-r6,r12,r14, flags.
;    Return V set/R0=>Error block to stop module being removed.

module_die
    mov     r6,r12
    ldr     ws,[r6]
    teq     ws,#0
    moveq   pc,lr

    stmfd   sp!,{lr}

    mov     r0,#KeyV
    adr     r1,key_v
    mov     r2,ws
    swi     XOS_Release
    ldmvsfd sp!,{pc}

    mov     r0,#7
    mov     r2,ws
    swi     XOS_Module

    ClrErr
    mov     r0,#0
    str     r0,[r6]
    ldmfd   sp!,{pc}


;----------------------------------------------------------------------------
; KeyV interception
;----------------------------------------------------------------------------
; => r0 = Reason code (only interested in KeyUp/KeyDown)
;    r1 = Internal Key Number
key_v
    teq     r0,#KeyV_KeyPressed
    teqne   r0,#KeyV_KeyReleased
    movne   pc,lr
    cmp     r1,#no_keys
    ldrlob  r1,[ws,r1]
    mov     pc,lr

;----------------------------------------------------------------------------
; *Command Table
;----------------------------------------------------------------------------
module_commands
    DCB     "KeyMap",0
    ALIGN
    DCD     command_key_map               - module_base
    DCD     &00020300
    DCD     command_key_map_syntax        - module_base
    DCD     command_key_map_help          - module_base
    DCB     "KeyMapReset",0
    ALIGN
    DCD     command_reset_key_map         - module_base
    DCD     &00020300
    DCD     command_reset_key_map_syntax  - module_base
    DCD     command_reset_key_map_help    - module_base
    DCD     0

;----------------------------------------------------------------------------
; *KeyMap <PhysicalKeyCode> <LogicalKeyCode>
;----------------------------------------------------------------------------
; => r0  => Command tail
;    r1  =  Number of parameters
;    r12 => Private word
;    r13 =  SVC stack pointer
;    r14 =  Return address
;
; <= r0  => Error block, if V set.
;    r0-r6,r12,r14, flags corruptable.

command_key_map
    stmfd   sp!,{lr}
    ldr     ws,[r12]

    bl      read_key_code
    bvs     command_key_map_exit
    cmn     r1,#1
    beq     command_key_map_dump_all
    mov     r2,r1                       ; r2 = physical key

    bl      read_key_code               ; r1 = logical key
    bvs     command_key_map_exit
    cmn     r1,#1
    beq     command_key_map_dump_one

    strb    r1,[ws,r2]

command_key_map_exit
    ldmfd   sp!,{pc}

command_key_map_dump_one
    mov     r0,r2
    bl      print_key_code
    bvs     command_key_map_exit
    swi     XOS_WriteS
    DCB     " --> ",0
    ALIGN
    ldrvcb  r0,[ws,r2]
    blvc    print_key_code
    swivc   XOS_NewLine
    b       command_key_map_exit

command_key_map_dump_all
    mov     r1,#0
command_key_map_dump_all_loop
    ldrb    r2,[ws,r1]
    teq     r1,r2
    beq     command_key_map_dump_all_skip

    mov     r0,r1
    bl      print_key_code
    bvs     command_key_map_exit
    swi     XOS_WriteS
    DCB     " --> ",0
    ALIGN
    movvc   r0,r2
    blvc    print_key_code
    swivc   XOS_NewLine

command_key_map_dump_all_skip
    add     r1,r1,#1
    cmp     r1,#no_keys
    bne     command_key_map_dump_all_loop
    b       command_key_map_exit

command_key_map_help
    DCB     "*",27,0," allows the internal key number returned when a "
    DCB     "keyboard key or mouse button (<from>) is pressed to be "
    DCB     "mapped to different value (<to>) before reaching the "
    DCB     "kernel. The key codes are internal key numbers (see the OS "
    DCB     "StrongHelp manual). If <to> is omitted, its current "
    DCB     "mapping is shown; if both keys are omitted, all mappings "
    DCB     "are shown.",13,10
command_key_map_syntax
    DCB     27,1," [<from> [<to>]]",0
    ALIGN

;----------------------------------------------------------------------------
; *ResetKeyMap
;----------------------------------------------------------------------------
command_reset_key_map
    stmfd   sp!,{lr}
    ldr     ws,[r12]
    bl      reset_key_map
    ClrErr
    ldmfd   sp!,{pc}

command_reset_key_map_help
    DCB     "*",27,0," removes all key mappings",13,10
command_reset_key_map_syntax
    DCB     27,1,0
    ALIGN

;----------------------------------------------------------------------------
; read_key_code
;----------------------------------------------------------------------------
; => r0 = Pointer to CTRL terminated string
;
; <= r0 Updated to end of key code/string terminator
;    r1 = Internal key number or -1 if none.
;
; V set, r0 => Error block tro return an error, r1 undefined.

read_key_code
    stmfd   sp!,{r2,lr}
read_key_code_loop
    ldrb    r14,[r0],#1
    cmp     r14,#32
    beq     read_key_code_loop
    sub     r0,r0,#1
    mvnlo   r1,#0
    blo     read_keu_code_exit

    mov     r1,r0
    mov     r0,#10
    orr     r0,r0,#1:SHL:29
    mov     r2,#no_keys-1
    swi     XOS_ReadUnsigned
    mvnvs   r1,#0
    ldmvsfd sp!,{r2,pc}
    mov     r0,r1
    mov     r1,r2

read_keu_code_exit
    ClrErr
    ldmfd   sp!,{r2,pc}

;----------------------------------------------------------------------------
; print_key_code
;----------------------------------------------------------------------------
; => r0 = Key code
; <= r0 Corrupted/error (if V set)
print_key_code
    stmfd   sp!,{r1-r2,lr}
    sub     sp,sp,#32
    mov     r1,sp
    mov     r2,#32
    swi     XOS_ConvertCardinal4
    swivc   XOS_Write0
    add     sp,sp,#32
    ldmfd   sp!,{r1-r2,pc}

;----------------------------------------------------------------------------
; reset_key_map
;----------------------------------------------------------------------------
; Corrupts R0, flags
reset_key_map
    mov     r0,#no_keys
reset_key_map_loop
    subs    r0,r0,#1
    strb    r0,[ws,r0]
    bne     reset_key_map_loop
    mov     pc,lr

    END
