import stdio
import stdlib
import idt

type
  TMultiboot_header = object
  PMultiboot_header = ptr TMultiboot_header

proc kmain(mb_header: PMultiboot_header, magic: int) {.exportc.} =
  if magic != 0x2BADB002:
    discard

  let i = 104

  echo "Hello world!"
  echo "Other things."
  echo "hello", " ", i, " ", "test"
  echo "Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!Hello world!"

  idt.setupIDT()
  idt.loadIDT()
  idt.enableInterrupts()
