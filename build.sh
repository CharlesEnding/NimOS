#!/bin/bash

# gcc -I ../bootloader -c -save-temps ../bootloader/boot.S  -m32
# as boot.s -o boot.o --32

nasm -felf64 ../bootloader/boot.s

# Build the kernel.
nim c ../kernel/kernel.nim

# nasm -felf ../bootloader/boot.s -o boot.o

mkdir -p iso/boot/grub
mv kernel.elf iso/boot/
cp ../grub/grub.cfg iso/boot/grub
grub-mkrescue -o image.iso iso
