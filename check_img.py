import struct
img = bytearray(open('IMG/minidos.img','rb').read())
u16 = lambda o: struct.unpack_from('<H', img, o)[0]

bps, spc   = u16(0x0B), img[0x0D]
resvd, nfats = u16(0x0E), img[0x10]
rootent, fatsz = u16(0x11), u16(0x16)

root_sec  = resvd + nfats*fatsz
root_secs = (rootent*32 + bps - 1)//bps
data_sec  = root_sec + root_secs
print(f"bps={bps} spc={spc} resvd={resvd} fats={nfats} rootent={rootent} fatsz={fatsz}")
print(f"root_sec={root_sec} root_secs={root_secs} data_sec={data_sec}")

def fat_next(c):
    w = u16(resvd*bps + c*3//2)
    return (w & 0xFFF) if c % 2 == 0 else (w >> 4)

for i in range(rootent):
    e = root_sec*bps + i*32
    name = bytes(img[e:e+11])
    if name[0] in (0, 0xE5): continue
    first, size = u16(e+26), u16(e+28) | u16(e+30)<<16
    print(f"entry {i}: {name!r} first_cluster={first} size={size}")
    if name == b'MINIDOS SYS':
        chain, c = [], first
        while c < 0xFF8 and len(chain) < 100:
            chain.append(c); c = fat_next(c)
        print("  chain  :", chain, "end marker:", hex(c))
        print("  sectors:", [(x-2)*spc + data_sec for x in chain])
        kern = open('BIN/MINIDOS.SYS','rb').read()
        disk = bytes(img[data_sec*bps : data_sec*bps+16])
        print("  file head :", kern[:16].hex())
        print("  disk head :", disk.hex(), " match:", kern[:16]==disk)
