import sys, struct
# Parse a .ko's __versions section: array of {u64 crc; char name[56]} (64 bytes each)
def sections(data):
    assert data[:4]==b'\x7fELF'
    is64 = data[4]==2; le = data[5]==1
    end = '<' if le else '>'
    e_shoff=struct.unpack_from(end+'Q',data,0x28)[0]
    e_shentsize=struct.unpack_from(end+'H',data,0x3a)[0]
    e_shnum=struct.unpack_from(end+'H',data,0x3c)[0]
    e_shstrndx=struct.unpack_from(end+'H',data,0x3e)[0]
    secs=[]
    for i in range(e_shnum):
        off=e_shoff+i*e_shentsize
        name,typ,flags,addr,offset,size=struct.unpack_from(end+'IIQQQQ',data,off)
        secs.append([name,offset,size])
    strtab_off=secs[e_shstrndx][1]
    def nm(n):
        e=data.index(b'\0',strtab_off+n); return data[strtab_off+n:e].decode()
    return {nm(s[0]):(s[1],s[2]) for s in secs}, end
def versions(path):
    d=open(path,'rb').read(); secs,end=sections(d)
    if '__versions' not in secs: return {}
    off,size=secs['__versions']; out={}
    for i in range(0,size,64):
        crc=struct.unpack_from(end+'Q',d,off+i)[0] & 0xffffffff
        name=d[off+i+8:off+i+64].split(b'\0')[0].decode()
        if name: out[name]=crc
    return out
if __name__=='__main__':
    a=versions(sys.argv[1])
    if len(sys.argv)==2:
        for k,v in sorted(a.items()): print(f"{v:08x} {k}")
    else:
        b=versions(sys.argv[2])
        common=set(a)&set(b); print(f"# comparing {sys.argv[1]} vs {sys.argv[2]}; shared imports={len(common)}")
        mism=[k for k in sorted(common) if a[k]!=b[k]]
        for k in mism: print(f"MISMATCH {k}: {a[k]:08x} vs {b[k]:08x}")
        print(f"# mismatches={len(mism)} of {len(common)} shared")
