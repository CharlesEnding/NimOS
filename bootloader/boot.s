
; boot.asm

; The label start is our entry point. We have to make it
; public so that the linker can use it.
global _start
; we are still in 32-bit protected mode so we have to use
; 32-bit wide instructions
bits 32

section .multiboot_header
header_start:
    dd 0xe85250d6                ; magic number (multiboot 2)
    dd 0                         ; architecture 0 (protected mode i386)
    dd header_end - header_start ; header length
    dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start)) ;checksum
    dw 0    ; type
    dw 0    ; flags
    dd 8    ; size
header_end:

section .bss
; must be page aligned
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
	resb 32768
stack_top:


section .text

PTE_PRESENT equ 1 << 7
PDE_PRESENT  equ 1 << 0
PDE_WRITABLE equ 1 << 1
PDE_LARGE    equ 1 << 7

set_up_page_tables:
    ; Step 5: Set the 0th entry of p3 to point to our p2 table
	mov eax, p2_table ; load the address of the p2 table
	or eax, (PDE_PRESENT | PDE_WRITABLE)
	mov [p3_table], eax

	; Step 6: Set the 0th entry of p4 to point to our p3 table
	mov eax, p3_table
	or eax, (PDE_PRESENT | PDE_WRITABLE)
	mov [p4_table], eax
	
	mov ecx, 0         ; counter variable

.map_p2_table:
    ; map ecx-th P2 entry to a huge page that starts at address 2MiB*ecx
    mov eax, 0x200000  ; 2MiB
    mul ecx            ; start address of ecx-th page
    or eax, 0b10000011 ; present + writable + huge
    mov [p2_table + ecx * 8], eax ; map ecx-th entry

    inc ecx            ; increase counter
    cmp ecx, 512       ; if counter == 512, the whole P2 table is mapped
    jne .map_p2_table  ; else map the next entry

    ret

_start:
    ; Step 3: Set `cr3` register
    mov eax, p4_table
    mov cr3, eax
    ; Step 2: Enable Physical Address Extension
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    call set_up_page_tables

	; Step 7: Set EFER.LME to 1 to enable the long mode
	mov ecx, 0xC0000080
	rdmsr
	or  eax, 1 << 8
	wrmsr
	; Step 8: enable paging
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

    lgdt [gdt64.pointer]
    jmp gdt64.code:longstart
   

extern kmain
bits 64
longstart:
	cli
    mov word [0xb8000], 0x0e4f ; 'O', yellow on black
    mov word [0xb8002], 0x0e4b ; 'K', yellow on black
    call kmain
    hlt


section .rodata
gdt64:
	dq 0
.code: equ $ - gdt64
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)
.pointer:
	dw $ - gdt64 - 1 ; length of the gdt64 table
	dq gdt64         ; addess of the gdt64 table
