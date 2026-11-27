import struct, sys
ids={93544,93545,93546,93553,93554,93556,95385,93425,100168,100562,84069,84153,83483}
def check(path):
    try:
        with open(path,'rb') as f: data=f.read()
    except Exception as e: print(path,"OPEN-ERR",e); return
    if data[:4]!=b'WDBC': print(path,"not WDBC (%r)"%data[:4]); return
    rc,fc,rs,ss=struct.unpack('<4I', data[4:20])
    present=set(); maxid=0; base=20
    for i in range(rc):
        rid=struct.unpack('<I', data[base+i*rs:base+i*rs+4])[0]
        if rid>maxid: maxid=rid
        if rid in ids: present.add(rid)
    print(f"{path}\n   records={rc} fields={fc} recsize={rs} maxid={maxid}\n   DEEPHOLM-FOUND={sorted(present)}")
for p in sys.argv[1:]: check(p)
