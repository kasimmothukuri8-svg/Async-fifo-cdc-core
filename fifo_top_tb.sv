timescale 1ns/1ps

module fifo_top_tb;

    // testbench constraints matching design parameters
    parameter D_WIDTH = 16;
    parameter A_WIDTH = 5;

    // input registers
    reg clk_write;
    reg rst_write_n;
    reg write_increment;
    reg clk_read;
    reg rst_read_n;
    reg read_increment;
    reg [D_WIDTH-1:0] data_in_bus;
    
    // output wires
    wire [D_WIDTH-1:0] data_out_bus;
    wire buffer_full;
    wire buffer_empty;

    // internal array for manual scoreboard checking
    reg [D_WIDTH-1:0] local_ram [0:63];
    integer w_count = 0;
    integer r_count = 0;
    reg [D_WIDTH-1:0] curr_expected;

    // DUT connection
    my_custom_async_fifo #(D_WIDTH, A_WIDTH) uut_fifo (
        .clk_write(clk_write),
        .rst_write_n(rst_write_n),
        .write_increment(write_increment),
        .clk_read(clk_read),
        .rst_read_n(rst_read_n),
        .read_increment(read_increment),
        .data_in_bus(data_in_bus),
        .data_out_bus(data_out_bus),
        .buffer_full(buffer_full),
        .buffer_empty(buffer_empty)
    );

    // Write Clock Logic - 100MHz approx
    initial clk_write = 0;
    always #5 clk_write = ~clk_write;

    // Read Clock Logic - 50MHz approx (slower domain)
    initial clk_read = 0;
    always #10 clk_read = ~clk_read;

    // Manual block for writing data into fifo
    task push_item(input [D_WIDTH-1:0] val);
        begin
            @(posedge clk_write);
            if (buffer_full == 0) begin
                write_increment = 1;
                data_in_bus = val;
                local_ram[w_count] = val;
                w_count = w_count + 1;
                $display("[TB_WRITE] -> time=%0t | pushing payload=%h", $time, val);
            end else begin
                write_increment = 0;
                $display("[TB_WRITE_BLOCKED] -> memory array full, dropping=%h", val);
            end
            @(posedge clk_write);
            write_increment = 0;
        end
    endtask

    // Manual block for reading data from fifo
    task pop_item();
        begin
            @(posedge clk_read);
            if (buffer_empty == 0) begin
                read_increment = 1;
                curr_expected = local_ram[r_count];
                r_count = r_count + 1;
                #2; // slight gate delay
                if (data_out_bus == curr_expected) begin
                    $display("[TB_READ_PASS] -> time=%0t | read payload=%h | match ok", $time, data_out_bus);
                end else begin
                    $display("[TB_READ_FAIL] -> time=%0t | got=%h | expected=%h", $time, data_out_bus, curr_expected);
                end
            end else begin
                read_increment = 0;
                $display("[TB_READ_BLOCKED] -> memory empty, nothing to read");
            end
            @(posedge clk_read);
            read_increment = 0;
        end
    endtask

    // main test flow execution
    initial begin
        // setup wave dump for epwave tool
        $dumpfile("dump.vcd");
        $dumpvars(0, fifo_top_tb);

        // initial state setup
        write_increment = 0;
        read_increment = 0;
        data_in_bus = 0;
        rst_write_n = 0;
        rst_read_n = 0;

        // hold reset for a few cycles
        #35;
        rst_write_n = 1;
        rst_read_n = 1;
        $display("--- SYSTEM HARDWARE RESET RELEASED ---");
        #15;

        // TEST CASE 1: continuous loading till 32 locations fill up
        $display("\n--- RUNNING TEST CASE 1: BURST WRITES ---");
        push_item(16'hAAAA);
        push_item(16'hBBBB);
        push_item(16'hCCCC);
        push_item(16'hDDDD);
        push_item(16'h1111);
        push_item(16'h2222);
        push_item(16'h3333);
        push_item(16'h4444);
        push_item(16'h5555);
        push_item(16'h6666);
        push_item(16'h7777);
        push_item(16'h8888);
        push_item(16'h9999);
        push_item(16'hFAFA);
        push_item(16'hEBEB);
        push_item(16'hDCDC);
        
        // filling up remaining spots to test full limit flags
        repeat(20) begin
            push_item($random % 16'hFFFF);
            #1;
        end

        #80;

        // TEST CASE 2: continuous draining to read back everything
        $display("\n--- RUNNING TEST CASE 2: BURST READS ---");
        repeat(36) begin
            pop_item();
            #3;
        end

        #100;
        $display("\n--- TEST BENCH SIMULATION ENDED ---");
        $finish;
    end

endmodule
