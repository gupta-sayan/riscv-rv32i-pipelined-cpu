// MODULE 07; Class A verification-only change, authorized by CODEX TASK.
// Independent arithmetic/byte-lane oracle; no DUT internals inspected.
// Legal-control checks and unspecified-control characterization are separate.
// LB/LBU and LH/LHU are identical EX requests; extension belongs to MEM.
`timescale 1ns/1ps
module tb_lsu_ex;
    logic [31:0] eff_addr, store_data;
    logic [1:0] mem_size;
    logic mem_read, mem_write, idex_valid, run_active, rst;
    wire [31:0] dmem_addr, dmem_wdata;
    wire dmem_re, dmem_we, lsu_evt_valid;
    wire [3:0] dmem_wmask, lsu_evt_cause;
    lsu_ex dut (.*);
    integer tests=0, failures=0, probes=0;
    integer ops[0:7], lanes[0:3], causes[0:8];
    integer accepted_reads=0, accepted_writes=0;
    reg [31:0] rng=32'h07c0ffee;
    reg [31:0] boundaries[0:23];
    integer i,j,k,g;
    reg [31:0] a, payload;

    function automatic [31:0] random_word();
        begin
            rng=rng ^ (rng << 13);
            rng=rng ^ (rng >> 17);
            rng=rng ^ (rng << 5);
            random_word=rng;
        end
    endfunction

    task automatic check_access(input integer op, input reg [31:0] addr,
                                input reg [31:0] data, input integer gates);
        integer size_bytes, lane, b, cause;
        reg active, legal, er, ew;
        reg [3:0] mask;
        reg [31:0] shifted;
        begin
            // op: LB,LBU,LH,LHU,LW,SB,SH,SW.
            case(op)
                0,1,5: size_bytes=1;
                2,3,6: size_bytes=2;
                default: size_bytes=4;
            endcase
            eff_addr=addr; store_data=data;
            case(size_bytes)
                1: mem_size=0;
                2: mem_size=1;
                default: mem_size=2;
            endcase
            mem_read=(op<5); mem_write=(op>=5);
            rst=(gates & 1)!=0;
            run_active=(gates & 2)==0;
            idex_valid=(gates & 4)==0;
            active=!rst && run_active && idex_valid;
            cause=0;
            // Natural alignment from arithmetic, range from the region quotient.
            if(active) begin
                if((addr % size_bytes)!=0) cause=(op<5)?5:7;
                else if((addr / 16384)!=4) cause=(op<5)?6:8;
            end
            legal=active && (cause==0);
            er=legal && (op<5); ew=legal && (op>=5);
            lane=addr % 4; mask=0; shifted=0;
            // Construct individual bytes rather than copying RTL shifts/masks.
            for(b=0;b<size_bytes;b=b+1) begin
                if(lane+b<4) begin
                    mask[lane+b]=1;
                    shifted[8*(lane+b)+:8]=data[8*b+:8];
                end
            end
            // Word payload/mask are specified only for naturally aligned stores.
            #1;
            tests=tests+1; ops[op]=ops[op]+1; lanes[lane]=lanes[lane]+1;
            causes[cause]=causes[cause]+1;
            if(dmem_addr!==addr || dmem_re!==er || dmem_we!==ew ||
               lsu_evt_valid!==(cause!=0) || lsu_evt_cause!==cause[3:0] ||
               (dmem_re && dmem_we) ||
               (ew && (dmem_wmask!==mask || dmem_wdata!==shifted))) begin
                failures=failures+1;
                $display("FAIL test=%0d op=%0d addr=%h data=%h gates=%0d actual re/we/evt/cause=%b%b%b/%h expected=%b%b/%0d mask=%h/%h data=%h/%h",
                         tests,op,addr,data,gates,dmem_re,dmem_we,lsu_evt_valid,
                         lsu_evt_cause,er,ew,cause,dmem_wmask,mask,dmem_wdata,shifted);
            end
            if(dmem_re) accepted_reads=accepted_reads+1;
            if(dmem_we) accepted_writes=accepted_writes+1;
        end
    endtask

    initial begin
        for(i=0;i<8;i=i+1) ops[i]=0;
        for(i=0;i<4;i=i+1) lanes[i]=0;
        for(i=0;i<9;i=i+1) causes[i]=0;
        boundaries[0]=0; boundaries[1]=1; boundaries[2]=2; boundaries[3]=3;
        boundaries[4]=32'hfffc; boundaries[5]=32'hfffd;
        boundaries[6]=32'hfffe; boundaries[7]=32'hffff;
        boundaries[8]=32'h10000; boundaries[9]=32'h10001;
        boundaries[10]=32'h10002; boundaries[11]=32'h10003;
        boundaries[12]=32'h13ffc; boundaries[13]=32'h13ffd;
        boundaries[14]=32'h13ffe; boundaries[15]=32'h13fff;
        boundaries[16]=32'h14000; boundaries[17]=32'h14001;
        boundaries[18]=32'h14002; boundaries[19]=32'h14003;
        boundaries[20]=32'hfffffffc; boundaries[21]=32'hfffffffd;
        boundaries[22]=32'hfffffffe; boundaries[23]=32'hffffffff;
        for(i=0;i<8;i=i+1)
            for(j=0;j<24;j=j+1)
                for(g=0;g<8;g=g+1)
                    check_access(i,boundaries[j],32'h89abcdef,g);
        // Exhaustive starting byte coverage of the entire DMEM for each op.
        for(i=0;i<8;i=i+1)
            for(j=0;j<16384;j=j+1) begin
                payload=random_word();
                check_access(i,32'h10000+32'(j),payload,0);
            end
        // Fixed xorshift seed; uniform full-address and boundary-biased cases.
        for(k=0;k<20000;k=k+1) begin
            a=random_word();
            case(k%3)
                0: a=32'h10000+(a%16384);
                1: a=boundaries[a%24];
                default: begin end
            endcase
            payload=random_word();
            check_access(k%8,a,payload,(k%5==0)?(k%8):0);
        end
        // No-intent and unspecified control probes: check unconditional safety,
        // print observed events without inventing architectural fault semantics.
        rst=0; run_active=1; idex_valid=1; store_data=32'hdeadbeef;
        for(i=0;i<4;i=i+1)
            for(j=0;j<24;j=j+1) begin
                eff_addr=boundaries[j]; mem_size=2'(i);
                mem_read=0; mem_write=0; #1;
                tests=tests+1;
                if(dmem_re!==0 || dmem_we!==0 || lsu_evt_valid!==0) failures=failures+1;
                mem_read=1; mem_write=1; #1;
                probes=probes+1;
                if(dmem_re!==0 || dmem_we!==0) failures=failures+1;
                if(j==8 || j==19)
                    $display("PROBE overlap size=%0d addr=%h re/we=%b%b event=%b cause=%h",i,eff_addr,dmem_re,dmem_we,lsu_evt_valid,lsu_evt_cause);
            end
        mem_size=3;
        for(i=0;i<2;i=i+1)
            for(j=0;j<24;j=j+1) begin
                mem_read=(i==0); mem_write=(i==1); eff_addr=boundaries[j]; #1;
                probes=probes+1;
                if(dmem_re!==0 || dmem_we!==0) failures=failures+1;
                if(j==8 || j==19)
                    $display("PROBE reserved write=%0d addr=%h event=%b cause=%h",i,eff_addr,lsu_evt_valid,lsu_evt_cause);
            end
        for(i=0;i<8;i=i+1) begin
            $display("COVER op=%0d cases=%0d",i,ops[i]);
            if(ops[i]==0) failures=failures+1;
        end
        for(i=0;i<4;i=i+1) begin
            $display("COVER lane=%0d cases=%0d",i,lanes[i]);
            if(lanes[i]==0) failures=failures+1;
        end
        for(i=5;i<=8;i=i+1) begin
            $display("COVER cause=%0h cases=%0d",i,causes[i]);
            if(causes[i]==0) failures=failures+1;
        end
        $display("RESULT tests=%0d characterization_probes=%0d failures=%0d reads=%0d writes=%0d seed=07c0ffee",tests,probes,failures,accepted_reads,accepted_writes);
        if(failures!=0) $fatal(1,"LSU verification failed");
        $finish;
    end
endmodule
