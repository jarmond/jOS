;;; Simple bootloader for jOS
;;; (c)2012 J. W. Armond
;;; Written for NASM

;;; Memory map
;;; 100000 Top of low memory
;;; 00f000-09f000 Kernel preload (576 kb)
;;; 007c00-007dff Bootloader (512 bytes)
;;; 006000-007000 Real-mode stack
;;; 001000 GDT 8-byte aligned
;;; 000000 Reserved

;;; Disk map
;;; t0 h0 s1             bootloader
;;; t0 h0 s2..18         extended bootloader if needed
;;; t1..32 h0..1 s1..18  kernel
        
        [bits 16]               ; 16-bit mode
        org     0
        jmp     start
        nop
        
        ;; Data
        version         db      'JWA OS',13,10,0
        a20_error       db      'A20 err',13,10,0
        disk_error      db      'Disk err ',13,10,0
        drive_num       db      0

        kernel_tracks   equ     31
        kernel_seg      equ     0xf00
        kernel_off      equ     0x0
        kernel_start    equ     0xf000

start:  
        mov     ax, 0x7c0       ; bootloaders loaded from 0x7c00
        mov     ds, ax          ; setup data segment

        ;; Set up stack
        cli
        mov     ax, 0x600      ; put stack top at linear 0x07000
        mov     ss, ax
        mov     sp, 0x1000     ; stack grows down
        sti

        mov     [drive_num], dl   ; record drive number
        
        ;; Clear screen
        call    clear_screen

        ;; Set cursor to top left
        mov     ah, 0x02
        mov     bh, 0
        mov     dx, 0
        int     0x10
        
        ;; Print some infomation
        mov     si, version
        call    print_message

        ;; A20 gate enable
        mov     ax, 0x2401
        int     0x15
        cmp     ah, 0x86
        jz      a20_fail

        ;; Load kernel into memory
        mov     ah, 0           ; floppy controller reset
        int     0x13
        mov     cx, 1           ; track counter
        mov     dh, 0           ; start with head 0
        mov     dl, [drive_num] ; drive number
        mov     bx, kernel_seg  ; kernel preload segment
        mov     es, bx

read_track:
        shl     cx, 8           ; track to read to ch
        mov     cl, 1           ; sector to start
        mov     bx, 0           ; segment offset
read_head:      
        mov     ax, 0x0212      ; ah=0x02 (read sectors), al=18 sectors
        int     0x13
        
        cmp     dh, 0           ; if head 0, do head 1
        jnz     goto_next_track
        inc     dh              ; set head 1
        add     bx, 0x240       ; set disk buffer offset for next head
        jmp     read_head

        ;; Print track dot
        mov     ax, 0x0e2e      ; ah=0x0e, al='.'
        mov     bx, 0x07
        int     0x10

goto_next_track:
        mov     bx, es
        add     bx, 0x48        ; increment buffer addr by 0x480 bytes
                                ; = 1 track, 2 heads, 18 sectors
        mov     es, bx
        mov     dh, 0           ; return to head 0
        shr     cx, 8           ; restore track counter
        inc     cx              ; move to next track
        cmp     cx, kernel_tracks
        jnz     read_track      
        
        ;; Set protected mode
        mov     eax, cr0
        or      eax, 1
        mov     cr0, eax

        xchg    bx, bx

        ;; Reload segment registers
        jmp     0x08:reload_cs  ; Ring0 code descriptor
reload_cs:
        mov     ax, 0x10        ; Ring3 data descriptor
        mov     ds, ax
        mov     es, ax
        mov     fs, ax
        mov     gs, ax
        mov     ss, ax
        
        ;; Load kernel
        jmp dword 0:kernel_start
        
disk_fail:
        mov     si, disk_error
        call    print_message
        jmp     idle
        
a20_fail:
        mov     si, a20_error
        call    print_message
        
idle:
        hlt
        jmp     idle


;;; SUBROUTINES
        
;;; Clear screen
clear_screen:   
        mov     ax, 0x0700
        mov     bh, 0x07
        xor     cx, cx
        mov     dh, 24          ; 25 rows
        mov     dl, 79          ; 80 cols
        int     0x10

;;; Print message at ds:si
print_message:
        lodsb                   ; load a byte into al
        or      al, al
        jz      print_message_end ; if null, finished
        mov     ah, 0x0e        ; print char
        mov     bx, 0x07        ; grey on black, page zero
        int     0x10
        jmp     print_message
print_message_end:      
        ret


        
        ;; Pad to 512 bytes
        times   510-($-$$) db 0 ; pad with zeros
        dw      0xaa55          ; boot signature
        
