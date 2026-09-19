`timescale 1ns/1ps

module ahb_slave_top_tb;

    parameter ADDR_W = 8;
    parameter DATA_W = 32;

    reg         hclk_i;
    reg         hresetn_i;
    reg         hsel_i;
    reg [31:0]  haddr_i;
    reg [1:0]   htrans_i;
    reg         hwrite_i;
    reg [2:0]   hsize_i;
    reg         hreadyin_i;
    reg [DATA_W-1:0] hwdata_i;

    wire        hready_o;
    wire        hresp_o;
    wire [DATA_W-1:0] hrdata_o;

    amba_ahb_slave_core #(ADDR_W, DATA_W) my_ahb_slave (
        .HCLK(hclk_i),
        .HRESETn(hresetn_i),
        .HSEL(hsel_i),
        .HADDR(haddr_i),
        .HTRANS(htrans_i),
        .HWRITE(hwrite_i),
        .HSIZE(hsize_i),
        .HREADYIN(hreadyin_i),
        .HWDATA(hwdata_i),
        .HREADY(hready_o),
        .HRESP(hresp_o),
        .HRDATA(hrdata_o)
    );

    initial hclk_i = 0;
    always #5 hclk_i = ~hclk_i;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, ahb_slave_top_tb);

        hsel_i   = 0;
        haddr_i  = 0;
        htrans_i = 0;
        hwrite_i = 0;
        hsize_i  = 3'b010; 
        hreadyin_i = 1;
        hwdata_i   = 0;
        
        hresetn_i = 0; 
        #25;
        
        hresetn_i = 1;
        #15;
        
        @(posedge hclk_i);
        hsel_i   = 1;
        haddr_i  = 32'h0000_0004;
        htrans_i = 2'b10; 
        hwrite_i = 1;     

        @(posedge hclk_i);
        hwdata_i = 32'hDEAD_BEEF; 
        haddr_i  = 32'h0000_0008; 
        htrans_i = 2'b11;         

        @(posedge hclk_i);
        hwdata_i = 32'hCAFE_BABE; 
        haddr_i  = 32'h0000_0004; 
        hwrite_i = 0;             
        htrans_i = 2'b10;         

        @(posedge hclk_i);
        htrans_i = 2'b00; 
        hsel_i   = 0;     
        
        @(posedge hclk_i);
        #1; 
        $display("[USER_READ_TRACK] -> time=%0t | fetching data from offset 0x04 = %h", $time, hrdata_o);

        @(posedge hclk_i);
        hsel_i   = 1;
        haddr_i  = 32'h0000_0008;
        htrans_i = 2'b10;
        hwrite_i = 0;
        
        @(posedge hclk_i);
        htrans_i = 2'b00;
        hsel_i   = 0;
        
        @(posedge hclk_i);
        #1;
        $display("[USER_READ_TRACK] -> time=%0t | fetching data from offset 0x08 = %h", $time, hrdata_o);

        #80;
        $finish;
    end

endmodule
