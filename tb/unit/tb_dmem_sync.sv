// MODULE 08: Class A verification-only change, authorized by user task.
// Independent byte-addressed scoreboard, initialized only through port writes.
// No simultaneous read/write and no out-of-range enabled transactions.
`timescale 1ns/1ps
module tb_dmem_sync;
    logic clk=0;
    logic [31:0] dmem_addr=32'h10000, dmem_wdata=0;
    logic dmem_re=0, dmem_we=0;
    logic [3:0] dmem_wmask=0;
    wire [31:0] dmem_rdata;
    dmem_sync dut (.*);
    reg [7:0] reference_bytes[0:16383];
    reg [31:0] expected_output;
    reg [31:0] rng=32'h08c0ffee;
    integer vectors=0, checks=0, failures=0, reads=0, writes=0, idles=0;
    integer masks[0:15], lanes[0:3], read_words[0:4095], write_words[0:4095];
    integer rr=0, ww=0, rw=0, wr=0, previous=0;
    integer i,j,k;
    reg [31:0] a,data;
    reg [3:0] mask;
    integer mode;
    function automatic [31:0] random_word();
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic compare_output(input string phase);
        begin
            checks=checks+1;
            if(dmem_rdata !== expected_output) begin
                failures=failures+1;
                $display("FAIL vector=%0d phase=%s addr=%h re/we=%b%b expected=%h actual=%h",
                         vectors,phase,dmem_addr,dmem_re,dmem_we,expected_output,dmem_rdata);
            end
        end
    endtask
    task automatic cycle(input integer operation, input reg [31:0] address,
                         input reg [3:0] byte_mask, input reg [31:0] payload);
        integer base,b,current;
        begin
            if(clk!==0 || operation<0 || operation>2 || address<32'h10000 || address>32'h13fff)
                $fatal(1,"Invalid testbench stimulus");
            vectors=vectors+1;
            dmem_addr=address; dmem_wmask=byte_mask; dmem_wdata=payload;
            dmem_re=(operation==1); dmem_we=(operation==2);
            base=4*int'((address-32'h10000)/4);
            #2; compare_output("before rising edge");
            clk=1;
            // Check in the initiating active region, before DUT NBA updates.
            compare_output("before NBA");
            if(operation==1) begin
                expected_output={reference_bytes[base+3],reference_bytes[base+2],
                                 reference_bytes[base+1],reference_bytes[base]};
                reads=reads+1; read_words[base/4]=read_words[base/4]+1;
            end
            if(operation==2) begin
                for(b=0;b<4;b=b+1)
                    if(byte_mask[b]) reference_bytes[base+b]=payload[8*b+:8];
                writes=writes+1; masks[byte_mask]=masks[byte_mask]+1;
                write_words[base/4]=write_words[base/4]+1;
            end
            if(operation==0) idles=idles+1;
            lanes[address%4]=lanes[address%4]+1;
            current=operation;
            if(previous==1 && current==1) rr=rr+1;
            if(previous==2 && current==2) ww=ww+1;
            if(previous==1 && current==2) rw=rw+1;
            if(previous==2 && current==1) wr=wr+1;
            previous=current;
            #1; compare_output("after rising-edge NBA");
            #2; clk=0;
            #1; compare_output("after falling edge");
        end
    endtask
    // Assert a write spanning a falling edge but no rising edge, then verify
    // via the public read port that no memory write was accepted.
    task automatic cancelled_write(input reg [31:0] address);
        begin
            cycle(1,address,0,0);
            dmem_re=0;
            #1; clk=1; #1;
            dmem_we=1; dmem_wmask=15; dmem_wdata=~expected_output;
            #1; compare_output("write pulse while clock high");
            clk=0; #1; compare_output("write pulse at falling edge");
            dmem_we=0; #1;
            vectors=vectors+1; previous=0;
            cycle(1,address,0,0);
        end
    endtask
    initial begin
        // X initialization belongs only to the reference model, never DUT.
        expected_output=32'hxxxxxxxx;
        for(i=0;i<16384;i=i+1) reference_bytes[i]=8'hxx;
        for(i=0;i<16;i=i+1) masks[i]=0;
        for(i=0;i<4;i=i+1) lanes[i]=0;
        for(i=0;i<4096;i=i+1) begin read_words[i]=0; write_words[i]=0; end
        #1; compare_output("uninitialized output (four-state simulation)");
        cycle(0,32'h10000,0,0);
        cycle(1,32'h10000,0,0);
        cycle(1,32'h13fff,0,0);
        // Partially initialized word: unknown lanes remain unknown.
        cycle(2,32'h10000,1,32'h76543210);
        cycle(1,32'h10000,0,0);
        // Distinct reproducible data in all 4096 words, written via ports only.
        for(i=0;i<4096;i=i+1)
            cycle(2,32'h10000+4*32'(i),15,32'ha5910000^32'(i*65793));
        // All 16384 byte addresses must select the containing word.
        for(i=0;i<16384;i=i+1) cycle(1,32'h10000+32'(i),0,0);
        // Every mask at every word; immediately read back to detect corruption.
        for(i=0;i<4096;i=i+1)
            for(j=0;j<16;j=j+1) begin
                data=random_word();
                cycle(2,32'h10000+4*32'(i)+32'(j%4),4'(j),data);
                cycle(1,32'h10000+4*32'(i),0,0);
            end
        for(i=0;i<64;i=i+1) begin
            if(i%2==0) a=32'h10000; else a=32'h13fff;
            cancelled_write(a);
        end
        // Random read/write/idle stream, fixed algorithm and seed.
        for(k=0;k<20000;k=k+1) begin
            a=32'h10000+(random_word()%16384);
            data=random_word(); mask=4'(random_word()); mode=int'(random_word()%3);
            cycle(mode,a,mask,data);
        end
        // Persistence while disabled with changing address, data and mask.
        for(i=0;i<100;i=i+1) begin
            a=32'h10000+(random_word()%16384); data=random_word();
            cycle(0,a,4'(i),data);
        end
        // Whole-memory final sweep catches aliases and unintended byte writes.
        for(i=0;i<4096;i=i+1) cycle(1,32'h10000+4*32'(i),0,0);
        for(i=0;i<4096;i=i+1)
            if(read_words[i]==0 || write_words[i]==0) $fatal(1,"Missing word coverage");
        for(i=0;i<16;i=i+1) begin
            $display("COVER mask=%h writes=%0d",4'(i),masks[i]);
            if(masks[i]<4096) $fatal(1,"Missing mask coverage");
        end
        for(i=0;i<4;i=i+1) $display("COVER offset=%0d vectors=%0d",i,lanes[i]);
        if(rr==0 || ww==0 || rw==0 || wr==0) $fatal(1,"Missing transition coverage");
        $display("COVER transitions RR=%0d WW=%0d RW=%0d WR=%0d",rr,ww,rw,wr);
        $display("RESULT vectors=%0d checks=%0d failures=%0d reads=%0d writes=%0d idles=%0d cancelled_writes=64 words=4096 seed=08c0ffee",
                 vectors,checks,failures,reads,writes,idles);
        if(failures!=0) $fatal(1,"DMEM verification failed");
        $finish;
    end
endmodule
