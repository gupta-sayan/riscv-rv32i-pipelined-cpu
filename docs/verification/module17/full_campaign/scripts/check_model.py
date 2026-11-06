#!/usr/bin/env python3
"""Hand-calculated anchors for the independent oracle, using fixed machine words."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'reference_models'))
from rv32i import Program, execute

cases=[
 ('negative_add_modulo',[0xfff00093,0x00108113,0x73],2,0,4),
 ('signed_less',[0x800000b7,0x00100113,0x0020a1b3,0x73],3,1,4),
 ('unsigned_not_less',[0x800000b7,0x00100113,0x0020b1b3,0x73],3,0,4),
 ('sltiu_negative',[0x00000093,0xfff0b113,0x73],2,1,4),
 ('arithmetic_shift',[0x800000b7,0x41f0d113,0x73],2,0xffffffff,4),
 ('logical_shift',[0x800000b7,0x01f0d113,0x73],2,1,4),
 ('subtract_overflow',[0x800000b7,0x00100113,0x402081b3,0x73],3,0x7fffffff,4),
 ('auipc_pc',[0x00000013,0xfffff097,0x73],1,0xfffff004,4),
 ('illegal_shift',[0x02001093],0,0,2),
 ('nonexact_system',[0x000000f3],0,0,2),
 ('ebreak',[0x00100073],0,0,3),
 ('sb_truncated_payload',[0x000100b7,0xfff00113,0x00208023,0x73],2,0xffffffff,4),
]
for name,words,reg,value,cause in cases:
    p=Program(name)
    for word in words:p.emit(word)
    m=execute(p)
    assert m['cause']==cause,(name,m['cause'],cause)
    assert m['regs'][reg]==value,(name,m['regs'][reg],value)
    if name=='sb_truncated_payload':
        assert m['events'][-1]['wd']==255 and m['events'][-1]['mask']==1 and m['memory'][0]==255
    print('PASS MODEL ANCHOR',name)
print('PASS ALL MODEL ANCHORS cases=12')
