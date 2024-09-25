package CrossBar;

import Vector::*;
import GetPut::*;
import XArbiter::*;
import FIFO::*;
import Connectable::*;

// Build a crossbar between multiple master and slave.
// Routing Policy and Arbiter Policy is flexable.

// Latency is fixed for now.
module mkCrossbarIntf#(
    function Bit#(slv_num) getRoute(mst_index_t mst, data_t payload),
    module #(XArbiter#(mst_num, data_t)) mkArb
)(
    Tuple2#(Vector#(mst_num, Put#(data_t)), Vector#(slv_num, Get#(data_t)))
) provisos(
    Alias#(mst_index_t, Bit#(TLog#(mst_num))),
    Bits#(data_t, data_size),
    FShow#(data_t)
);
    // Creating Interface vector.
    Vector#(mst_num, Put#(data_t)) mst_intf = ?;
    Vector#(slv_num, Get#(data_t)) slv_intf = ?;

    // For each master, Create a skid buffer, for Put interface.
    Reg#(Bool) mst_valid [valueOf(mst_num)][2];
    Reg#(data_t) mst_payload [valueOf(mst_num)][2];
    // A Clear signal used for clear mst request.
    Vector#(mst_num, Vector#(slv_num, Wire#(Bool))) mst_clear <- replicateM(replicateM(mkDWire(False)));
    // Note: this module does not support QOS Sort of things. so dec must be One-Hot encoded;
    Reg#(Bit#(slv_num)) mst_dec [valueOf(mst_num)][2];
    for(Integer m = 0 ; m < valueOf(mst_num) ; m = m + 1) begin
        mst_valid[m] <- mkCReg(2, False);
        mst_payload[m] <- mkCReg(2, ?);
        mst_dec[m] <- mkCReg(2, ?);
        mst_intf[m] = (
        interface Put#(data_t);
            method Action put(data_t payload) if(mst_valid[m][0] == False);
                let slv_dec = getRoute(fromInteger(m), payload);
                mst_valid[m][0] <= True;
                mst_dec[m][0] <= slv_dec;
                mst_payload[m][0] <= payload;
            endmethod
        endinterface
        );
        // Clear master skid buffer when needed
        rule mst_clear_handle;
            Bool c = False;
            for(Integer s = 0 ; s < valueOf(slv_num) ; s = s + 1) begin
                c = c || mst_clear[m][s];
            end
            if(c) mst_valid[m][1] <= False;
        endrule
    end

    // For each slave, also create a skid buffer.
    Reg#(Bool) slv_valid [valueOf(slv_num)][2];
    Reg#(data_t) slv_payload [valueOf(slv_num)][2];
    for(Integer s = 0 ; s < valueOf(slv_num) ; s = s + 1) begin
        slv_valid[s] <- mkCReg(2, False);
        slv_payload[s] <- mkCReg(2, ?);

        // Connect slave Get interface to skid buffer.
        slv_intf[s] = (
        interface Get#(data_t);
            method ActionValue#(data_t) get() if(slv_valid[s][1] == True);
                slv_valid[s][1] <= False;
                return slv_payload[s][1];
            endmethod
        endinterface
        );
    end

    // Now the question is how to transfer data from master skid buffer to slave skid buffer.
    for(Integer s = 0 ; s < valueOf(slv_num) ; s = s + 1) begin
        // Master request arbiter.
        XArbiter#(mst_num, data_t) arb <- mkArb;
        for(Integer m = 0 ; m < valueOf(mst_num) ; m = m + 1) begin
            rule submit_request_to_arb(!slv_valid[s][0] &&& mst_valid[m][1] &&& mst_dec[m][1][s] == 1'b1);
                arb.clients[m].request(mst_payload[m][1]);
            endrule
        end

        rule arbiter_handle(!slv_valid[s][0]);
            let sel = arb.grant_id;
            if(arb.clients[sel].grant) begin
                mst_clear[sel][s] <= True;
                slv_valid[s][0] <= True;
                slv_payload[s][0] <= mst_payload[sel][1];
            end
        endrule
    end

    return tuple2(mst_intf, slv_intf);

endmodule

module mkCrossbarConnect #(
    function Bit#(slv_num) getRoute(mst_index_t mst, data_t payload),
    module #(XArbiter#(mst_num, data_t)) mkArb,
    Vector#(mst_num, Get#(data_t)) mst_if,
    Vector#(slv_num, Put#(data_t)) slv_if
)(Empty) provisos(
    Alias#(mst_index_t, Bit#(TLog#(mst_num))),
    Bits#(data_t, data_size),
    FShow#(data_t)
);

    Tuple2#(Vector#(mst_num, Put#(data_t)),Vector#(slv_num, Get#(data_t))) intf <- mkCrossbarIntf(getRoute, mkArb);
    match {.mst, .slv} = intf;
    for(Integer m = 0 ; m < valueOf(mst_num) ; m = m + 1) mkConnection(mst[m], mst_if[m]);
    for(Integer s = 0 ; s < valueOf(slv_num) ; s = s + 1) mkConnection(slv[s], slv_if[s]);

endmodule

endpackage : CrossBar