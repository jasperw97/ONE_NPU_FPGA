module mock_npu #(
    parameter int DRAM_ADDR_WIDTH = 32,
    parameter int DATA_WIDTH      = 1024
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         start_i,
    output logic                         busy_o,

    // Interface matching your wrapper
    output logic                         dram_rd_valid,
    input  logic                         dram_rd_ready,
    output logic [DRAM_ADDR_WIDTH-1:0]   dram_rd_addr,
    input  logic                         dram_rd_data_valid,
    input  logic [DATA_WIDTH-1:0]        dram_rd_data,

    output logic                         dram_wr_valid,
    input  logic                         dram_wr_ready,
    output logic [DRAM_ADDR_WIDTH-1:0]   dram_wr_addr,
    output logic [DATA_WIDTH-1:0]        dram_wr_data
);

    typedef enum logic [2:0] {
        M_IDLE,
        M_READ_REQ,
        M_READ_WAIT,
        M_CALC,
        M_WRITE_DATA,
        M_DONE
    } mock_state_t;

    mock_state_t state;
    logic [DATA_WIDTH-1:0] hold_data;

    // Hardcoded addresses for testing
    localparam logic [DRAM_ADDR_WIDTH-1:0] TEST_SRC_ADDR  = 32'h0000_0000; 
    localparam logic [DRAM_ADDR_WIDTH-1:0] TEST_DEST_ADDR = 32'h1000_0000;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= M_IDLE;
            dram_rd_valid <= 1'b0;
            dram_wr_valid <= 1'b0;
            hold_data     <= '0;
            busy_o        <= 1'b0;
        end else begin
            case (state)
                M_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        state  <= M_READ_REQ;
                        busy_o <= 1'b1;
                    end
                end

                M_READ_REQ: begin
                    dram_rd_valid <= 1'b1;
                    dram_rd_addr  <= TEST_SRC_ADDR;
                    if (dram_rd_valid && dram_rd_ready) begin
                        dram_rd_valid <= 1'b0;
                        state         <= M_READ_WAIT;
                    end
                end


                M_READ_WAIT: begin
                    if (dram_rd_data_valid) begin
                        hold_data <= dram_rd_data; // Capture the incoming data
                        state     <= M_CALC;
                    end
                end

        
                M_CALC: begin
                    hold_data <= hold_data + 1; 
                    state     <= M_WRITE_DATA;
                end

                M_WRITE_DATA: begin
                    dram_wr_valid <= 1'b1;
                    dram_wr_addr  <= TEST_DEST_ADDR;
                    dram_wr_data  <= hold_data;
                    if (dram_wr_valid && dram_wr_ready) begin
                        dram_wr_valid <= 1'b0;
                        state         <= M_DONE;
                    end
                end

                M_DONE: begin
                    state <= M_IDLE;
                end
            endcase
        end
    end

endmodule