package FIRO;

import FIFO::*;
import Vector::*;
import LCGR::*;

// FIRST IN, RANDOM OUT
// AN MODULE USED MAINLY FOR TEST.

module mkFIRO (
    FIFO#(data_t)
) provisos (
    Bits#(data_t, data_size)
);

// Compress FIFO
// 0 for read to update valid status
// 1 for compress
// 2 for write to update valid status and data
Reg#(Maybe#(data_t)) compress_fifo[32][3];
for(Integer i = 0 ; i < 32 ; i = i + 1) begin
    compress_fifo[i] <- mkCReg(3, Invalid);
end

// FIFO Compressor
// Compress one entry per cycle
rule compress_fifo_maintain;
    Bool compressed = False;
    for(Integer i = 0 ; i < 31 ; i = i + 1) begin
        if(compress_fifo[i][1] matches tagged Invalid) compressed = True;
        if(compressed) begin
            compress_fifo[i][1] <= compress_fifo[i + 1][1];
        end
    end
endrule

// CNT
// Valid data count
// 0 for read and update
// 1 for write
Reg#(Bit#(6)) cnt[2] <- mkCReg(2, 0);
Wire#(Bool) can_read  <- mkWire;
Wire#(Bool) can_write <- mkWire;
rule can_read_maintain(cnt[0] != 0);
    can_read <= True;
endrule
rule can_write_maintain(cnt[0] != 32);
    can_write <= True;
endrule

// RPTR
// only maintained by read logic.
Reg#(Bit#(5)) rptr <- mkReg(0);

// Random number
Reg#(UInt#(32)) random_number <- mkReg(1234567);
// Read logic
method Action deq();
    if(can_read) begin
        Bit#(6) new_count = cnt[0] - 1;
        cnt[0] <= new_count;
        // rptr <= gen_random_value between [0, new_count + 0.5);
        random_number <= lcg(random_number);
        rptr <= new_count != 0 ? truncate(unpack(pack(random_number % zeroExtend(unpack(pack(new_count)))))) : 0;
        compress_fifo[rptr][0] <= tagged Invalid;
    end
endmethod

// Write logic
method Action enq(data_t d);
    if(can_write) begin
        compress_fifo[cnt[1]][2] <= tagged Valid d;
        cnt[1] <= cnt[1] + 1;
    end
endmethod

method data_t first;
    data_t d = ?;
    if(compress_fifo[rptr][0] matches tagged Valid .payload) d = payload;
    return d;
endmethod

method Action clear;
    $display("FIRO DO NOT SUPPORT CLEAR.");
endmethod

endmodule

endpackage

