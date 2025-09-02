# FLASH MEMORY WRITER for Raspberry Pi
# DIY FC/GB/PCE/P6 CARTRIDGE
# BY TAKUYA MATSUBARA
import os
import spidev
import time
import RPi.GPIO as GPIO

KILO = 1024
MEGA = 1024*1024
ADR1M = int(1*MEGA/8) #ADDRESS
ADR2M = int(2*MEGA/8) #ADDRESS
ADR4M = int(4*MEGA/8) #ADDRESS
ADR8M = int(8*MEGA/8) #ADDRESS

SAFE       = 18 #GPIO NUMBER
READENABLE = 23 #GPIO NUMBER
CHIPSEL    = 24 #GPIO NUMBER
WE         = 25 #GPIO NUMBER
CPURW      = 22 #GPIO NUMBER

spi = spidev.SpiDev()
spi.open(0, 0)
spi.mode = 0
spi.max_speed_hz = 400000

#---
def fileselect(filter_ext):
    ext_len = len(filter_ext)
    print("SELECT IMAGE FILE(*"+filter_ext+")")
    #カレントディレクトリの一覧
    filelist = os.listdir()
    fileindex = []
    index = 0
    for file in filelist:
        if file[-ext_len:].upper()==filter_ext:
            index = index+1
            print(" "+str(index)+": "+file)
            fileindex.append(index)
        else:
            fileindex.append(0)

    if index ==0:
        print("Error:File not found")
        return ""
        
    num = input("SELECT NUMBER?(1-"+str(index)+"):")
    if num=="" :
        return ""

    num = int(num)
    if num<=0 or num>index:
        return ""
    
    index = fileindex.index(num)
    print("FILE NAME:"+filelist[index])    
    return filelist[index]

#---
def romread():
    GPIO.output(READENABLE,GPIO.LOW)
    #GPIO.output(READENABLE,GPIO.HIGH)
    GPIO.output(CHIPSEL,GPIO.HIGH)
    GPIO.output(WE,GPIO.HIGH)
    mcp23s17setdatamode(0) #0:INPUT/1:OUTPUT
    print("READ ROM 256 BYTES")

    a=input("ADDRESS(HEX)?:")
    if a=="":a="0"
    romadr = int(a,16)
    if hard==4 : #PC-6001よう とくべつしょり
        if romadr < 0x4000 : romadr=0x4000

    time.sleep(0.00005)
    work = ""
    work2 = ""
    for i in range(0x100):
        clkwait()
        mcp23s17setadr(romadr)
        clkwait()
        GPIO.output(READENABLE,GPIO.LOW) #READ ENABLE
        GPIO.output(CHIPSEL,GPIO.LOW)
        time.sleep(0.00025)
        clkwait()
        readdata = mcp23s17getdata()
        # GPIO.output(READENABLE,GPIO.HIGH)
        GPIO.output(CHIPSEL,GPIO.HIGH)

        x = romadr % 16
        if x==0 :
            if work!="" : print(work,work2)
            work = "{:08X}".format(romadr)+":"
            work2 = "|"

        work += "{:02X}".format(readdata)
        work += " "
        work2 += code2chr(readdata)
        romadr = romadr+1

    if work!="" :
        print(work,work2)

    #GPIO.output(READENABLE,GPIO.HIGH)
    GPIO.output(CHIPSEL,GPIO.HIGH)

#---
def romwrite():
    print("WRITE IMAGE TO ROM")
    filename = fileselect(ext)
    if filename=="" : return
    
    f = open(filename, 'rb')
    bindata = f.read()
    f.close()
    bufsize = len(bindata)

    print("READ "+str(bufsize)+" BYTES("+str(int(bufsize*8/MEGA))+"M BITS)")

    GPIO.output(WE,GPIO.HIGH)  #DISABLE
    GPIO.output(READENABLE,GPIO.HIGH)  #DISABLE
    GPIO.output(CHIPSEL,GPIO.HIGH)  #DISABLE

    mcp23s17setdatamode(1) #0:INPUT/1:OUTPUT

    if inputyn()=="n" : return

    errflag = 0
    startcnt = time.time()

    work = ""
    startadr = 0
    endadr = bufsize-1-headersize
    binptr = headersize
    if hard==1: #Famicom
        prgromsize = 16*KILO*bindata[4]
        endadr = prgromsize-1

    if hard==4 : #PC-6001よう とくべつしょり
        startadr = startadr+0x4000
        endadr = endadr+0x4000

    romadr = startadr
    while 1:
        if romadr==endadr:break
        if romadr>=rombytemax : break
        if binptr>=bufsize : break
        writedata = bindata[binptr]
        flashwritebyte(romadr,writedata)

        if (romadr & 0xff)==0 :
            work = "WRITE ADR. "
            work += "{:08X}".format(romadr)+"/"
            work += "{:08X}".format(endadr)            
            work += "("+str(int(romadr*100/bufsize))+"%)"
            print(work)

        if errflag :
            return

        binptr += 1
        romadr += 1

    if work!="" :
        print(work)
    
    mcp23s17setdatamode(0) #0:INPUT/1:OUTPUT
    if errflag :
        return

    print()
    print("COMPLETE")
    endcnt = time.time()
    worktime = int((endcnt - startcnt)/60)
    print("RUNNING TIME:"+str(worktime)+" MINUTE")

#---
def flashchiperase():
    print("FLASH MEMORY CHIP ERASE")
    if inputyn()=="N" : return

    for romadr in range(0, rombytemax, chipsize):
        print("ADDRESS "+"{:08X}".format(romadr)+" - "+"{:08X}".format(romadr+chipsize-1))
        flashchiperasesub(romadr)

#---
def code2chr(chrnum):
    if chrnum>=0x20 and chrnum<=0x7f :
        return "{:c}".format(chrnum)
    else:
        return "."

#---
def flashwritebyte( romadr,writedata):
    if writedata==0xFF : return
    chipadr=int(romadr/chipsize)*chipsize #
    GPIO.output(READENABLE,GPIO.HIGH)  #DISABLE
    GPIO.output(WE,GPIO.HIGH)  #DISABLE
    GPIO.output(CHIPSEL,GPIO.HIGH) #DISABLE
    clkwait()
    GPIO.output(CHIPSEL,GPIO.LOW) #ENABLE
    if flash==1 : #EN29F002T
        setadr_data(chipadr+0x555,0xAA) #CYCLE1
        setweclk()
        setadr_data(chipadr+0xAAA,0x55) #CYCLE2
        setweclk()
        setadr_data(chipadr+0x555,0xA0) #CYCLE3
        setweclk()
        setadr_data(romadr,writedata)   #CYCLE4
        setweclk()
    else: #SST39SF040/10A
        setadr_data(chipadr+0x5555,0xAA) #CYCLE1
        setweclk()
        setadr_data(chipadr+0x2AAA,0x55) #CYCLE2
        setweclk()
        setadr_data(chipadr+0x5555,0xA0) #CYCLE3
        setweclk()
        setadr_data(romadr,writedata)   #CYCLE4
        setweclk()

    GPIO.output(CHIPSEL,GPIO.HIGH)  #DISABLE
    clkwait()

#---
def flashchiperasesub(romadr):
    chipadr = int(romadr/chipsize)*chipsize #
    mcp23s17setdatamode(1) #0:INPUT/1:OUTPUT

    if flash==1 : #EN29F002T
        GPIO.output(READENABLE,GPIO.LOW) #READ ENABLE
        GPIO.output(WE,GPIO.HIGH)    #WRITE DISABLE
        GPIO.output(READENABLE,GPIO.HIGH)    #READ DISABLE
        clkwait()
        setadr_data(chipadr+0x555,0xAA) #CYCLE1
        GPIO.output(CHIPSEL,GPIO.LOW) #CHIP ENABLE
        clkwait()
        GPIO.output(READENABLE,GPIO.HIGH)
        clkwait()
        setweclk() #WE=LOW-->HIGH
        GPIO.output(CHIPSEL,GPIO.HIGH)
        setadr_data(chipadr+0xAAA,0x55) #CYCLE2
        GPIO.output(CHIPSEL,GPIO.LOW)
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x555,0x80) #CYCLE3
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x555,0xAA) #CYCLE4
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0xAAA,0x55) #CYCLE5
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x555,0x10) #CYCLE6       
        setweclk() #WE=LOW-->HIGH
    else:
        GPIO.output(READENABLE,GPIO.LOW) #READ ENABLE
        GPIO.output(WE,GPIO.HIGH)    #WRITE DISABLE
        GPIO.output(READENABLE,GPIO.HIGH)    #READ DISABLE
        clkwait()
        setadr_data(chipadr+0x5555,0xAA) #CYCLE1
        GPIO.output(CHIPSEL,GPIO.LOW) #CHIP ENABLE
        clkwait()
        GPIO.output(READENABLE,GPIO.HIGH)
        clkwait()
        setweclk() #WE=LOW-->HIGH
        GPIO.output(CHIPSEL,GPIO.HIGH)
        setadr_data(chipadr+0x2AAA,0x55) #CYCLE2
        GPIO.output(CHIPSEL,GPIO.LOW)
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x5555,0x80) #CYCLE3
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x5555,0xAA) #CYCLE4
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x2AAA,0x55) #CYCLE5
        setweclk() #WE=LOW-->HIGH
        setadr_data(chipadr+0x5555,0x10) #CYCLE6
        setweclk() #WE=LOW-->HIGH

    for i in range(30):
        print(" "+str(i+1)+"/30")
        time.sleep(1)

    GPIO.output(CHIPSEL,GPIO.HIGH)  #CHIP DISABLE
    GPIO.output(READENABLE,GPIO.HIGH)
    mcp23s17setdatamode(0) #0:INPUT/1:OUTPUT

#---
def setadr_data(romadr,writedata):
    mcp23s17setadr(romadr)
    mcp23s17setdata(writedata)

#---
def setcpurwclk():
    time.sleep(0.00002)
    GPIO.output(CPURW,GPIO.LOW)  #WRITE ENABLE
    time.sleep(0.00002)
    GPIO.output(CPURW,GPIO.HIGH)  #WRITE DISABLE
    time.sleep(0.00002)

#---
def setweclk():
    time.sleep(0.00002)
    GPIO.output(WE,GPIO.LOW)  #ENABLE
    time.sleep(0.00002)
    GPIO.output(WE,GPIO.HIGH)  #DISABLE
    time.sleep(0.00002)

#---
def mcp23s17getdata():
    return(mcp23s17recv(1,0x13)) # CHIP1:B

#---
def mcp23s17setdata(dat):
    mcp23s17send(1,0x13,dat) #CHIP1 GPIOB

#---
def mcp23s17setadr(workadr):
    mcp23s17send(0,0x12,(workadr & 0xFF))       #A00-07 CHIP0:A
    mcp23s17send(0,0x13,((workadr>>8) & 0xFF))  #A08-15 CHIP0:B
    mcp23s17send(1,0x12,((workadr>>16) & 0xFF)) #A16-23 CHIP1:A

#---
def mcp23s17setdatamode(d): #0:INPUT/1:OUTPUT
    if d :
        mcp23s17send(1,0x01,0x00) #CHIP1 IODIRB OUTPUT
    else:
        mcp23s17send(1,0x01,0xFF) #CHIP1 IODIRB input

#---
def mcp23s17init():
    GPIO.setmode(GPIO.BCM)   # GPIO
    GPIO.setup(SAFE,GPIO.OUT)
    GPIO.setup(READENABLE,GPIO.OUT)
    GPIO.setup(CHIPSEL,GPIO.OUT)
    GPIO.setup(WE,GPIO.OUT)
    GPIO.setup(CPURW,GPIO.OUT)

    GPIO.output(READENABLE,GPIO.LOW)
    GPIO.output(CHIPSEL,GPIO.HIGH)
    GPIO.output(WE,GPIO.HIGH)
    GPIO.output(CPURW,GPIO.HIGH) #CPU H=READ/L=WRITE
    GPIO.output(SAFE,GPIO.LOW)

    mcp23s17send(0,0x0A,0x28)  #IOCON
    #  BANK/MIRROR/SEQOP/DISSLW/HAEN/ODR/INTPOL/0

    mcp23s17send(0,0x00,0x00) #CHIP0 IODIRA OUTPUT
    mcp23s17send(0,0x01,0x00) #CHIP0 IODIRB OUTPUT

    mcp23s17send(1,0x00,0x00) #CHIP1 IODIRA OUTPUT
    mcp23s17send(1,0x01,0xFF) #CHIP1 IODIRB input

    mcp23s17send(0,0x12,0x00) #CHIP0 GPIOA
    mcp23s17send(0,0x13,0x00) #CHIP0 GPIOB

    mcp23s17send(1,0x12,0x00) #CHIP1 GPIOA
    mcp23s17send(1,0x13,0x00) #CHIP1 GPIOB

#---
def mcp23s17send(chip,address, dat):
    spibuf = [ 0x40+(chip<<1) , address , dat ]
    spi.xfer(spibuf)
    clkwait()

#---
def mcp23s17recv(chip,address):
    spibuf = [ 0x40+(chip<<1)+1, address, 0]
    recvbuf = spi.xfer(spibuf)
    clkwait()
    return(recvbuf[2])

#---
def clkwait():
    time.sleep(0.00005)

#---
def verify():
    print("VERIFY")
    GPIO.output(READENABLE,GPIO.LOW)
    GPIO.output(CHIPSEL,GPIO.HIGH)
    GPIO.output(WE,GPIO.HIGH)
    mcp23s17setdatamode(0) #0:INPUT/1:OUTPUT

    filename = fileselect(ext)
    if filename=="" : return
    
    f = open(filename, 'rb')
    bindata = f.read()
    f.close()
    bufsize = len(bindata)

    print("READ "+str(bufsize)+" BYTES("+str(int(bufsize*8/MEGA))+"M BITS)")

    romadr=0
    if hard==4 : #PC-6001よう とくべつしょり
        if romadr < 0x4000 : romadr=0x4000

    time.sleep(0.00005)
    work = ""
    for i in range(0x1000000):
        binptr = headersize + i
        if binptr>=bufsize : break #EOF

        time.sleep(0.00005)
        mcp23s17setadr(romadr)
        time.sleep(0.00005)
        GPIO.output(READENABLE,GPIO.LOW) #READ ENABLE
        GPIO.output(CHIPSEL,GPIO.LOW)

        time.sleep(0.00005)
        readdata = mcp23s17getdata()
        GPIO.output(CHIPSEL,GPIO.HIGH)

        x = romadr % 16
        if x==0 :
            if work!="" :
                print(work)

            work = "{:08X}".format(romadr)+":"

        work += "{:02X}".format(readdata)

        writedata = bindata[binptr]
        if readdata!=writedata : break

        romadr=romadr+1

    if work!="" : print(work)

    GPIO.output(CHIPSEL,GPIO.HIGH)

    if binptr<bufsize :
        print("VERIFY ERROR")
    else:
        print("OK!(NO ERROR)")

#---
def filedump():
    print("IMAGE FILE DUMP")
    filename = fileselect(ext)
    if filename=="" : return

    f = open(filename, 'rb')
    bindata = f.read()
    f.close()
    bufsize = len(bindata)

    print("READ "+str(bufsize)+" BYTES("+str(int(bufsize*8/MEGA))+"M BITS)")

    if hard==1 :
        print(" PRG ROM SIZE:"+str(16384 * bindata[4])+" BYTES")
        print(" CHR ROM SIZE:"+str(8192 * bindata[5])+" BYTES")
        if (bindata[6] & 1)==0 :
            print(" Mirroring:Horizontal(VRAMA10 = PPU A11)")
        else:
            print(" Mirroring:Vertical(VRAMA10 = PPU A10)")
 
        print(" MAPPER:"+str(bindata[6]>>4))

    a=input("ADDRESS(HEX)?:")
    if a=="" : a="0"
    romadr=int(a,16)
    work=""
    work2=""
    for i in range(0x100):
        binptr = headersize + romadr
        if binptr>=bufsize : break
        x = romadr % 16
        readdata = bindata[binptr]
        if x==0 :
            if work!="" :
                print(work,work2)

            work = "{:08X}".format(romadr)+":"
            work2 ="|"
 
        work += "{:02X}".format(readdata)
        work += " "
        work2 += code2chr(readdata)

        romadr=romadr+1

    if work!="" :
        print(work,work2)

#---
def inputyn():
    while 1:
        yn = input(" よろしいですか? [Y]/[N]:")
        yn = yn.upper()
        if yn=="Y" or yn=="":
            break

        if yn=="N" :
            break

    return yn

#---
mcp23s17init()

while 1:
    print("TARGET")
    print(" 1:FAMICOM(.NES)")
    print(" 2:GAMEBOY(.GB)")
    print(" 3:PC ENGINE(.PCE)")
    print(" 4:PC-6001(.BIN)")
    a=input("SELECT(1-4)?:")
    hard=int(a)
    if hard>0 and hard<5:break

if hard==1 :
    ext = ".NES"  #
    headersize = 16 #NES HEADER SIZE

if hard==2 :
    ext = ".GB"   #
    headersize = 0  #GB HEADER SIZE

if hard==3 :
    ext = ".PCE"  #
    headersize = 512  #PCE HEADER SIZE

if hard==4 :
    ext = ".BIN"   #
    headersize = 0  #P6 HEADER SIZE

while 1:
    print("FLASH MEMORY")
    print(" 1:(EN29F002T)   2M bits")
    print(" 2:(SST39SF040)  4M bits")
    print(" 3:(SST39SF010A) 1M bits")
    a=input("SELECT?(1-3):")
    flash=int(a)
    if flash>0 and flash<4 : break

if flash==1 : chipsize=ADR2M #EN29F002T
if flash==2 : chipsize=ADR4M #SST39SF040
if flash==3 : chipsize=ADR1M #SST39SF010A

rombytemax=chipsize

while 1:
    print("")
    print("---MENU")
    print("TARGET=FLASHROM("+str(int(rombytemax*8/MEGA))+"M bits)")
    print(" 1:READ ROM(256バイト 読み込みテスト)")
    print(" 3:ERASE FLASH MEMORY(ROMの中身を消去)")
    print(" 4:WRITE IMAGE TO ROM(ROMにイメージを書き込み)")
    print(" 5:VERIFY")
    print(" 8:DUMP IMAGE FILE(イメージファイルを見る)")
    print(" 0:EXIT")
    cmd = input("COMMAND?:")
    if cmd=="1" : romread()
    if cmd=="3" : flashchiperase()
    if cmd=="4" : romwrite()
    if cmd=="5" : verify()
    if cmd=="8" : filedump()
    if cmd=="0" : break

print("END")

