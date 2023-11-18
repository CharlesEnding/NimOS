/* Tell the linker that we want an x86_64 ELF64 output file */
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)

ENTRY(_start)

SECTIONS {
    . = 0x100000;

    .boot :
    {
        *(.multiboot_header)
    }

    .text  BLOCK(4K) : ALIGN(4K)
    {
        *(.text)
    }

    .rodata  BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
    }

    .data  BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }

    .bss  BLOCK(4K) : ALIGN(4K)
    {
        *(.bss)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.note .note.*)
    }
}
