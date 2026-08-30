`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 11:08:13 AM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
import axi_vip_pkg::*;
import tb_design_axi_vip_0_0_pkg::*;

module tb_top();
    //reset_n drives ext_rst signal of rst_clk_wizard, rst_wizard drives the active high reset of the clk wizard
    logic clk, reset_n, rst_wizard, start_txn, txn_done, error;


    tb_design_wrapper UUT (
        .clk_in1_0(clk),
        .reset_0(rst_wizard),               // Clock Wizard Reset
        .ext_reset_in_0(reset_n),           // System Reset
        .m00_axi_init_axi_txn_0(start_txn), // VIO start button
        .m00_axi_txn_done_0(txn_done),      // VIO done flag
        .m00_axi_error_0(error)
    );

    tb_design_axi_vip_0_0_slv_mem_t slave_agent; //declares VIP agent as a slave operating in memory model mode

    //Generate 100mhz clk
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        bit [7:0] read_byte_0, read_byte_1, read_byte_2, read_byte_3;
        logic [31:0] final_result;

        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);

        //init
        start_txn = 0;

        //resets
        rst_wizard = 1; // Wizard is active high, do we need this?
        reset_n = 0;    // System is active low

        #50;
        // Release Wizard Reset so PLL can lock
        rst_wizard = 0; 
        
        #100;
        // Release System Reset
        reset_n = 1;    
        #100;

        //Create and start agent
        slave_agent = new("slave_agent", UUT.tb_design_i.axi_vip_0.inst.IF); //matches path(when instantiating modules)
        slave_agent.start_slave();

        $display("Loading %h into DDR...", 32'h00000005);
        slave_agent.mem_model.backdoor_memory_write(32'h40000000, 32'h00000005); // LSB
        $display("Checking backdoor write result at 00: %h", slave_agent.mem_model.backdoor_memory_read(32'h40000000));
        $display("Checking backdoor write result at 04: %h", slave_agent.mem_model.backdoor_memory_read(32'h40000004));

        $display("Checking final address before write, data at write address is %h", slave_agent.mem_model.backdoor_memory_read(32'h50000000));
        #50;

        #10000;

        // Pulse to start the IP
        $display("Sending Start Pulse to IP...");
        start_txn = 1;
        #10; // Wait 1 clock cycle
        start_txn = 0;


        // Wait
        $display("Waiting for TXN_DONE...");
        wait(txn_done == 1'b1);
        $display("Hardware finished!");

        // Read 0x50000000 to see if it successfully added 1 and wrote 6
        $display("Checking Result at 0x50000000:");

        final_result = slave_agent.mem_model.backdoor_memory_read(32'h50000000);
        
        $display("Result is: %h", final_result);

        $display("Additional check at addr 04: %h", slave_agent.mem_model.backdoor_memory_read(32'h50000004));
        $display("Additional check at addr 08: %h", slave_agent.mem_model.backdoor_memory_read(32'h50000008));
        $display("Additional check at addr 0c: %h", slave_agent.mem_model.backdoor_memory_read(32'h5000000c));
        $display("Additional check at addr 10: %h", slave_agent.mem_model.backdoor_memory_read(32'h50000010));


        #100;
        $finish;


    end




endmodule
