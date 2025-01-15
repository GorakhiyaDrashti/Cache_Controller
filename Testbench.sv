// Define constants
`define ADDR_WIDTH 64
`define DATA_WIDTH 32
`define L1_CACHE_SIZE 256 // Number of lines in L1
`define L2_CACHE_SIZE 1024 // Number of sets in L2
`define L2_WAYS 4         // 4-way set associative for L2
`define L2_BLOCK_SIZE 4   // Number of words per block in L2

// Calculate tag sizes
`define L1_INDEX_BITS 8  // log2(L1_CACHE_SIZE)
`define L1_TAG_BITS (`ADDR_WIDTH - `L1_INDEX_BITS - 0) // No block offset for L1
`define L2_INDEX_BITS 10 // log2(L2_CACHE_SIZE)
`define L2_BLOCK_OFFSET_BITS 2 // log2(L2_BLOCK_SIZE)
`define L2_TAG_BITS (`ADDR_WIDTH - `L2_INDEX_BITS - `L2_BLOCK_OFFSET_BITS)

module CacheControllerTB;

    // Testbench signals
    logic clk;
    logic reset;
    logic [`ADDR_WIDTH-1:0] address;
    logic read_write;
    logic [`DATA_WIDTH-1:0] write_data;
    logic [`DATA_WIDTH-1:0] read_data;
    logic hit;
    logic miss;

    CacheController dut (
        .clk(clk),
        .reset(reset),
        .address(address),
        .read_write(read_write),
        .write_data(write_data),
        .read_data(read_data),
        .hit(hit),
        .miss(miss)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Generate a clock with a period of 10 time units
    end

    // Reset logic
    initial begin
        reset = 1;
        #10 reset = 0; 
    end

task display_cache_and_memory;
    integer i, j;
    $display("\nL1 Cache:");
    for (i = 0; i < `L1_CACHE_SIZE; i++) begin
        if (dut.L1[i].valid) begin
            $display("L1[%0d]: Valid=%0d, Tag=%h, Data=%h", i, dut.L1[i].valid, dut.L1[i].tag, dut.L1[i].data);
        end
    end

    $display("\nL2 Cache:");
    for (i = 0; i < `L2_CACHE_SIZE; i++) begin
        for (j = 0; j < `L2_WAYS; j++) begin
            if (dut.L2[i][j].valid) begin
                $display("L2[%0d][%0d]: Valid=%0d, Tag=%h, Data=%h %h %h %h", 
                         i, j, dut.L2[i][j].valid, dut.L2[i][j].tag, 
                         dut.L2[i][j].data[0], dut.L2[i][j].data[1], dut.L2[i][j].data[2], dut.L2[i][j].data[3]);
            end
        end
    end

    $display("\nMain Memory:");
    for (i = 0; i < 16; i++) begin
        if (dut.MainMemory[i] !== 32'hX) begin 
            $display("Memory[%0d]: %h", i, dut.MainMemory[i]);
        end
    end
endtask


    // Test logic
    initial begin
        @(negedge reset);

        address = 64'h0000_0000;     
        write_data = 32'h1234;
        #20;                         
        display_cache_and_memory();
      
        read_write = 0;             
        address = 64'h0000_0000;     
        //write_data = 32'h1234;
        #20;
        display_cache_and_memory();

        $stop; 
    end

endmodule
