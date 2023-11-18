
type
  InterruptDescriptor64  {.packed.} = object
    offset1: uint16   # offset bits 0..15
    selector: uint16  # code segment selector in GDT or LDT
    ist: uint8        # bits 0..2 holds Interrupt Stack Table offset, rest of bits zero
    typeAttributes: uint8  # gate type, dpl, and p fields
    offset2: uint16   # offset bits 16..31
    offset3: uint32   # offset bits 32..63
    zero: uint32      # reserved

# AMD64 Architecture Programmer's Manual Volume 2, page 291.
type
  InterruptHandlerStack {.packed, exportc.} = object
    instructionPointer: uint64
    codeSegment: uint64
    cpuFlags: uint64
    stackPointer: uint64
    stackSegment: uint64

type
  IDTR  {.packed.} = object
    limit: uint16
    base: uint64


const IDTSize = 256
const erroringVectors = [8, 10, 11, 12, 13, 14, 17, 21, 29, 30]
var idt {.exportc.} : array[IDTSize, InterruptDescriptor64]
var idtr {.exportc.} : IDTR


proc genericHandler*(stack: var InterruptHandlerStack) {.exportc, cdecl.} =
  echo "Generic happened. Halting.", stack
  asm """
    cli
    hlt
  """


proc errorHandler*(stack: var InterruptHandlerStack, error: uint64) {.exportc, cdecl.} =
  echo "Error happened. Halting.", stack
  echo "Error: ", error
  asm """
    cli
    hlt
  """


proc interruptWrapper*() {.exportc, asmNoStackFrame.} =
  asm """
    push %rax
    push %rcx
    push %rdx
   
    mov %rsp, %rax
    add $64, %rax
    push %rax
    call genericHandler
   
    pop %rdx
    pop %rcx
    pop %rax

    iretq
  """


proc errorInterruptWrapper*() {.exportc, asmNoStackFrame.} =
  asm """
    push %rax
    push %rcx
    push %rdx
   
    mov %rsp, %rax
    add $40, %rax
    push [%rax]
    add $32, %rax
    push %rax
    call errorHandler
    add $16, %rsp
    
    pop %rdx
    pop %rcx
    pop %rax
    
    iretq
  """


proc setupIDT*() {.noconv, exportc.} =
  var
    addrGeneric: uint64 = cast[uint64](interruptWrapper)
    addrError: uint64 = cast[uint64](errorInterruptWrapper)
    address: uint64
  idtr.limit = IDTSize * sizeof(InterruptDescriptor64) - 1
  idtr.base = cast[uint64](idt.addr)

  for i in 0..<32:
    if i in erroringVectors:
      address = addrError
    else:
      address = addrGeneric

    idt[i].offset1 = address.uint16
    idt[i].offset2 = (address shr 16).uint16
    idt[i].offset3 = (address shr 32).uint32
    idt[i].selector = 0x08
    idt[i].ist = 0
    idt[i].typeAttributes = 0x8E
    idt[i].zero = 0


proc loadIDT*() =
  asm """
    lidt `idtr`
  """


proc enableInterrupts*() =
  asm """
    sti
  """
