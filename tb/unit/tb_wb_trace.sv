// Module 16: dual static configurations, input-only cycle-accurate model.
// Trace payload is architecturally checked on retirement or synchronous clear.
module tb_wb_trace;
    timeunit 1ns; timeprecision 1ps;
    logic clk=0;
    logic rst=0;
    logic halted=0;
    logic memwb_valid=0;
    logic memwb_reg_write=0;
    logic memwb_mem_read=0;
    logic memwb_mem_write=0;
    logic [31:0] memwb_pc=0;
    logic [31:0] memwb_instr=0;
    logic [4:0] memwb_rd=0;
    logic [31:0] memwb_wb_data=0;
    logic [31:0] memwb_mem_addr=0;
    logic [3:0] memwb_mem_wmask=0;
    logic [31:0] memwb_mem_wdata=0;
    logic [31:0] memwb_mem_rdata=0;
    wire wb_rd_we[0:1];
    wire [4:0] wb_rd[0:1];
    wire [31:0] wb_data[0:1];
    wire retire_valid[0:1];
    wire [31:0] retire_pc[0:1];
    wire [31:0] retire_instr[0:1];
    wire [4:0] retire_rd[0:1];
    wire retire_rd_we[0:1];
    wire [31:0] retire_rd_data[0:1];
    wire retire_mem_valid[0:1];
    wire retire_mem_write[0:1];
    wire [31:0] retire_mem_addr[0:1];
    wire [3:0] retire_mem_wmask[0:1];
    wire [31:0] retire_mem_wdata[0:1];
    wire [31:0] retire_mem_rdata[0:1];
    logic expected_retire_valid=0;
    logic ones_retire_valid=0, zeros_retire_valid=0;
    logic [31:0] expected_retire_pc=0;
    logic [31:0] ones_retire_pc=0, zeros_retire_pc=0;
    logic [31:0] expected_retire_instr=0;
    logic [31:0] ones_retire_instr=0, zeros_retire_instr=0;
    logic [4:0] expected_retire_rd=0;
    logic [4:0] ones_retire_rd=0, zeros_retire_rd=0;
    logic expected_retire_rd_we=0;
    logic ones_retire_rd_we=0, zeros_retire_rd_we=0;
    logic [31:0] expected_retire_rd_data=0;
    logic [31:0] ones_retire_rd_data=0, zeros_retire_rd_data=0;
    logic expected_retire_mem_valid=0;
    logic ones_retire_mem_valid=0, zeros_retire_mem_valid=0;
    logic expected_retire_mem_write=0;
    logic ones_retire_mem_write=0, zeros_retire_mem_write=0;
    logic [31:0] expected_retire_mem_addr=0;
    logic [31:0] ones_retire_mem_addr=0, zeros_retire_mem_addr=0;
    logic [3:0] expected_retire_mem_wmask=0;
    logic [3:0] ones_retire_mem_wmask=0, zeros_retire_mem_wmask=0;
    logic [31:0] expected_retire_mem_wdata=0;
    logic [31:0] ones_retire_mem_wdata=0, zeros_retire_mem_wdata=0;
    logic [31:0] expected_retire_mem_rdata=0;
    logic [31:0] ones_retire_mem_rdata=0, zeros_retire_mem_rdata=0;
    for(genvar t=0;t<2;t=t+1) begin : configs
        wb_trace #(.TRACE_EN(t==1)) dut (
            .clk(clk),
            .rst(rst),
            .halted(halted),
            .memwb_valid(memwb_valid),
            .memwb_reg_write(memwb_reg_write),
            .memwb_mem_read(memwb_mem_read),
            .memwb_mem_write(memwb_mem_write),
            .memwb_pc(memwb_pc),
            .memwb_instr(memwb_instr),
            .memwb_rd(memwb_rd),
            .memwb_wb_data(memwb_wb_data),
            .memwb_mem_addr(memwb_mem_addr),
            .memwb_mem_wmask(memwb_mem_wmask),
            .memwb_mem_wdata(memwb_mem_wdata),
            .memwb_mem_rdata(memwb_mem_rdata),
            .wb_rd_we(wb_rd_we[t]),
            .wb_rd(wb_rd[t]),
            .wb_data(wb_data[t]),
            .retire_valid(retire_valid[t]),
            .retire_pc(retire_pc[t]),
            .retire_instr(retire_instr[t]),
            .retire_rd(retire_rd[t]),
            .retire_rd_we(retire_rd_we[t]),
            .retire_rd_data(retire_rd_data[t]),
            .retire_mem_valid(retire_mem_valid[t]),
            .retire_mem_write(retire_mem_write[t]),
            .retire_mem_addr(retire_mem_addr[t]),
            .retire_mem_wmask(retire_mem_wmask[t]),
            .retire_mem_wdata(retire_mem_wdata[t]),
            .retire_mem_rdata(retire_mem_rdata[t])
        );
    end
    integer vectors=0, checks=0, failures=0, directed=0, edges=0;
    integer config_checks[0:1], config_failures[0:1];
    integer controls_seen[0:63], rd_seen[0:31], retired_rd_seen[0:31];
    integer completions=0, writes=0, x0_retired=0, nonwriters=0, consecutive=0;
    integer mem_class[0:3], idle_edges=0, reset_edges=0, halted_edges=0;
    integer i,j;
    logic initialized=0, model_clear=0, previous_completion=0;
    logic [31:0] rng=32'h16c0ffee;
    logic [5:0] random_flags;
    function automatic [31:0] random_word();
        rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
        return rng;
    endfunction
    function automatic logic write_allowed();
        case({rst,halted,memwb_valid,memwb_reg_write,(memwb_rd!=0)})
            5'b00111: return 1'b1;
            default: return 1'b0;
        endcase
    endfunction
    task automatic verify(input bit ok,input string detail);
        checks=checks+1;
        if(!ok) begin
            failures=failures+1;
            if(failures<30) $display("FAIL vector=%0d edge=%0d time=%0t %s",vectors,edges,$time,detail);
        end
    endtask
    task automatic field_check(input logic [31:0] actual, predicted,
                               input string name,input integer cfg);
        config_checks[cfg]=config_checks[cfg]+1;
        if(actual!==predicted) begin
            config_failures[cfg]=config_failures[cfg]+1;
            if(failures<30) $display("DETAIL TRACE=%0d %s actual=%h expected=%h",cfg,name,actual,predicted);
        end
        verify(actual===predicted,name);
    endtask
    task automatic payload();
        memwb_pc=32'(random_word());
        memwb_instr=32'(random_word());
        memwb_rd=5'(random_word());
        memwb_wb_data=32'(random_word());
        memwb_mem_addr=32'(random_word());
        memwb_mem_wmask=4'(random_word());
        memwb_mem_wdata=32'(random_word());
        memwb_mem_rdata=32'(random_word());
    endtask
    task automatic predict();
        logic completion;
        begin
            completion=({rst,halted,memwb_valid}==3'b001);
            model_clear=rst;
            expected_retire_valid=rst ? 1'd0 : (completion);
            expected_retire_pc=rst ? 32'd0 : (memwb_pc);
            expected_retire_instr=rst ? 32'd0 : (memwb_instr);
            expected_retire_rd=rst ? 5'd0 : (memwb_rd);
            expected_retire_rd_we=rst ? 1'd0 : (write_allowed());
            expected_retire_rd_data=rst ? 32'd0 : (memwb_wb_data);
            expected_retire_mem_valid=rst ? 1'd0 : (completion && ({memwb_mem_read,memwb_mem_write}!=2'b00));
            expected_retire_mem_write=rst ? 1'd0 : (memwb_mem_write);
            expected_retire_mem_addr=rst ? 32'd0 : (memwb_mem_addr);
            expected_retire_mem_wmask=rst ? 4'd0 : (memwb_mem_wmask);
            expected_retire_mem_wdata=rst ? 32'd0 : (memwb_mem_wdata);
            expected_retire_mem_rdata=rst ? 32'd0 : (memwb_mem_rdata);
        end
    endtask
    task automatic observe(input string label_text);
        for(integer c=0;c<2;c=c+1) begin
            field_check(32'(wb_rd_we[c]),32'(write_allowed()),{label_text," functional write enable"},c);
            field_check(32'(wb_rd[c]),32'(memwb_rd),{label_text," functional destination"},c);
            field_check(wb_data[c],memwb_wb_data,{label_text," final WB data"},c);
            if(c==0 || model_clear || expected_retire_valid || 1'b1)
                field_check(32'(retire_valid[c]),c==0?32'd0:32'(expected_retire_valid),{label_text," retire_valid"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_pc[c]),c==0?32'd0:32'(expected_retire_pc),{label_text," retire_pc"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_instr[c]),c==0?32'd0:32'(expected_retire_instr),{label_text," retire_instr"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_rd[c]),c==0?32'd0:32'(expected_retire_rd),{label_text," retire_rd"},c);
            if(c==0 || model_clear || expected_retire_valid || 1'b1)
                field_check(32'(retire_rd_we[c]),c==0?32'd0:32'(expected_retire_rd_we),{label_text," retire_rd_we"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_rd_data[c]),c==0?32'd0:32'(expected_retire_rd_data),{label_text," retire_rd_data"},c);
            if(c==0 || model_clear || expected_retire_valid || 1'b1)
                field_check(32'(retire_mem_valid[c]),c==0?32'd0:32'(expected_retire_mem_valid),{label_text," retire_mem_valid"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_mem_write[c]),c==0?32'd0:32'(expected_retire_mem_write),{label_text," retire_mem_write"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_mem_addr[c]),c==0?32'd0:32'(expected_retire_mem_addr),{label_text," retire_mem_addr"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_mem_wmask[c]),c==0?32'd0:32'(expected_retire_mem_wmask),{label_text," retire_mem_wmask"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_mem_wdata[c]),c==0?32'd0:32'(expected_retire_mem_wdata),{label_text," retire_mem_wdata"},c);
            if(c==0 || model_clear || expected_retire_valid)
                field_check(32'(retire_mem_rdata[c]),c==0?32'd0:32'(expected_retire_mem_rdata),{label_text," retire_mem_rdata"},c);
        end
        verify(wb_rd_we[0] === wb_rd_we[1],{label_text," TRACE functional equality wb_rd_we"});
        verify(wb_rd[0] === wb_rd[1],{label_text," TRACE functional equality wb_rd"});
        verify(wb_data[0] === wb_data[1],{label_text," TRACE functional equality wb_data"});
    endtask
    task automatic step(input logic [5:0] flags,input string label_text);
        begin
            vectors=vectors+1;
            {rst,halted,memwb_valid,memwb_reg_write,memwb_mem_read,memwb_mem_write}=flags;
            controls_seen[flags]=controls_seen[flags]+1;
            rd_seen[memwb_rd]=rd_seen[memwb_rd]+1;
            #1;if(initialized) observe({label_text," before rising edge"});
            predict();
            if(expected_retire_valid) begin
                completions=completions+1;retired_rd_seen[memwb_rd]=retired_rd_seen[memwb_rd]+1;
                mem_class[{memwb_mem_read,memwb_mem_write}]=mem_class[{memwb_mem_read,memwb_mem_write}]+1;
                if(memwb_rd==0) x0_retired=x0_retired+1;
                if(!memwb_reg_write) nonwriters=nonwriters+1;
                if(previous_completion) consecutive=consecutive+1;
            end else idle_edges=idle_edges+1;
            if(write_allowed()) writes=writes+1;
            if(rst) reset_edges=reset_edges+1;
            if(halted) halted_edges=halted_edges+1;
            previous_completion=expected_retire_valid;
            clk=1;edges=edges+1;
            #1;observe({label_text," after completing WB edge"});
            // Change the packet during high clock: WB is live, retirement must
            // still describe the snapshot from BEFORE the completing edge.
            memwb_pc=~memwb_pc;memwb_instr=~memwb_instr;
            memwb_rd=~memwb_rd;memwb_wb_data=~memwb_wb_data;
            memwb_mem_addr=~memwb_mem_addr;memwb_mem_wmask=~memwb_mem_wmask;
            memwb_mem_wdata=~memwb_mem_wdata;memwb_mem_rdata=~memwb_mem_rdata;
            #1;observe({label_text," next packet while clock high"});
            clk=0;#1;observe({label_text," after falling edge"});
            initialized=1;
            if(model_clear || expected_retire_valid) begin ones_retire_valid=ones_retire_valid|expected_retire_valid;zeros_retire_valid=zeros_retire_valid|~expected_retire_valid;end
            if(model_clear || expected_retire_valid) begin ones_retire_pc=ones_retire_pc|expected_retire_pc;zeros_retire_pc=zeros_retire_pc|~expected_retire_pc;end
            if(model_clear || expected_retire_valid) begin ones_retire_instr=ones_retire_instr|expected_retire_instr;zeros_retire_instr=zeros_retire_instr|~expected_retire_instr;end
            if(model_clear || expected_retire_valid) begin ones_retire_rd=ones_retire_rd|expected_retire_rd;zeros_retire_rd=zeros_retire_rd|~expected_retire_rd;end
            if(model_clear || expected_retire_valid) begin ones_retire_rd_we=ones_retire_rd_we|expected_retire_rd_we;zeros_retire_rd_we=zeros_retire_rd_we|~expected_retire_rd_we;end
            if(model_clear || expected_retire_valid) begin ones_retire_rd_data=ones_retire_rd_data|expected_retire_rd_data;zeros_retire_rd_data=zeros_retire_rd_data|~expected_retire_rd_data;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_valid=ones_retire_mem_valid|expected_retire_mem_valid;zeros_retire_mem_valid=zeros_retire_mem_valid|~expected_retire_mem_valid;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_write=ones_retire_mem_write|expected_retire_mem_write;zeros_retire_mem_write=zeros_retire_mem_write|~expected_retire_mem_write;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_addr=ones_retire_mem_addr|expected_retire_mem_addr;zeros_retire_mem_addr=zeros_retire_mem_addr|~expected_retire_mem_addr;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_wmask=ones_retire_mem_wmask|expected_retire_mem_wmask;zeros_retire_mem_wmask=zeros_retire_mem_wmask|~expected_retire_mem_wmask;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_wdata=ones_retire_mem_wdata|expected_retire_mem_wdata;zeros_retire_mem_wdata=zeros_retire_mem_wdata|~expected_retire_mem_wdata;end
            if(model_clear || expected_retire_valid) begin ones_retire_mem_rdata=ones_retire_mem_rdata|expected_retire_mem_rdata;zeros_retire_mem_rdata=zeros_retire_mem_rdata|~expected_retire_mem_rdata;end
        end
    endtask
    task automatic scenario(input logic [5:0] flags,input string label_text);
        step(flags,label_text);directed=directed+1;
        $display("DIRECTED %s retire=%b rd_we=%b pc=%h",label_text,retire_valid[1],retire_rd_we[1],retire_pc[1]);
    endtask
    task automatic reset_pulse(input string label_text);
        vectors=vectors+1;directed=directed+1;
        rst=1;#1;observe({label_text," asserted without edge"});
        payload();#1;observe({label_text," data changes while reset high"});
        rst=0;#1;observe({label_text," released without edge"});
    endtask
    initial begin
        for(i=0;i<64;i=i+1) controls_seen[i]=0;
        for(i=0;i<32;i=i+1) begin rd_seen[i]=0;retired_rd_seen[i]=0;end
        for(i=0;i<4;i=i+1) mem_class[i]=0;
        for(i=0;i<2;i=i+1) begin config_checks[i]=0;config_failures[i]=0;end
        payload();scenario(6'b111111,"startup reset suppresses WB and clears all trace");
        payload();memwb_rd=5;scenario(6'b001100,"ALU-like valid register write");
        reset_pulse("subcycle reset holds previous retirement, blocks write immediately");
        payload();memwb_rd=6;scenario(6'b001100,"consecutive ALU-like completion");
        payload();scenario(6'b001000,"branch-like nonwriter still retires");
        payload();memwb_rd=0;scenario(6'b001100,"x0 retires without register write");
        payload();memwb_rd=7;scenario(6'b001110,"load-like completion");
        payload();scenario(6'b001001,"store-like completion reports history only");
        payload();scenario(6'b000100,"invalid WB suppresses write and clears retire_valid");
        payload();scenario(6'b000000,"consecutive idle slot");
        payload();memwb_rd=8;scenario(6'b001100,"valid WB before HALTED change");
        // HALTED is independently driven: a preexisting pulse can overlap a
        // newly asserted HALTED input. CPU-level prevention is not tested here.
        vectors=vectors+1;directed=directed+1;
        halted=1;#1;observe("HALTED asserted without clock: old retirement retained");
        payload();#1;observe("HALTED blocks writes with changed inputs");
        #1;observe("HALTED does not asynchronously clear trace");
        scenario(6'b011111,"HALTED suppresses new retirement at edge");
        scenario(6'b111111,"reset while HALTED clears every trace field");
        reset_pulse("reset release without edge cannot generate retirement");
        payload();scenario(6'b001100,"resume supplied valid WB after reset");
        // Set every transported bit, then clear through reset. Both memory
        // flags high is deliberate malformed metadata transport robustness.
        memwb_pc='1;
        memwb_instr='1;
        memwb_rd='1;
        memwb_wb_data='1;
        memwb_mem_addr='1;
        memwb_mem_wmask='1;
        memwb_mem_wdata='1;
        memwb_mem_rdata='1;
        scenario(6'b001111,"all retirement payload bits one");
        scenario(6'b100000,"synchronous trace clear");
        // All six Boolean controls crossed with all 32 destination identifiers.
        for(i=0;i<64;i=i+1)
            for(j=0;j<32;j=j+1) begin
                payload();memwb_rd=5'(j);step(6'(i),"Boolean/destination cross");
            end
        for(i=0;i<10000;i=i+1) begin
            payload();random_flags=6'(random_word());
            step(random_flags,"random MEM/WB/control sequence");
        end
        for(i=0;i<64;i=i+1) verify(controls_seen[i]>0,"Boolean control coverage");
        for(i=0;i<32;i=i+1) begin
            verify(rd_seen[i]>0,"all functional destinations exercised");
            verify(retired_rd_seen[i]>0,"all destinations retire, including x0");
        end
        for(i=0;i<4;i=i+1) begin
            verify(mem_class[i]>0,"memory class coverage");
            $display("COVER memory_flags=%b completions=%0d",2'(i),mem_class[i]);
        end
        verify((&ones_retire_valid)===1'b1,"every retire_valid bit high");
        verify((&zeros_retire_valid)===1'b1,"every retire_valid bit low");
        verify((&ones_retire_pc)===1'b1,"every retire_pc bit high");
        verify((&zeros_retire_pc)===1'b1,"every retire_pc bit low");
        verify((&ones_retire_instr)===1'b1,"every retire_instr bit high");
        verify((&zeros_retire_instr)===1'b1,"every retire_instr bit low");
        verify((&ones_retire_rd)===1'b1,"every retire_rd bit high");
        verify((&zeros_retire_rd)===1'b1,"every retire_rd bit low");
        verify((&ones_retire_rd_we)===1'b1,"every retire_rd_we bit high");
        verify((&zeros_retire_rd_we)===1'b1,"every retire_rd_we bit low");
        verify((&ones_retire_rd_data)===1'b1,"every retire_rd_data bit high");
        verify((&zeros_retire_rd_data)===1'b1,"every retire_rd_data bit low");
        verify((&ones_retire_mem_valid)===1'b1,"every retire_mem_valid bit high");
        verify((&zeros_retire_mem_valid)===1'b1,"every retire_mem_valid bit low");
        verify((&ones_retire_mem_write)===1'b1,"every retire_mem_write bit high");
        verify((&zeros_retire_mem_write)===1'b1,"every retire_mem_write bit low");
        verify((&ones_retire_mem_addr)===1'b1,"every retire_mem_addr bit high");
        verify((&zeros_retire_mem_addr)===1'b1,"every retire_mem_addr bit low");
        verify((&ones_retire_mem_wmask)===1'b1,"every retire_mem_wmask bit high");
        verify((&zeros_retire_mem_wmask)===1'b1,"every retire_mem_wmask bit low");
        verify((&ones_retire_mem_wdata)===1'b1,"every retire_mem_wdata bit high");
        verify((&zeros_retire_mem_wdata)===1'b1,"every retire_mem_wdata bit low");
        verify((&ones_retire_mem_rdata)===1'b1,"every retire_mem_rdata bit high");
        verify((&zeros_retire_mem_rdata)===1'b1,"every retire_mem_rdata bit low");
        verify(x0_retired>0,"x0 completion coverage");verify(nonwriters>0,"nonwriting completion coverage");
        verify(consecutive>0,"consecutive retirement coverage");verify(writes>0,"functional write coverage");
        verify(reset_edges>0,"reset coverage");verify(halted_edges>0,"HALTED coverage");verify(idle_edges>0,"idle coverage");
        for(i=0;i<2;i=i+1)
            $display("CONFIG TRACE_EN=%0d checks=%0d failures=%0d",i,config_checks[i],config_failures[i]);
        $display("COVER controls=64/64 destinations=32/32 retired_destinations=32/32 completions=%0d writes=%0d x0=%0d nonwriters=%0d consecutive=%0d idle=%0d reset_edges=%0d halted_edges=%0d",
                 completions,writes,x0_retired,nonwriters,consecutive,idle_edges,reset_edges,halted_edges);
        $display("RESULT vectors=%0d edges=%0d checks=%0d passing=%0d failures=%0d directed=%0d cross=2048 random=10000 seed=16c0ffee",
                 vectors,edges,checks,checks-failures,failures,directed);
        if(failures!=0) $fatal(1,"Writeback trace verification failed");
        $finish;
    end
endmodule
