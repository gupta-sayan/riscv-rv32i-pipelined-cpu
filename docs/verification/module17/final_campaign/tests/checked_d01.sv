`timescale 1ns/1ps
module checked_d01;
    parameter bit TRACE_EN=1;
    tb_d01 original();
    // Existing accepted bench remains unchanged; configure its actual core.
    defparam original.dut.TRACE_EN=TRACE_EN;
    initial begin
        #0;
        assert(original.dut.TRACE_EN===TRACE_EN) else $fatal(1,"D01 trace override ineffective");
        $display("D01_CONFIG TRACE_EN=%0d",original.dut.TRACE_EN);
    end
endmodule
