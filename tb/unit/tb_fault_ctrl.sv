// Module 15: architecture-derived cycle model. DUT state is never forced/read.
// The sole internal observation is the architecturally named drained expression.
module tb_fault_ctrl;
    timeunit 1ns; timeprecision 1ps;
    logic clk=0, rst=1;
    logic ex_evt_valid=0, redirect_valid=0, idex_valid=0, id_evt_valid=0;
    logic exmem_valid=0, memwb_valid=0;
    logic [3:0] ex_evt_cause=0, id_evt_cause=0;
    logic [31:0] ex_evt_pc=0, id_evt_pc=0;
    wire fetch_redirect_valid, kill_if, kill_id, kill_ex, enter_drain, stop_fetch, halted;
    wire [31:0] fault_pc;
    wire [3:0] fault_cause;
    fault_ctrl dut (.*);
    localparam integer LIVE=0, FLUSHING=1, STOPPED=2;
    localparam integer NONE=0, ID_EVENT=1, REDIRECT=2, EX_EVENT=3;
    integer phase=LIVE, vectors=0, checks=0, failures=0, directed=0, edges=0;
    integer control_seen[0:2][0:127], transitions[0:2][0:2];
    integer selected_count[0:3], reset_count[0:2], ex_causes[5:9], id_causes[1:4];
    integer captures=0, retention_edges=0, reset_pulses=0;
    integer i,j;
    logic initialized=0, captured=0;
    logic [31:0] record_pc=0, rng=32'h15c0ffee, pc_ones=0, pc_zeros=0;
    logic [3:0] record_cause=0;
    logic [6:0] random_flags;

    function automatic [31:0] random_word();
        rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
        return rng;
    endfunction
    task automatic payload();
        ex_evt_pc=random_word();id_evt_pc=random_word();
        ex_evt_cause=4'(random_word());id_evt_cause=4'(random_word());
    endtask
    // Age-ranked decision table uses inputs and model phase, never DUT controls.
    function automatic integer decision();
        if(rst || phase!=LIVE) return NONE;
        casez({(idex_valid && ex_evt_valid),(idex_valid && redirect_valid),id_evt_valid})
            3'b1??: return EX_EVENT;
            3'b01?: return REDIRECT;
            3'b001: return ID_EVENT;
            default: return NONE;
        endcase
    endfunction
    task automatic verify(input bit ok,input string detail);
        checks=checks+1;
        if(!ok) begin
            failures=failures+1;
            if(failures<40)
                $display("FAIL vector=%0d edge=%0d time=%0t phase=%0d %s actual_control=%b%b%b%b%b%b%b record=%h/%h expected=%h/%h",
                         vectors,edges,$time,phase,detail,fetch_redirect_valid,
                         kill_if,kill_id,kill_ex,enter_drain,stop_fetch,halted,
                         fault_pc,fault_cause,record_pc,record_cause);
        end
    endtask
    task automatic observe(input string label_text);
        integer choice;
        bit terminal;
        begin
            choice=decision();terminal=(choice==EX_EVENT || choice==ID_EVENT);
            verify(fetch_redirect_valid === (choice==REDIRECT),{label_text," qualified redirect"});
            verify(kill_if === (choice!=NONE),{label_text," IF kill"});
            verify(kill_id === (choice!=NONE),{label_text," ID kill"});
            verify(kill_ex === (choice==EX_EVENT),{label_text," EX kill"});
            verify(enter_drain === terminal,{label_text," terminal acceptance"});
            verify(stop_fetch === (phase!=LIVE),{label_text," fetch block"});
            verify(halted === (phase==STOPPED),{label_text," HALTED timing"});
            verify(fault_pc === record_pc,{label_text," terminal PC"});
            verify(fault_cause === record_cause,{label_text," terminal cause"});
            verify(dut.drained === ({idex_valid,exmem_valid,memwb_valid}==3'b000),
                   {label_text," exact drained expression"});
            verify({fetch_redirect_valid,stop_fetch} !== 2'b11,{label_text," redirect/stop exclusion"});
            verify({kill_ex,fetch_redirect_valid} !== 2'b11,{label_text," EX fault/redirect exclusion"});
            verify((enter_drain===1'b0) || (!rst && phase==LIVE && terminal),
                   {label_text," acceptance only in RUN"});
            verify((choice!=REDIRECT && choice!=ID_EVENT) || (kill_ex===1'b0),
                   {label_text," younger ID or redirect preserves EX"});
        end
    endtask
    task automatic step(input logic [6:0] flags,input string label_text);
        integer choice, old_phase;
        logic [35:0] previous_record;
        begin
            vectors=vectors+1;
            {rst,ex_evt_valid,redirect_valid,id_evt_valid,idex_valid,exmem_valid,memwb_valid}=flags;
            #1;
            if(initialized) observe({label_text," pre-edge"});
            control_seen[phase][flags]=control_seen[phase][flags]+1;
            choice=decision();old_phase=phase;previous_record={record_pc,record_cause};
            selected_count[choice]=selected_count[choice]+1;
            if(rst) begin
                reset_count[phase]=reset_count[phase]+1;
                phase=LIVE;record_pc=0;record_cause=0;captured=0;
            end else if(phase==LIVE && (choice==EX_EVENT || choice==ID_EVENT)) begin
                verify(!captured,"terminal selected at most once per reset epoch");
                captured=1;captures=captures+1;phase=FLUSHING;
                record_pc=(choice==EX_EVENT)?ex_evt_pc:id_evt_pc;
                record_cause=(choice==EX_EVENT)?ex_evt_cause:id_evt_cause;
                if(choice==EX_EVENT && record_cause>=5 && record_cause<=9)
                    ex_causes[record_cause]=ex_causes[record_cause]+1;
                if(choice==ID_EVENT && record_cause>=1 && record_cause<=4)
                    id_causes[record_cause]=id_causes[record_cause]+1;
                pc_ones=pc_ones|record_pc;pc_zeros=pc_zeros|~record_pc;
            end else if(phase==FLUSHING && {idex_valid,exmem_valid,memwb_valid}==0)
                phase=STOPPED;
            transitions[old_phase][phase]=transitions[old_phase][phase]+1;
            clk=1;edges=edges+1;
            #1;observe({label_text," post-rising-edge"});
            if(!rst && old_phase!=LIVE) begin
                verify({fault_pc,fault_cause} === previous_record,"record immutable outside RUN");
                retention_edges=retention_edges+1;
            end
            clk=0;#1;observe({label_text," post-falling-edge"});
            initialized=1;
        end
    endtask
    task automatic scenario(input logic [6:0] flags,input string label_text);
        step(flags,label_text);directed=directed+1;
        $display("DIRECTED %s phase=%0d stop=%b halted=%b record=%h/%h",
                 label_text,phase,stop_fetch,halted,fault_pc,fault_cause);
    endtask
    task automatic reset_pulse(input string label_text);
        // No clock changes: controls mask immediately; registered data must stay.
        vectors=vectors+1;directed=directed+1;reset_pulses=reset_pulses+1;
        rst=1;#1;observe({label_text," asserted without edge"});
        payload();#1;observe({label_text," inputs changed while reset high"});
        rst=0;#1;observe({label_text," released without edge"});
        $display("DIRECTED %s: registered phase/record retained",label_text);
    endtask
    initial begin
        for(i=0;i<3;i=i+1) begin
            for(j=0;j<128;j=j+1) control_seen[i][j]=0;
            for(j=0;j<3;j=j+1) transitions[i][j]=0;
            reset_count[i]=0;
        end
        for(i=0;i<4;i=i+1) selected_count[i]=0;
        for(i=5;i<=9;i=i+1) ex_causes[i]=0;
        for(i=1;i<=4;i=i+1) id_causes[i]=0;
        payload();scenario(7'b1111111,"startup reset defeats all requests");
        scenario(7'b0000000,"RUN idle");
        // All architecturally supported causes at their owning stage.
        for(i=1;i<=9;i=i+1) begin
            scenario(7'b1000000,"reset for supported cause");
            ex_evt_pc=32'h80000100+32'(i)*4;id_evt_pc=32'h00000200+32'(i)*4;
            ex_evt_cause=4'(i);id_evt_cause=4'(i);
            if(i>=5) scenario(7'b0111111,"EX fault wins EX/redirect/ID triple");
            else scenario(7'b0001011,"ID terminal with older MEM/WB occupancy");
            reset_pulse("subcycle reset preserves captured DRAIN record");
            payload();scenario(7'b0111111,"DRAIN ignores changed requests while occupied");
            scenario(7'b0111000,"first empty pre-edge enters HALTED");
            reset_pulse("subcycle reset cannot restart HALTED");
            scenario(7'b0111111,"HALTED ignores requests and remains terminal");
        end
        scenario(7'b1000000,"active reset restarts HALTED");
        payload();scenario(7'b0011100,"redirect beats simultaneous ID terminal");
        scenario(7'b0010100,"consecutive eligible redirect does not capture");
        scenario(7'b0110000,"invalid EX fault and redirect are ignored");
        id_evt_cause=4'h4;id_evt_pc=32'h300;
        scenario(7'b0111000,"invalid EX candidates cannot mask ID event");
        scenario(7'b0000000,"bare ID event halts at next empty edge, no extra cycle");
        scenario(7'b1000000,"reset before last-WB timing case");
        scenario(7'b0001001,"ID terminal while final older WB remains valid");
        scenario(7'b0000001,"final WB retirement edge still samples occupied WB");
        scenario(7'b0000000,"next edge samples empty WB and halts immediately");
        // Exhaust all seven Boolean inputs in every reachable model phase.
        for(i=0;i<3;i=i+1)
            for(j=0;j<128;j=j+1) begin
                payload();step(7'b1000000,"sweep setup reset");
                if(i>=1) step(7'b0001111,"sweep setup DRAIN");
                if(i==2) step(7'b0000000,"sweep setup HALTED");
                payload();step(7'(j),"state/control exhaustive case");
            end
        // Long random sequences include every supported and unsupported cause;
        // reset every 37 cycles permits natural occupancy-dependent draining.
        for(i=0;i<20000;i=i+1) begin
            payload();random_flags=7'(random_word());random_flags[6]=(i%37==0);
            step(random_flags,"random timing, requests, PCs, causes and occupancy");
        end
        for(i=0;i<3;i=i+1) begin
            for(j=0;j<128;j=j+1) verify(control_seen[i][j]>0,"phase/control coverage");
            verify(reset_count[i]>0,"synchronous reset from every phase");
            $display("COVER reset_from_phase=%0d count=%0d",i,reset_count[i]);
        end
        for(i=0;i<4;i=i+1) begin
            verify(selected_count[i]>0,"arbitration selection coverage");
            $display("COVER selection=%0d vectors=%0d",i,selected_count[i]);
        end
        for(i=0;i<3;i=i+1)
            for(j=0;j<3;j=j+1)
                if(!((i==LIVE && j==STOPPED)||(i==STOPPED && j==FLUSHING))) begin
                    verify(transitions[i][j]>0,"reachable state transition coverage");
                    $display("COVER transition=%0d->%0d count=%0d",i,j,transitions[i][j]);
                end
        for(i=5;i<=9;i=i+1) begin
            verify(ex_causes[i]>0,"supported EX capture cause");
            $display("COVER EX cause=%h captures=%0d",4'(i),ex_causes[i]);
        end
        for(i=1;i<=4;i=i+1) begin
            verify(id_causes[i]>0,"supported ID capture cause");
            $display("COVER ID cause=%h captures=%0d",4'(i),id_causes[i]);
        end
        verify(retention_edges>0,"immutable terminal record coverage");
        verify(reset_pulses>0,"subcycle reset pulse coverage");
        verify((&pc_ones)===1'b1,"all captured PC bits high");
        verify((&pc_zeros)===1'b1,"all captured PC bits low");
        $display("COVER phase_controls=384/384 captures=%0d retention_edges=%0d reset_pulses=%0d",
                 captures,retention_edges,reset_pulses);
        $display("RESULT vectors=%0d edges=%0d checks=%0d passing=%0d failures=%0d directed=%0d sweep=1152 random=20000 seed=15c0ffee",
                 vectors,edges,checks,checks-failures,failures,directed);
        if(failures!=0) $fatal(1,"Fault controller verification failed");
        $finish;
    end
endmodule
