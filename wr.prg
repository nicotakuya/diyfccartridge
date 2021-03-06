'FLASH MEMORY WRITER for Pi STARTER
'DIY FC/GB/PCE/P6 CARTRIDGE
'BY TAKUYA MATSUBARA
ACLS
DIM SPIBUF%[3]
WHILE 1
 PRINT "TARGET"
 PRINT "1:FAMICOM(.NES)"
 PRINT "2:GAMEBOY(.GB)"
 PRINT "3:PC ENGINE(.PCE)"
 PRINT "4:PC-6001(.BIN)"
 NUM=0
 INPUT NUM
 IF NUM==1 THEN
  EXT$ = ".NES"  '
  HEADERSIZE = 16 'NES HEADER SIZE
  BREAK
 ENDIF

 IF NUM==2 THEN
  EXT$ = ".GB"   '
  HEADERSIZE = 0  'GB HEADER SIZE
  BREAK
 ENDIF

 IF NUM==3 THEN
  EXT$ = ".PCE"  '
  HEADERSIZE = 512  'PCE HEADER SIZE
  BREAK
 ENDIF

 IF NUM==4 THEN
  EXT$ = ".BIN"   '
  HEADERSIZE = 0  'P6 HEADER SIZE
  BREAK
 ENDIF
WEND

'KEYCODE
RIGHT = 28
LEFT  = 29
UP    = 30
DOWN  = 31
ENTER = 13
SPACE = 32
ESCAPE= &H1B

HIGH = 1
LOW = 0
KILO = 1024
MEGA = 1024*1024
ADR1M = FLOOR(1*MEGA/8) 'ADDRESS
ADR2M = FLOOR(2*MEGA/8) 'ADDRESS
ADR4M = FLOOR(4*MEGA/8) 'ADDRESS
ADR8M = FLOOR(8*MEGA/8) 'ADDRESS

SAFE = #GPIO18 'GPIO NUMBER
READENABLE = #GPIO23 'GPIO NUMBER
CHIPSEL = #GPIO24 'GPIO NUMBER
WE = #GPIO25 'GPIO NUMBER
CPURW = #GPIO22 'GPIO NUMBER

GPIOMODE SAFE,#GPIOMODE_OUT
GPIOMODE READENABLE,#GPIOMODE_OUT
GPIOMODE CHIPSEL,#GPIOMODE_OUT
GPIOMODE WE,#GPIOMODE_OUT
GPIOMODE CPURW,#GPIOMODE_OUT

GPIOOUT READENABLE,LOW
'GPIOOUT READENABLE,HIGH
GPIOOUT CHIPSEL,HIGH
GPIOOUT WE,HIGH
GPIOOUT CPURW,HIGH 'CPU H=READ/L=WRITE
GPIOOUT SAFE,LOW
MCP23S17INIT

WHILE 1
 PRINT "FLASH MEMORY"
 PRINT "1:(EN29F002T)   2M bits"
 PRINT "2:(SST39SF040)  4M bits"
 PRINT "3:(SST39SF010A) 1M bits"
 FLASH=0
 INPUT FLASH
 IF FLASH==1 THEN
  CHIPSIZE=ADR2M 'EN29F002T
  BREAK
 ENDIF

 IF FLASH==2 THEN
  CHIPSIZE=ADR4M 'SST39SF040
  BREAK
 ENDIF

 IF FLASH==3 THEN
  CHIPSIZE=ADR1M 'SST39SF010A
  BREAK
 ENDIF
WEND
ROMBYTEMAX=CHIPSIZE

DIM BINDATA[ROMBYTEMAX] 'ROM IMAGE
FILENAME$=""

WHILE 1
 PRINT ""
 PRINT "---MENU"
 PRINT "TARGET=";EXT$;" /FLASHROM=";
 PRINT ROMBYTEMAX*8/MEGA;" MEGA bits"
 PRINT " 1:READ ROM"
 PRINT " 3:ERASE FLASH MEMORY(ROMのなかみを しょうきょ)"
 PRINT " 4:WRITE IMAGE TO ROM(ROMにイメージをかきこみ)"
 PRINT " 7:VERIFY"
 PRINT " 8:DUMP IMAGE FILE(イメージファイルをみる)"
 PRINT " 9:PIN TEST"
 PRINT " 0:EXIT"
 INPUT "COMMAND";CMD
 IF CMD==1 THEN GOSUB @ROMREAD
 IF CMD==3 THEN GOSUB @FLASHCHIPERASE
 IF CMD==4 THEN GOSUB @ROMWRITE
 IF CMD==7 THEN GOSUB @VERIFY
 IF CMD==8 THEN GOSUB @FILEDUMP
' IF CMD==9 THEN GOSUB @PINTEST
 IF CMD==0 THEN BREAK
WEND
CLS
END

'---
@PINTEST
  FOR I=0 TO 4
   GPIOOUT CHIPSEL,LOW
   PRINT "CHIPSEL=LOW"
   WAIT 60*3
   GPIOOUT CHIPSEL,HIGH
   PRINT "CHIPSEL=HIGH"
   WAIT 60*3
  NEXT
  FOR I=0 TO 4
   GPIOOUT READENABLE,LOW
   PRINT "READ READENABLE=LOW"
   WAIT 60*3
   GPIOOUT READENABLE,HIGH
   PRINT "READ READENABLE=HIGH"
   WAIT 60*3
  NEXT
  FOR I=0 TO 4
   GPIOOUT WE,LOW
   PRINT "WRITE ENABLE=LOW"
   WAIT 60*3
   GPIOOUT WE,HIGH
   PRINT "WRITE ENABLE=HIGH"
   WAIT 60*3
  NEXT
RETURN

'---
@ROMREAD
GPIOOUT READENABLE,LOW
'GPIOOUT READENABLE,HIGH
GPIOOUT CHIPSEL,HIGH
GPIOOUT WE,HIGH
MCP23S17SETDATAMODE 0 '0:INPUT/1:OUTPUT
PRINT "READ ROM 256 BYTES"
A$=""
INPUT "ADDRESS(HEX):";A$
IF A$=="" THEN A$="000000"
ROMADR=VAL("&H"+A$)
IF NUM==4 THEN 'PC-6001よう とくべつしょり
 IF ROMADR < &H4000 THEN ROMADR=&H4000
ENDIF
USLEEP 50
WORK$ = ""
FOR I=&H00 TO &HFF
 USLEEP 50
 MCP23S17SETADR ROMADR
 USLEEP 50
 GPIOOUT READENABLE,LOW 'READ ENABLE
 GPIOOUT CHIPSEL,LOW
 USLEEP 250
 READDATA = MCP23S17GETDATA()
' GPIOOUT READENABLE,HIGH
 GPIOOUT CHIPSEL,HIGH

 X = ROMADR MOD 16
 IF X==0 THEN
  IF WORK$!="" THEN PRINT WORK$:WORK$=""
  WORK$ = HEX$(ROMADR,8)+":"+(" "*64)
 ENDIF
 WORK$ = SUBST$(WORK$,9+(X*3),2,HEX$(READDATA,2))
 IF READDATA>=&H20 AND READDATA<=&H7F THEN
  C$=CHR$(READDATA)
 ELSE
  C$="."
 ENDIF
 WORK$ = SUBST$(WORK$,9+(16*3)+X,1,C$)

 ROMADR=ROMADR+1
NEXT
IF WORK$!="" THEN PRINT WORK$:WORK$=""
'GPIOOUT READENABLE,HIGH
GPIOOUT CHIPSEL,HIGH
RETURN

'---
@ROMWRITE

FILENAME$ = FILESELECT(0,EXT$)
IF FILENAME$=="" THEN RETURN

PRINT "WRITE IMAGE TO ROM"
PRINT "READ IMAGE FILE:";FILENAME$
LOAD "RAW:"+FILENAME$,BINDATA
PRINT "READ ";LEN(BINDATA);" BYTES(";LEN(BINDATA)*8;"BITS)"

GPIOOUT WE,HIGH  'DISABLE
GPIOOUT READENABLE,HIGH  'DISABLE
GPIOOUT CHIPSEL,HIGH  'DISABLE

MCP23S17SETDATAMODE 1 '0:INPUT/1:OUTPUT

IF INPUTYN()==ASC("N") THEN RETURN

ERRFLAG=0
STARTCNT=MAINCNT

WORK$ = ""
STARTADR=0
ENDADR=LEN(BINDATA)-1-HEADERSIZE
BINPTR = HEADERSIZE
IF NUM==4 THEN 'PC-6001よう とくべつしょり
 STARTADR = STARTADR+&H4000
 ENDADR = ENDADR+&H4000
ENDIF

FOR ROMADR=STARTADR TO ENDADR
 IF ROMADR>=ROMBYTEMAX THEN BREAK
 IF BINPTR>=LEN(BINDATA) THEN BREAK
 WRITEDATA = BINDATA[BINPTR]
 FLASHWRITEBYTE ROMADR,WRITEDATA
 X = ROMADR MOD 16
 IF X==0 THEN
  IF WORK$!="" THEN PRINT WORK$:WORK$=""
  WORK$ = HEX$(ROMADR,8)+":"+(" "*64)
  IF (ROMADR AND &HFF)==0 THEN
   PRINT FLOOR((BINPTR+1)*100/LEN(BINDATA));"%"
  ENDIF
 ENDIF
 WORK$ = SUBST$(WORK$,9+(X*3),2,HEX$(WRITEDATA,2))
 IF ERRFLAG THEN RETURN
 BINPTR = BINPTR + 1
NEXT
IF WORK$!="" THEN PRINT WORK$:WORK$=""
MCP23S17SETDATAMODE 0 '0:INPUT/1:OUTPUT

IF ERRFLAG THEN RETURN

WORKTIME=FLOOR((MAINCNT-STARTCNT)/(60*60))
PRINT "COMPLETE"
PRINT "RUNNING TIME:";WORKTIME;" MINUTE"
RETURN

'---
@FLASHCHIPERASE

PRINT "FLASH MEMORY CHIP ERASE"

IF INPUTYN()==ASC("N") THEN RETURN

FOR ROMADR=0 TO ROMBYTEMAX-1 STEP CHIPSIZE
 PRINT "ADDRESS ";HEX$(ROMADR);" - ";HEX$(ROMADR+CHIPSIZE-1)
 FLASHCHIPERASESUB ROMADR
NEXT
RETURN

'---
DEF FLASHWRITEBYTE ROMADR,WRITEDATA
 IF WRITEDATA==&HFF THEN RETURN
 CHIPADR=FLOOR(ROMADR/CHIPSIZE)*CHIPSIZE '
 GPIOOUT READENABLE,HIGH  'DISABLE
 GPIOOUT WE,HIGH  'DISABLE
 GPIOOUT CHIPSEL,HIGH 'DISABLE
 CLKWAIT
 GPIOOUT CHIPSEL,LOW 'ENABLE
 IF FLASH==1 THEN 'EN29F002T
  SETADR_DATA CHIPADR+&H555,&HAA 'CYCLE1
  SETWECLK
  SETADR_DATA CHIPADR+&HAAA,&H55 'CYCLE2
  SETWECLK
  SETADR_DATA CHIPADR+&H555,&HA0 'CYCLE3
  SETWECLK
  SETADR_DATA ROMADR,WRITEDATA   'CYCLE4
  SETWECLK
 ELSE 'SST39SF040/10A
  SETADR_DATA CHIPADR+&H5555,&HAA 'CYCLE1
  SETWECLK
  SETADR_DATA CHIPADR+&H2AAA,&H55 'CYCLE2
  SETWECLK
  SETADR_DATA CHIPADR+&H5555,&HA0 'CYCLE3
  SETWECLK
  SETADR_DATA ROMADR,WRITEDATA   'CYCLE4
  SETWECLK
 ENDIF
 GPIOOUT CHIPSEL,HIGH  'DISABLE
 CLKWAIT
END

'---EN29F002T
DEF FLASHCHIPERASESUB ROMADR
CHIPADR = FLOOR(ROMADR/CHIPSIZE)*CHIPSIZE '
MCP23S17SETDATAMODE 1 '0:INPUT/1:OUTPUT

IF FLASH==1 THEN 'EN29F002T
 GPIOOUT READENABLE,LOW 'READ ENABLE
 GPIOOUT WE,HIGH    'WRITE DISABLE
 GPIOOUT READENABLE,HIGH    'READ DISABLE
 CLKWAIT
 SETADR_DATA CHIPADR+&H555,&HAA 'CYCLE1
 GPIOOUT CHIPSEL,LOW 'CHIP ENABLE
 CLKWAIT
 GPIOOUT READENABLE,HIGH
 CLKWAIT
 SETWECLK 'WE=LOW-->HIGH
 GPIOOUT CHIPSEL,HIGH
 SETADR_DATA CHIPADR+&HAAA,&H55 'CYCLE2
 GPIOOUT CHIPSEL,LOW
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H555,&H80 'CYCLE3
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H555,&HAA 'CYCLE4
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&HAAA,&H55 'CYCLE5
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H555,&H10 'CYCLE6
 SETWECLK 'WE=LOW-->HIGH
ELSE
 GPIOOUT READENABLE,LOW 'READ ENABLE
 GPIOOUT WE,HIGH    'WRITE DISABLE
 GPIOOUT READENABLE,HIGH    'READ DISABLE
 CLKWAIT
 SETADR_DATA CHIPADR+&H5555,&HAA 'CYCLE1
 GPIOOUT CHIPSEL,LOW 'CHIP ENABLE
 CLKWAIT
 GPIOOUT READENABLE,HIGH
 CLKWAIT
 SETWECLK 'WE=LOW-->HIGH
 GPIOOUT CHIPSEL,HIGH
 SETADR_DATA CHIPADR+&H2AAA,&H55 'CYCLE2
 GPIOOUT CHIPSEL,LOW
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H5555,&H80 'CYCLE3
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H5555,&HAA 'CYCLE4
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H2AAA,&H55 'CYCLE5
 SETWECLK 'WE=LOW-->HIGH
 SETADR_DATA CHIPADR+&H5555,&H10 'CYCLE6
 SETWECLK 'WE=LOW-->HIGH
ENDIF

FOR I=1 TO 30
 PRINT " ";I;"/30"
 WAIT 60
NEXT
GPIOOUT CHIPSEL,HIGH  'CHIP DISABLE
GPIOOUT READENABLE,HIGH
MCP23S17SETDATAMODE 0 '0:INPUT/1:OUTPUT
END

'---
DEF SETADR_DATA ROMADR,WRITEDATA
 MCP23S17SETADR ROMADR
 MCP23S17SETDATA WRITEDATA
END

'---
DEF MAPPER2_BANK BANK
 MCP23S17SETDATAMODE 1 '0:INPUT/1:OUTPUT
 SETADR_DATA &h4000,BANK
 GPIOOUT CPURW,LOW  'WRITE ENABLE
 USLEEP 30
 GPIOOUT CHIPSEL,LOW
 USLEEP 50
 GPIOOUT CHIPSEL,HIGH
 USLEEP 50
 GPIOOUT CPURW,HIGH  'WRITE DISABLE
 USLEEP 20
 MCP23S17SETDATAMODE 0 '0:INPUT/1:OUTPUT
end

'---
DEF SETCPURWCLK
 USLEEP 10
 GPIOOUT CPURW,LOW  'WRITE ENABLE
 USLEEP 30
 GPIOOUT CPURW,HIGH  'WRITE DISABLE
 USLEEP 20
END

'---
DEF SETWECLK
 USLEEP 10
 GPIOOUT WE,LOW  'WRITE ENABLE
 USLEEP 30
 GPIOOUT WE,HIGH  'WRITE DISABLE
 USLEEP 20
END

'---
DEF MCP23S17GETDATA()
 MCP23S17RECV 1,&H13 ' CHIP1:B
 RETURN(SPIBUF%[2])
END

'---
DEF MCP23S17SETDATA DAT
 MCP23S17SEND 1,&H13,DAT 'CHIP1 GPIOB
END

'---
DEF MCP23S17SETADR WORKADR
 MCP23S17SEND 0,&H12,(WORKADR AND &HFF)       'A00-07 CHIP0:A
 MCP23S17SEND 0,&H13,((WORKADR>>8) AND &HFF)  'A08-15 CHIP0:B
 MCP23S17SEND 1,&H12,((WORKADR>>16) AND &HFF) 'A16-23 CHIP1:A
END

'---
DEF MCP23S17SETADR16 WORKADR
 MCP23S17SEND 0,&H12,(WORKADR AND &HFF)       'A00-07 CHIP0:A
 MCP23S17SEND 0,&H13,((WORKADR>>8) AND &HFF)  'A08-15 CHIP0:B
END

'---
DEF MCP23S17SETDATAMODE D '0:INPUT/1:OUTPUT
 IF D THEN
  MCP23S17SEND 1,&H01,&H00 'CHIP1 IODIRB OUTPUT
 ELSE
  MCP23S17SEND 1,&H01,&HFF 'CHIP1 IODIRB INPUT
 ENDIF
END

'---
DEF MCP23S17INIT
' F=600000 'SPI クロック(HZ)
' F=800000 'SPI クロック(HZ)
 F=400000 'SPI クロック(HZ)
' T=0 'タイミング CPOL=0,CPHA=0
 T=1 'タイミング CPOL=0,CPHA=1
' T=2 'タイミング CPOL=1,CPHA=0
' T=3 'タイミング CPOL=1,CPHA=1

 SPISTART F,T
 WAIT 15

 MCP23S17SEND 0,&H0A,&H28  'IOCON
 '  BANK/MIRROR/SEQOP/DISSLW/HAEN/ODR/INTPOL/0

 MCP23S17SEND 0,&H00,&H00 'CHIP0 IODIRA OUTPUT
 MCP23S17SEND 0,&H01,&H00 'CHIP0 IODIRB OUTPUT

 MCP23S17SEND 1,&H00,&H00 'CHIP1 IODIRA OUTPUT
 MCP23S17SEND 1,&H01,&HFF 'CHIP1 IODIRB INPUT

 MCP23S17SEND 0,&H12,&H00 'CHIP0 GPIOA
 MCP23S17SEND 0,&H13,&H00 'CHIP0 GPIOB

 MCP23S17SEND 1,&H12,&H00 'CHIP1 GPIOA
 MCP23S17SEND 1,&H13,&H00 'CHIP1 GPIOB
END

'---
DEF MCP23S17SEND CHIP,ADDRESS, DAT
 SPIBUF%[0]=&H40+(CHIP<<1)
 SPIBUF%[1]=ADDRESS
 SPIBUF%[2]=DAT
 SPISEND SPIBUF%,3
 CLKWAIT
END

'---
DEF MCP23S17RECV CHIP,ADDRESS
 SPIBUF%[0]=&H40+(CHIP<<1)+1
 SPIBUF%[1]=ADDRESS
 SPIBUF%[2]=0
 SPISENDRECV SPIBUF%,3
 CLKWAIT
END

'---
DEF CLKWAIT
' USLEEP 50
 USLEEP 20
END

'---
@VERIFY
GPIOOUT READENABLE,LOW
GPIOOUT CHIPSEL,HIGH
GPIOOUT WE,HIGH
MCP23S17SETDATAMODE 0 '0:INPUT/1:OUTPUT

FILENAME$ = FILESELECT(0,EXT$)
IF FILENAME$=="" THEN RETURN

PRINT "VERIFY"
PRINT "FILE NAME:";FILENAME$

LOAD "RAW:"+FILENAME$,BINDATA

PRINT "READ ";LEN(BINDATA);" BYTES(";LEN(BINDATA)*8;"BITS)"

ROMADR=0
IF NUM==4 THEN 'PC-6001よう とくべつしょり
 IF ROMADR < &H4000 THEN ROMADR=&H4000
ENDIF
USLEEP 50
WORK$ = ""
FOR I=&H0 TO &HFFFFFF
 BINPTR = HEADERSIZE + I
 IF BINPTR>=LEN(BINDATA) THEN BREAK 'EOF

 USLEEP 50
 MCP23S17SETADR ROMADR
 USLEEP 50
 GPIOOUT READENABLE,LOW 'READ ENABLE
 GPIOOUT CHIPSEL,LOW
 USLEEP 250
 READDATA = MCP23S17GETDATA()
 GPIOOUT CHIPSEL,HIGH

 X = ROMADR MOD 16
 IF X==0 THEN
  IF WORK$!="" THEN PRINT WORK$:WORK$=""
  WORK$ = HEX$(ROMADR,8)+":"+(" "*64)
 ENDIF
 WORK$ = SUBST$(WORK$,9+(X*3),2,HEX$(READDATA,2))

 WRITEDATA = BINDATA[BINPTR]
 IF READDATA!=WRITEDATA THEN BREAK

 ROMADR=ROMADR+1
NEXT
IF WORK$!="" THEN PRINT WORK$:WORK$=""
GPIOOUT CHIPSEL,HIGH

IF BINPTR<LEN(BINDATA) THEN
 PRINT "VERIFY ERROR:";HEX$(ROMADR,8)
ELSE
 PRINT "OK!(NO ERROR)"
ENDIF
RETURN

'---
@FILEDUMP
FILENAME$ = FILESELECT(0,EXT$)
IF FILENAME$=="" THEN RETURN

PRINT "IMAGE FILE DUMP"
PRINT "FILE NAME:";FILENAME$

LOAD "RAW:"+FILENAME$,BINDATA

PRINT "READ ";LEN(BINDATA);" BYTES(";LEN(BINDATA)*8;"BITS)"

IF EXT$==".NES" THEN
 PRINT " PRG ROM SIZE:"; (16384 * BINDATA[4]);" BYTES"
 PRINT " CHR ROM SIZE:"; (8192 * BINDATA[5]);" BYTES"
 PRINT " Mirroring:";
 IF (BINDATA[6] AND 1)==0 THEN
  PRINT "Horizontal(VRAMA10 = PPU A11)"
 ELSE
  PRINT "Vertical(VRAMA10 = PPU A10)"
 ENDIF
 PRINT " MAPPER:"; BINDATA[6]>>4
ENDIF

A$=""
INPUT "ADDRESS(HEX):";A$
IF A$=="" THEN A$="000000"
ROMADR=VAL("&H"+A$)
WORK$=""
FOR I=0 TO &H1FF
 BINPTR = HEADERSIZE + ROMADR
 IF BINPTR>=LEN(BINDATA) THEN BREAK
 X = ROMADR MOD 16
 WRITEDATA = BINDATA[BINPTR]
 IF X==0 THEN
  IF WORK$!="" THEN PRINT WORK$:WORK$=""
  WORK$ = HEX$(ROMADR,8)+":"+(" "*64)
 ENDIF
 WORK$ = SUBST$(WORK$,9+(X*3),2,HEX$(WRITEDATA,2))
 IF WRITEDATA>=&H20 AND WRITEDATA<=&H7F THEN
  C$=CHR$(WRITEDATA)
 ELSE
  C$="."
 ENDIF
 WORK$ = SUBST$(WORK$,9+(16*3)+X,1,C$)
 INC ROMADR
NEXT
IF WORK$!="" THEN PRINT WORK$:WORK$=""

RETURN

'---
DEF HEXBYTE(ADR)
 RETURN(HEX$(BINDATA[BASEADR+ADR],2))
END

'---
DEF FILESELECT(DIRFLAG,FILTER$)

DIM NAME$[0]
DIM NAME2$[0]
COLOR #WHITE,0
CLS

FILTER$=UCASE(FILTER$)

FP=48
FH=20

PATH$=CHDIR()
SELPATH$=PATH$
OFX=0
OFY=0

LOCATE 1,FH+4
PRINT "[UP][DOWN]:カ-ソルいどう / [SPACE]:けってい / [ESC]:CANCEL"

WHILE 1
 COLOR #BLACK,#BLUE
 FOR I=0 TO FH+1+2
  LOCATE OFX,OFY+I
  PRINT " "*(FP+2)
 NEXT
 COLOR #WHITE,0
 FOR I=0 TO FH-1
  LOCATE OFX+1,OFY+I+1+2
  PRINT " "*FP
 NEXT
 
 LOCATE OFX+1,OFY+1
 PRINT "DIR:";SELPATH$

 IF FILTER$!="" THEN
  LOCATE OFX+38,OFY+1
  PRINT "FILTER:";FILTER$
 ENDIF
 WHILE LEN(NAME2$)
  R$=POP(NAME2$)
 WEND
 FILES SELPATH$,NAME$
 FOR I=0 TO LEN(NAME$)-1
  T$=NAME$[I]
  KAK$=RIGHT$(T$,4)
  IF UCASE(KAK$)==".PRG" THEN CONTINUE
  IF MID$(T$,1,1)=="@" THEN CONTINUE
  IF DIRFLAG==0 THEN
   IF LEFT$(T$,1)!="+" THEN
    IF FILTER$!="" AND INSTR(UCASE(T$),FILTER$)<0 THEN CONTINUE
   ENDIF
  ELSE
   IF LEFT$(T$,1)!="+" THEN CONTINUE
  ENDIF
  PUSH NAME2$,T$
 NEXT
 UNSHIFT NAME2$,"+.."

 IF DIRFLAG THEN
  PUSH NAME2$,"["+SELPATH$+"にけってい]"
  IDX=LEN(NAME2$)-1
 ELSE
  IDX=0
 ENDIF

 IDXOFS=0
 WHILE 1
  FOR I=0 TO LEN(NAME2$)-1
   X=OFX+1
   Y=(I-IDXOFS)
   IF Y<0 THEN CONTINUE
   IF Y>=FH THEN BREAK
   Y=Y+OFY+1+2
   LOCATE X,Y
   T$=" "*FP
   T$=SUBST$(T$,0,LEN(NAME2$[I]),NAME2$[I])
   IF IDX==I THEN COLOR 0,#WHITE ELSE COLOR #WHITE,0
   PRINT T$;
  NEXT
  COLOR #WHITE,0

  BT=KEYWAIT()
  IF BT==SPACE THEN BREAK
  IF BT==ENTER THEN BREAK
  IF BT==UP    THEN DEC IDX
  IF BT==DOWN  THEN INC IDX
  IF BT==ESCAPE THEN IDX=-1:BREAK

  IDX=FIXNUM(IDX,0,LEN(NAME2$)-1)

  WHILE IDXOFS>IDX
   DEC IDXOFS
  WEND
  WHILE (IDXOFS+FH-1)<IDX
   INC IDXOFS
  WEND
 WEND
 LOCATE 1,FH+4
 PRINT " "*80

 IF IDX<0 THEN SELPATH$="":BREAK

 NB$=MID$(NAME2$[IDX],0,1)
 NA$=MID$(NAME2$[IDX],1,999)
 IF DIRFLAG==0 THEN
  IF NB$!="+" THEN
   IF RIGHT$(SELPATH$,1)!="/" THEN SELPATH$=SELPATH$+"/"
   RETURN (SELPATH$+NA$)
  ENDIF
 ELSE
  IF IDX==LEN(NAME2$)-1 THEN BREAK
 ENDIF

 IF NA$==".." THEN
  TMP=1
  WHILE 1
   IF LEFT$(RIGHT$(SELPATH$,TMP),1)=="/" THEN BREAK
   INC TMP
  WEND
  SELPATH$=LEFT$(SELPATH$,LEN(SELPATH$)-TMP)
  IF LEFT$(SELPATH$,1)!="/" THEN SELPATH$="/"+SELPATH$
 ELSE
  IF RIGHT$(SELPATH$,1)!="/" THEN SELPATH$=SELPATH$+"/"
  SELPATH$=SELPATH$+NA$
 ENDIF
WEND
RETURN SELPATH$
END

'---
DEF LCASE(TMP$)
 FOR TMPI=0 TO LEN(TMP$)-1
  TMPC=ASC(MID$(TMP$,TMPI,1))
  IF TMPC>=&H41 AND TMPC<=&H5A THEN
   TMP$=SUBST$(TMP$,TMPI,1,CHR$(TMPC+&H20))
  ENDIF
 NEXT
 RETURN TMP$
END

'---
DEF UCASE(TMP$)
 FOR TMPI=0 TO LEN(TMP$)-1
  TMPC=ASC(MID$(TMP$,TMPI,1))
  IF TMPC>=&H61 AND TMPC<=&H7A THEN
   TMP$=SUBST$(TMP$,TMPI,1,CHR$(TMPC-&H20))
  ENDIF
 NEXT
 RETURN TMP$
END

'---
DEF KEYWAIT()
 BT=0
 WHILE BT==0
  VSYNC 1
  NOWKEY$=INKEY$()
  IF NOWKEY$ != "" THEN BT=ASC(NOWKEY$)
 WEND
 WHILE 1
  VSYNC 2
  IF INKEY$=="" THEN BREAK 'KEY BUFF CLEAR
 WEND
 IF BT>=&H60 AND BT<=&H7A THEN BT=BT-&H20 'UCASE
 RETURN BT
END

'---
DEF SWOFFWAIT
 WHILE 1
  VSYNC 1
  IF INKEY$=="" THEN BREAK
 WEND
END

'---
DEF INPUTYN()
 PRINT
 COLOR #BLACK,#WHITE
 PRINT " よろしいですか? [Y]/[N] ";
 COLOR #WHITE,0
 WHILE 1
  YN=KEYWAIT()
  IF YN==ASC("Y") THEN PRINT " YES":BREAK
  IF YN==ASC("N") THEN PRINT " NO":BREAK
 WEND
 WAIT 30
 RETURN YN
END

'---
DEF FIXNUM(NUMBER,MINNUM,MAXNUM)
 IF NUMBER<MINNUM THEN NUMBER=MINNUM
 IF NUMBER>MAXNUM THEN NUMBER=MAXNUM
 RETURN NUMBER
END

