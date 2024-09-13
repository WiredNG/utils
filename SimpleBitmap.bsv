package SimpleBitmap;

import FIFO::*;
import PriorityEncodeOH::*;

module mkSimpleBitmap (
    Tuple2(Get#(index_t), Put#(index_t))
) provisos(
    Bits#(index_t, index_width)
);

typedef TExp#(index_width) bit_count;

Reg#(Bit#(bit_count)) bitmap <- mkReg('1); // free map
Reg#(Bool) empty <- mkReg(0);

FIFOF#(Bit#(index_t)) allocate_list <- mkFIFO;
FIFOF#(Bit#(index_t)) free_list <- mkFIFO;

rule allocate_from_freelist(free_list.notEmpty && !allocate_list.notFull);
    // BITMAP WILL NOT CHANGED
    free_list.deq;
    allocate_list.enq(free_list.first);
endrule

rule allocate_from_map(!free_list.notEmpty && !empty);
    // UPDATE BITMAP
    let sel = priorityEncodeOHR(bitmap);
    Bit#(bit_count) map = bitmap;
    map[sel] = 0;
    busy_map.enq(sel);
    bitmap <= map;
endrule

rule free_to_map(!allocate_list.notFull);
    // UPDATE BITMAP
    let sel = free_list.first;
    free_list.deq;
    Bit#(bit_count) map = bitmap;
    map[sel] = 1;
    bitmap <= map;
endrule

endmodule

endpackage
