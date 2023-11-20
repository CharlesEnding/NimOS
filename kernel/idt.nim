import macros

type
  InterruptDescriptor  {.packed.} = object
    offset1: uint16   # offset bits 0..15
    selector: uint16  # code segment selector in GDT or LDT
    ist: uint8        # bits 0..2 holds Interrupt Stack Table offset, rest of bits zero
    typeAttributes: uint8  # gate type, dpl, and p fields
    offset2: uint16   # offset bits 16..31
    offset3: uint32   # offset bits 32..63
    zero: uint32      # reserved

  # AMD64 Architecture Programmer's Manual Volume 2, page 291.
  InterruptInformation {.packed, exportc.} = object
    instructionPointer: uint64
    codeSegment: uint64
    cpuFlags: uint64
    stackPointer: uint64
    stackSegment: uint64

  # Our interrupt wrapper pushes volatile registers on the stack, 
  # as well as the vector code, as well as the missing error code conditionally, 
  # so we need a new type for the interrupt handler's argument
  InterruptStack {.packed, exportc.} = object
    rdx: uint64
    rcx: uint64
    rax: uint64
    vector: uint64
    errorCode: uint64
    info: InterruptInformation

  # AMD64 Architecture Programmer's Manual Volume 2, page 267 & 268.
  # Note: bools are one byte in Nim.
  SelectorErrorCode {.packed.} = object
    external {.bitsize: 1.}: bool
    idt {.bitsize: 1.}: bool
    ldt {.bitsize: 1.}: bool
    selectorIndex {.bitsize: 13.}: uint16
    reserved: uint16

  # AMD64 Architecture Programmer's Manual Volume 2, page 267 & 268.
  PageFaultErrorCode {.packed.} = object
    p {.bitsize: 1.}: bool
    rw {.bitsize: 1.}: bool
    us {.bitsize: 1.}: bool
    rsv {.bitsize: 1.}: bool
    id {.bitsize: 1.}: bool
    reserved {.bitsize: 27.}: uint32

  # AMD64 Architecture Programmer's Manual Volume 2, page 249.
  Exception = enum
    DivideByZeroError
    Debug
    NonMaskableInterrupt
    Breakpoint
    Overflow
    BoundRange
    InvalidOpcode
    DeviceNotAvailable
    DoubleFault
    CoprocessorSegmentOverrun
    InvalidTSS
    SegmentNotPresent
    Stack
    GeneralProtection
    PageFault
    Reserved15
    X87FloatingPointExceptionPending
    AlignmentCheck
    MachineCheck
    SIMDFloatingPoint
    # Rest is reserved.


  IDTR  {.packed.} = object
    limit: uint16
    base: uint64


const IDTSize = 256
const erroringVectors = [8, 10, 11, 12, 13, 14, 17, 21, 29, 30]
var idt {.exportc.} : array[IDTSize, InterruptDescriptor]
var idtr {.exportc.} : IDTR
var interruptProcedures {.exportc.} : array[32, uint64]

proc interruptHandler*(stack: var InterruptStack) {.cdecl, exportc.} =
  echo "-------------------------------"
  echo "Interrupt #" & $stack.vector & " happened. Halting."
  echo Exception(stack.vector)
  if Exception(stack.vector) == PageFault:
    echo "Error:", cast[PageFaultErrorCode](stack.errorCode)
  else:
    echo "Error:", cast[SelectorErrorCode](stack.errorCode)
  echo repr(stack)
  asm """
    cli
    hlt
  """

# I don't know why we need to move rsp to rdi, despite using cdecl.
# If we don't the arguments is misaligned.
proc interruptWrapper*() {.exportc, asmNoStackFrame.} =
  asm """
    push %rax
    push %rcx
    push %rdx

    mov %rsp, %rdi
   
    call interruptHandler
   
    pop %rdx
    pop %rcx
    pop %rax

    add $16, %rsp

    iretq
  """

# We create procedures in a loop, one for each interrupt
# they're called vectorPusher0 to vectorPusher31
# Their only role is to push the appropriate interrupt vector
# on the stack, as well as to add a 0 error code for non-erroring
# interrupts, so that the stack is uniform in both cases.
macro createInterruptVectorPushers() =
  result = newStmtList()

  for iv in 0..<32:
    let name = ident("vectorPusher" & $iv)
    #var asmLiteral = "pushq $47806;jmp interruptWrapper"
    var asmLiteral = "pushq $" & $iv & ";jmp interruptWrapper"
    if not (iv in erroringVectors): asmLiteral = "pushq $0;" & asmLiteral
    let asmCode = newNimNode(nnkAsmStmt).add(newEmptyNode()).add(newLit(asmLiteral))

    result.add quote do:
      proc `name`(stack: var InterruptStack) {.exportc, asmNoStackFrame, cdecl.} =
        `asmCode`

  return result

createInterruptVectorPushers()


# Adds all vectorPusher functions to an array so we can refer
# to their address later when filling the IDT.
macro createVectorPusherArray() =
  result = newStmtList()

  for iv in 0..<32:
    let name = ident("vectorPusher" & $iv)
    let vector = newLit(iv)

    result.add quote do:
      interruptProcedures[`vector`] = cast[uint64](`name`)

  return result


proc setupInterrupt*(i: int) {.noconv, exportc.} =
  var address: uint64 = interruptProcedures[i]
  idt[i].offset1 = address.uint16
  idt[i].offset2 = (address shr 16).uint16
  idt[i].offset3 = (address shr 32).uint32
  idt[i].selector = 0x08
  idt[i].ist = 0
  idt[i].typeAttributes = 0x8E
  idt[i].zero = 0


proc setupIDT*() {.noconv, exportc.} =
  idtr.limit = IDTSize * sizeof(InterruptDescriptor) - 1
  idtr.base = cast[uint64](idt.addr)

  createVectorPusherArray()
  for i in 0..<32:
    setupInterrupt(i)


proc loadIDT*() =
  asm """
    lidt `idtr`
  """


proc enableInterrupts*() =
  asm """
    sti
  """
