"""Independent instruction interpreter for the frozen restricted EEI.

Python integer mathematics, byte-addressed memory, no RTL imports or DUT inputs.
Uninitialized source reads fail model generation rather than guessing zero.
"""
MASK=(1<<32)-1
def u(x): return x&MASK
def signed(x,n=32): return (x&((1<<n)-1))-(1<<n) if x&(1<<(n-1)) else x&((1<<n)-1)
def I(imm,a,f,rd,op=0x13): return ((imm&4095)<<20)|(a<<15)|(f<<12)|(rd<<7)|op
def R(f7,b,a,f,rd): return (f7<<25)|(b<<20)|(a<<15)|(f<<12)|(rd<<7)|0x33
def S(imm,b,a,f): return ((imm&0xfe0)<<20)|(b<<20)|(a<<15)|(f<<12)|((imm&31)<<7)|0x23
def B(imm,b,a,f): return (((imm>>12)&1)<<31)|(((imm>>5)&63)<<25)|(b<<20)|(a<<15)|(f<<12)|(((imm>>1)&15)<<8)|(((imm>>11)&1)<<7)|0x63
def J(imm,rd=0): return (((imm>>20)&1)<<31)|(((imm>>1)&1023)<<21)|(((imm>>11)&1)<<20)|(((imm>>12)&255)<<12)|(rd<<7)|0x6f
class Program:
    def __init__(self,name): self.name=name; self.code={}; self.data={}; self.pc=0
    def emit(self,x): self.code[self.pc]=u(x); self.pc+=4; return self
    def at(self,pc): self.pc=pc; return self
    def li(self,rd,value):
        value=signed(u(value)); upper=(value+2048)>>12; low=value-(upper<<12)
        if upper: self.emit((u(upper<<12)&0xfffff000)|(rd<<7)|0x37).emit(I(low,rd,0,rd))
        else: self.emit(I(low,0,0,rd))
        return self
    def end(self): return self.emit(0x73)

def execute(p):
    regs=[0]+[None]*31; mem=bytearray(16384)
    for offset,word in p.data.items(): mem[offset:offset+4]=u(word).to_bytes(4,'little')
    pc=0; events=[]; stalls=0; previous_load=None
    def locals_result(cause,fault_pc):
        return dict(cause=cause,fault_pc=fault_pc,events=events,regs=regs,
                    memory=[int.from_bytes(mem[i:i+4],'little') for i in range(0,16384,4)],stalls=stalls,
                    reads=sum(e['mk']==1 for e in events),writes=sum(e['mk']==2 for e in events))
    def read(r):
        assert regs[r] is not None, f'{p.name}: uninitialized x{r} PC={pc:x}'
        return regs[r]
    for step in range(2000):
        if not 0<=pc<16384: return locals_result(1,pc)
        word=p.code.get(pc,0xffffffff); op=word&127; rd=(word>>7)&31; f=(word>>12)&7; a=(word>>15)&31; b=(word>>20)&31; f7=word>>25
        imm=signed(word>>20,12); nxt=u(pc+4); value=None; sources=[]; mk=0; addr=mask=wd=raw=0; load=False
        cause=0
        if op==0x37: value=word&0xfffff000
        elif op==0x17: value=u(pc+(word&0xfffff000))
        elif op==0x6f:
            off=signed(((word>>31)<<20)|(((word>>12)&255)<<12)|(((word>>20)&1)<<11)|(((word>>21)&1023)<<1),21)
            nxt=u(pc+off); value=u(pc+4)
            if nxt%4: cause=9
        elif op==0x67 and f==0:
            sources=[a]; nxt=u(read(a)+imm)&~1; value=u(pc+4)
            if nxt%4: cause=9
        elif op==0x63 and f in (0,1,4,5,6,7):
            sources=[a,b]; av,bv=read(a),read(b)
            take={0:av==bv,1:av!=bv,4:signed(av)<signed(bv),5:signed(av)>=signed(bv),6:av<bv,7:av>=bv}[f]
            if take:
                off=signed(((word>>31)<<12)|(((word>>7)&1)<<11)|(((word>>25)&63)<<5)|(((word>>8)&15)<<1),13)
                nxt=u(pc+off)
                if nxt%4: cause=9
        elif op in (0x13,0x33):
            legal=(op==0x13 and (f in (0,2,3,4,6,7) or f==1 and f7==0 or f==5 and f7 in (0,32))) or (op==0x33 and (f7==0 or f7==32 and f in (0,5)))
            if not legal: cause=2
            else:
                sources=[a] if op==0x13 else [a,b]; av=read(a); bv=u(imm) if op==0x13 else read(b); sh=bv&31
                if f==0: value=u(av-bv) if op==0x33 and f7==32 else u(av+bv)
                elif f==1: value=u(av<<sh)
                elif f==2: value=int(signed(av)<signed(bv))
                elif f==3: value=int(av<bv)
                elif f==4: value=av^bv
                elif f==5: value=u(signed(av)>>sh) if f7==32 else av>>sh
                elif f==6: value=av|bv
                elif f==7: value=av&bv
        elif op in (3,0x23):
            load=op==3; legal=f in ((0,1,2,4,5) if load else (0,1,2))
            if not legal: cause=2
            else:
                sources=[a] if load else [a,b]
                off=imm if load else signed(((word>>25)<<5)|((word>>7)&31),12)
                addr=u(read(a)+off); width=1<<(f&3)
                if addr%width: cause=5 if load else 7
                elif not 0x10000<=addr<=0x13fff: cause=6 if load else 8
                else:
                    index=addr-0x10000; lane=addr%4; mk=1 if load else 2
                    raw=int.from_bytes(mem[index-lane:index-lane+4],'little')
                    if load:
                        value=int.from_bytes(mem[index:index+width],'little')
                        if f<4: value=u(signed(value,width*8))
                    else:
                        payload=read(b)&((1<<(width*8))-1)
                        mem[index:index+width]=payload.to_bytes(width,'little'); mask=((1<<width)-1)<<lane; wd=u(payload<<(8*lane))
        elif op==0xf and f==0: pass
        elif word==0x73: cause=4
        elif word==0x100073: cause=3
        else: cause=2
        if previous_load and previous_load in sources: stalls+=1
        if cause: return locals_result(cause,pc)
        actual_rd=rd if value is not None and rd else 0
        if actual_rd: regs[rd]=u(value)
        events.append(dict(pc=pc,word=word,rd=actual_rd,value=u(value or 0),mk=mk,addr=addr,mask=mask,wd=wd,raw=raw))
        previous_load=rd if load and rd else None
        pc=nxt
    raise ValueError(f'{p.name}: model watchdog')

