// MODULE 10: Class A verification-only change authorized by the user task.
// Oracle constructs a register-indexed producer map, older producer first.
// Sticky diagnostic storage belongs to rv32i_core_top, not this test or DUT.
`timescale 1ns/1ps
module tb_forward_unit;
    logic idex_valid, idex_uses_rs1, idex_uses_rs2, idex_is_store;
    logic [4:0] idex_rs1, idex_rs2, exmem_rd, memwb_rd;
    logic exmem_valid, exmem_reg_write, exmem_result_ready;
    logic memwb_valid, memwb_reg_write;
    wire [1:0] fwd_a_sel, fwd_b_sel, fwd_store_sel;
    wire fwd_nonready_error;
    forward_unit dut (.*);
    integer vectors=0, checks=0, failures=0;
    integer directed=0, semantic=0, register_sweep=0, randomized=0;
    integer coverage_a[0:3],coverage_b[0:3],coverage_store[0:3];
    integer coverage_pair[0:3][0:3],coverage_error[0:1];
    integer errors_a_only=0,errors_b_only=0,errors_both=0;
    integer stale_a=0,stale_b=0;
    integer i,j,k,l,c,r,s,t,ready;
    reg [4:0] representatives[0:4];
    reg [31:0] rng=32'h10c0ffee,random_flags,random_ids;

    function automatic [31:0] random_word();
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic check_current(input string label_text);
        reg [1:0] producer_map[0:31];
        reg [1:0] a,b,store;
        reg error_expected;
        integer n;
        begin
            for(n=0;n<32;n=n+1) producer_map[n]=0;
            // Populate oldest first, then overwrite with the newest producer.
            if(memwb_valid && memwb_reg_write) producer_map[memwb_rd]=2;
            if(exmem_valid && exmem_reg_write)
                producer_map[exmem_rd]=exmem_result_ready?1:3;
            producer_map[0]=0;
            a=0; b=0; store=0;
            if(idex_valid) begin
                if(idex_uses_rs1) a=producer_map[idex_rs1];
                if(idex_uses_rs2) b=producer_map[idex_rs2];
                if(idex_is_store) store=b;
            end
            error_expected=(a==3 || b==3);
            #1;
            vectors=vectors+1;
            checks=checks+4;
            if(fwd_a_sel!==a) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d A actual=%b expected=%b",label_text,vectors,fwd_a_sel,a);
            end
            if(fwd_b_sel!==b) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d B actual=%b expected=%b",label_text,vectors,fwd_b_sel,b);
            end
            if(fwd_store_sel!==store) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d STORE actual=%b expected=%b",label_text,vectors,fwd_store_sel,store);
            end
            if(fwd_nonready_error!==error_expected) begin
                failures=failures+1;
                $display("FAIL %s vector=%0d ERROR actual=%b expected=%b",label_text,vectors,fwd_nonready_error,error_expected);
            end
            coverage_a[a]=coverage_a[a]+1; coverage_b[b]=coverage_b[b]+1;
            coverage_store[store]=coverage_store[store]+1;
            coverage_pair[a][b]=coverage_pair[a][b]+1;
            coverage_error[error_expected]=coverage_error[error_expected]+1;
            if(a==3 && b!=3) errors_a_only=errors_a_only+1;
            if(a!=3 && b==3) errors_b_only=errors_b_only+1;
            if(a==3 && b==3) errors_both=errors_both+1;
            if(a==3 && memwb_valid && memwb_reg_write && memwb_rd==idex_rs1) stale_a=stale_a+1;
            if(b==3 && memwb_valid && memwb_reg_write && memwb_rd==idex_rs2) stale_b=stale_b+1;
        end
    endtask
    task automatic apply_vector(input reg [8:0] flags,
                                input reg [4:0] rs1,rs2,exrd,wbrd,
                                input string label_text);
        begin
            // flags[8:0]: valid,use1,use2,store,EXvalid,EXwrite,ready,WBvalid,WBwrite.
            {idex_valid,idex_uses_rs1,idex_uses_rs2,idex_is_store,
             exmem_valid,exmem_reg_write,exmem_result_ready,
             memwb_valid,memwb_reg_write}=flags;
            idex_rs1=rs1; idex_rs2=rs2; exmem_rd=exrd; memwb_rd=wbrd;
            check_current(label_text);
        end
    endtask
    task automatic directed_vector(input reg [8:0] flags,
                                   input reg [4:0] rs1,rs2,exrd,wbrd,
                                   input string label_text);
        begin
            apply_vector(flags,rs1,rs2,exrd,wbrd,label_text);
            directed=directed+1;
            $display("DIRECTED %s",label_text);
        end
    endtask
    initial begin
        for(i=0;i<4;i=i+1) begin
            coverage_a[i]=0; coverage_b[i]=0; coverage_store[i]=0;
            for(j=0;j<4;j=j+1) coverage_pair[i][j]=0;
        end
        coverage_error[0]=0; coverage_error[1]=0;
        representatives[0]=0; representatives[1]=1; representatives[2]=2;
        representatives[3]=3; representatives[4]=31;
        directed_vector(479,1,2,3,4,"no matching producer");
        directed_vector(479,5,6,5,7,"ALU to ALU EX/MEM");
        directed_vector(479,5,6,7,5,"ALU to ALU MEM/WB");
        directed_vector(511,1,5,5,7,"ADD to SW store data");
        directed_vector(415,5,5,5,5,"ALU to JALR base, unused rs2");
        directed_vector(479,5,6,5,6,"branch A from EX/MEM B from MEM/WB");
        directed_vector(479,5,6,6,5,"branch A from MEM/WB B from EX/MEM");
        directed_vector(479,5,5,5,5,"two matching producers, youngest ready");
        directed_vector(475,5,6,5,5,"nonready load and stale WB source A");
        directed_vector(507,1,5,5,5,"nonready load and stale WB store source B");
        directed_vector(507,5,5,5,5,"nonready load both sources");
        directed_vector(511,0,0,0,0,"x0 does not forward");
        directed_vector(255,5,5,5,5,"invalid ID/EX clears prior diagnostic");
        directed_vector(287,5,5,5,5,"LUI AUIPC JAL FENCE unused sources");
        directed_vector(495,5,5,5,5,"invalid EX/MEM allows eligible WB");
        directed_vector(503,5,5,5,5,"EX/MEM reg_write zero allows WB");
        directed_vector(509,5,5,7,5,"invalid MEM/WB suppresses forwarding");
        directed_vector(510,5,5,7,5,"MEM/WB reg_write zero suppresses forwarding");
        directed_vector(479,5,5,5,5,"non-store retains zero store select");
        // Exhaust all nine Boolean controls over all register equality/zero
        // patterns: zero plus four distinct nonzero representatives suffice.
        for(c=0;c<512;c=c+1)
            for(i=0;i<5;i=i+1)
                for(j=0;j<5;j=j+1)
                    for(k=0;k<5;k=k+1)
                        for(l=0;l<5;l=l+1) begin
                            apply_vector(9'(c),representatives[i],representatives[j],
                                         representatives[k],representatives[l],"semantic sweep");
                            semantic=semantic+1;
                        end
        // All 32 register numbers through each source and both producers,
        // with ready and nonready EX/MEM, and stale WB matches included.
        for(r=0;r<32;r=r+1)
            for(s=0;s<32;s=s+1)
                for(t=0;t<32;t=t+1)
                    for(ready=0;ready<2;ready=ready+1) begin
                        apply_vector(ready?511:507,5'(r),5'((r+1)%32),5'(s),5'(t),"source A register sweep");
                        apply_vector(ready?511:507,5'((r+1)%32),5'(r),5'(s),5'(t),"source B register sweep");
                        register_sweep=register_sweep+2;
                    end
        for(i=0;i<100000;i=i+1) begin
            random_flags=random_word(); random_ids=random_word();
            apply_vector(random_flags[8:0],random_ids[4:0],random_ids[9:5],
                         random_ids[14:10],random_ids[19:15],"random");
            randomized=randomized+1;
        end
        // Same inputs revisited after diagnostic state: no sticky state in DUT.
        directed_vector(507,5,5,5,5,"combinational error asserted");
        directed_vector(511,5,5,5,5,"readiness alone clears error without clock");
        directed_vector(507,5,5,5,5,"readiness alone reasserts error without clock");
        directed_vector(255,5,5,5,5,"valid alone clears error without clock");
        for(i=0;i<4;i=i+1) begin
            $display("COVER select=%0d A=%0d B=%0d STORE=%0d",i,coverage_a[i],coverage_b[i],coverage_store[i]);
            if(coverage_a[i]==0 || coverage_b[i]==0 || coverage_store[i]==0)
                $fatal(1,"Missing select coverage");
        end
        $display("COVER split A_EX_B_WB=%0d A_WB_B_EX=%0d",coverage_pair[1][2],coverage_pair[2][1]);
        $display("COVER errors A_only=%0d B_only=%0d both=%0d stale_A=%0d stale_B=%0d low=%0d high=%0d",
                 errors_a_only,errors_b_only,errors_both,stale_a,stale_b,coverage_error[0],coverage_error[1]);
        if(errors_a_only==0 || errors_b_only==0 || errors_both==0 || stale_a==0 || stale_b==0 ||
           coverage_pair[1][2]==0 || coverage_pair[2][1]==0) $fatal(1,"Missing diagnostic/independent source coverage");
        $display("RESULT vectors=%0d checks=%0d passing=%0d failures=%0d directed=%0d semantic=%0d register_sweep=%0d random=%0d seed=10c0ffee",
                 vectors,checks,checks-failures,failures,directed,semantic,register_sweep,randomized);
        if(failures!=0) $fatal(1,"Forwarding verification failed");
        $finish;
    end
endmodule
