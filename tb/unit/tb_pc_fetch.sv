// Module 12, local verification against ARCH-001 Rev C and task ownership split.
// No hierarchical state access, force, decoder, IMEM or pipeline registers.
module tb_pc_fetch;
    timeunit 1ns;
    timeprecision 1ps;
    logic clk=0, rst=1, hold_if=0, fetch_redirect_valid=0, stop_fetch=0;
    logic [31:0] redirect_pc=0;
    wire [31:0] imem_addr;
    wire imem_en, fetch_issue, fetch_token_fault;
    pc_fetch dut (
        .clk(clk), .rst(rst), .hold_if(hold_if),
        .fetch_redirect_valid(fetch_redirect_valid), .redirect_pc(redirect_pc),
        .stop_fetch(stop_fetch), .imem_addr(imem_addr), .imem_en(imem_en),
        .fetch_issue(fetch_issue), .fetch_token_fault(fetch_token_fault)
    );
    logic [31:0] model_pc=0;
    logic [31:0] rng=32'h12c0ffee, random_target;
    logic [4:0] random_controls;
    logic [31:0] candidates[0:7];
    integer vectors=0, checks=0, failures=0, directed=0;
    integer sweeps=0, walk=0, randomized=0, rising_edges=0;
    integer control_seen[0:15], actions[0:3], results[0:2];
    integer last_word=0, first_fault=0, wraps=0, zero_pc=0;
    integer i,j,k;

    function automatic [31:0] random_word();
        rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
        return rng;
    endfunction

    task automatic verify(input bit condition, input string detail);
        checks=checks+1;
        if(!condition) begin
            failures=failures+1;
            $display("FAIL vector=%0d time=%0t %s PC=%h expected=%h controls=%b%b%b%b",
                     vectors,$time,detail,imem_addr,model_pc,rst,fetch_redirect_valid,hold_if,stop_fetch);
        end
    endtask

    task automatic observe(input string phase);
        integer status;
        begin
            // Model the architectural slot type, independently of DUT tag logic.
            status=0;
            if({rst,hold_if,stop_fetch}==3'b000)
                status=(model_pc < 32'h00004000)?1:2;
            verify(imem_addr === model_pc,{phase," candidate PC"});
            verify(fetch_issue === (status!=0),{phase," slot issue"});
            verify(imem_en === (status==1),{phase," legal read enable"});
            verify(fetch_token_fault === (status==2),{phase," fault token"});
            verify({imem_en,fetch_token_fault} !== 2'b11,{phase," exclusive read/token"});
            verify((imem_en===1'b0) || ((imem_addr < 32'h4000)===1'b1),
                   {phase," no out-of-range read"});
            results[status]=results[status]+1;
        end
    endtask

    task automatic step(input logic [3:0] controls,
                        input logic [31:0] target, input string label_text);
        begin
            vectors=vectors+1;
            {rst,fetch_redirect_valid,hold_if,stop_fetch}=controls;
            redirect_pc=target;
            control_seen[controls]=control_seen[controls]+1;
            #1;
            observe({label_text," before edge: no asynchronous PC change"});
            if(fetch_issue===1'b1) begin
                if(model_pc==0) zero_pc=zero_pc+1;
                if(model_pc==32'h3ffc) last_word=last_word+1;
                if(model_pc==32'h4000) first_fault=first_fault+1;
            end
            // Transition table: reset, redirect, sequential issue, otherwise hold.
            // Stop+redirect is a robustness observation, not CPU arbitration signoff.
            casez(controls)
                4'b1???: begin model_pc=0; actions[0]=actions[0]+1; end
                4'b01??: begin model_pc=target; actions[1]=actions[1]+1; end
                4'b0000: begin
                    if(model_pc==32'hfffffffc) wraps=wraps+1;
                    model_pc=32'((64'(model_pc)+64'd4) % 64'h100000000);
                    actions[2]=actions[2]+1;
                end
                default: actions[3]=actions[3]+1;
            endcase
            clk=1; rising_edges=rising_edges+1;
            #1; observe({label_text," after rising edge"});
            clk=0;
            #1; observe({label_text," after falling edge"});
        end
    endtask

    task automatic scenario(input logic [3:0] controls,
                            input logic [31:0] target, input string label_text);
        step(controls,target,label_text);
        directed=directed+1;
        $display("DIRECTED %s PC=%h issue=%b read=%b fault=%b",
                 label_text,imem_addr,fetch_issue,imem_en,fetch_token_fault);
    endtask

    initial begin
        for(i=0;i<16;i=i+1) control_seen[i]=0;
        for(i=0;i<4;i=i+1) actions[i]=0;
        for(i=0;i<3;i=i+1) results[i]=0;
        // Startup PC is unspecified until a synchronous reset edge.
        vectors=1;
        #1;
        verify(fetch_issue===1'b0,"startup reset blocks slots before edge");
        verify(imem_en===1'b0,"startup reset blocks reads before edge");
        verify(fetch_token_fault===1'b0,"startup reset blocks tokens before edge");
        clk=1; rising_edges=1;
        #1; clk=0;
        #1; observe("initial synchronous reset");
        directed=1;
        scenario(4'b0000,0,"first post-reset fetch accepts PC zero");
        scenario(4'b0000,0,"normal increment");
        scenario(4'b0010,0,"hold PC");
        scenario(4'b0001,0,"stop PC");
        scenario(4'b0011,0,"hold and stop");
        scenario(4'b0100,32'h100,"redirect at edge");
        scenario(4'b0100,32'h200,"consecutive redirect");
        scenario(4'b0110,32'h300,"redirect overrides hold");
        scenario(4'b0101,32'h400,"robustness: redirect with stop");
        scenario(4'b1111,32'h800,"reset overrides all controls");
        scenario(4'b0000,0,"first fetch after reset override");
        scenario(4'b0100,32'h3ffc,"redirect to last valid word");
        scenario(4'b0000,0,"accept last word then first fault token");
        scenario(4'b0000,0,"accept first out-of-range token and advance");
        scenario(4'b0010,0,"hold suppresses out-of-range token");
        scenario(4'b0001,0,"stop suppresses out-of-range token");
        scenario(4'b0100,32'hfffffffc,"redirect to high address");
        scenario(4'b0000,0,"32-bit wrap to zero");
        scenario(4'b0100,32'h100,"nonzero PC before reset pulse");
        // A reset pulse with no clock edge suppresses output but cannot reset PC.
        vectors=vectors+1; directed=directed+1;
        rst=1; #1; observe("reset pulse without clock");
        rst=0; #1; observe("reset pulse released without clock");
        fetch_redirect_valid=0; redirect_pc=32'h200;
        #1; observe("redirect input changed without clock");
        scenario(4'b0000,0,"continue after subcycle reset pulse");

        candidates[0]=0; candidates[1]=4; candidates[2]=32'h3ff8;
        candidates[3]=32'h3ffc; candidates[4]=32'h4000;
        candidates[5]=32'h10000; candidates[6]=32'h80000000;
        candidates[7]=32'hfffffffc;
        // All four Boolean controls crossed with eight representative PCs.
        for(i=0;i<8;i=i+1)
            for(j=0;j<16;j=j+1) begin
                step(4'b0100,candidates[i],"sweep setup redirect");
                step(4'(j),candidates[(i+1)%8],"control/PC cross");
                sweeps=sweeps+2;
            end
        // Walk every aligned legal IMEM address, then the first invalid word.
        step(4'b1000,0,"walk reset"); walk=walk+1;
        for(i=0;i<4097;i=i+1) begin
            step(4'b0000,0,"sequential IMEM walk"); walk=walk+1;
        end
        // Exercise each upper address bit without truncating the full PC.
        for(k=14;k<32;k=k+1) begin
            step(4'b0100,32'd1<<k,"high bit redirect");
            step(4'b0000,0,"high bit fault token"); walk=walk+2;
        end
        for(i=0;i<10000;i=i+1) begin
            random_controls=5'(random_word()); random_target=random_word();
            // Aligned, architecturally qualified target; mix local and high PCs.
            if(random_controls[4]) random_target=random_target & 32'h00003ffc;
            else random_target=random_target & 32'hfffffffc;
            step(random_controls[3:0],random_target,"random sequence");
            randomized=randomized+1;
        end
        for(i=0;i<16;i=i+1) verify(control_seen[i]>0,"control coverage");
        for(i=0;i<4;i=i+1) verify(actions[i]>0,"PC action coverage");
        for(i=0;i<3;i=i+1) verify(results[i]>0,"output class coverage");
        verify(last_word>0,"last valid word coverage");
        verify(first_fault>0,"first invalid word coverage");
        verify(wraps>0,"32-bit wrap coverage");
        verify(zero_pc>0,"zero PC fetch coverage");
        $display("COVER controls=16/16 reset=%0d redirect=%0d advance=%0d hold_or_stop=%0d",
                 actions[0],actions[1],actions[2],actions[3]);
        $display("COVER disabled=%0d legal=%0d fault=%0d zero=%0d last_word=%0d first_fault=%0d wraps=%0d",
                 results[0],results[1],results[2],zero_pc,last_word,first_fault,wraps);
        $display("RESULT vectors=%0d checks=%0d passing=%0d failures=%0d directed=%0d sweep=%0d walk=%0d random=%0d rising_edges=%0d seed=12c0ffee",
                 vectors,checks,checks-failures,failures,directed,sweeps,walk,randomized,rising_edges);
        if(failures!=0) $fatal(1,"PC Fetch verification failed");
        $finish;
    end
endmodule
