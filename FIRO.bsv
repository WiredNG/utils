package FIRO;

import FIFO::*;
import Vector::*;
import LCGR::*;
import GetPut::*;

// FIRST IN, RANDOM OUT
// AN MODULE USED MAINLY FOR TEST.

interface FIRO #(type data_t, numeric type count);
    method Action deq();
    method Action enq(data_t d);
    method data_t first;
endinterface

instance ToGet#(FIRO#(data_t, count), data_t);
  function Get#(data_t) toGet(FIRO#(data_t, count) f);
    return (interface Get;
      method ActionValue#(data_t) get;
        f.deq;
        return f.first;
      endmethod
    endinterface);
  endfunction
endinstance

instance ToPut#(FIRO#(data_t, count), data_t);
  function Put#(data_t) toPut(FIRO#(data_t, count) f);
    return (interface Put;
      method Action put(data_t payload);
        f.enq(payload);
      endmethod
    endinterface);
  endfunction
endinstance

module mkFIRO (
    FIRO#(data_t, count)
) provisos (
    Bits#(data_t, data_size),
    Add#(sub0, TLog#(count), 31),
    Add#(sub1, TLog#(count), 32)
);

// Compress FIFO
// 0 for read to update valid status
// 1 for compress
// 2 for write to update valid status and data
Reg#(Maybe#(data_t)) compress_fifo[valueOf(count)][3];
for(Integer i = 0 ; i < valueOf(count) ; i = i + 1) begin
    compress_fifo[i] <- mkCReg(3, Invalid);
end

// FIFO Compressor
// Compress one entry per cycle
rule compress_fifo_maintain;
    Bool compressed = False;
    for(Integer i = 0 ; i < (valueOf(count) - 1) ; i = i + 1) begin
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
Reg#(Bit#(TAdd#(TLog#(count), 1))) cnt[2] <- mkCReg(2, 0);
Wire#(Bool) can_read  <- mkWire;
Wire#(Bool) can_write <- mkWire;
rule can_read_maintain(cnt[0] != 0);
    can_read <= True;
endrule
rule can_write_maintain(cnt[0] != fromInteger(valueOf(count)));
    can_write <= True;
endrule

// RPTR
// only maintained by read logic.
Reg#(Bit#(TLog#(count))) rptr <- mkReg(0);

// Random number
Reg#(UInt#(32)) random_number <- mkReg(1234567);
// Read logic
method Action deq();
    if(can_read) begin
        Bit#(TAdd#(TLog#(count), 1)) new_count = cnt[0] - 1;
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

endmodule

endpackage

