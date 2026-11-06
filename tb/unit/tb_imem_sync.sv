// MODULE 09; Class A verification-only work authorized by the user task.
// Generate imem.hex in ascending word order; preload DUT only via $readmemh.
// Independent oracle calculates expected instructions from the byte PC.
`timescale 1ns/1ps
module tb_imem_sync;
    logic clk=0, imem_en=0;
    logic [31:0] imem_addr=0;
    wire [31:0] imem_rdata;
    imem_sync dut (.*);
    reg [31:0] expected_output=32'hxxxxxxxx;
    reg [31:0] rng=32'h09c0ffee;
    integer vectors=0, checks=0, failures=0, enabled=0, disabled=0;
    integer word_reads[0:4095], word_disabled[0:4095];
    integer transitions[0:3];
    reg previous_enable=0;
    integer i,k,fd;
    reg [31:0] address,sample;
    reg enable;
    string image_path;

    function automatic [31:0] instruction_at(input reg [31:0] byte_pc);
        reg [31:0] ordinal;
        begin
            ordinal=byte_pc/4;
            // ADDI x(ordinal modulo 32),x0,imm12. All 4096 words distinct.
            instruction_at=(ordinal*32'h00100000)+((ordinal%32)*128)+32'h13;
        end
    endfunction
    function automatic [31:0] random_word();
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic check_output(input string phase);
        begin
            checks=checks+1;
            if(imem_rdata !== expected_output) begin
                failures=failures+1;
                $display("FAIL vector=%0d phase=%s pc=%h en=%b actual=%h expected=%h",
                         vectors,phase,imem_addr,imem_en,imem_rdata,expected_output);
            end
        end
    endtask
    task automatic fetch_cycle(input reg en, input reg [31:0] pc);
        begin
            if(clk!==0 || pc>32'h3ffc || pc%4!=0)
                $fatal(1,"Invalid testbench stimulus");
            vectors=vectors+1;
            imem_en=en; imem_addr=pc;
            #2; check_output("inputs changed, before rising edge");
            clk=1;
            check_output("initiating active region, before NBA");
            if(en) begin
                expected_output=instruction_at(pc);
                enabled=enabled+1; word_reads[pc/4]=word_reads[pc/4]+1;
            end else begin
                disabled=disabled+1; word_disabled[pc/4]=word_disabled[pc/4]+1;
            end
            transitions[{previous_enable,en}]=transitions[{previous_enable,en}]+1;
            previous_enable=en;
            #1; check_output("after rising-edge NBA");
            #2; clk=0;
            #1; check_output("after falling edge");
        end
    endtask
    task automatic cancelled_enable(input reg [31:0] pc);
        begin
            // Start from low clock; pulse en before the next rising edge.
            vectors=vectors+1;
            imem_en=1; imem_addr=pc;
            #1; check_output("enable pulse while clock low");
            imem_en=0;
            #1; check_output("enable pulse ended before rising edge");
            fetch_cycle(0,pc);
            // Now pulse across a falling edge, with no enabled rising edge.
            vectors=vectors+1;
            clk=1; #1; check_output("disabled rising edge before high pulse");
            imem_en=1; imem_addr=pc^32'h3ffc;
            #1; check_output("enable pulse while clock high");
            clk=0; #1; check_output("enable pulse at falling edge");
            imem_en=0; #1; check_output("enable pulse ended");
            fetch_cycle(0,pc);
        end
    endtask
    initial begin
        for(i=0;i<4096;i=i+1) begin word_reads[i]=0; word_disabled[i]=0; end
        for(i=0;i<4;i=i+1) transitions[i]=0;
        if(!$value$plusargs("IMAGE=%s",image_path)) image_path="/tmp/module09-imem.hex";
        fd=$fopen(image_path,"w");
        if(fd==0) $fatal(1,"Cannot create test image %s",image_path);
        // File generation is explicit bit-field construction; oracle above uses
        // arithmetic PC mapping and does not read this file or DUT storage.
        for(i=0;i<4096;i=i+1)
            $fdisplay(fd,"%08h",{12'(i),5'b0,3'b0,5'(i),7'b0010011});
        $fclose(fd);
        $readmemh(image_path,dut.mem,0,4095);
        $display("IMAGE %s: 4096 ascending 32-bit words; index 0 at PC 0",image_path);
        #1; check_output("preload does not update registered output");
        fetch_cycle(0,0);
        fetch_cycle(1,0);
        fetch_cycle(1,32'h3ffc);
        // Back-to-back requests, exhaustive indexing then reverse persistence.
        for(i=0;i<4096;i=i+1) fetch_cycle(1,4*32'(i));
        for(i=4095;i>=0;i=i-1) fetch_cycle(1,4*32'(i));
        // Every location exercised with both enable states and alternating edges.
        for(i=0;i<4096;i=i+1) begin
            fetch_cycle(0,4*32'(i));
            fetch_cycle(1,4*32'(i));
        end
        // Address changes between edges with enable continuously high must hold.
        for(i=0;i<128;i=i+1) begin
            vectors=vectors+1;
            imem_en=1; imem_addr=4*32'(i);
            #1; check_output("enabled address change without clock edge");
            imem_addr=32'h3ffc-4*32'(i);
            #1; check_output("second enabled address change without clock edge");
            imem_en=0;
            cancelled_enable(4*32'(i));
        end
        for(k=0;k<20000;k=k+1) begin
            sample=random_word(); address=4*(sample%4096);
            sample=random_word(); enable=sample[0];
            fetch_cycle(enable,address);
        end
        // Re-read every word after all stress to check persistence.
        for(i=0;i<4096;i=i+1) fetch_cycle(1,4*32'(i));
        for(i=0;i<4096;i=i+1)
            if(word_reads[i]<4 || word_disabled[i]==0) $fatal(1,"Missing address coverage");
        for(i=0;i<4;i=i+1) begin
            $display("COVER enable_transition=%02b cycles=%0d",2'(i),transitions[i]);
            if(transitions[i]==0) $fatal(1,"Missing enable transition coverage");
        end
        $display("COVER words=4096 first_reads=%0d last_reads=%0d enabled=%0d disabled=%0d address_change_vectors=128 cancelled_enable_pulses=256 seed=09c0ffee",
                 word_reads[0],word_reads[4095],enabled,disabled);
        $display("RESULT vectors=%0d checks=%0d passing=%0d failures=%0d",vectors,checks,checks-failures,failures);
        if(failures!=0) $fatal(1,"IMEM verification failed");
        $finish;
    end
endmodule
