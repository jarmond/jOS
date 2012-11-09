# Makefile for OS

CC=gcc
AS=nasm

CSRC=
ASRC=asm.asm

all: boot

boot: boot.img

boot.img: bootldr kernel
	dd if=/dev/zero bs=1k count=1440 of=$@
	dd if=bootldr bs=512 count=1 of=$@ conv=notrunc
	dd if=kernel.bin bs=512 seek=1 count=1440 of=$@ conv=notrunc

# Assemble bootloader.
bootldr: bootldr.asm
	nasm -f bin -l $@.lst -o $@ bootldr.asm

# Compile kernel main.
kernel_main: kernel.c
	gcc -m32 -nostdlib -c $<

# Compile kernel C source.
kernel_c: ${CSRC}
#	gcc -m32 -nostdlib -c $<

# Compile kernel assembly.
kernel_asm: ${ASRC}
	nasm -f macho -l $@.lst -o $@.o $<


# Compile kernel and strip header.
kernel: kernel_main kernel_c kernel_asm
#	ld $(CSRC:.c=.o) -o $@.bin --oformat=binary -Ttext=0x100000
	ld kernel.o kernel_asm.o $(CSRC:.c=.o) -o $@_1.bin -U start -arch i386 -macosx_version_min 10.5 -r
	dd if=$@_1.bin of=$@.bin ibs=240 skip=1


clean:
	rm -f bootldr *.lst boot.img *.o *.bin

