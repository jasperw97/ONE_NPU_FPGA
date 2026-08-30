`timescale 1ns/1ps
`default_nettype wire
`include "params.vh"

module npu_int16 #(
    parameter int LANES        = `LANES,
    parameter int MAX_M        = 4096,
    parameter int MAX_K        = 4096,
    parameter int MAX_N        = 4096,
    parameter int MAX_BROADCAST_N = 1024
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start_i,

    // ------------------------------------------------------------
    // Top-level status
    // ------------------------------------------------------------
    output logic                        done_o,

    // ------------------------------------------------------------
    // External DRAM interface
    // ------------------------------------------------------------
    output logic                        dram_rd_valid,
    input  logic                        dram_rd_ready,
    output logic [`DRAM_ADDR_WIDTH-1:0] dram_rd_addr,

    input  logic                        dram_rd_data_valid,
    input  logic [`SRAM_WIDTH_O-1:0]    dram_rd_data,

    output logic                        dram_wr_valid,
    input  logic                        dram_wr_ready,
    output logic [`DRAM_ADDR_WIDTH-1:0] dram_wr_addr,
    output logic [`SRAM_WIDTH_O-1:0]    dram_wr_data,

    output logic busy_o
);

    // ============================================================
    // NPU Top Overview
    // ============================================================
    // Runtime flow:
    //   start_i
    //   |- LOAD_JOB: read job header counts
    //   |- LOAD_INST: preload instruction SRAM
    //   |- LOAD_LUT: preload EXP/RCP LUT SRAM
    //   |- LOAD_DESC: preload descriptor SRAM when desc_word_len_r != 0
    //   |- LOAD_TENSOR: preload tensor SRAM payloads or pass through when count is 0
    //   |- for each instruction
    //   |  |- FETCH_INST -> DECODE_INST
    //   |  |- NEXT_OP: select/skip op slots and decide the next action
    //   |  |  |- skip IDLE/unsupported slots without consuming a descriptor
    //   |  |  |- FETCH_DESC when the selected op uses a descriptor
    //   |  |  `- SETUP_OP -> ISSUE_OP -> WAIT_OP -> NEXT_OP
    //   |  `- leave instruction loop after all four slots are scanned
    //   |- NEXT_INST when more instructions remain
    //   |- STORE_RESULT when store_result_valid_r is set
    //   `- DONE: pulse done_o and return to IDLE
    //
    // Main ownership:
    //   top shell: frontend FSM, setup packet, SRAM/compute muxing
    //   LSU: external DRAM reads/writes
    //   sram_unit: tensor, instruction, descriptor, and LUT SRAMs
    //   op_decoder / desc_decoder: combinational metadata decode
    //   controller: SRAM-to-EW tensor stream control
    //   SA / EW: runtime compute engines
    //
    // File order:
    //   constants/types -> helper functions -> internal signals -> FSM control
    //   -> assigns/muxes -> combinational datapath -> clocked registers
    //   -> generate blocks -> submodule instances.

    // ============================================================
    // Address Map and State Types
    // ============================================================
    // ------------------------------------------------------------
    // LSU pseudo-bank targets
    // ------------------------------------------------------------
    localparam logic [3:0] LSU_BANK_LUT  = 4'd8;
    localparam logic [3:0] LSU_BANK_QDESC = 4'd9;
    localparam logic [3:0] LSU_BANK_INST = 4'd10;
    // Pseudo LSU target for reading control words into lsu_job_wdata.
    // This is not a physical tensor SRAM bank.
    localparam logic [3:0] LSU_BANK_JOB  = 4'd11;
    // ------------------------------------------------------------
    // Fixed DRAM regions
    // ------------------------------------------------------------
    localparam logic [`DRAM_ADDR_WIDTH-1:0] PROFILE_DRAM_BASE = 32'd0;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] LUT_DRAM_BASE  = 23'd2_000_000;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] JOB_DRAM_BASE  = 23'd6_000_000;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] INST_DRAM_BASE = 23'd5_000_000;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] DESC_DRAM_BASE = 23'd7_000_000;
    // Result stores currently use the fixed DRAM output region used by the TB.
    localparam logic [`DRAM_ADDR_WIDTH-1:0] RESULT_DRAM_BASE = 23'd3_000_000;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] TENSOR_DMA_TABLE_DRAM_BASE = 23'd7_100_000;
    // ------------------------------------------------------------
    // Job header layout
    // ------------------------------------------------------------
    // Bit offsets inside the single job header word. The TB/compiler computes
    // these counts before start_i; LOAD_JOB only latches them.
    localparam int JOB_INST_COUNT_LSB = 0;
    localparam int JOB_DESC_WORD_LEN_LSB = 16;
    localparam int JOB_TENSOR_DMA_COUNT_LSB = 32;
    //Additions to track multiple job
    localparam int JOB_IS_LAST_LSB          = 47;
    localparam int JOB_RESULT_BASE_LSB      = 48;
    localparam int JOB_INST_OFFSET_LSB      = 80;
    localparam int JOB_DESC_OFFSET_LSB      = 96;
    localparam int JOB_DMA_OFFSET_LSB       = 112;

    // ------------------------------------------------------------
    // Tensor DMA entry layout
    // ------------------------------------------------------------
    // Tensor DMA entry fields. word_len is a fixed payload length for one
    // entry; LSU tracks the transfer progress internally.
    localparam int TENSOR_ENTRY_BANK_LSB = 0;
    localparam int TENSOR_ENTRY_DRAM_BASE_LSB = 32;
    localparam int TENSOR_ENTRY_WORD_LEN_LSB = 64;
    // ------------------------------------------------------------
    // LUT image layout
    // ------------------------------------------------------------
    // EXP and reciprocal LUT images use fixed subregions in DRAM and LUT SRAM.
    localparam logic [`DRAM_ADDR_WIDTH-1:0] EXP_LUT_DRAM_BASE = LUT_DRAM_BASE;
    localparam logic [`DRAM_ADDR_WIDTH-1:0] RCP_LUT_DRAM_BASE = LUT_DRAM_BASE + {{(`DRAM_ADDR_WIDTH-9){1'b0}}, 9'd256};
    localparam logic [`SRAM_ADDR_WIDTH-1:0] EXP_LUT_BASE_ADDR = {`SRAM_ADDR_WIDTH{1'b0}};
    localparam logic [`SRAM_ADDR_WIDTH-1:0] RCP_LUT_BASE_ADDR = {{(`SRAM_ADDR_WIDTH-9){1'b0}}, 9'd256};
    localparam int LUT_ENTRY_NUM = 513;
    localparam int LUT_ENTRIES_PER_WORD = (`SRAM_WIDTH_O / `INT16_SIZE);
    localparam logic [`SRAM_ADDR_WIDTH-1:0] LUT_WORD_NUM =
        (LUT_ENTRY_NUM + LUT_ENTRIES_PER_WORD - 1) / LUT_ENTRIES_PER_WORD;
    localparam int INST_BITS = `INST_BITS;
    localparam int INST_PER_WORD = (`SRAM_WIDTH_O / INST_BITS);
    localparam int DESC_WORDS_PER_PACKET =
        (`DESC_PACKET_BITS + (`SRAM_WIDTH_O) - 1) / (`SRAM_WIDTH_O);
    localparam int DESC_STORAGE_BITS = DESC_WORDS_PER_PACKET * `SRAM_WIDTH_O;
    localparam int DESC_WORD_IDX_WIDTH = (DESC_WORDS_PER_PACKET <= 1) ? 1
                                         : $clog2(DESC_WORDS_PER_PACKET);
    localparam int CFG_M_WIDTH = $clog2(MAX_M);
    localparam int CFG_K_WIDTH = $clog2(MAX_K);
    localparam int CFG_N_WIDTH = $clog2(MAX_N);
    localparam int WORD_COL_IDX_WIDTH = (((MAX_N + LANES - 1) / LANES) <= 1) ? 1
                                        : $clog2((MAX_N + LANES - 1) / LANES);
    // ------------------------------------------------------------
    // Frontend FSM state types
    // ------------------------------------------------------------
    typedef enum logic [4:0] {
        S_IDLE, //0
        S_LOAD_JOB, //1
        S_LOAD_INST, //2
        S_LOAD_LUT, //3
        S_LOAD_DESC, //4
        S_LOAD_TENSOR, //5
        S_FETCH_INST, //6
        S_DECODE_INST, //7
        S_NEXT_OP, //8
        S_FETCH_DESC, //9
        S_SETUP_OP, //a
        S_PREP_BCAST, //b
        S_ISSUE_OP, //c
        S_WAIT_OP, //d
        S_STORE_RESULT, //e
        S_NEXT_INST, //f
        S_STORE_PROFILE, //10
        S_DONE //11
    } npu_state_t;

    // Keep S_LOAD_LUT as one top-level state; this phase tracks its local steps.
    typedef enum logic [1:0] {
        LUT_DMA_EXP,
        LUT_DMA_RCP,
        LUT_LOAD_BOTH,
        LUT_WAIT_BOTH
    } lut_phase_t;

    // S_LOAD_TENSOR uses LSU twice per entry: first for the control word,
    // then for the tensor payload itself.
    typedef enum logic {
        TENSOR_ENTRY,
        TENSOR_PAYLOAD
    } tensor_phase_t;

    // ------------------------------------------------------------
    // Descriptor decode and runtime setup packets
    // ------------------------------------------------------------
    typedef struct packed {
        logic [31:0] header;
        logic [15:0] reserved;
        logic [7:0]  version;
        logic [3:0]  op_slot;
        logic [3:0]  op_code;
        logic [31:0] m;
        logic [31:0] n;
        logic [31:0] k;
        logic [31:0] data_count;
        logic [31:0] src1_count;
        logic [31:0] total_words;
        logic [31:0] broadcast_count;
        logic [2:0]  src0_bank;
        logic [`SRAM_ADDR_WIDTH-1:0] src0_word_base;
        logic [2:0]  src1_bank;
        logic [`SRAM_ADDR_WIDTH-1:0] src1_word_base;
        logic [2:0]  dst_bank;
        logic [`SRAM_ADDR_WIDTH-1:0] dst_word_base;
        logic [31:0] conv_stride_h;
        logic [31:0] conv_stride_w;
        logic [31:0] conv_padding;
        logic [31:0] conv_batch;
        logic [31:0] conv_img_row;
        logic [31:0] conv_img_col;
        logic [31:0] conv_in_channel;
        logic [31:0] conv_out_channel;
        logic [31:0] conv_ker_row;
        logic [31:0] conv_ker_col;
        logic [31:0] conv_requant_multiplier;
        logic [31:0] conv_requant_shift;
        logic [31:0] conv_requant_output_offset;
        logic [31:0] conv_activation_min;
        logic [31:0] conv_activation_max;
        logic [31:0] conv_input_requant_multiplier;
        logic [31:0] conv_input_requant_shift;
        logic [31:0] conv_input_requant_offset;
        logic [31:0] conv_input_activation_min;
        logic [31:0] conv_input_activation_max;
        logic [31:0] conv_weight_requant_multiplier;
        logic [31:0] conv_weight_requant_shift;
        logic [31:0] conv_weight_requant_offset;
        logic [31:0] conv_weight_activation_min;
        logic [31:0] conv_weight_activation_max;
        logic [31:0] exp_deq_input_range_radius;
        logic [31:0] exp_deq_input_zero_point;
        logic [31:0] exp_deq_input_multiplier;
        logic [31:0] exp_deq_input_left_shift;
        logic [31:0] exp_req_input_quantized_multiplier;
        logic [31:0] exp_req_input_shift;
        logic [31:0] exp_req_input_offset;
        logic [31:0] rcp_deq_input_range_radius;
        logic [31:0] rcp_deq_input_zero_point;
        logic [31:0] rcp_deq_input_multiplier;
        logic [31:0] rcp_deq_input_left_shift;
        logic [31:0] rcp_req_input_quantized_multiplier;
        logic [31:0] rcp_req_input_shift;
        logic [31:0] rcp_req_input_offset;
        logic [31:0] add_input1_offset;
        logic [31:0] add_input2_offset;
        logic [31:0] add_left_shift;
        logic [31:0] add_input1_multiplier;
        logic [31:0] add_input2_multiplier;
        logic [31:0] add_input1_shift;
        logic [31:0] add_input2_shift;
        logic [31:0] add_output_multiplier;
        logic [31:0] add_output_shift;
        logic [31:0] add_output_offset;
        logic [31:0] add_activation_min;
        logic [31:0] add_activation_max;
        logic [31:0] sub_input1_offset;
        logic [31:0] sub_input2_offset;
        logic [31:0] sub_left_shift;
        logic [31:0] sub_input1_multiplier;
        logic [31:0] sub_input2_multiplier;
        logic [31:0] sub_input1_shift;
        logic [31:0] sub_input2_shift;
        logic [31:0] sub_output_multiplier;
        logic [31:0] sub_output_shift;
        logic [31:0] sub_output_offset;
        logic [31:0] sub_activation_min;
        logic [31:0] sub_activation_max;
        logic [31:0] mul_input1_offset;
        logic [31:0] mul_input2_offset;
        logic [31:0] mul_output_multiplier;
        logic [31:0] mul_output_shift;
        logic [31:0] mul_output_offset;
        logic [31:0] mul_activation_min;
        logic [31:0] mul_activation_max;
        logic [31:0] mul_in1_requant_multiplier;
        logic [31:0] mul_in1_requant_shift;
        logic [31:0] mul_in1_requant_offset;
        logic [31:0] mul_in1_activation_min;
        logic [31:0] mul_in1_activation_max;
        logic [31:0] mul_in2_requant_multiplier;
        logic [31:0] mul_in2_requant_shift;
        logic [31:0] mul_in2_requant_offset;
        logic [31:0] mul_in2_activation_min;
        logic [31:0] mul_in2_activation_max;
    } desc_cfg_t;

    // Instruction-side tag for one active op slot.
    // op_idx selects slot 0..3; op_code/b_cast come from the decoded
    // instruction; desc_idx is the descriptor SRAM index assigned to it.
    typedef struct packed {
        logic [2:0]  op_idx;
        logic [3:0]  op_code;
        logic [1:0]  b_cast;
        logic [24:0] desc_idx;
    } op_context_t;

    typedef struct packed {
        logic        valid;
        op_context_t op_context;
        desc_cfg_t   desc;
    } setup_cfg_t;
    // ============================================================
    // Helper Functions
    // ============================================================
    // ------------------------------------------------------------
    // Op classifiers
    // ------------------------------------------------------------
    function automatic logic op_needs_desc(input logic [3:0] op_code);
        unique case (op_code)
            `OP_CONV, `OP_FC, `OP_EXP, `OP_RCP, `OP_ADD, `OP_SUB, `OP_MUL: op_needs_desc = 1'b1;
            default: op_needs_desc = 1'b0;
        endcase
    endfunction

    function automatic logic op_is_sa(input logic [3:0] op_code);
        unique case (op_code)
            `OP_CONV, `OP_FC: op_is_sa = 1'b1;
            default:         op_is_sa = 1'b0;
        endcase
    endfunction

    function automatic logic op_is_ew(input logic [3:0] op_code);
        unique case (op_code)
            `OP_EXP, `OP_RCP, `OP_ADD, `OP_SUB, `OP_MUL: op_is_ew = 1'b1;
            default:                                      op_is_ew = 1'b0;
        endcase
    endfunction

    function automatic logic op_is_binary_ew(input logic [3:0] op_code);
        unique case (op_code)
            `OP_ADD, `OP_SUB, `OP_MUL: op_is_binary_ew = 1'b1;
            default:                   op_is_binary_ew = 1'b0;
        endcase
    endfunction
    // ------------------------------------------------------------
    // INT8 clamp helpers
    // ------------------------------------------------------------
    function automatic logic signed [`INT8_SIZE-1:0] sat_int8(input int signed x);
        if (x > 127)  sat_int8 = 127;
        else if (x < -128) sat_int8 = -128;
        else          sat_int8 = x[`INT8_SIZE-1:0];
    endfunction

    function automatic logic signed [`INT8_SIZE-1:0] clamp_to_int8(
        input logic signed [`INT32_SIZE-1:0] x,
        input logic signed [`INT32_SIZE-1:0] offset,
        input logic signed [`INT32_SIZE-1:0] act_min,
        input logic signed [`INT32_SIZE-1:0] act_max
    );
        logic signed [`INT32_SIZE-1:0] y;
        begin
            y = x + offset;

            if (y > act_max)
                y = act_max;
            else if (y < act_min)
                y = act_min;

            clamp_to_int8 = sat_int8(y);
        end
    endfunction

    // ============================================================
    // Internal Signals
    // ============================================================
    // ------------------------------------------------------------
    // Preload, program counters, and FSM state
    // ------------------------------------------------------------
    npu_state_t    state, state_n;
    lut_phase_t    lut_phase_r, lut_phase_n;
    tensor_phase_t tensor_phase_r, tensor_phase_n;
    logic          ctrl_busy;

    //Signals for performance profiling
    logic [31:0] dram_cycles_r;
    logic [31:0] sa_cycles_r;
    logic [31:0] ew_cycles_r;
    logic        lsu_busy_sig;
    logic [31:0] total_cycles_r;
    logic [`SRAM_WIDTH_O-1:0] lsu_dram_wr_data;

    logic lsu_cmd_issued_r;
    logic lsu_load_lut;
    logic lsu_load_desc;
    logic lsu_load_tensor_entry;
    logic lsu_load_tensor_payload;
    logic lsu_load_tensor;

    logic exp_load_npu;
    logic reciprocal_load_npu;
    logic exp_lut_ready;
    logic rcp_lut_ready;

    logic [`SRAM_ADDR_WIDTH+3:0] inst_pc_r;
    logic [`SRAM_ADDR_WIDTH+3:0] inst_count_r;
    logic [`SRAM_ADDR_WIDTH-1:0] desc_word_len_r;
    logic [`SRAM_ADDR_WIDTH-1:0] tensor_dma_count_r;
    logic [14:0]                 inst_tensor_dma_count_r;
    logic [14:0]                 inst_tensor_entry_count_r;
    logic [`SRAM_ADDR_WIDTH-1:0] tensor_entry_idx_r;
    logic [3:0]                  tensor_entry_bank_r;
    logic [`DRAM_ADDR_WIDTH-1:0] tensor_entry_dram_base_r;
    logic [`SRAM_ADDR_WIDTH-1:0] tensor_entry_word_len_r;

    //Signals for job queue
    logic [15:0]                   job_idx_r;
    logic                          is_last_job_r;
    logic [`DRAM_ADDR_WIDTH-1:0]   job_result_base_r;
    logic [15:0]   inst_offset_r;
    logic [15:0]   desc_offset_r;
    logic [15:0]   dma_offset_r;

    // ------------------------------------------------------------
    // Internal LSU command/status
    // ------------------------------------------------------------
    logic                        lsu_valid;
    logic                        lsu_write;
    logic [3:0]                  lsu_bank;
    logic [`DRAM_ADDR_WIDTH-1:0] lsu_dram_base;
    logic [`SRAM_ADDR_WIDTH-1:0] lsu_sram_base;
    logic [`SRAM_ADDR_WIDTH-1:0] lsu_len;
    logic                        lsu_ready;
    logic                        lsu_complete;
    logic                        lsu_job_we;
    logic [`SRAM_WIDTH_O-1:0]    lsu_job_wdata;

    logic                        tensor_entry_done;
    logic                        tensor_payload_done;
    logic                        tensor_entry_is_last;
    logic                        tensor_entry_idx_valid;
    logic [15:0]                 inst_tensor_entry_count_next;
    logic [15:0]                 inst_tensor_dma_count_ext;
    logic [`SRAM_ADDR_WIDTH:0]   tensor_entry_idx_next;
    logic [`SRAM_ADDR_WIDTH:0]   tensor_dma_count_ext;
    logic                        tensor_entry_bank_from_job_valid;
    logic                        tensor_entry_bank_valid;
    logic [3:0]                  tensor_entry_bank_from_job;
    logic [`DRAM_ADDR_WIDTH-1:0] tensor_entry_dram_base_from_job;
    logic [`SRAM_ADDR_WIDTH-1:0] tensor_entry_word_len_from_job;
    // ------------------------------------------------------------
    // Instruction and descriptor dispatch by FSM state
    // ------------------------------------------------------------
    // S_FETCH_INST: fetch one packed instruction SRAM word.
    logic                        inst_fetch_en;
    logic [`SRAM_ADDR_WIDTH-1:0] inst_fetch_addr;
    logic [`SRAM_ADDR_WIDTH-1:0] load_inst_word_len;
    logic [`SRAM_WIDTH_O-1:0]    inst_fetch_data;

    // S_DECODE_INST: split raw instruction fields and latch per-op metadata.
    logic                        decode_valid_r;
    logic [63:0]                 raw_inst;
    logic [15:0]                 decoded_op;
    logic [14:0]                 decoded_inst_reserved;
    logic [7:0]                  decoded_b_cast;
    logic [24:0]                 decoded_dsc_idx;
    logic [3:0]                  decode_inst_op_slot_r [0:3];
    logic [1:0]                  decode_inst_b_cast_slot_r [0:3];
    logic [24:0]                 decode_inst_base_desc_idx_r;

    // S_NEXT_OP: select/skip the next active op slot in this instruction.
    logic                        next_op_needs_desc;
    logic [2:0]                  next_op_slot_idx_r;
    logic [24:0]                 next_op_desc_idx_r;

    // S_FETCH_DESC: issue one descriptor SRAM read and keep its op context.
    logic                        fetch_desc_en;
    logic                        fetch_desc_read_pending_r;
    logic [DESC_WORD_IDX_WIDTH-1:0] fetch_desc_word_idx_r;
    logic [`SRAM_ADDR_WIDTH-1:0] fetch_desc_addr;
    logic [`SRAM_WIDTH_O-1:0]    fetch_desc_data;
    logic [DESC_STORAGE_BITS-1:0] fetch_desc_packet_r;
    logic [DESC_STORAGE_BITS-1:0] fetch_desc_packet_complete;
    logic                        fetch_desc_last_word;
    op_context_t                 fetch_desc_context_r;

    // S_SETUP_OP: decode the returned descriptor and stage issue context.
    logic                        setup_op_issue_valid;
    logic                        setup_op_desc_valid_r;
    logic [`DESC_PACKET_BITS-1:0] setup_op_desc_data_r;
    op_context_t                 setup_op_context_r;
    desc_cfg_t                   decoded_desc;
    setup_cfg_t                  setup_r;

    // S_ISSUE_OP / S_WAIT_OP: runtime compute issue, done, and config view.
    logic                        issue_op_valid;
    logic                        sa_done;
    logic                        ew_done;
    logic [3:0]                  issue_op_code;
    logic [CFG_M_WIDTH-1:0]      cfg_m;
    logic [CFG_K_WIDTH-1:0]      cfg_k;
    logic [CFG_N_WIDTH-1:0]      cfg_n;
    logic [2*CFG_M_WIDTH:0]      cfg_total_words;
    logic [2:0]                  cfg_src0_bank;
    logic [2:0]                  cfg_src1_bank;
    logic [2:0]                  cfg_dst_bank;
    logic                        cfg_ew_src0_broadcast;
    logic                        cfg_ew_src1_broadcast;

    // A sequential baseline prepares at most one compact broadcast operand
    // before issuing its EW operation.
    logic [2:0]                  broadcast_prep_src_bank;
    logic [`INT32_SIZE-1:0]      broadcast_prep_n;
    logic [`INT32_SIZE-1:0]      broadcast_prep_count;
    logic                        broadcast_prep_start;
    logic                        broadcast_prep_busy;
    logic                        broadcast_prep_done;
    logic                        broadcast_prep_read_en;
    logic [2:0]                  broadcast_prep_read_bank;
    logic [`SRAM_ADDR_WIDTH-1:0] broadcast_prep_read_addr;
    logic [`SRAM_WIDTH_O-1:0]    broadcast_prep_read_data;
    logic                        broadcast_runtime_read_en;
    logic [WORD_COL_IDX_WIDTH-1:0]
                                 broadcast_runtime_word_col_idx;
    logic [`SRAM_WIDTH_O-1:0]    broadcast_runtime_read_data;

    // S_WAIT_OP / S_STORE_RESULT: remember the latest completed output copy.
    logic                        wait_op_done;
    logic                        store_result_valid_r;
    logic [2:0]                  store_result_bank_r;
    logic [`SRAM_ADDR_WIDTH-1:0] store_result_sram_base_r;
    logic [`SRAM_ADDR_WIDTH-1:0] store_result_words_r;
    // ------------------------------------------------------------
    // SA request, output, and requantization
    // ------------------------------------------------------------
    logic sa_start_i;
    logic sa_busy;
    logic sa_sram_req_valid;
    logic sa_requant_input_valid;

    logic sa_out_valid_i16;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_out_addr_x_i16;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_out_addr_y_i16;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_waddr;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_words_per_row;

    logic signed [`INT16_SIZE*LANES-1:0] sa_input_data_raw;
    logic signed [`INT16_SIZE*LANES-1:0] sa_weight_data_raw;
    logic signed [`INT16_SIZE*LANES-1:0] sa_out_data_i16;

    logic [`SRAM_ADDR_WIDTH-1:0]         sa_input_addr_x;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_input_addr_y;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_weight_addr_x;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_weight_addr_y;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_data_addr;
    logic [`SRAM_ADDR_WIDTH-1:0]         sa_weight_addr;

    logic signed [LANES*`INT8_SIZE-1:0] sa_input_data_q8;
    logic signed [LANES*`INT8_SIZE-1:0] sa_weight_data_q8;
    logic signed [LANES*`INT8_SIZE-1:0] mul_in1_data_q8;
    logic signed [LANES*`INT8_SIZE-1:0] mul_in2_data_q8;

    logic [LANES-1:0] sa_data_requant_output_valid;
    logic [LANES-1:0] sa_weight_requant_output_valid;
    logic [LANES-1:0] mul_in1_requant_output_valid;
    logic [LANES-1:0] mul_in2_requant_output_valid;

    logic signed [`INT32_SIZE-1:0] sa_data_requant_out32   [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] sa_weight_requant_out32 [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] mul_in1_requant_out32   [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] mul_in2_requant_out32   [0:LANES-1];

    logic signed [`INT32_SIZE-1:0] sa_data_lane_32   [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] sa_weight_lane_32 [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] mul_in1_lane_32   [0:LANES-1];
    logic signed [`INT32_SIZE-1:0] mul_in2_lane_32   [0:LANES-1];

    logic sa_input_data_valid_to_sa;
    logic mul_input_valid;

    // Controller MUL stream enters the INT8 requant path before u_ew.
    logic                                  mul_en;
    logic [`INT16_SIZE*LANES-1:0]          mul_data_in;
    logic [`INT16_SIZE*LANES-1:0]          ew_src1_data_selected;
    // ------------------------------------------------------------
    // Tensor SRAM arbitration
    // ------------------------------------------------------------
    // The compute path and internal LSU share tensor SRAM ports.
    logic                                  load_sram_en;
    logic [`SRAM_ADDR_WIDTH-1:0]           load_sram_addr;
    logic [`INT16_SIZE*LANES-1:0]          load_sram_rdata;
    logic                                  ew_src1_ren;
    logic [`SRAM_ADDR_WIDTH-1:0]           ew_src1_addr;
    logic [CFG_N_WIDTH:0]                  ew_broadcast_word_in_row;
    logic [CFG_N_WIDTH:0]                  ew_broadcast_words_per_row;

    logic                                  ew_we;
    logic [`SRAM_ADDR_WIDTH-1:0]           ew_waddr;
    logic [`INT16_SIZE*LANES-1:0]          ew_wdata;

    logic [2:0]                            tensor_src0_bank;
    logic                                  tensor_src0_ren;
    logic [`SRAM_ADDR_WIDTH-1:0]           tensor_src0_addr;
    logic [`INT16_SIZE*LANES-1:0]          tensor_src0_data;
    logic [2:0]                            tensor_src1_bank;
    logic                                  tensor_src1_ren;
    logic [`SRAM_ADDR_WIDTH-1:0]           tensor_src1_addr;
    logic [`INT16_SIZE*LANES-1:0]          tensor_src1_data;
    logic [2:0]                            tensor_dst_bank;
    logic                                  tensor_dst_we;
    logic [`SRAM_ADDR_WIDTH-1:0]           tensor_dst_waddr;
    logic [`INT16_SIZE*LANES-1:0]          tensor_dst_wdata;
    logic                                  tensor_compute_we;

    logic                                  lsu_bank_we;
    logic [2:0]                            lsu_bank_wbank;
    logic [`SRAM_ADDR_WIDTH-1:0]           lsu_bank_waddr;
    logic [`SRAM_WIDTH_O-1:0]              lsu_bank_wdata;

    logic                                  lsu_store_sram_ren;
    logic [2:0]                            lsu_store_sram_bank;
    logic [`SRAM_ADDR_WIDTH-1:0]           lsu_store_sram_addr;
    // ------------------------------------------------------------
    // Element-wise LUT SRAM interface
    // ------------------------------------------------------------
    logic [`INT16_SIZE*LANES-1:0]          exp_lut_sram_data;
    logic                                  exp_lut_sram_en;
    logic [`SRAM_ADDR_WIDTH-1:0]           exp_lut_data_addr;

    logic [`INT16_SIZE*LANES-1:0]          reciprocal_lut_sram_data;
    logic                                  reciprocal_lut_sram_en;
    logic [`SRAM_ADDR_WIDTH-1:0]           reciprocal_lut_data_addr;
    // ------------------------------------------------------------
    // LSU preload and store SRAM ports
    // ------------------------------------------------------------
    logic                        lsu_lut_we;
    logic [`SRAM_ADDR_WIDTH-1:0] lsu_lut_waddr;
    logic [`SRAM_WIDTH_O-1:0]    lsu_lut_wdata;
    logic                        lsu_inst_we;
    logic [`SRAM_ADDR_WIDTH-1:0] lsu_inst_waddr;
    logic [`SRAM_WIDTH_O-1:0]    lsu_inst_wdata;
    logic                        lsu_desc_we;
    logic [`SRAM_ADDR_WIDTH-1:0] lsu_desc_waddr;
    logic [`SRAM_WIDTH_O-1:0]    lsu_desc_wdata;
    // ------------------------------------------------------------
    // Element-wise request/result wires
    // ------------------------------------------------------------
    logic                                  sub_en;
    logic [`INT16_SIZE*LANES-1:0]          sub_data_in;
    logic [`INT16_SIZE*LANES-1:0]          sub_data_out;
    logic                                  sub_valid;

    logic                                  add_en;
    logic [`INT16_SIZE*LANES-1:0]          add_data_in;
    logic [`INT16_SIZE*LANES-1:0]          add_data_out;
    logic                                  add_valid;

    logic [`INT16_SIZE*LANES-1:0]          mul_data_out;
    logic                                  mul_valid;

    logic                                  exp_en;
    logic [`INT16_SIZE*LANES-1:0]          exp_data_in;
    logic [`INT16_SIZE*LANES-1:0]          exp_data_out;
    logic                                  exp_valid;

    logic                                  reciprocal_en;
    logic [`INT16_SIZE*LANES-1:0]          reciprocal_data_in;
    logic [`INT16_SIZE*LANES-1:0]          reciprocal_data_out;
    logic                                  reciprocal_valid;

    // ============================================================
    // FSM Next-State Control
    // ============================================================
    // ------------------------------------------------------------
    // Main frontend FSM
    // ------------------------------------------------------------
    // Sub-phases below keep LUT and tensor DMA sequencing local while
    // preserving one visible top-level state per phase.
    always_comb begin
        state_n = state;
        unique case (state)
            S_IDLE: begin
                if (start_i) state_n = S_LOAD_JOB;
            end
            S_LOAD_JOB: begin
                if (lsu_cmd_issued_r && lsu_complete) state_n = S_LOAD_INST;
            end
            S_LOAD_INST: begin
                if ((load_inst_word_len == '0) || (inst_count_r == '0)) begin
                    state_n = is_last_job_r ? S_STORE_PROFILE : S_DONE;
                end else if (lsu_cmd_issued_r && lsu_complete) begin
                    state_n = S_LOAD_LUT;
                end
            end
            S_LOAD_LUT: begin
                // Exit only after both element-wise LUT loaders finish their local copies.
                if ((lut_phase_r == LUT_WAIT_BOTH) && exp_lut_ready && rcp_lut_ready) begin
                    state_n = (desc_word_len_r == '0) ? S_FETCH_INST
                            : S_LOAD_DESC;
                end
            end
            S_LOAD_DESC: begin
                if ((desc_word_len_r == '0) || (lsu_cmd_issued_r && lsu_complete)) begin
                    state_n = S_FETCH_INST;
                end
            end
            S_LOAD_TENSOR: begin
                if ((inst_tensor_dma_count_r == '0) || !tensor_entry_idx_valid) begin
                    // Treat an out-of-range entry index as complete to avoid table overrun.
                    state_n = S_NEXT_OP;
                end else if (tensor_entry_done &&
                             ((tensor_entry_word_len_from_job == '0) ||
                              !tensor_entry_bank_from_job_valid) &&
                             tensor_entry_is_last) begin
                    // Skipped final entries have no payload_done event to wait for.
                    state_n = S_NEXT_OP;
                end else if (tensor_payload_done && tensor_entry_is_last) begin
                    state_n = S_NEXT_OP;
                end
            end
            S_FETCH_INST: begin
                state_n = S_DECODE_INST;
            end
            S_DECODE_INST: begin
                if (decode_valid_r) begin
                    state_n = (inst_tensor_dma_count_r == '0) ? S_NEXT_OP
                            : S_LOAD_TENSOR;
                end
            end
            S_NEXT_OP: begin
                if (next_op_slot_idx_r >= 3'd4) begin
                    if ((inst_pc_r + 1'b1) < inst_count_r) state_n = S_NEXT_INST;
                    // Last instruction: store only if some completed op latched
                    // a nonzero output length. All-IDLE/zero-length jobs finish here.
                    else if (store_result_valid_r)          state_n = S_STORE_RESULT;
                    else                                      state_n = is_last_job_r ? S_STORE_PROFILE : S_DONE;
                end else if (next_op_needs_desc) begin
                    state_n = S_FETCH_DESC;
                end
            end
            S_FETCH_DESC: begin
                if (fetch_desc_read_pending_r && fetch_desc_last_word) begin
                    state_n = S_SETUP_OP;
                end else if (!next_op_needs_desc) begin
                    state_n = S_NEXT_OP;
                end
            end
            S_SETUP_OP: begin
                if (!setup_op_issue_valid) begin
                    state_n = S_NEXT_OP;
                end else if (op_is_binary_ew(setup_op_context_r.op_code) &&
                             (setup_op_context_r.b_cast != 2'd0)) begin
                    state_n = S_PREP_BCAST;
                end else begin
                    state_n = S_ISSUE_OP;
                end
            end
            S_PREP_BCAST: begin
                if (broadcast_prep_done) begin
                    state_n = S_ISSUE_OP;
                end
            end
            S_ISSUE_OP: begin
                state_n = S_WAIT_OP;
            end
            S_WAIT_OP: begin
                if (op_is_sa(setup_r.op_context.op_code)) begin
                    if (sa_done) state_n = S_NEXT_OP;
                end else if (op_is_ew(setup_r.op_context.op_code)) begin
                    if (ew_done) state_n = S_NEXT_OP;
                end else begin
                    state_n = S_NEXT_OP;
                end
            end
            S_STORE_RESULT: begin
                if (!store_result_valid_r || (lsu_cmd_issued_r && lsu_complete)) begin
                    state_n = is_last_job_r ? S_STORE_PROFILE : S_DONE;
                end
            end
            S_NEXT_INST: begin
                state_n = S_FETCH_INST;
            end
            S_STORE_PROFILE: begin
                if (lsu_cmd_issued_r && lsu_complete) begin
                    state_n = S_DONE;
                end
            end
            S_DONE: begin
                state_n = is_last_job_r ? S_IDLE : S_LOAD_JOB;
            end
            default: begin
                state_n = S_IDLE;
            end
        endcase
    end
    // ------------------------------------------------------------
    // LUT preload sub-phase
    // ------------------------------------------------------------
    always_comb begin
        lut_phase_n = lut_phase_r;

        if (state != S_LOAD_LUT) begin
            lut_phase_n = LUT_DMA_EXP;
        end else begin
            // The LSU command path is shared, so EXP/RCP DMA transfers run one at a time.
            unique case (lut_phase_r)
                LUT_DMA_EXP: begin
                    if (lsu_cmd_issued_r && lsu_complete) lut_phase_n = LUT_DMA_RCP;
                end
                LUT_DMA_RCP: begin
                    if (lsu_cmd_issued_r && lsu_complete) lut_phase_n = LUT_LOAD_BOTH;
                end
                LUT_LOAD_BOTH: begin
                    // EXP/RCP LUT memories are separate, so both internal loaders start together.
                    lut_phase_n = LUT_WAIT_BOTH;
                end
                LUT_WAIT_BOTH: begin
                    if (exp_lut_ready && rcp_lut_ready) lut_phase_n = LUT_DMA_EXP;
                end
                default: begin
                    lut_phase_n = LUT_DMA_EXP;
                end
            endcase
        end
    end
    // ------------------------------------------------------------
    // Tensor DMA sub-phase
    // ------------------------------------------------------------
    always_comb begin
        tensor_phase_n = tensor_phase_r;

        if (state != S_LOAD_TENSOR) begin
            tensor_phase_n = TENSOR_ENTRY;
        end else if (inst_tensor_dma_count_r == '0) begin
            tensor_phase_n = TENSOR_ENTRY;
        end else begin
            unique case (tensor_phase_r)
                TENSOR_ENTRY: begin
                    if (tensor_entry_done) begin
                        // word_len comes from the just-read entry; it does not count down.
                        // Payload DMA is only legal for tensor SRAM banks 0..7.
                        tensor_phase_n = ((tensor_entry_word_len_from_job == '0) ||
                                          !tensor_entry_bank_from_job_valid) ? TENSOR_ENTRY
                                       : TENSOR_PAYLOAD;
                    end
                end
                TENSOR_PAYLOAD: begin
                    if (tensor_payload_done) tensor_phase_n = TENSOR_ENTRY;
                end
                default: begin
                    tensor_phase_n = TENSOR_ENTRY;
                end
            endcase
        end
    end

    // ============================================================
    // Continuous Assigns and Request Muxes
    // ============================================================
    // ------------------------------------------------------------
    // Instruction and descriptor read addresses
    // ------------------------------------------------------------
    assign load_inst_word_len =
        (inst_count_r + INST_PER_WORD - 1) / INST_PER_WORD;
    assign raw_inst = inst_fetch_data[(inst_pc_r % INST_PER_WORD)*INST_BITS +: INST_BITS];
    assign next_op_needs_desc = (next_op_slot_idx_r < 3'd4) ? op_needs_desc(decode_inst_op_slot_r[next_op_slot_idx_r])
                              : 1'b0;
    // ------------------------------------------------------------
    // Tensor DMA entry decode
    // ------------------------------------------------------------
    // Decode the current tensor DMA entry word captured by LSU. These are
    // combinational fields, not remaining-transfer counters.
    assign tensor_entry_bank_from_job =
        lsu_job_wdata[TENSOR_ENTRY_BANK_LSB +: 4];
    assign tensor_entry_dram_base_from_job =
        lsu_job_wdata[TENSOR_ENTRY_DRAM_BASE_LSB +: `DRAM_ADDR_WIDTH];
    assign tensor_entry_word_len_from_job =
        lsu_job_wdata[TENSOR_ENTRY_WORD_LEN_LSB +: `SRAM_ADDR_WIDTH];
    assign tensor_entry_done                = (state == S_LOAD_TENSOR) &&
                                              (tensor_phase_r == TENSOR_ENTRY) &&
                                              lsu_cmd_issued_r && lsu_complete;
    assign tensor_payload_done              = (state == S_LOAD_TENSOR) &&
                                              (tensor_phase_r == TENSOR_PAYLOAD) &&
                                              lsu_cmd_issued_r && lsu_complete;
    assign inst_tensor_entry_count_next    = {1'b0, inst_tensor_entry_count_r} + 16'd1;
    assign inst_tensor_dma_count_ext        = {1'b0, inst_tensor_dma_count_r};
    assign tensor_entry_idx_next            = {1'b0, tensor_entry_idx_r} +
                                              {{`SRAM_ADDR_WIDTH{1'b0}}, 1'b1};
    assign tensor_dma_count_ext             = {1'b0, tensor_dma_count_r};
    assign tensor_entry_idx_valid           = (tensor_entry_idx_r < tensor_dma_count_r) &&
                                              (inst_tensor_entry_count_r < inst_tensor_dma_count_r);
    assign tensor_entry_bank_from_job_valid = (tensor_entry_bank_from_job < 4'd8);
    assign tensor_entry_bank_valid          = (tensor_entry_bank_r < 4'd8);
    assign tensor_entry_is_last             = (inst_tensor_entry_count_next >= inst_tensor_dma_count_ext) ||
                                              (tensor_entry_idx_next >= tensor_dma_count_ext);
    // ------------------------------------------------------------
    // LSU request selection
    // ------------------------------------------------------------
    // LUT DMA is active only during the EXP/RCP transfer phases.
    assign lsu_load_lut = (state == S_LOAD_LUT) &&
                          ((lut_phase_r == LUT_DMA_EXP) || (lut_phase_r == LUT_DMA_RCP));
    assign lsu_load_desc = (state == S_LOAD_DESC) && (desc_word_len_r != '0);
    // Entry reads fetch the DMA control word; payload reads move tensor data.
    assign lsu_load_tensor_entry = (state == S_LOAD_TENSOR) &&
                                   (inst_tensor_dma_count_r != '0) &&
                                   tensor_entry_idx_valid &&
                                   (tensor_phase_r == TENSOR_ENTRY);
    assign lsu_load_tensor_payload = (state == S_LOAD_TENSOR) &&
                                     (inst_tensor_dma_count_r != '0) &&
                                     tensor_entry_idx_valid &&
                                     tensor_entry_bank_valid &&
                                     (tensor_phase_r == TENSOR_PAYLOAD) &&
                                     (tensor_entry_word_len_r != '0);
    assign lsu_load_tensor = lsu_load_tensor_entry || lsu_load_tensor_payload;
    // Result-store latching happens on the real compute done edge, not at
    // SETUP_OP, so the stored bank/base/length describe the op that finished.
    assign wait_op_done = (state == S_WAIT_OP) &&
                             ((op_is_sa(setup_r.op_context.op_code) && sa_done) ||
                              (op_is_ew(setup_r.op_context.op_code) && ew_done));

    // Frontend issues one LSU command at a time for job, instruction,
    // descriptor, tensor, LUT, and result-store transfers.
    assign lsu_valid = ((state == S_LOAD_JOB) ||
                        ((state == S_LOAD_INST) &&
                         (load_inst_word_len != '0) &&
                         (inst_count_r != '0)) ||
                        lsu_load_lut ||
                        lsu_load_desc ||
                        lsu_load_tensor ||
                        ((state == S_STORE_RESULT) && store_result_valid_r) ||
                        (state == S_STORE_PROFILE)) &&
                       !lsu_cmd_issued_r;
    assign lsu_write = (state == S_STORE_RESULT) || (state == S_STORE_PROFILE);

    // LOAD_JOB and tensor entry reads both fetch one control word through
    // the pseudo JOB target; only tensor payload reads use banks 0..7.
    assign lsu_bank = (state == S_LOAD_JOB)     ? LSU_BANK_JOB
                    : (state == S_LOAD_INST)    ? LSU_BANK_INST
                    : (state == S_STORE_RESULT) ? {1'b0, store_result_bank_r}
                    : lsu_load_tensor_entry     ? LSU_BANK_JOB
                    : lsu_load_tensor_payload   ? tensor_entry_bank_r
                    : lsu_load_lut              ? LSU_BANK_LUT
                    : (state == S_STORE_PROFILE) ? 4'd0 // Dummy bank
                    : LSU_BANK_QDESC;

    assign lsu_dram_base = (state == S_LOAD_JOB)        ? (JOB_DRAM_BASE + {{(`DRAM_ADDR_WIDTH-16){1'b0}}, job_idx_r})
                         : (state == S_LOAD_INST)       ? (INST_DRAM_BASE + {{(`DRAM_ADDR_WIDTH-16){1'b0}}, inst_offset_r})
                         : (state == S_STORE_RESULT)    ? job_result_base_r
                         : (state == S_STORE_PROFILE) ? PROFILE_DRAM_BASE
                         : lsu_load_tensor_entry        ? (TENSOR_DMA_TABLE_DRAM_BASE +
                                                           {{(`DRAM_ADDR_WIDTH-`SRAM_ADDR_WIDTH){1'b0}}, tensor_entry_idx_r} + {{(`DRAM_ADDR_WIDTH-16){1'b0}}, dma_offset_r})
                         : lsu_load_tensor_payload      ? tensor_entry_dram_base_r
                         : (state == S_LOAD_DESC)       ? (DESC_DRAM_BASE + {{(`DRAM_ADDR_WIDTH-16){1'b0}}, desc_offset_r})
                         : (lut_phase_r == LUT_DMA_EXP) ? EXP_LUT_DRAM_BASE
                         : RCP_LUT_DRAM_BASE;

    assign lsu_sram_base = (state == S_STORE_RESULT)    ? store_result_sram_base_r
                         : lsu_load_tensor_payload      ? '0
                         : (state == S_LOAD_LUT)        ? ((lut_phase_r == LUT_DMA_EXP) ? EXP_LUT_BASE_ADDR
                                                                                        : RCP_LUT_BASE_ADDR)
                         : '0;

    assign lsu_len = (state == S_LOAD_JOB)     ? {{(`SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1}
                   : (state == S_LOAD_INST)    ? load_inst_word_len
                   : (state == S_STORE_RESULT) ? store_result_words_r
                   : (state == S_STORE_PROFILE) ? {{(`SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1}
                   : lsu_load_tensor_entry     ? {{(`SRAM_ADDR_WIDTH-1){1'b0}}, 1'b1}
                   : lsu_load_tensor_payload   ? tensor_entry_word_len_r
                   : (state == S_LOAD_DESC)    ? desc_word_len_r
                   : LUT_WORD_NUM;

    // Muxing write data going out to dram
    assign dram_wr_data = (state == S_STORE_PROFILE) ? { {(`SRAM_WIDTH_O - 128){1'b0}}, total_cycles_r, ew_cycles_r, sa_cycles_r, dram_cycles_r } : lsu_dram_wr_data;

    // Pulse both element-wise LUT loaders once after both SRAM regions have been filled.
    assign exp_load_npu        = (state == S_LOAD_LUT) && (lut_phase_r == LUT_LOAD_BOTH);
    assign reciprocal_load_npu = (state == S_LOAD_LUT) && (lut_phase_r == LUT_LOAD_BOTH);

    assign inst_fetch_en   = (state == S_FETCH_INST);
    assign inst_fetch_addr = inst_pc_r / INST_PER_WORD;
    assign fetch_desc_en   = (state == S_FETCH_DESC) && !fetch_desc_read_pending_r && next_op_needs_desc;
    assign fetch_desc_addr = next_op_desc_idx_r + fetch_desc_word_idx_r;
    assign fetch_desc_last_word =
        (fetch_desc_word_idx_r == (DESC_WORDS_PER_PACKET - 1));

    always_comb begin
        fetch_desc_packet_complete = fetch_desc_packet_r;
        fetch_desc_packet_complete[
            fetch_desc_word_idx_r*`SRAM_WIDTH_O +: `SRAM_WIDTH_O
        ] = fetch_desc_data;
    end
    // ------------------------------------------------------------
    // Issue and runtime config aliases
    // ------------------------------------------------------------
    // ISSUE_OP is a one-cycle launch point. WAIT_OP keeps descriptor-backed
    // config stable while the selected compute engine is running.
    assign setup_op_issue_valid = (tensor_dma_count_r != '0) &&
                               ((op_is_sa(setup_op_context_r.op_code) &&
                                 (decoded_desc.m != '0) &&
                                 (decoded_desc.n != '0) &&
                                 (decoded_desc.k != '0)) ||
                                (op_is_ew(setup_op_context_r.op_code) && (decoded_desc.total_words != '0)));
    assign issue_op_valid   = (state == S_ISSUE_OP);
    assign issue_op_code = setup_r.op_context.op_code;

    assign cfg_m                       = setup_r.desc.m[CFG_M_WIDTH-1:0];
    assign cfg_k                       = setup_r.desc.k[CFG_K_WIDTH-1:0];
    assign cfg_n                       = setup_r.desc.n[CFG_N_WIDTH-1:0];
    assign cfg_total_words             = setup_r.desc.total_words[2*CFG_M_WIDTH:0];
    assign cfg_src0_bank               = setup_r.desc.src0_bank;
    assign cfg_src1_bank               = setup_r.desc.src1_bank;
    assign cfg_dst_bank                = setup_r.desc.dst_bank;
    // Compiler selector contract: 1 expands EW src1/input2, 2 expands EW src0/input1.
    assign cfg_ew_src0_broadcast       = (setup_r.op_context.b_cast == 2'd2);
    assign cfg_ew_src1_broadcast       = (setup_r.op_context.b_cast == 2'd1);

    assign broadcast_prep_src_bank = (setup_op_context_r.b_cast == 2'd2) ? decoded_desc.src0_bank
                                   : decoded_desc.src1_bank;
    assign broadcast_prep_n = decoded_desc.n;
    assign broadcast_prep_count = decoded_desc.broadcast_count;
    assign broadcast_prep_start =
        (state == S_SETUP_OP) && setup_op_issue_valid &&
        op_is_binary_ew(setup_op_context_r.op_code) &&
        (setup_op_context_r.b_cast != 2'd0);
    assign broadcast_runtime_read_en = load_sram_en &&
                                       (cfg_ew_src0_broadcast || cfg_ew_src1_broadcast);
    assign broadcast_runtime_word_col_idx =
        ew_broadcast_word_in_row[WORD_COL_IDX_WIDTH-1:0];

    assign ctrl_busy = (state != S_IDLE) && ((state != S_DONE) || !is_last_job_r);
    assign done_o    = (state == S_DONE) && is_last_job_r;
    assign busy_o    = sa_busy | ctrl_busy;
    // ------------------------------------------------------------
    // SA launch and output address
    // ------------------------------------------------------------
    assign sa_words_per_row = (cfg_n + LANES - 1) / LANES;
    assign sa_waddr        = sa_out_addr_y_i16 * sa_words_per_row + sa_out_addr_x_i16;
    // ------------------------------------------------------------
    // INT8 valid reduction
    // ------------------------------------------------------------
    assign sa_input_data_valid_to_sa =
        (&sa_data_requant_output_valid) & (&sa_weight_requant_output_valid);
    assign mul_input_valid = (&mul_in1_requant_output_valid) & (&mul_in2_requant_output_valid);
    // ------------------------------------------------------------
    // Tensor SRAM read/write mux
    // ------------------------------------------------------------
    // Ops are scheduled sequentially, so EW reuses src0 for the previous
    // result while SA uses src0/src1 for data/weight.
    assign ew_src1_ren  = load_sram_en;
    assign ew_src1_addr = load_sram_addr;

    assign ew_src1_data_selected = cfg_ew_src1_broadcast ? broadcast_runtime_read_data
                                 : tensor_src1_data;

    // Broadcast preparation temporarily owns the selected source port.
    // Runtime broadcast data comes from the prepared row buffer, so that
    // source SRAM port is disabled while the other binary operand still reads.
    assign tensor_src0_bank  = (broadcast_prep_busy && cfg_ew_src0_broadcast) ? broadcast_prep_read_bank
                             : lsu_store_sram_ren                             ? lsu_store_sram_bank
                             : cfg_src0_bank;
    assign tensor_src0_ren   = (broadcast_prep_busy && cfg_ew_src0_broadcast) ? broadcast_prep_read_en
                             : (lsu_store_sram_ren |
                                (load_sram_en && !cfg_ew_src0_broadcast) |
                                sa_sram_req_valid);
    assign tensor_src0_addr  = (broadcast_prep_busy && cfg_ew_src0_broadcast) ? broadcast_prep_read_addr
                             : lsu_store_sram_ren                             ? lsu_store_sram_addr
                             : load_sram_en                                   ? load_sram_addr
                             : sa_data_addr;

    assign tensor_src1_bank  = (broadcast_prep_busy && cfg_ew_src1_broadcast) ? broadcast_prep_read_bank
                             : cfg_src1_bank;
    assign tensor_src1_ren   = (broadcast_prep_busy && cfg_ew_src1_broadcast) ? broadcast_prep_read_en
                             : ((ew_src1_ren && !cfg_ew_src1_broadcast) |
                                sa_sram_req_valid);
    assign tensor_src1_addr  = (broadcast_prep_busy && cfg_ew_src1_broadcast) ? broadcast_prep_read_addr
                             : ew_src1_ren                                    ? ew_src1_addr
                             : sa_weight_addr;
    assign tensor_compute_we = ew_we | sa_out_valid_i16;
    assign tensor_dst_bank   = tensor_compute_we ? cfg_dst_bank
                             : lsu_bank_wbank;
    assign tensor_dst_we     = tensor_compute_we | lsu_bank_we;
    assign tensor_dst_waddr  = tensor_compute_we ? (ew_we ? ew_waddr
                                                          : sa_waddr)
                             : lsu_bank_waddr;
    assign tensor_dst_wdata  = tensor_compute_we ? (ew_we ? ew_wdata
                                                          : sa_out_data_i16)
                             : lsu_bank_wdata;
    assign sa_input_data_raw  = tensor_src0_data;
    assign sa_weight_data_raw = tensor_src1_data;
    assign load_sram_rdata = cfg_ew_src0_broadcast ? broadcast_runtime_read_data
                           : tensor_src0_data;
    assign broadcast_prep_read_data = cfg_ew_src0_broadcast ? tensor_src0_data
                                    : tensor_src1_data;

    // ============================================================
    // Clocked Registers
    // ============================================================
    // ------------------------------------------------------------
    // Frontend state registers and side effects
    // ------------------------------------------------------------
    // setup_r groups descriptor-backed runtime config for reset and launch updates.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            lut_phase_r <= LUT_DMA_EXP;
            tensor_phase_r <= TENSOR_ENTRY;
            lsu_cmd_issued_r <= 1'b0;
            inst_pc_r <= '0;
            inst_count_r <= '0;
            desc_word_len_r <= '0;
            tensor_dma_count_r <= '0;
            inst_tensor_dma_count_r <= '0;
            inst_tensor_entry_count_r <= '0;
            tensor_entry_idx_r <= '0;
            tensor_entry_bank_r <= '0;
            tensor_entry_dram_base_r <= '0;
            tensor_entry_word_len_r <= '0;
            decode_valid_r <= 1'b0;
            for (int op_i = 0; op_i < 4; op_i = op_i + 1) begin
                decode_inst_op_slot_r[op_i] <= '0;
                decode_inst_b_cast_slot_r[op_i] <= '0;
            end
            decode_inst_base_desc_idx_r <= '0;
            next_op_slot_idx_r <= '0;
            next_op_desc_idx_r <= '0;
            fetch_desc_read_pending_r <= 1'b0;
            fetch_desc_word_idx_r <= '0;
            fetch_desc_packet_r <= '0;
            fetch_desc_context_r <= '0;
            setup_op_context_r <= '0;
            setup_op_desc_data_r <= '0;
            setup_op_desc_valid_r <= 1'b0;
            setup_r <= '0;
            store_result_valid_r <= 1'b0;
            store_result_bank_r <= '0;
            store_result_sram_base_r <= '0;
            store_result_words_r <= '0;

            dram_cycles_r <= '0;
            sa_cycles_r   <= '0;
            ew_cycles_r   <= '0;
            total_cycles_r <= '0;

        end else begin
            state <= state_n;
            lut_phase_r <= lut_phase_n;
            tensor_phase_r <= tensor_phase_n;

            if (state == S_IDLE && state_n == S_LOAD_JOB) begin
                dram_cycles_r <= '0;
                sa_cycles_r   <= '0;
                ew_cycles_r   <= '0;
                total_cycles_r <= '0;
            end else begin
                total_cycles_r <= total_cycles_r + 1'b1;
                if (lsu_busy_sig)
                    dram_cycles_r <= dram_cycles_r + 1'b1;
                if (sa_busy)
                    sa_cycles_r   <= sa_cycles_r + 1'b1;
                if ((state == S_WAIT_OP) && op_is_ew(setup_r.op_context.op_code))
                    ew_cycles_r   <= ew_cycles_r + 1'b1;
            end

            // Reset command flag when profile store completes
            if (state == S_STORE_PROFILE && lsu_cmd_issued_r && lsu_complete) begin 
                lsu_cmd_issued_r <= 1'b0; 
            end

            if ((state == S_IDLE && state_n == S_LOAD_JOB) || (state == S_DONE && state_n == S_LOAD_JOB)) begin
                if (state == S_IDLE) job_idx_r <= '0;
                else                 job_idx_r <= job_idx_r + 1'b1;
                lsu_cmd_issued_r <= 1'b0;
                inst_pc_r <= '0;
                inst_count_r <= '0;
                desc_word_len_r <= '0;
                tensor_dma_count_r <= '0;
                inst_tensor_dma_count_r <= '0;
                inst_tensor_entry_count_r <= '0;
                tensor_entry_idx_r <= '0;
                tensor_entry_bank_r <= '0;
                tensor_entry_dram_base_r <= '0;
                tensor_entry_word_len_r <= '0;
                decode_valid_r <= 1'b0;
                for (int op_i = 0; op_i < 4; op_i = op_i + 1) begin
                    decode_inst_op_slot_r[op_i] <= '0;
                    decode_inst_b_cast_slot_r[op_i] <= '0;
                end
                decode_inst_base_desc_idx_r <= '0;
                next_op_slot_idx_r <= '0;
                next_op_desc_idx_r <= '0;
                fetch_desc_read_pending_r <= 1'b0;
                fetch_desc_word_idx_r <= '0;
                fetch_desc_packet_r <= '0;
                fetch_desc_context_r <= '0;
                setup_op_context_r <= '0;
                setup_op_desc_data_r <= '0;
                setup_op_desc_valid_r <= 1'b0;
                setup_r <= '0;
                store_result_valid_r <= 1'b0;
                store_result_bank_r <= '0;
                store_result_sram_base_r <= '0;
                store_result_words_r <= '0;
            end else if (state == S_LOAD_JOB && state_n == S_LOAD_INST) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if (state == S_LOAD_INST && state_n == S_LOAD_LUT) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if ((state == S_LOAD_LUT) &&
                         ((lut_phase_r == LUT_DMA_EXP) || (lut_phase_r == LUT_DMA_RCP)) &&
                         lsu_cmd_issued_r && lsu_complete) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if ((state == S_LOAD_LUT) &&
                         ((state_n == S_LOAD_DESC) || (state_n == S_FETCH_INST))) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if (state == S_LOAD_DESC && state_n == S_FETCH_INST) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if (tensor_entry_done || tensor_payload_done) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if (state == S_STORE_RESULT && lsu_cmd_issued_r && lsu_complete) begin
                lsu_cmd_issued_r <= 1'b0;
            end else if (lsu_valid && lsu_ready) begin
                lsu_cmd_issued_r <= 1'b1;
            end

            if (lsu_job_we && (state == S_LOAD_JOB)) begin
                // LOAD_JOB unpacks counts from fixed bit offsets in the job word.
                inst_count_r <= lsu_job_wdata[JOB_INST_COUNT_LSB +: (`SRAM_ADDR_WIDTH+4)];
                desc_word_len_r <= lsu_job_wdata[JOB_DESC_WORD_LEN_LSB +: `SRAM_ADDR_WIDTH];
                tensor_dma_count_r <= lsu_job_wdata[JOB_TENSOR_DMA_COUNT_LSB +: `SRAM_ADDR_WIDTH];
                // Additions for job tracking
                is_last_job_r           <= lsu_job_wdata[JOB_IS_LAST_LSB];
                job_result_base_r       <= lsu_job_wdata[JOB_RESULT_BASE_LSB      +: `DRAM_ADDR_WIDTH];
                inst_offset_r           <= lsu_job_wdata[JOB_INST_OFFSET_LSB      +: 16];
                desc_offset_r           <= lsu_job_wdata[JOB_DESC_OFFSET_LSB      +: 16];
                dma_offset_r            <= lsu_job_wdata[JOB_DMA_OFFSET_LSB       +: 16];

            end else if (lsu_job_we && (state == S_LOAD_TENSOR) && (tensor_phase_r == TENSOR_ENTRY)) begin
                // The entry word is read through the job capture path, then latched
                // for the following payload DMA command.
                tensor_entry_bank_r <= tensor_entry_bank_from_job;
                tensor_entry_dram_base_r <= tensor_entry_dram_base_from_job;
                tensor_entry_word_len_r <= tensor_entry_word_len_from_job;
                if ((tensor_entry_word_len_from_job == '0) || !tensor_entry_bank_from_job_valid) begin
                    // Skip entries that do not issue payload DMA.
                    tensor_entry_idx_r <= tensor_entry_idx_r + 1'b1;
                    inst_tensor_entry_count_r <= inst_tensor_entry_count_r + 1'b1;
                end
            end

            if (tensor_payload_done) begin
                tensor_entry_idx_r <= tensor_entry_idx_r + 1'b1;
                inst_tensor_entry_count_r <= inst_tensor_entry_count_r + 1'b1;
            end

            setup_op_desc_valid_r <= 1'b0;
            setup_r.valid <= 1'b0;

            if (wait_op_done) begin
                // Store the most recent completed op as the final result candidate.
                // total_words==0 means there is no meaningful payload to copy back.
                store_result_valid_r <= (setup_r.desc.total_words != '0);
                store_result_bank_r <= setup_r.desc.dst_bank;
                store_result_sram_base_r <= setup_r.desc.dst_word_base;
                store_result_words_r <= setup_r.desc.total_words[`SRAM_ADDR_WIDTH-1:0];
            end

            if (state == S_DECODE_INST) begin
                if (!decode_valid_r) begin
                    for (int op_i = 0; op_i < 4; op_i = op_i + 1) begin
                        decode_inst_op_slot_r[op_i] <= decoded_op[op_i*4 +: 4];
                        decode_inst_b_cast_slot_r[op_i] <= decoded_b_cast[op_i*2 +: 2];
                    end
                    decode_inst_base_desc_idx_r <= decoded_dsc_idx;
                    inst_tensor_dma_count_r <= decoded_inst_reserved;
                    inst_tensor_entry_count_r <= '0;
                    next_op_slot_idx_r <= '0;
                    next_op_desc_idx_r <= decoded_dsc_idx;
                    fetch_desc_read_pending_r <= 1'b0;
                    fetch_desc_word_idx_r <= '0;
                    fetch_desc_packet_r <= '0;
                    setup_op_desc_valid_r <= 1'b0;
                    decode_valid_r <= 1'b1;
                end else begin
                    decode_valid_r <= 1'b0;
                end
            end

            if (state == S_NEXT_OP) begin
                if ((next_op_slot_idx_r < 3'd4) && !next_op_needs_desc) begin
                    // IDLE or unsupported op does not consume a descriptor.
                    next_op_slot_idx_r <= next_op_slot_idx_r + 3'd1;
                end

                if (state_n == S_NEXT_INST) begin
                    inst_pc_r <= inst_pc_r + 1'b1;
                end
            end

            if (state == S_FETCH_DESC) begin
                if (fetch_desc_read_pending_r) begin
                    // fetch_desc_data returns one cycle after fetch_desc_en/address.
                    fetch_desc_packet_r[
                        fetch_desc_word_idx_r*`SRAM_WIDTH_O +: `SRAM_WIDTH_O
                    ] <= fetch_desc_data;
                    fetch_desc_read_pending_r <= 1'b0;
                    if (fetch_desc_last_word) begin
                        setup_op_context_r <= fetch_desc_context_r;
                        setup_op_desc_data_r <=
                            fetch_desc_packet_complete[`DESC_PACKET_BITS-1:0];
                        setup_op_desc_valid_r <= 1'b1;
                        next_op_slot_idx_r <= fetch_desc_context_r.op_idx + 3'd1;
                        next_op_desc_idx_r <=
                            fetch_desc_context_r.desc_idx + DESC_WORDS_PER_PACKET;
                        fetch_desc_word_idx_r <= '0;
                    end else begin
                        fetch_desc_word_idx_r <= fetch_desc_word_idx_r + 1'b1;
                    end
                end else if (next_op_needs_desc) begin
                    // Issue one descriptor read for the current active op.
                    fetch_desc_read_pending_r <= 1'b1;
                    if (fetch_desc_word_idx_r == '0) begin
                        fetch_desc_packet_r <= '0;
                    end
                    fetch_desc_context_r.op_idx <= next_op_slot_idx_r;
                    fetch_desc_context_r.desc_idx <= next_op_desc_idx_r;
                    fetch_desc_context_r.op_code <= decode_inst_op_slot_r[next_op_slot_idx_r];
                    fetch_desc_context_r.b_cast <= decode_inst_b_cast_slot_r[next_op_slot_idx_r];
                end
            end

            if (state == S_SETUP_OP) begin
                setup_r.valid <= 1'b1;
                setup_r.op_context <= setup_op_context_r;
                setup_r.desc <= decoded_desc;
            end
            if (state == S_DONE && state_n == S_IDLE) begin
                lsu_cmd_issued_r <= 1'b0;
                inst_tensor_dma_count_r <= '0;
                inst_tensor_entry_count_r <= '0;
                decode_valid_r <= 1'b0;
                for (int op_i = 0; op_i < 4; op_i = op_i + 1) begin
                    decode_inst_op_slot_r[op_i] <= '0;
                    decode_inst_b_cast_slot_r[op_i] <= '0;
                end
                decode_inst_base_desc_idx_r <= '0;
                next_op_slot_idx_r <= '0;
                next_op_desc_idx_r <= '0;
                fetch_desc_read_pending_r <= 1'b0;
                fetch_desc_word_idx_r <= '0;
                fetch_desc_packet_r <= '0;
                fetch_desc_context_r <= '0;
                setup_op_context_r <= '0;
                setup_op_desc_data_r <= '0;
                setup_op_desc_valid_r <= 1'b0;
                setup_r <= '0;
                store_result_valid_r <= 1'b0;
                store_result_bank_r <= '0;
                store_result_sram_base_r <= '0;
                store_result_words_r <= '0;
            end
        end
    end
    // ------------------------------------------------------------
    // SA launch register
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) sa_start_i <= 1'b0;
        else        sa_start_i <= issue_op_valid && op_is_sa(issue_op_code);
    end
    // ------------------------------------------------------------
    // SA/MUL requant input staging
    // ------------------------------------------------------------
    // Match the 1-cycle SRAM read latency before feeding SA requantization.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sa_requant_input_valid <= 1'b0;
        end else begin
            sa_requant_input_valid <= sa_sram_req_valid;
        end
    end

    // Track the requested word column so either prepared operand repeats from
    // word zero at each logical row boundary.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ew_broadcast_word_in_row <= '0;
            ew_broadcast_words_per_row <= {{CFG_N_WIDTH{1'b0}}, 1'b1};
        end else if (issue_op_valid && op_is_ew(issue_op_code)) begin
            ew_broadcast_word_in_row <= '0;
            ew_broadcast_words_per_row <= (((cfg_n + (LANES-1)) / LANES) == 0) ? {{CFG_N_WIDTH{1'b0}}, 1'b1}
                                         : ((cfg_n + (LANES-1)) / LANES);
        end else if (load_sram_en &&
                     (cfg_ew_src0_broadcast || cfg_ew_src1_broadcast)) begin
            if ((ew_broadcast_word_in_row + 1'b1) >= ew_broadcast_words_per_row) begin
                ew_broadcast_word_in_row <= '0;
            end else begin
                ew_broadcast_word_in_row <= ew_broadcast_word_in_row + 1'b1;
            end
        end
    end

    // ============================================================
    // Generate Blocks
    // ============================================================
    // ------------------------------------------------------------
    // Generate indices
    // ------------------------------------------------------------
    genvar gi;
    // ------------------------------------------------------------
    // Lane extension and requantization
    // ------------------------------------------------------------
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : EXTEND_INPUTS
            // SA input and weight paths.
            assign sa_data_lane_32[gi] = {{(`INT32_SIZE-`INT16_SIZE){sa_input_data_raw [(gi+1)*`INT16_SIZE-1]}},
                                        sa_input_data_raw [(gi+1)*`INT16_SIZE-1 -: `INT16_SIZE]};

            assign sa_weight_lane_32[gi] = {{(`INT32_SIZE-`INT16_SIZE){sa_weight_data_raw[(gi+1)*`INT16_SIZE-1]}},
                                        sa_weight_data_raw[(gi+1)*`INT16_SIZE-1 -: `INT16_SIZE]};
            // MUL input paths.
            assign mul_in1_lane_32[gi] = {{(`INT32_SIZE-`INT16_SIZE){mul_data_in[(gi+1)*`INT16_SIZE-1]}},
                                        mul_data_in[(gi+1)*`INT16_SIZE-1 -: `INT16_SIZE]};
            assign mul_in2_lane_32[gi] = {{(`INT32_SIZE-`INT16_SIZE){ew_src1_data_selected[(gi+1)*`INT16_SIZE-1]}},
                                        ew_src1_data_selected[(gi+1)*`INT16_SIZE-1 -: `INT16_SIZE]};
        end
    endgenerate
    // ------------------------------------------------------------
    // INT8 lane packing
    // ------------------------------------------------------------
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : PACK_Q8
            assign sa_input_data_q8[(gi+1)*`INT8_SIZE-1 -: `INT8_SIZE] =
                clamp_to_int8(
                    sa_data_requant_out32[gi],
                    $signed(setup_r.desc.conv_input_requant_offset),
                    $signed(setup_r.desc.conv_input_activation_min),
                    $signed(setup_r.desc.conv_input_activation_max)
                );

            assign sa_weight_data_q8[(gi+1)*`INT8_SIZE-1 -: `INT8_SIZE] =
                clamp_to_int8(
                    sa_weight_requant_out32[gi],
                    $signed(setup_r.desc.conv_weight_requant_offset),
                    $signed(setup_r.desc.conv_weight_activation_min),
                    $signed(setup_r.desc.conv_weight_activation_max)
                );
            assign mul_in1_data_q8[(gi+1)*`INT8_SIZE-1 -: `INT8_SIZE] =
                clamp_to_int8(
                    mul_in1_requant_out32[gi],
                    $signed(setup_r.desc.mul_in1_requant_offset),
                    $signed(setup_r.desc.mul_in1_activation_min),
                    $signed(setup_r.desc.mul_in1_activation_max)
                );
            assign mul_in2_data_q8[(gi+1)*`INT8_SIZE-1 -: `INT8_SIZE] =
                clamp_to_int8(
                    mul_in2_requant_out32[gi],
                    $signed(setup_r.desc.mul_in2_requant_offset),
                    $signed(setup_r.desc.mul_in2_activation_min),
                    $signed(setup_r.desc.mul_in2_activation_max)
                );
        end
    endgenerate
    // ------------------------------------------------------------
    // INT8 requantization instances
    // ------------------------------------------------------------
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : DATA_REQUANT

            MultiplyByQuantizedMultiplier u_data_requant (
                .clk                        (clk),
                .rst                        (rst_n),   // Active-low reset input.
                .x                          (sa_data_lane_32[gi]),
                .quantized_multiplier       ($signed(setup_r.desc.conv_input_requant_multiplier)),
                .shift                      ($signed(setup_r.desc.conv_input_requant_shift)),
                .input_valid                (sa_requant_input_valid),
                .output_valid               (sa_data_requant_output_valid[gi]),
                .x_mul_by_quantized_multiplier(sa_data_requant_out32[gi])
            );

        end
    endgenerate

    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : WEIGHT_REQUANT

            MultiplyByQuantizedMultiplier u_weight_requant (
                .clk                        (clk),
                .rst                        (rst_n),
                .x                          (sa_weight_lane_32[gi]),
                .quantized_multiplier       ($signed(setup_r.desc.conv_weight_requant_multiplier)),
                .shift                      ($signed(setup_r.desc.conv_weight_requant_shift)),
                .input_valid                (sa_requant_input_valid),
                .output_valid               (sa_weight_requant_output_valid[gi]),
                .x_mul_by_quantized_multiplier(sa_weight_requant_out32[gi])
            );

        end
    endgenerate

    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : MUL_IN1_REQUANT

            MultiplyByQuantizedMultiplier u_mul_in1_requant (
                .clk                        (clk),
                .rst                        (rst_n),
                .x                          (mul_in1_lane_32[gi]),
                .quantized_multiplier       ($signed(setup_r.desc.mul_in1_requant_multiplier)),
                .shift                      ($signed(setup_r.desc.mul_in1_requant_shift)),
                .input_valid                (mul_en),
                .output_valid               (mul_in1_requant_output_valid[gi]),
                .x_mul_by_quantized_multiplier(mul_in1_requant_out32[gi])
            );

        end
    endgenerate

    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : MUL_IN2_REQUANT

            MultiplyByQuantizedMultiplier u_mul_in2_requant (
                .clk                        (clk),
                .rst                        (rst_n),
                .x                          (mul_in2_lane_32[gi]),
                .quantized_multiplier       ($signed(setup_r.desc.mul_in2_requant_multiplier)),
                .shift                      ($signed(setup_r.desc.mul_in2_requant_shift)),
                .input_valid                (mul_en),
                .output_valid               (mul_in2_requant_output_valid[gi]),
                .x_mul_by_quantized_multiplier(mul_in2_requant_out32[gi])
            );

        end
    endgenerate

    // ============================================================
    // Submodule Instances
    // ============================================================
    // ------------------------------------------------------------
    // Broadcast preparation and runtime row lookup
    // ------------------------------------------------------------
    broadcast_unit #(
        .LANES(LANES),
        .MAX_BROADCAST_N(MAX_BROADCAST_N),
        .WORD_COL_IDX_WIDTH(WORD_COL_IDX_WIDTH)
    ) u_broadcast_unit (
        .clk(clk),
        .rst_n(rst_n),
        .clear_i(state == S_DONE),
        .start_i(broadcast_prep_start),
        .prep_src_bank_i(broadcast_prep_src_bank),
        .prep_n_i(broadcast_prep_n),
        .prep_count_i(broadcast_prep_count),
        .prep_busy_o(broadcast_prep_busy),
        .prep_done_o(broadcast_prep_done),
        .prep_read_en_o(broadcast_prep_read_en),
        .prep_read_bank_o(broadcast_prep_read_bank),
        .prep_read_addr_o(broadcast_prep_read_addr),
        .prep_read_data_i(broadcast_prep_read_data),
        .runtime_read_en_i(broadcast_runtime_read_en),
        .runtime_word_col_idx_i(broadcast_runtime_word_col_idx),
        .runtime_read_data_o(broadcast_runtime_read_data)
    );

    // ------------------------------------------------------------
    // Instruction and descriptor decoders
    // ------------------------------------------------------------
    op_decoder u_op_decoder (
        .inst_i(raw_inst),
        .op_o(decoded_op),
        .reserved_o(decoded_inst_reserved),
        .b_cast_o(decoded_b_cast),
        .dsc_idx_o(decoded_dsc_idx)
    );

    desc_decoder u_desc_decoder (
        .desc_i(setup_op_desc_data_r),
        .header_o(decoded_desc.header),
        .reserved_o(decoded_desc.reserved),
        .version_o(decoded_desc.version),
        .op_slot_o(decoded_desc.op_slot),
        .op_code_o(decoded_desc.op_code),
        .m_o(decoded_desc.m),
        .n_o(decoded_desc.n),
        .k_o(decoded_desc.k),
        .data_count_o(decoded_desc.data_count),
        .src1_count_o(decoded_desc.src1_count),
        .total_words_o(decoded_desc.total_words),
        .broadcast_count_o(decoded_desc.broadcast_count),
        .src0_bank_o(decoded_desc.src0_bank),
        .src0_word_base_o(decoded_desc.src0_word_base),
        .src1_bank_o(decoded_desc.src1_bank),
        .src1_word_base_o(decoded_desc.src1_word_base),
        .dst_bank_o(decoded_desc.dst_bank),
        .dst_word_base_o(decoded_desc.dst_word_base),
        .conv_stride_h_o(decoded_desc.conv_stride_h),
        .conv_stride_w_o(decoded_desc.conv_stride_w),
        .conv_padding_o(decoded_desc.conv_padding),
        .conv_batch_o(decoded_desc.conv_batch),
        .conv_img_row_o(decoded_desc.conv_img_row),
        .conv_img_col_o(decoded_desc.conv_img_col),
        .conv_in_channel_o(decoded_desc.conv_in_channel),
        .conv_out_channel_o(decoded_desc.conv_out_channel),
        .conv_ker_row_o(decoded_desc.conv_ker_row),
        .conv_ker_col_o(decoded_desc.conv_ker_col),
        .conv_requant_multiplier_o(decoded_desc.conv_requant_multiplier),
        .conv_requant_shift_o(decoded_desc.conv_requant_shift),
        .conv_requant_output_offset_o(decoded_desc.conv_requant_output_offset),
        .conv_activation_min_o(decoded_desc.conv_activation_min),
        .conv_activation_max_o(decoded_desc.conv_activation_max),
        .conv_input_requant_multiplier_o(decoded_desc.conv_input_requant_multiplier),
        .conv_input_requant_shift_o(decoded_desc.conv_input_requant_shift),
        .conv_input_requant_offset_o(decoded_desc.conv_input_requant_offset),
        .conv_input_activation_min_o(decoded_desc.conv_input_activation_min),
        .conv_input_activation_max_o(decoded_desc.conv_input_activation_max),
        .conv_weight_requant_multiplier_o(decoded_desc.conv_weight_requant_multiplier),
        .conv_weight_requant_shift_o(decoded_desc.conv_weight_requant_shift),
        .conv_weight_requant_offset_o(decoded_desc.conv_weight_requant_offset),
        .conv_weight_activation_min_o(decoded_desc.conv_weight_activation_min),
        .conv_weight_activation_max_o(decoded_desc.conv_weight_activation_max),
        .exp_deq_input_range_radius_o(decoded_desc.exp_deq_input_range_radius),
        .exp_deq_input_zero_point_o(decoded_desc.exp_deq_input_zero_point),
        .exp_deq_input_multiplier_o(decoded_desc.exp_deq_input_multiplier),
        .exp_deq_input_left_shift_o(decoded_desc.exp_deq_input_left_shift),
        .exp_req_input_quantized_multiplier_o(decoded_desc.exp_req_input_quantized_multiplier),
        .exp_req_input_shift_o(decoded_desc.exp_req_input_shift),
        .exp_req_input_offset_o(decoded_desc.exp_req_input_offset),
        .rcp_deq_input_range_radius_o(decoded_desc.rcp_deq_input_range_radius),
        .rcp_deq_input_zero_point_o(decoded_desc.rcp_deq_input_zero_point),
        .rcp_deq_input_multiplier_o(decoded_desc.rcp_deq_input_multiplier),
        .rcp_deq_input_left_shift_o(decoded_desc.rcp_deq_input_left_shift),
        .rcp_req_input_quantized_multiplier_o(decoded_desc.rcp_req_input_quantized_multiplier),
        .rcp_req_input_shift_o(decoded_desc.rcp_req_input_shift),
        .rcp_req_input_offset_o(decoded_desc.rcp_req_input_offset),
        .add_input1_offset_o(decoded_desc.add_input1_offset),
        .add_input2_offset_o(decoded_desc.add_input2_offset),
        .add_left_shift_o(decoded_desc.add_left_shift),
        .add_input1_multiplier_o(decoded_desc.add_input1_multiplier),
        .add_input2_multiplier_o(decoded_desc.add_input2_multiplier),
        .add_input1_shift_o(decoded_desc.add_input1_shift),
        .add_input2_shift_o(decoded_desc.add_input2_shift),
        .add_output_multiplier_o(decoded_desc.add_output_multiplier),
        .add_output_shift_o(decoded_desc.add_output_shift),
        .add_output_offset_o(decoded_desc.add_output_offset),
        .add_activation_min_o(decoded_desc.add_activation_min),
        .add_activation_max_o(decoded_desc.add_activation_max),
        .sub_input1_offset_o(decoded_desc.sub_input1_offset),
        .sub_input2_offset_o(decoded_desc.sub_input2_offset),
        .sub_left_shift_o(decoded_desc.sub_left_shift),
        .sub_input1_multiplier_o(decoded_desc.sub_input1_multiplier),
        .sub_input2_multiplier_o(decoded_desc.sub_input2_multiplier),
        .sub_input1_shift_o(decoded_desc.sub_input1_shift),
        .sub_input2_shift_o(decoded_desc.sub_input2_shift),
        .sub_output_multiplier_o(decoded_desc.sub_output_multiplier),
        .sub_output_shift_o(decoded_desc.sub_output_shift),
        .sub_output_offset_o(decoded_desc.sub_output_offset),
        .sub_activation_min_o(decoded_desc.sub_activation_min),
        .sub_activation_max_o(decoded_desc.sub_activation_max),
        .mul_input1_offset_o(decoded_desc.mul_input1_offset),
        .mul_input2_offset_o(decoded_desc.mul_input2_offset),
        .mul_output_multiplier_o(decoded_desc.mul_output_multiplier),
        .mul_output_shift_o(decoded_desc.mul_output_shift),
        .mul_output_offset_o(decoded_desc.mul_output_offset),
        .mul_activation_min_o(decoded_desc.mul_activation_min),
        .mul_activation_max_o(decoded_desc.mul_activation_max),
        .mul_in1_requant_multiplier_o(decoded_desc.mul_in1_requant_multiplier),
        .mul_in1_requant_shift_o(decoded_desc.mul_in1_requant_shift),
        .mul_in1_requant_offset_o(decoded_desc.mul_in1_requant_offset),
        .mul_in1_activation_min_o(decoded_desc.mul_in1_activation_min),
        .mul_in1_activation_max_o(decoded_desc.mul_in1_activation_max),
        .mul_in2_requant_multiplier_o(decoded_desc.mul_in2_requant_multiplier),
        .mul_in2_requant_shift_o(decoded_desc.mul_in2_requant_shift),
        .mul_in2_requant_offset_o(decoded_desc.mul_in2_requant_offset),
        .mul_in2_activation_min_o(decoded_desc.mul_in2_activation_min),
        .mul_in2_activation_max_o(decoded_desc.mul_in2_activation_max)
    );
    // ------------------------------------------------------------
    // Systolic array instance
    // ------------------------------------------------------------
    SystolicArray_OS_INT8_REQUANT_SRAM #(
        .PE_SIZE(LANES),
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) u_sa (
        .clk(clk),
        .rst_n(rst_n),

        .start_i(sa_start_i),
        .M(cfg_m),
        .K(cfg_k),
        .N(cfg_n),

        .sram_req_valid(sa_sram_req_valid),
        .sram_data_valid(sa_input_data_valid_to_sa),

        .input_data(sa_input_data_q8),
        .weight_data(sa_weight_data_q8),

        .quantized_multiplier($signed(setup_r.desc.conv_requant_multiplier)),
        .shift($signed(setup_r.desc.conv_requant_shift)),
        .output_offset($signed(setup_r.desc.conv_requant_output_offset)),
        .act_min($signed(setup_r.desc.conv_activation_min)),
        .act_max($signed(setup_r.desc.conv_activation_max)),

        .busy(sa_busy),
        .sa_done(sa_done),

        .input_addr_x(sa_input_addr_x),
        .input_addr_y(sa_input_addr_y),
        .weight_addr_x(sa_weight_addr_x),
        .weight_addr_y(sa_weight_addr_y),

        .output_valid_i16(sa_out_valid_i16),
        .output_addr_x_i16(sa_out_addr_x_i16),
        .output_addr_y_i16(sa_out_addr_y_i16),
        .output_data_i16(sa_out_data_i16)
    );
    // ------------------------------------------------------------
    // LSU instance
    // ------------------------------------------------------------
    LSU #(
        .DRAM_ADDR_WIDTH(`DRAM_ADDR_WIDTH),
        .SRAM_ADDR_WIDTH(`SRAM_ADDR_WIDTH),
        .DATA_WIDTH(`SRAM_WIDTH_O)
    ) u_lsu (
        .clk(clk),
        .rst_n(rst_n),

        // Command interface
        .cmd_valid(lsu_valid),
        .cmd_ready(lsu_ready),
        .cmd_write(lsu_write),
        .cmd_bank(lsu_bank),
        .cmd_dram_base(lsu_dram_base),
        .cmd_sram_base(lsu_sram_base),
        .cmd_len(lsu_len),
        .busy(lsu_busy_sig),
        .done(lsu_complete),

        // DRAM read channel
        .dram_rd_valid(dram_rd_valid),
        .dram_rd_ready(dram_rd_ready),
        .dram_rd_addr(dram_rd_addr),
        .dram_rd_data_valid(dram_rd_data_valid),
        .dram_rd_data(dram_rd_data),

        // DRAM write channel
        .dram_wr_valid(dram_wr_valid),
        .dram_wr_ready(dram_wr_ready),
        .dram_wr_addr(dram_wr_addr),
        .dram_wr_data(lsu_dram_wr_data), //modified so we can mux the actual data going out to dram

        // Tensor SRAM write channel
        .bank_we(lsu_bank_we),
        .bank_wbank(lsu_bank_wbank),
        .bank_waddr(lsu_bank_waddr),
        .bank_wdata(lsu_bank_wdata),

        // LUT SRAM preload channel
        .lut_we(lsu_lut_we),
        .lut_waddr(lsu_lut_waddr),
        .lut_wdata(lsu_lut_wdata),

        // Instruction SRAM preload channel
        .inst_we(lsu_inst_we),
        .inst_waddr(lsu_inst_waddr),
        .inst_wdata(lsu_inst_wdata),

        // Descriptor SRAM preload channel
        .qdesc_we(lsu_desc_we),
        .qdesc_waddr(lsu_desc_waddr),
        .qdesc_wdata(lsu_desc_wdata),

        // Job word capture channel
        .job_we(lsu_job_we),
        .job_wdata(lsu_job_wdata),

        // Result-store SRAM read channel
        .store_sram_ren(lsu_store_sram_ren),
        .store_sram_bank(lsu_store_sram_bank),
        .store_sram_addr(lsu_store_sram_addr),
        .store_sram_rdata(tensor_src0_data)
    );
    // ------------------------------------------------------------
    // Local SRAM wrapper
    // ------------------------------------------------------------
    sram_unit #(
        .ADDR_WIDTH(`SRAM_ADDR_WIDTH)
    ) u_sram (
        .clk(clk),
        .rst_n(rst_n),

        // Tensor SRAM read/write ports. Tensor LOAD and compute share dst.
        .src0_bank(tensor_src0_bank),
        .src0_ren(tensor_src0_ren),
        .src0_addr(tensor_src0_addr),
        .src0_o(tensor_src0_data),

        .src1_bank(tensor_src1_bank),
        .src1_ren(tensor_src1_ren),
        .src1_addr(tensor_src1_addr),
        .src1_o(tensor_src1_data),

        .dst_bank(tensor_dst_bank),
        .dst_waddr(tensor_dst_waddr),
        .dst_data_i(tensor_dst_wdata),
        .dst_we(tensor_dst_we),

        // LUT preload port from LSU
        .pre_lut_addr(lsu_lut_waddr),
        .pre_lut_data(lsu_lut_wdata),
        .pre_lut_we(lsu_lut_we),

        // EXP LUT read port
        .exp_lut_sram_data_o(exp_lut_sram_data),
        .exp_lut_sram_en(exp_lut_sram_en),
        .exp_lut_data_addr(exp_lut_data_addr),

        // RCP LUT read port
        .reciprocal_lut_sram_data_o(reciprocal_lut_sram_data),
        .reciprocal_lut_sram_en(reciprocal_lut_sram_en),
        .reciprocal_lut_data_addr(reciprocal_lut_data_addr),

        // Instruction SRAM preload/read port
        .pre_inst_addr(lsu_inst_waddr),
        .pre_inst_data(lsu_inst_wdata),
        .pre_inst_we(lsu_inst_we),
        .inst_sram_data_o(inst_fetch_data),
        .inst_sram_en(inst_fetch_en),
        .inst_sram_addr(inst_fetch_addr),

        // Descriptor SRAM preload/read port
        .pre_desc_addr(lsu_desc_waddr),
        .pre_desc_data(lsu_desc_wdata),
        .pre_desc_we(lsu_desc_we),
        .desc_sram_data_o(fetch_desc_data),
        .desc_sram_en(fetch_desc_en),
        .desc_sram_addr(fetch_desc_addr)
    );
    // ------------------------------------------------------------
    // Element-wise stream controller
    // ------------------------------------------------------------
    controller #(
        .MN_WIDTH($clog2(MAX_M)),           // M/N bit width
        .LANES(LANES)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),

        // Control
        .op_valid_i(issue_op_valid),
        .op_code_i(issue_op_code),
        .M(cfg_m),
        .K(cfg_k),
        .N(cfg_n),
        .total_words_i(cfg_total_words),
        .done(ew_done),

        // Tensor SRAM read request
        .in_sram_en(load_sram_en),
        .in_sram_addr(load_sram_addr),
        .in_sram_rdata(load_sram_rdata),

        // SA address feedback
        .input_addr_x(sa_input_addr_x),
        .input_addr_y(sa_input_addr_y),
        .weight_addr_x(sa_weight_addr_x),
        .weight_addr_y(sa_weight_addr_y),
        .data_addr(sa_data_addr),
        .weight_addr(sa_weight_addr),

        // Element-wise request stream
        .sub_en(sub_en),
        .sub_data(sub_data_in),
        .add_en(add_en),
        .add_data(add_data_in),
        .mul_en(mul_en),
        .mul_data(mul_data_in),
        .exp_en(exp_en),
        .exp_data(exp_data_in),
        .rcp_en(reciprocal_en),
        .rcp_data(reciprocal_data_in),

        // Element-wise response stream
        .sub_valid(sub_valid),
        .sub_output(sub_data_out),
        .add_valid(add_valid),
        .add_output(add_data_out),
        .mul_valid(mul_valid),
        .mul_output(mul_data_out),
        .exp_valid(exp_valid),
        .exp_output(exp_data_out),
        .rcp_valid(reciprocal_valid),
        .rcp_output(reciprocal_data_out),

        // Tensor SRAM writeback stream
        .out_sram_we(ew_we),
        .out_sram_addr(ew_waddr),
        .out_sram_wdata(ew_wdata)
    );
    // ------------------------------------------------------------
    // Element-wise arithmetic/LUT unit
    // ------------------------------------------------------------
    // ADD/SUB/EXP/RCP consume INT16 lanes; MUL consumes requantized INT8 lanes.
    element_wise_LUT #(
        .LANES(LANES)
    ) u_ew (
        .clk(clk),
        .rst(rst_n),
        .init(1'b0),

        // Group count
        .groups(1),

        // EXP params
        .exp_deq_input_range_radius($signed(setup_r.desc.exp_deq_input_range_radius)),
        .exp_deq_input_zero_point($signed(setup_r.desc.exp_deq_input_zero_point)),
        .exp_deq_input_left_shift($signed(setup_r.desc.exp_deq_input_left_shift)),
        .exp_deq_input_multiplier($signed(setup_r.desc.exp_deq_input_multiplier)),
        .exp_req_input_quantized_multiplier($signed(setup_r.desc.exp_req_input_quantized_multiplier)),
        .exp_req_input_shift($signed(setup_r.desc.exp_req_input_shift)),
        .exp_req_input_offset($signed(setup_r.desc.exp_req_input_offset)),

        // RCP params
        .reciprocal_deq_input_zero_point($signed(setup_r.desc.rcp_deq_input_zero_point)),
        .reciprocal_deq_input_range_radius($signed(setup_r.desc.rcp_deq_input_range_radius)),
        .reciprocal_deq_input_left_shift($signed(setup_r.desc.rcp_deq_input_left_shift)),
        .reciprocal_deq_input_multiplier($signed(setup_r.desc.rcp_deq_input_multiplier)),
        .reciprocal_req_input_quantized_multiplier($signed(setup_r.desc.rcp_req_input_quantized_multiplier)),
        .reciprocal_req_input_shift($signed(setup_r.desc.rcp_req_input_shift)),
        .reciprocal_req_input_offset($signed(setup_r.desc.rcp_req_input_offset)),

        // ADD params
        .add_input1_offset($signed(setup_r.desc.add_input1_offset)),
        .add_input2_offset($signed(setup_r.desc.add_input2_offset)),
        .add_left_shift($signed(setup_r.desc.add_left_shift)),
        .add_input1_multiplier(setup_r.desc.add_input1_multiplier),
        .add_input2_multiplier(setup_r.desc.add_input2_multiplier),
        .add_input1_shift($signed(setup_r.desc.add_input1_shift)),
        .add_input2_shift($signed(setup_r.desc.add_input2_shift)),
        .add_output_multiplier(setup_r.desc.add_output_multiplier),
        .add_output_shift($signed(setup_r.desc.add_output_shift)),
        .add_output_offset($signed(setup_r.desc.add_output_offset)),
        .add_quantized_activation_min($signed(setup_r.desc.add_activation_min)),
        .add_quantized_activation_max($signed(setup_r.desc.add_activation_max)),

        // SUB params
        .sub_input1_offset($signed(setup_r.desc.sub_input1_offset)),
        .sub_input2_offset($signed(setup_r.desc.sub_input2_offset)),
        .sub_left_shift($signed(setup_r.desc.sub_left_shift)),
        .sub_input1_multiplier(setup_r.desc.sub_input1_multiplier),
        .sub_input2_multiplier(setup_r.desc.sub_input2_multiplier),
        .sub_input1_shift($signed(setup_r.desc.sub_input1_shift)),
        .sub_input2_shift($signed(setup_r.desc.sub_input2_shift)),
        .sub_output_multiplier(setup_r.desc.sub_output_multiplier),
        .sub_output_shift($signed(setup_r.desc.sub_output_shift)),
        .sub_output_offset($signed(setup_r.desc.sub_output_offset)),
        .sub_quantized_activation_min($signed(setup_r.desc.sub_activation_min)),
        .sub_quantized_activation_max($signed(setup_r.desc.sub_activation_max)),

        // MUL params
        .mul_input1_offset($signed(setup_r.desc.mul_input1_offset)),
        .mul_input2_offset($signed(setup_r.desc.mul_input2_offset)),
        .mul_output_multiplier(setup_r.desc.mul_output_multiplier),
        .mul_output_shift($signed(setup_r.desc.mul_output_shift)),
        .mul_output_offset($signed(setup_r.desc.mul_output_offset)),
        .mul_quantized_activation_min($signed(setup_r.desc.mul_activation_min)),
        .mul_quantized_activation_max($signed(setup_r.desc.mul_activation_max)),

        // Enable and data ports
        .exp_en(exp_en),
        .exp_valid_out(exp_valid),
        .exp_data_in(exp_data_in),
        .exp_data_out(exp_data_out),
        .exp_load(exp_load_npu),
        .exp_lut_ready(exp_lut_ready),
        .exp_lut_sram_data_in(exp_lut_sram_data),
        .exp_lut_sram_en(exp_lut_sram_en),
        .exp_lut_data_addr(exp_lut_data_addr),

        .reciprocal_en(reciprocal_en),
        .reciprocal_valid_out(reciprocal_valid),
        .reciprocal_data_in(reciprocal_data_in),
        .reciprocal_data_out(reciprocal_data_out),
        .reciprocal_load(reciprocal_load_npu),
        .rcp_lut_ready(rcp_lut_ready),
        .reciprocal_lut_sram_data_in(reciprocal_lut_sram_data),
        .reciprocal_lut_sram_en(reciprocal_lut_sram_en),
        .reciprocal_lut_data_addr(reciprocal_lut_data_addr),

        .add_en(add_en),
        .add_valid_out(add_valid),
        .add_data_in(add_data_in),
        .add_data_out(add_data_out),
        .add_weight_data_in(ew_src1_data_selected),

        .sub_en(sub_en),
        .sub_valid_out(sub_valid),
        .sub_data_in(sub_data_in),
        .sub_data_out(sub_data_out),
        .sub_weight_data_in(ew_src1_data_selected),

        .mul_en(mul_input_valid),
        .mul_valid_out(mul_valid),
        .mul_data_in(mul_in1_data_q8),
        .mul_data_out(mul_data_out),
        .mul_weight_data_in(mul_in2_data_q8)
    );

endmodule