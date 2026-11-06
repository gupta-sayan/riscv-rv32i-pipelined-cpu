module fault_ctrl (
    input  logic clk,
    input  logic rst,

    input  logic        ex_evt_valid, // EX stage
    input  logic [3:0]  ex_evt_cause,
    input  logic [31:0] ex_evt_pc,
    input  logic redirect_valid,
    input  logic idex_valid,

    input  logic        id_evt_valid, // ID-stage
    input  logic [3:0]  id_evt_cause,
    input  logic [31:0] id_evt_pc,

    input  logic        exmem_valid, //pipeline occupancy
    input  logic        memwb_valid,

    output logic fetch_redirect_valid,

    output logic kill_if, //kill order
    output logic kill_id,
    output logic kill_ex,

    output logic        enter_drain,
    output logic        stop_fetch,
    output logic        halted,
    output logic [31:0] fault_pc,
    output logic [3:0]  fault_cause
);
// using typedef for defining states for future type checking
typedef enum logic [1:0] { 
    RUN    = 2'b00,
    DRAIN  = 2'b01,
    HALTED = 2'b10
} fault_state_t;

fault_state_t state_q;

logic drained;
assign drained = !idex_valid && !exmem_valid && !memwb_valid;

assign halted = (state_q == HALTED);

always_ff @(posedge clk) begin // synchronous fault controller
    if (rst) begin
        state_q <= RUN;
    end
    else begin
        case (state_q)
            RUN: begin
                if (enter_drain)
                    state_q <= DRAIN;
            end

            DRAIN: begin
                if (drained)
                    state_q <= HALTED;
            end

            HALTED: begin
                state_q <= HALTED;
            end

            default: begin
                state_q <= HALTED;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        fault_pc    <= 32'b0;
        fault_cause <= 4'h0;
    end
    else if ((state_q == RUN) && enter_drain) begin
        if (idex_valid && ex_evt_valid) begin
            fault_pc    <= ex_evt_pc;
            fault_cause <= ex_evt_cause;
        end
        else if (id_evt_valid) begin
            // ID terminal event, selected only if EX does not win.
            fault_pc    <= id_evt_pc;
            fault_cause <= id_evt_cause;
        end
    end
end

always_comb begin
    //default
    kill_if = 1'b0;
    kill_id = 1'b0;
    kill_ex = 1'b0;

    enter_drain = 1'b0;

    fetch_redirect_valid = 1'b0;

    //Disable fetching outside RUN
    stop_fetch = (state_q != RUN);
 
    if (!rst && (state_q == RUN) && idex_valid && ex_evt_valid) begin //EX-stage fault.
        kill_if     = 1'b1;
        kill_id     = 1'b1;
        kill_ex     = 1'b1;
        enter_drain = 1'b1;
    end
    else if (!rst && (state_q == RUN) && idex_valid && redirect_valid) begin //EX branch/jump redirect
        kill_if              = 1'b1;
        kill_id              = 1'b1;
        fetch_redirect_valid = 1'b1;
    end
    else if (!rst && (state_q == RUN) && id_evt_valid) begin //ID stage
        kill_if     = 1'b1;
        kill_id     = 1'b1;
        enter_drain = 1'b1;
    end
end


endmodule
