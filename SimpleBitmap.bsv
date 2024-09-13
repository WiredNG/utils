package SimpleBitmap;

import GetPut::*;
import FIFOF::*;
import PriorityEncodeOH::*;

module mkSimpleBitmap (
    GetPut#(index_t)
) provisos (
    Bits#(index_t, index_width),
    PrimIndex#(index_t, __a),
    NumAlias#(count, TExp#(index_width))
);

Reg#(Bit#(count)) bitmap <- mkReg('1); // free map
Reg#(Bool) empty <- mkReg(False);

FIFOF#(index_t) allocate_list <- mkFIFOF;
FIFOF#(index_t) free_list <- mkFIFOF;

rule allocate_from_freelist(free_list.notEmpty && allocate_list.notFull);
    // BITMAP WILL NOT CHANGED
    free_list.deq;
    allocate_list.enq(free_list.first);
    // $display("ALLOC FROM FREE LIST");
endrule

rule allocate_from_map(!free_list.notEmpty && !empty);
    // UPDATE BITMAP
    index_t sel = unpack(pack(encodeOH(priorityEncodeOHR(bitmap))));
    Bit#(count) map = bitmap;
    map[sel] = 0;
    allocate_list.enq(sel);
    bitmap <= map;
    empty <= map == 0;
    // $display("ALLOC FROM MAP");
endrule

rule free_to_map(!allocate_list.notFull);
    // UPDATE BITMAP
    index_t sel = free_list.first;
    free_list.deq;
    Bit#(count) map = bitmap;
    map[sel] = 1;
    bitmap <= map;
    empty <= map == 0;
    // $display("FREE TO MAP");
endrule

return tuple2(toGet(allocate_list), toPut(free_list));

endmodule

endpackage
