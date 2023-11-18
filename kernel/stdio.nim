type
  VGABuffer* = ptr array[0..2000, uint16]
  VGALine* = distinct range[0..24]
  VGACursor* = distinct range[0..79]
  FILE = object

# The design would be better done with a cursor object that holds a row and column type so that the operators don't refer to global variables
# but I'm not going to rewrite it.

var
  line: VGALine = 0.VGALine
  cursor: VGACursor = 0.VGACursor

proc `+=` (a: var VGALine, b: int) =
  a = ((a.int+b) mod 25).VGALine
  cursor = 0.VGACursor

proc `+=` (a: var VGACursor, b: int)  =
  a = ((a.int+b) mod 80).VGACursor
  if a.int == 0:
    line += 1

proc bufferAddress(): int =
  return cursor.int+(line.int*80)

var stdout* {.exportc.} : ptr FILE
var stderr* {.exportc.} : ptr FILE
const video_memory = cast[VGABuffer](0xB8000)

proc flockfile(f: ptr FILE) {.exportc.} = discard
proc funlockfile(f: ptr FILE) {.exportc.} = discard
proc fflush(stream: ptr FILE): cint {.exportc.} = 0.cint
proc fwrite(data: cstring, size: csize_t, nitems: csize_t, stream: ptr FILE): csize_t {.exportc.} =
  let
    backColour: byte = 0b00000000
    foreColour: byte = 0b00001111
    colour: byte = (backColour shl 4) or foreColour
  
  for i in 0..<size:
    var
      c = data[i]
      info = c.uint8 or (colour.uint16 shl 8)
    if c == '\n':
      line += 1
    else:
      video_memory[bufferAddress()] = info
      cursor += 1
  
  return nitems
