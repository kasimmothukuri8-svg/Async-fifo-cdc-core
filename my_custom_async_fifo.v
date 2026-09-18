module fifo_storage_core #(parameter DATA_WIDTH = 16, parameter ADDR_WIDTH = 5) (
    input  clk_write,
    input  write_enable,
    input  buffer_full,
    input  [ADDR_WIDTH-1:0] w_pointer_addr,
    input  [ADDR_WIDTH-1:0] r_pointer_addr,
    input  [DATA_WIDTH-1:0] data_in_bus,
    output [DATA_WIDTH-1:0] data_out_bus
);
    localparam MEM_DEPTH = 1 << ADDR_WIDTH; // 32 Locations
    reg [DATA_WIDTH-1:0] registers_matrix [0:MEM_DEPTH-1];

    assign data_out_bus = registers_matrix[r_pointer_addr];

    always @(posedge clk_write) begin
        if (write_enable && !buffer_full)
            registers_matrix[w_pointer_addr] <= data_in_bus;
    end
endmodule

// 2. Multi-stage CDC Flip-Flop Synchronizer
module cdc_bits_synchronizer #(parameter ADDR_WIDTH = 5) (
    input  clk_destination,
    input  rst_dest_n,
    input  [ADDR_WIDTH:0] async_ptr_in, 
    output reg [ADDR_WIDTH:0] sync_ptr_out
);
    reg [ADDR_WIDTH:0] stage1_flop;
    always @(posedge clk_destination or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            stage1_flop  <= 0;
            sync_ptr_out <= 0;
        end else begin
            stage1_flop  <= async_ptr_in;   // First staging
            sync_ptr_out <= stage1_flop;    // Stabilized output
        end
    end
endmodule

// 3. READ DOMAIN CONTROLLER & EMPTY LOGIC
module read_domain_ctrl #(parameter ADDR_WIDTH = 5) (
    input  clk_read,
    input  rst_read_n,
    input  read_increment,
    input  [ADDR_WIDTH:0] synchronized_wptr, 
    output reg buffer_empty,
    output [ADDR_WIDTH-1:0] r_addr_out,
    output reg [ADDR_WIDTH:0] r_gray_ptr_out
);
    reg [ADDR_WIDTH:0] read_binary_counter;
    wire [ADDR_WIDTH:0] next_r_bin, next_r_gray;
    wire is_empty_cond;

    always @(posedge clk_read or negedge rst_read_n) begin 
        if (!rst_read_n) begin
            read_binary_counter <= 0;
            r_gray_ptr_out      <= 0;
        end else begin
            read_binary_counter <= next_r_bin;
            r_gray_ptr_out      <= next_r_gray;
        end
    end

    assign next_r_bin  = read_binary_counter + (read_increment & ~buffer_empty);
    assign next_r_gray = next_r_bin ^ (next_r_bin >> 1); 
    assign r_addr_out  = read_binary_counter[ADDR_WIDTH-1:0];

    assign is_empty_cond = (next_r_gray == synchronized_wptr);
    always @(posedge clk_read or negedge rst_read_n) begin
        if (!rst_read_n) buffer_empty <= 1'b1;
        else             buffer_empty <= is_empty_cond;
    end
endmodule

// 4. WRITE DOMAIN CONTROLLER & FULL LOGIC
module write_domain_ctrl #(parameter ADDR_WIDTH = 5) (
    input  clk_write,
    input  rst_write_n,
    input  write_increment,
    input  [ADDR_WIDTH:0] synchronized_rptr, 
    output reg buffer_full,
    output [ADDR_WIDTH-1:0] w_addr_out,
    output reg [ADDR_WIDTH:0] w_gray_ptr_out
);
    reg [ADDR_WIDTH:0] write_binary_counter;
    wire [ADDR_WIDTH:0] next_w_bin, next_w_gray;
    wire is_full_cond;

    always @(posedge clk_write or negedge rst_write_n) begin
        if (!rst_write_n) begin
            write_binary_counter <= 0;
            w_gray_ptr_out       <= 0;
        end else begin
            write_binary_counter <= next_w_bin;
            w_gray_ptr_out       <= next_w_gray;
        end
    end

    assign next_w_bin   = write_binary_counter + (write_increment & ~buffer_full);
    assign next_w_gray  = next_w_bin ^ (next_w_bin >> 1);
    assign w_addr_out   = write_binary_counter[ADDR_WIDTH-1:0];

    assign is_full_cond = (next_w_gray == {~synchronized_rptr[ADDR_WIDTH:ADDR_WIDTH-1], synchronized_rptr[ADDR_WIDTH-2:0]});
    always @(posedge clk_write or negedge rst_write_n) begin
        if (!rst_write_n) buffer_full <= 1'b0;
        else              buffer_full <= is_full_cond;
    end
endmodule

// 5. TOP LEVEL INSTANTIATION
module my_custom_async_fifo #(parameter DATA_WIDTH = 16, parameter ADDR_WIDTH = 5) (
    input  clk_write, rst_write_n, write_increment,
    input  clk_read, rst_read_n, read_increment,
    input  [DATA_WIDTH-1:0] data_in_bus,
    output [DATA_WIDTH-1:0] data_out_bus,
    output buffer_full, buffer_empty
);
    wire [ADDR_WIDTH-1:0] w_addr_out, r_addr_out;
    wire [ADDR_WIDTH:0]   w_gray_ptr_out, r_gray_ptr_out, synchronized_rptr, synchronized_wptr;

    // Cross Domain Synchronizers
    cdc_bits_synchronizer #(ADDR_WIDTH) sync_r2w (.clk_destination(clk_write), .rst_dest_n(rst_write_n), .async_ptr_in(r_gray_ptr_out), .sync_ptr_out(synchronized_rptr));
    cdc_bits_synchronizer #(ADDR_WIDTH) sync_w2r (.clk_destination(clk_read), .rst_dest_n(rst_read_n), .async_ptr_in(w_gray_ptr_out), .sync_ptr_out(synchronized_wptr));

    // Module Maps
    fifo_storage_core #(DATA_WIDTH, ADDR_WIDTH) storage (.clk_write(clk_write), .write_enable(write_increment), .buffer_full(buffer_full), .w_pointer_addr(w_addr_out), .r_pointer_addr(r_addr_out), .data_in_bus(data_in_bus), .data_out_bus(data_out_bus));
    read_domain_ctrl  #(ADDR_WIDTH) r_ctrl (.clk_read(clk_read), .rst_read_n(rst_read_n), .read_increment(read_increment), .synchronized_wptr(synchronized_wptr), .buffer_empty(buffer_empty), .r_addr_out(r_addr_out), .r_gray_ptr_out(r_gray_ptr_out));
    write_domain_ctrl #(ADDR_WIDTH) w_ctrl (.clk_write(clk_write), .rst_write_n(rst_write_n), .write_increment(write_increment), .synchronized_rptr(synchronized_rptr), .buffer_full(buffer_full), .w_addr_out(w_addr_out), .w_gray_ptr_out(w_gray_ptr_out));

endmodule

