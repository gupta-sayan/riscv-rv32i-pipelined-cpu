// Module 11 local verification; ARCH-001 Rev C sections 6, 7.4, 8.5.1.
// Binary input contract. No clock: every check follows only input changes.
module tb_hazard_ctrl;
    timeunit 1ns;
    timeprecision 1ps;
    logic ifid_valid, id_evt_valid, ifid_uses_rs1, ifid_uses_rs2;
    logic idex_valid, idex_mem_read;
    logic [4:0] ifid_rs1, ifid_rs2, idex_rd;
    wire hold_if, bubble_ex;
    hazard_ctrl dut (.*);
    integer vectors=0, checks=0, failures=0, directed=0;
    integer controls[0:63];
    integer rs1_seen[0:31], rs2_seen[0:31], rd_seen[0:31];
    integer outcomes[0:1];
    integer i;
    logic [31:0] rng=32'h11c0ffee;
    logic [20:0] word_value;

    function automatic [31:0] random_word();
        rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
        return rng;
    endfunction

    task automatic apply_vector(input logic [20:0] value,
                                input string label_text);
        logic [31:0] consumed;
        logic expected;
        begin
            {ifid_valid,id_evt_valid,ifid_uses_rs1,ifid_uses_rs2,
             idex_valid,idex_mem_read,ifid_rs1,ifid_rs2,idex_rd}=value;
            // Independent architectural model: build the set of consumed
            // registers, discard x0, then ask if a live load produces a member.
            consumed=0;
            if(ifid_valid && !id_evt_valid) begin
                if(ifid_uses_rs1) consumed[ifid_rs1]=1;
                if(ifid_uses_rs2) consumed[ifid_rs2]=1;
            end
            consumed[0]=0;
            expected=0;
            if(idex_valid && idex_mem_read) expected=consumed[idex_rd];
            #1;
            vectors=vectors+1;
            checks=checks+3;
            if(hold_if !== expected) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d input=%h hold=%b expected=%b",
                         label_text,vectors,value,hold_if,expected);
            end
            if(bubble_ex !== expected) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d input=%h bubble=%b expected=%b",
                         label_text,vectors,value,bubble_ex,expected);
            end
            if(hold_if !== bubble_ex) begin
                failures=failures+1;
                $display("FAIL output disagreement vector=%0d",vectors);
            end
            controls[value[20:15]]=controls[value[20:15]]+1;
            rs1_seen[ifid_rs1]=rs1_seen[ifid_rs1]+1;
            rs2_seen[ifid_rs2]=rs2_seen[ifid_rs2]+1;
            rd_seen[idex_rd]=rd_seen[idex_rd]+1;
            outcomes[expected]=outcomes[expected]+1;
        end
    endtask

    task automatic scenario(input logic [5:0] flags,
                            input logic [4:0] rs1,rs2,rd,
                            input string label_text);
        apply_vector({flags,rs1,rs2,rd},label_text);
        directed=directed+1;
        $display("DIRECTED %s hold=%b bubble=%b",label_text,hold_if,bubble_ex);
    endtask

    initial begin
        for(i=0;i<64;i=i+1) controls[i]=0;
        for(i=0;i<32;i=i+1) begin
            rs1_seen[i]=0; rs2_seen[i]=0; rd_seen[i]=0;
        end
        outcomes[0]=0; outcomes[1]=0;
        // flags: IFvalid, IDevent, use1, use2, EXvalid, EXload.
        // Instruction names describe externally decoded input contracts;
        // this unit test does not instantiate or validate a decoder.
        scenario(6'b101111,5,6,5,"LW -> ADD rs1");
        scenario(6'b101111,6,5,5,"LW -> SUB rs2");
        scenario(6'b101111,5,5,5,"LW -> branch both sources");
        scenario(6'b101111,6,5,5,"LW -> SW store data");
        scenario(6'b101111,5,6,5,"LW -> SW address base");
        scenario(6'b101011,5,5,5,"LW -> JALR base, apparent rs2 unused");
        scenario(6'b101111,6,7,5,"LW -> independent ADD");
        scenario(6'b101111,0,0,0,"LW x0, both fields match");
        scenario(6'b101110,5,5,5,"non-load -> dependent ADD");
        scenario(6'b001111,5,5,5,"invalid IF/ID");
        scenario(6'b101101,5,5,5,"invalid ID/EX");
        scenario(6'b111111,5,5,5,"ID event overrides even stale usage flags");
        scenario(6'b110011,5,5,5,"fetch fault/illegal/ECALL/EBREAK contract");
        scenario(6'b100011,5,5,5,"LUI/AUIPC/JAL/FENCE apparent fields unused");
        scenario(6'b100111,5,6,5,"unused rs1 match");
        scenario(6'b101011,6,5,5,"unused rs2 match");
        // Explicit history and unused-field perturbation without any clock.
        scenario(6'b101011,5,1,5,"hazard on");
        scenario(6'b101011,5,31,5,"unused field change preserves hazard");
        scenario(6'b101011,6,5,5,"used source change clears hazard");
        scenario(6'b101011,5,5,5,"same dependency reasserts hazard");
        scenario(6'b101010,5,5,5,"load flag alone clears hazard");
        // Every combination of six control bits and three 5-bit register IDs.
        for(i=0;i<2097152;i=i+1)
            apply_vector(21'(i),"exhaustive");
        for(i=0;i<10000;i=i+1) begin
            word_value=21'(random_word());
            apply_vector(word_value[20:0],"random");
        end
        // Coverage checks are counted separately from the three per-vector checks.
        for(i=0;i<64;i=i+1) begin
            checks=checks+1;
            if(controls[i]==0) failures=failures+1;
        end
        for(i=0;i<32;i=i+1) begin
            checks=checks+3;
            if(rs1_seen[i]==0) failures=failures+1;
            if(rs2_seen[i]==0) failures=failures+1;
            if(rd_seen[i]==0) failures=failures+1;
        end
        for(i=0;i<2;i=i+1) begin
            checks=checks+1;
            if(outcomes[i]==0) failures=failures+1;
        end
        $display("COVER controls=64/64 rs1=32/32 rs2=32/32 rd=32/32 low=%0d high=%0d",
                 outcomes[0],outcomes[1]);
        $display("RESULT vectors=%0d checks=%0d failures=%0d directed=%0d exhaustive=2097152 random=10000 seed=11c0ffee",
                 vectors,checks,failures,directed);
        if(failures!=0) $fatal(1,"Hazard verification failed (including coverage)");
        $finish;
    end
endmodule
