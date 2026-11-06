// Module 14: binary combinational unit verification; no clock or DUT state access.
module tb_ex_event_mux;
    timeunit 1ns; timeprecision 1ps;
    logic idex_valid, lsu_evt_valid, target_misaligned;
    logic [31:0] idex_pc;
    logic [3:0] lsu_evt_cause;
    wire ex_evt_valid;
    wire [3:0] ex_evt_cause;
    wire [31:0] ex_evt_pc;
    ex_event_mux dut (
        .idex_valid(idex_valid), .idex_pc(idex_pc),
        .lsu_evt_valid(lsu_evt_valid), .lsu_evt_cause(lsu_evt_cause),
        .target_misaligned(target_misaligned),
        .ex_evt_valid(ex_evt_valid), .ex_evt_cause(ex_evt_cause), .ex_evt_pc(ex_evt_pc)
    );
    integer vectors=0, checks=0, failures=0, directed=0;
    integer compatible=0, robustness=0, invalid_ex=0, inactive=0;
    integer simultaneous_valid=0, simultaneous_invalid=0;
    integer supported[5:9], combinations[0:127];
    integer i,j,k;
    logic [31:0] rng=32'h14c0ffee, random_pc;
    logic [6:0] random_control;
    logic [31:0] pcs[0:71];
    logic [31:0] pc_ones=0, pc_zeros=0;
    function automatic [31:0] random_word();
        rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
        return rng;
    endfunction
    task automatic verify(input bit ok,input string name);
        checks=checks+1;
        if(!ok) begin
            failures=failures+1;
            if(failures<30)
                $display("FAIL vector=%0d %s controls=%b%b%b cause=%h pc=%h actual=%b/%h/%h",
                         vectors,name,idex_valid,lsu_evt_valid,target_misaligned,
                         lsu_evt_cause,idex_pc,ex_evt_valid,ex_evt_cause,ex_evt_pc);
        end
    endtask
    task automatic apply_vector(input logic [2:0] flags,input logic [3:0] cause,
                                input logic [31:0] pc,input string name);
        logic [4:0] candidate;
        logic [31:0] expected_pc;
        bit upstream_compatible;
        begin
            {idex_valid,lsu_evt_valid,target_misaligned}=flags;
            lsu_evt_cause=cause; idex_pc=pc;
            // Independent candidate construction: branch candidate is overlaid
            // by LSU, then the whole packet is validity qualified.
            // Overlay on simultaneous sources is implementation characterization
            // of malformed traffic, NOT an approved architectural tie-break.
            candidate=0;
            if(target_misaligned) candidate={1'b1,4'h9};
            if(lsu_evt_valid) candidate={1'b1,cause};
            if(!idex_valid) candidate=0;
            expected_pc=candidate[4]?pc:0;
            #1;
            vectors=vectors+1;
            verify(ex_evt_valid===candidate[4],{name," validity"});
            verify(ex_evt_cause===candidate[3:0],{name," cause"});
            verify(ex_evt_pc===expected_pc,{name," instruction PC"});
            verify((ex_evt_valid!==1'b0) || ({ex_evt_cause,ex_evt_pc}===36'd0),
                   {name," inactive payload zero"});
            verify(idex_valid || (ex_evt_valid===1'b0),{name," invalid EX suppresses event"});
            combinations[{flags,cause}]=combinations[{flags,cause}]+1;
            upstream_compatible=(pc[1:0]==0) && !(lsu_evt_valid && target_misaligned) &&
                (!lsu_evt_valid || (idex_valid && cause>=5 && cause<=8));
            if(upstream_compatible) compatible=compatible+1;
            else robustness=robustness+1;
            if(!idex_valid) invalid_ex=invalid_ex+1;
            if(!lsu_evt_valid && !target_misaligned) inactive=inactive+1;
            if(lsu_evt_valid && target_misaligned) begin
                if(idex_valid) simultaneous_valid=simultaneous_valid+1;
                else simultaneous_invalid=simultaneous_invalid+1;
            end
            // Supported-cause coverage counts only contract-compatible traffic.
            if(upstream_compatible && candidate[4] && candidate[3:0]>=5 && candidate[3:0]<=9)
                supported[candidate[3:0]]=supported[candidate[3:0]]+1;
            if(candidate[4]) begin pc_ones=pc_ones|pc;pc_zeros=pc_zeros|~pc;end
        end
    endtask
    task automatic scenario(input logic [2:0] flags,input logic [3:0] cause,
                            input logic [31:0] pc,input string name);
        apply_vector(flags,cause,pc,name);directed=directed+1;
        $display("DIRECTED %s output=%b/%h/%h",name,ex_evt_valid,ex_evt_cause,ex_evt_pc);
    endtask
    initial begin
        for(i=0;i<128;i=i+1) combinations[i]=0;
        for(i=5;i<=9;i=i+1) supported[i]=0;
        scenario(3'b100,4'hf,32'h100,"no active source; ignore stale cause");
        scenario(3'b110,4'h5,32'h104,"load misalignment");
        scenario(3'b110,4'h6,32'h108,"load access");
        scenario(3'b110,4'h7,32'h10c,"store misalignment");
        scenario(3'b110,4'h8,32'h110,"store access");
        scenario(3'b101,4'hf,32'h114,"branch/JAL/JALR target misalignment");
        scenario(3'b001,4'h8,32'h118,"invalid EX with stale branch candidate");
        scenario(3'b010,4'h5,32'h11c,"invalid EX suppresses malformed LSU candidate");
        scenario(3'b111,4'h6,32'h120,"defensive simultaneous sources: LSU observed");
        scenario(3'b011,4'h8,32'h124,"invalid EX with both sources");
        scenario(3'b110,4'h0,32'h128,"malformed zero LSU cause is transported");
        scenario(3'b110,4'hf,32'h12c,"malformed reserved LSU cause is transported");
        scenario(3'b100,4'h5,32'h130,"clear prior event without a clock");
        scenario(3'b101,4'h0,32'h134,"assert branch event without a clock");
        scenario(3'b101,4'h8,32'h138,"PC-only transition and ignored LSU cause");
        scenario(3'b000,4'hf,32'h13c,"clear all outputs without a clock");
        pcs[0]=0;pcs[1]=4;pcs[2]=32'h3ffc;pcs[3]=32'h4000;
        pcs[4]=32'h7ffffffc;pcs[5]=32'h80000000;pcs[6]=32'hfffffffc;pcs[7]=32'hffffffff;
        for(i=0;i<32;i=i+1) begin pcs[i+8]=32'd1<<i;pcs[i+40]=~(32'd1<<i);end
        // All three Boolean controls and every 4-bit LSU cause, over 72 PCs.
        for(i=0;i<8;i=i+1)
            for(j=0;j<16;j=j+1)
                for(k=0;k<72;k=k+1)
                    apply_vector(3'(i),4'(j),pcs[k],"exhaustive controls/PC patterns");
        // Legal boundary-contract inputs: aligned PC, exclusive sources,
        // supported LSU causes, and no LSU assertion on invalid EX.
        for(i=0;i<10000;i=i+1) begin
            random_control=7'(random_word());random_pc=random_word() & 32'hfffffffc;
            case(random_control[1:0])
                0: apply_vector({random_control[2],2'b00},random_control[6:3],random_pc,"compatible random inactive");
                1: apply_vector({random_control[2],2'b01},random_control[6:3],random_pc,"compatible random branch");
                default: apply_vector({random_control[2],random_control[2],1'b0},
                                     4'd5+{2'b00,random_control[4:3]},random_pc,"compatible random LSU");
            endcase
        end
        for(i=0;i<10000;i=i+1) begin
            random_control=7'(random_word());random_pc=random_word();
            apply_vector(random_control[6:4],random_control[3:0],random_pc,"unconstrained robustness random");
        end
        for(i=0;i<128;i=i+1) verify(combinations[i]>0,"control/cause coverage");
        for(i=5;i<=9;i=i+1) begin
            verify(supported[i]>0,"supported cause on compatible input");
            $display("COVER cause=%h compatible_events=%0d",4'(i),supported[i]);
        end
        verify(invalid_ex>0,"invalid EX coverage");verify(inactive>0,"inactive sources coverage");
        verify(simultaneous_valid>0,"valid EX simultaneous sources");
        verify(simultaneous_invalid>0,"invalid EX simultaneous sources");
        verify((&pc_ones)===1'b1,"every PC bit propagated high");
        verify((&pc_zeros)===1'b1,"every PC bit propagated low");
        $display("COVER compatible=%0d robustness=%0d invalid_EX=%0d inactive_sources=%0d simultaneous_valid=%0d simultaneous_invalid=%0d",
                 compatible,robustness,invalid_ex,inactive,simultaneous_valid,simultaneous_invalid);
        $display("RESULT vectors=%0d checks=%0d passing=%0d failures=%0d directed=%0d sweep=9216 compatible_random=10000 robustness_random=10000 seed=14c0ffee",
                 vectors,checks,checks-failures,failures,directed);
        if(failures!=0) $fatal(1,"EX event mux verification failed");
        $finish;
    end
endmodule
